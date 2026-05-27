-- ClaudeMCP Plugin for Roblox Studio
-- Multi-AI chat assistant with support for Groq, Gemini, Ollama, HuggingFace, Claude, Mistral, DeepSeek, SambaNova
-- All providers are FREE to use
--
-- Install: Place this file in your Roblox Studio plugins folder
--   Windows: %LOCALAPPDATA%\Roblox\Plugins\
--   macOS: ~/Documents/Roblox/Plugins/

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local TweenService = game:GetService("TweenService")

-- ============================================================
-- CONFIGURATION
-- ============================================================
local SERVER_URL = "http://localhost:3636"
local POLL_INTERVAL = 0.15

-- ============================================================
-- THEME
-- ============================================================
local COLORS = {
	bg = Color3.fromRGB(25, 25, 30),
	bgLight = Color3.fromRGB(35, 35, 42),
	bgDark = Color3.fromRGB(18, 18, 22),
	accent = Color3.fromRGB(100, 80, 220),
	accentDim = Color3.fromRGB(70, 55, 160),
	accentLight = Color3.fromRGB(140, 120, 255),
	text = Color3.fromRGB(230, 230, 235),
	textDim = Color3.fromRGB(140, 140, 150),
	textMuted = Color3.fromRGB(90, 90, 100),
	success = Color3.fromRGB(70, 200, 120),
	error = Color3.fromRGB(220, 70, 70),
	warning = Color3.fromRGB(220, 170, 50),
	userBubble = Color3.fromRGB(45, 55, 90),
	aiBubble = Color3.fromRGB(35, 35, 45),
	toolBubble = Color3.fromRGB(50, 45, 30),
	systemBubble = Color3.fromRGB(30, 30, 38),
	divider = Color3.fromRGB(45, 45, 55),
	inputBg = Color3.fromRGB(30, 30, 38),
	dropdownBg = Color3.fromRGB(28, 28, 35),
	dropdownHover = Color3.fromRGB(45, 45, 55),
	settingsBg = Color3.fromRGB(22, 22, 28),
}

-- ============================================================
-- STATE
-- ============================================================
local state = {
	connected = false,
	running = true,
	serverConnected = false,
	providers = {},
	activeProvider = "Groq",
	settingsOpen = false,
	chatMessages = {},
	isThinking = false,
}

-- ============================================================
-- UTILITY: Resolve path to instance
-- ============================================================
local function resolvePath(pathStr)
	if pathStr == "game" then return game end
	local parts = string.split(pathStr, ".")
	local current = game
	for i, part in ipairs(parts) do
		if i == 1 and part == "game" then continue end
		local child = current:FindFirstChild(part)
		if not child then return nil end
		current = child
	end
	return current
end

local function getPathString(instance)
	if instance == game then return "game" end
	local parts = {}
	local current = instance
	while current and current ~= game do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	table.insert(parts, 1, "game")
	return table.concat(parts, ".")
end

local function serializeValue(value, depth)
	depth = depth or 0
	if depth > 4 then return tostring(value) end
	local t = typeof(value)
	if t == "string" or t == "number" or t == "boolean" then return value end
	if t == "nil" then return nil end
	if t == "Vector3" then return { __type = "Vector3", x = value.X, y = value.Y, z = value.Z } end
	if t == "CFrame" then
		local p = value.Position
		return { __type = "CFrame", x = p.X, y = p.Y, z = p.Z }
	end
	if t == "Color3" then return { __type = "Color3", r = value.R, g = value.G, b = value.B } end
	if t == "BrickColor" then return { __type = "BrickColor", name = value.Name } end
	if t == "UDim2" then
		return { __type = "UDim2", xs = value.X.Scale, xo = value.X.Offset, ys = value.Y.Scale, yo = value.Y.Offset }
	end
	if t == "Instance" then
		return { __type = "Instance", path = getPathString(value), className = value.ClassName, name = value.Name }
	end
	if t == "table" then
		if #value > 0 then
			local arr = {}
			for _, v in ipairs(value) do table.insert(arr, serializeValue(v, depth + 1)) end
			return arr
		else
			local obj = {}
			for k, v in pairs(value) do obj[tostring(k)] = serializeValue(v, depth + 1) end
			return obj
		end
	end
	return tostring(value)
end

local function buildHierarchy(instance, depth, maxDepth)
	if depth > maxDepth then
		return { name = instance.Name, class = instance.ClassName, children = "..." }
	end
	local children = {}
	for _, child in ipairs(instance:GetChildren()) do
		table.insert(children, buildHierarchy(child, depth + 1, maxDepth))
	end
	return { name = instance.Name, class = instance.ClassName, path = getPathString(instance), children = children }
end

-- ============================================================
-- TOOL HANDLERS
-- ============================================================
local handlers = {}

function handlers.get_hierarchy(args)
	local path = args.path or "game"
	local depth = args.depth or 3
	local instance = resolvePath(path)
	if not instance then return { error = "Not found: " .. path } end
	return buildHierarchy(instance, 0, depth)
end

function handlers.read_script(args)
	local instance = resolvePath(args.path)
	if not instance then return { error = "Not found: " .. args.path } end
	if not instance:IsA("LuaSourceContainer") then
		return { error = "Not a script (class: " .. instance.ClassName .. ")" }
	end
	return { source = instance.Source, className = instance.ClassName, path = args.path }
end

function handlers.write_script(args)
	local instance = resolvePath(args.path)
	if not instance then return { error = "Not found: " .. args.path } end
	if not instance:IsA("LuaSourceContainer") then
		return { error = "Not a script (class: " .. instance.ClassName .. ")" }
	end
	ChangeHistoryService:SetWaypoint("AI_WriteScript")
	instance.Source = args.source
	ChangeHistoryService:SetWaypoint("AI_WriteScript_Done")
	return { success = true, path = args.path }
end

function handlers.create_script(args)
	local parent = resolvePath(args.parent)
	if not parent then return { error = "Not found: " .. args.parent } end
	ChangeHistoryService:SetWaypoint("AI_CreateScript")
	local s = Instance.new(args.className or "Script")
	s.Name = args.name
	s.Source = args.source or ""
	s.Parent = parent
	ChangeHistoryService:SetWaypoint("AI_CreateScript_Done")
	return { success = true, path = args.parent .. "." .. args.name, className = s.ClassName }
end

function handlers.delete_instance(args)
	local instance = resolvePath(args.path)
	if not instance then return { error = "Not found: " .. args.path } end
	if instance == game then return { error = "Cannot delete game" } end
	ChangeHistoryService:SetWaypoint("AI_Delete")
	local name = args.path
	instance:Destroy()
	ChangeHistoryService:SetWaypoint("AI_Delete_Done")
	return { success = true, deleted = name }
end

function handlers.get_properties(args)
	local instance = resolvePath(args.path)
	if not instance then return { error = "Not found: " .. args.path } end
	local props = {}
	local ok, propList = pcall(function() return instance:GetProperties() end)
	if ok then
		for _, name in ipairs(propList) do
			local s, v = pcall(function() return instance[name] end)
			if s then props[name] = serializeValue(v) end
		end
	end
	return { path = args.path, className = instance.ClassName, properties = props }
end

function handlers.set_property(args)
	local instance = resolvePath(args.path)
	if not instance then return { error = "Not found: " .. args.path } end
	local prop = args.property
	local val = args.value
	local cur = instance[prop]
	local parsed
	if typeof(cur) == "number" then
		parsed = tonumber(val)
	elseif typeof(cur) == "boolean" then
		parsed = (val == "true")
	elseif typeof(cur) == "Vector3" then
		local p = string.split(val, ",")
		if #p == 3 then parsed = Vector3.new(tonumber(p[1]), tonumber(p[2]), tonumber(p[3])) end
	elseif typeof(cur) == "Color3" then
		local p = string.split(val, ",")
		if #p == 3 then parsed = Color3.new(tonumber(p[1]), tonumber(p[2]), tonumber(p[3])) end
	elseif typeof(cur) == "CFrame" then
		local fn = loadstring("return CFrame.new(" .. val .. ")")
		if fn then parsed = fn() end
	else
		parsed = val
	end
	if parsed == nil then return { error = "Could not parse value: " .. val } end
	ChangeHistoryService:SetWaypoint("AI_SetProp")
	local ok, err = pcall(function() instance[prop] = parsed end)
	ChangeHistoryService:SetWaypoint("AI_SetProp_Done")
	if not ok then return { error = "Failed: " .. tostring(err) } end
	return { success = true, path = args.path, property = prop }
end

function handlers.execute_lua(args)
	local fn, err = loadstring(args.code)
	if not fn then return { error = "Compile error: " .. tostring(err) } end
	setfenv(fn, getfenv())
	ChangeHistoryService:SetWaypoint("AI_ExecuteLua")
	local results = { pcall(fn) }
	ChangeHistoryService:SetWaypoint("AI_ExecuteLua_Done")
	local ok = table.remove(results, 1)
	if not ok then return { error = "Runtime error: " .. tostring(results[1]) } end
	if #results == 0 then return { success = true, message = "No return value" } end
	local ser = {}
	for i, v in ipairs(results) do ser[i] = serializeValue(v) end
	return #ser == 1 and { result = ser[1] } or { results = ser }
end

function handlers.search_instances(args)
	local root = resolvePath(args.root or "game")
	if not root then return { error = "Not found: " .. (args.root or "game") } end
	local max = args.maxResults or 50
	local results = {}
	local function search(parent)
		if #results >= max then return end
		for _, child in ipairs(parent:GetChildren()) do
			if #results >= max then break end
			local match = true
			if args.className and child.ClassName ~= args.className then match = false end
			if args.name and not string.find(child.Name:lower(), args.name:lower()) then match = false end
			if match then
				table.insert(results, { name = child.Name, class = child.ClassName, path = getPathString(child) })
			end
			search(child)
		end
	end
	search(root)
	return { results = results, count = #results }
end

function handlers.get_selection()
	local sel = Selection:Get()
	local paths = {}
	for _, inst in ipairs(sel) do table.insert(paths, getPathString(inst)) end
	return { selection = paths, count = #paths }
end

function handlers.set_selection(args)
	local instances = {}
	for _, path in ipairs(args.paths) do
		local inst = resolvePath(path)
		if not inst then return { error = "Not found: " .. path } end
		table.insert(instances, inst)
	end
	Selection:Set(instances)
	return { success = true, selected = args.paths }
end

local function processRequest(data)
	local handler = handlers[data.tool]
	if not handler then return { id = data.id, error = "Unknown tool: " .. data.tool } end
	local ok, result = pcall(handler, data.args or {})
	if not ok then return { id = data.id, error = "Handler error: " .. tostring(result) } end
	return { id = data.id, result = result }
end

-- ============================================================
-- GUI CREATION
-- ============================================================
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right, false, false, 440, 650, 380, 500
)

local widget = plugin:CreateDockWidgetPluginGui("ClaudeMCP_Widget", widgetInfo)
widget.Title = "AI Assistant"
widget.Name = "AIAssistant_GUI"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main frame
local main = Instance.new("Frame")
main.Size = UDim2.new(1, 0, 1, 0)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Parent = widget

-- ============================================================
-- HEADER
-- ============================================================
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = COLORS.bgDark
header.BorderSizePixel = 0
header.Parent = main

local headerLine = Instance.new("Frame")
headerLine.Size = UDim2.new(1, 0, 0, 1)
headerLine.Position = UDim2.new(0, 0, 1, -1)
headerLine.BackgroundColor3 = COLORS.divider
headerLine.BorderSizePixel = 0
headerLine.Parent = header

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 100, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "AI Assistant"
titleLabel.TextColor3 = COLORS.text
titleLabel.TextSize = 15
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

-- Status dot
local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 115, 0.5, -4)
statusDot.BackgroundColor3 = COLORS.error
statusDot.BorderSizePixel = 0
statusDot.Parent = header
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

-- Provider dropdown button
local dropdownBtn = Instance.new("TextButton")
dropdownBtn.Size = UDim2.new(0, 120, 0, 28)
dropdownBtn.Position = UDim2.new(1, -180, 0.5, -14)
dropdownBtn.BackgroundColor3 = COLORS.accentDim
dropdownBtn.BorderSizePixel = 0
dropdownBtn.Text = "  Groq  ▾"
dropdownBtn.TextColor3 = COLORS.text
dropdownBtn.TextSize = 12
dropdownBtn.Font = Enum.Font.GothamMedium
dropdownBtn.TextXAlignment = Enum.TextXAlignment.Center
dropdownBtn.Parent = header
Instance.new("UICorner", dropdownBtn).CornerRadius = UDim.new(0, 6)

-- Settings button
local settingsBtn = Instance.new("TextButton")
settingsBtn.Size = UDim2.new(0, 28, 0, 28)
settingsBtn.Position = UDim2.new(1, -44, 0.5, -14)
settingsBtn.BackgroundColor3 = COLORS.bgLight
settingsBtn.BorderSizePixel = 0
settingsBtn.Text = "⚙"
settingsBtn.TextColor3 = COLORS.textDim
settingsBtn.TextSize = 16
settingsBtn.Font = Enum.Font.GothamBold
settingsBtn.Parent = header
Instance.new("UICorner", settingsBtn).CornerRadius = UDim.new(0, 6)

-- ============================================================
-- PROVIDER DROPDOWN MENU
-- ============================================================
local dropdownOpen = false
local dropdownFrame = Instance.new("Frame")
dropdownFrame.Size = UDim2.new(0, 120, 0, 0)
dropdownFrame.Position = UDim2.new(1, -180, 0, 50)
dropdownFrame.BackgroundColor3 = COLORS.dropdownBg
dropdownFrame.BorderSizePixel = 0
dropdownFrame.Visible = false
dropdownFrame.ZIndex = 10
dropdownFrame.Parent = main
Instance.new("UICorner", dropdownFrame).CornerRadius = UDim.new(0, 6)

local dropdownLayout = Instance.new("UIListLayout")
dropdownLayout.Parent = dropdownFrame

local providerNames = {"Groq", "Gemini", "Ollama", "HuggingFace", "Claude", "Mistral", "DeepSeek", "SambaNova"}

local function updateDropdown()
	for _, child in ipairs(dropdownFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local totalH = 0
	for _, name in ipairs(providerNames) do
		local opt = Instance.new("TextButton")
		opt.Size = UDim2.new(1, 0, 0, 32)
		opt.BackgroundColor3 = COLORS.dropdownBg
		opt.BackgroundTransparency = 1
		opt.BorderSizePixel = 0
		opt.Text = "  " .. name
		opt.TextColor3 = name == state.activeProvider and COLORS.accentLight or COLORS.text
		opt.TextSize = 12
		opt.Font = Enum.Font.GothamMedium
		opt.TextXAlignment = Enum.TextXAlignment.Left
		opt.ZIndex = 11
		opt.Parent = dropdownFrame

		opt.MouseEnter:Connect(function()
			opt.BackgroundColor3 = COLORS.dropdownHover
			opt.BackgroundTransparency = 0
		end)
		opt.MouseLeave:Connect(function()
			opt.BackgroundTransparency = 1
		end)

		opt.MouseButton1Click:Connect(function()
			state.activeProvider = name
			dropdownBtn.Text = "  " .. name .. "  ▾"
			dropdownFrame.Visible = false
			dropdownOpen = false

			-- Notify server
			pcall(function()
				HttpService:PostAsync(
					SERVER_URL .. "/provider",
					HttpService:JSONEncode({ name = name }),
					Enum.HttpContentType.ApplicationJson
				)
			end)
		end)

		totalH = totalH + 32
	end

	dropdownFrame.Size = UDim2.new(0, 120, 0, totalH)
end

dropdownBtn.MouseButton1Click:Connect(function()
	dropdownOpen = not dropdownOpen
	dropdownFrame.Visible = dropdownOpen
	if dropdownOpen then updateDropdown() end
end)

-- ============================================================
-- SETTINGS PANEL
-- ============================================================
local settingsPanel = Instance.new("ScrollingFrame")
settingsPanel.Size = UDim2.new(1, 0, 1, -50)
settingsPanel.Position = UDim2.new(0, 0, 0, 50)
settingsPanel.BackgroundColor3 = COLORS.settingsBg
settingsPanel.BorderSizePixel = 0
settingsPanel.ScrollBarThickness = 5
settingsPanel.ScrollBarImageColor3 = COLORS.accent
settingsPanel.Visible = false
settingsPanel.ZIndex = 5
settingsPanel.CanvasSize = UDim2.new(0, 0, 0, 650)
settingsPanel.Parent = main

local settingsPadding = Instance.new("UIPadding")
settingsPadding.PaddingLeft = UDim.new(0, 16)
settingsPadding.PaddingRight = UDim.new(0, 16)
settingsPadding.PaddingTop = UDim.new(0, 16)
settingsPadding.Parent = settingsPanel

local function createSettingsField(label, placeholder, yPos, isPassword)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 18)
	lbl.Position = UDim2.new(0, 0, 0, yPos)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = COLORS.text
	lbl.TextSize = 12
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 6
	lbl.Parent = settingsPanel

	local input = Instance.new("TextBox")
	input.Size = UDim2.new(1, 0, 0, 32)
	input.Position = UDim2.new(0, 0, 0, yPos + 22)
	input.BackgroundColor3 = COLORS.inputBg
	input.BorderSizePixel = 0
	input.Text = ""
	input.PlaceholderText = placeholder
	input.PlaceholderColor3 = COLORS.textMuted
	input.TextColor3 = COLORS.text
	input.TextSize = 12
	input.Font = Enum.Font.Gotham
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.ClearTextOnFocus = false
	input.ZIndex = 6
	input.Parent = settingsPanel
	Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)

	local pad = Instance.new("UIPadding")
	paddingLeft = UDim.new(0, 8)
	paddingRight = UDim.new(0, 8)
	pad.Parent = input

	return input
end

local groqKeyInput = createSettingsField("Groq API Key", "gsk_... (free at console.groq.com)", 0)
local geminiKeyInput = createSettingsField("Gemini API Key", "AIza... (free at aistudio.google.com)", 60)
local hfKeyInput = createSettingsField("HuggingFace Token", "hf_... (free at huggingface.co)", 120)
local ollamaUrlInput = createSettingsField("Ollama URL", "http://localhost:11434", 180)
local claudeKeyInput = createSettingsField("Claude API Key", "sk-ant-... (free tier at console.anthropic.com)", 240)
local mistralKeyInput = createSettingsField("Mistral API Key", "... (free at console.mistral.ai)", 300)
local deepseekKeyInput = createSettingsField("DeepSeek API Key", "... (free at platform.deepseek.com)", 360)
local sambanovaKeyInput = createSettingsField("SambaNova API Key", "... (free at cloud.sambanova.ai)", 420)

-- Save button
local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(1, 0, 0, 36)
saveBtn.Position = UDim2.new(0, 0, 0, 500)
saveBtn.BackgroundColor3 = COLORS.accent
saveBtn.BorderSizePixel = 0
saveBtn.Text = "Save Settings"
saveBtn.TextColor3 = COLORS.text
saveBtn.TextSize = 13
saveBtn.Font = Enum.Font.GothamBold
saveBtn.ZIndex = 6
saveBtn.Parent = settingsPanel
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 6)

-- Help text
local helpText = Instance.new("TextLabel")
helpText.Size = UDim2.new(1, 0, 0, 100)
helpText.Position = UDim2.new(0, 0, 0, 550)
helpText.BackgroundTransparency = 1
helpText.Text = "All providers are FREE.\n\nGroq: Fastest. console.groq.com\nGemini: Best quality. aistudio.google.com\nOllama: 100% local. No key needed\nHuggingFace: Many models. huggingface.co\nClaude: Smart AI. console.anthropic.com\nMistral: Fast EU AI. console.mistral.ai\nDeepSeek: Code expert. platform.deepseek.com\nSambaNova: Free Llama. cloud.sambanova.ai"
helpText.TextColor3 = COLORS.textDim
helpText.TextSize = 11
helpText.Font = Enum.Font.Gotham
helpText.TextXAlignment = Enum.TextXAlignment.Left
helpText.TextYAlignment = Enum.TextYAlignment.Top
helpText.TextWrapped = true
helpText.ZIndex = 6
helpText.Parent = settingsPanel

saveBtn.MouseButton1Click:Connect(function()
	local configs = {
		{ provider = "Groq", apiKey = groqKeyInput.Text },
		{ provider = "Gemini", apiKey = geminiKeyInput.Text },
		{ provider = "HuggingFace", apiKey = hfKeyInput.Text },
		{ provider = "Ollama", baseUrl = ollamaUrlInput.Text ~= "" and ollamaUrlInput.Text or nil },
		{ provider = "Claude", apiKey = claudeKeyInput.Text },
		{ provider = "Mistral", apiKey = mistralKeyInput.Text },
		{ provider = "DeepSeek", apiKey = deepseekKeyInput.Text },
		{ provider = "SambaNova", apiKey = sambanovaKeyInput.Text },
	}

	for _, cfg in ipairs(configs) do
		pcall(function()
			HttpService:PostAsync(
				SERVER_URL .. "/config",
				HttpService:JSONEncode(cfg),
				Enum.HttpContentType.ApplicationJson
			)
		end)
	end

	saveBtn.Text = "Saved!"
	task.wait(1.5)
	saveBtn.Text = "Save Settings"
end)

settingsBtn.MouseButton1Click:Connect(function()
	state.settingsOpen = not state.settingsOpen
	settingsPanel.Visible = state.settingsOpen
end)

-- ============================================================
-- CHAT AREA
-- ============================================================
local chatArea = Instance.new("ScrollingFrame")
chatArea.Size = UDim2.new(1, 0, 1, -108)
chatArea.Position = UDim2.new(0, 0, 0, 50)
chatArea.BackgroundColor3 = COLORS.bg
chatArea.BorderSizePixel = 0
chatArea.ScrollBarThickness = 5
chatArea.ScrollBarImageColor3 = COLORS.accentDim
chatArea.CanvasSize = UDim2.new(0, 0, 0, 0)
chatArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
chatArea.Parent = main

local chatLayout = Instance.new("UIListLayout")
chatLayout.Padding = UDim.new(0, 6)
chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
chatLayout.Parent = chatArea

local chatPad = Instance.new("UIPadding")
chatPad.PaddingLeft = UDim.new(0, 10)
chatPad.PaddingRight = UDim.new(0, 10)
chatPad.PaddingTop = UDim.new(0, 10)
chatPad.PaddingBottom = UDim.new(0, 10)
chatPad.Parent = chatArea

-- ============================================================
-- INPUT AREA
-- ============================================================
local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, 0, 0, 58)
inputFrame.Position = UDim2.new(0, 0, 1, -58)
inputFrame.BackgroundColor3 = COLORS.bgDark
inputFrame.BorderSizePixel = 0
inputFrame.Parent = main

local inputLine = Instance.new("Frame")
inputLine.Size = UDim2.new(1, 0, 0, 1)
inputLine.BackgroundColor3 = COLORS.divider
inputLine.BorderSizePixel = 0
inputLine.Parent = inputFrame

local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(1, -78, 0, 36)
inputBox.Position = UDim2.new(0, 10, 0, 11)
inputBox.BackgroundColor3 = COLORS.inputBg
inputBox.BorderSizePixel = 0
inputBox.Text = ""
inputBox.PlaceholderText = "Ask AI to help with your project..."
inputBox.PlaceholderColor3 = COLORS.textMuted
inputBox.TextColor3 = COLORS.text
inputBox.TextSize = 13
inputBox.Font = Enum.Font.Gotham
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.ClearTextOnFocus = false
inputBox.Parent = inputFrame
Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 8)
local inputPad = Instance.new("UIPadding")
inputPad.PaddingLeft = UDim.new(0, 10)
inputPad.PaddingRight = UDim.new(0, 10)
inputPad.Parent = inputBox

local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.new(0, 56, 0, 36)
sendBtn.Position = UDim2.new(1, -66, 0, 11)
sendBtn.BackgroundColor3 = COLORS.accent
sendBtn.BorderSizePixel = 0
sendBtn.Text = "Send"
sendBtn.TextColor3 = COLORS.text
sendBtn.TextSize = 13
sendBtn.Font = Enum.Font.GothamBold
sendBtn.Parent = inputFrame
Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 8)

-- ============================================================
-- CHAT MESSAGE HELPER
-- ============================================================
local msgOrder = 0

local function addChatMessage(role, text)
	msgOrder = msgOrder + 1

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BorderSizePixel = 0
	frame.LayoutOrder = msgOrder
	frame.Parent = chatArea

	if role == "user" then
		frame.BackgroundColor3 = COLORS.userBubble
	elseif role == "assistant" then
		frame.BackgroundColor3 = COLORS.aiBubble
	elseif role == "tool" then
		frame.BackgroundColor3 = COLORS.toolBubble
	elseif role == "error" then
		frame.BackgroundColor3 = Color3.fromRGB(55, 25, 25)
	else
		frame.BackgroundColor3 = COLORS.systemBubble
	end

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local roleLbl = Instance.new("TextLabel")
	roleLbl.Size = UDim2.new(1, -16, 0, 16)
	roleLbl.Position = UDim2.new(0, 10, 0, 6)
	roleLbl.BackgroundTransparency = 1
	roleLbl.TextSize = 10
	roleLbl.Font = Enum.Font.GothamBold
	roleLbl.TextXAlignment = Enum.TextXAlignment.Left
	roleLbl.ZIndex = 2
	roleLbl.Parent = frame

	if role == "user" then
		roleLbl.Text = "You"
		roleLbl.TextColor3 = COLORS.accentLight
	elseif role == "assistant" then
		roleLbl.Text = "AI"
		roleLbl.TextColor3 = COLORS.success
	elseif role == "tool" then
		roleLbl.Text = "Tool"
		roleLbl.TextColor3 = COLORS.warning
	elseif role == "error" then
		roleLbl.Text = "Error"
		roleLbl.TextColor3 = COLORS.error
	else
		roleLbl.Text = "System"
		roleLbl.TextColor3 = COLORS.textMuted
	end

	local msgLbl = Instance.new("TextLabel")
	msgLbl.Size = UDim2.new(1, -20, 0, 0)
	msgLbl.Position = UDim2.new(0, 10, 0, 24)
	msgLbl.BackgroundTransparency = 1
	msgLbl.Text = text
	msgLbl.TextColor3 = COLORS.text
	msgLbl.TextSize = 13
	msgLbl.Font = Enum.Font.Gotham
	msgLbl.TextXAlignment = Enum.TextXAlignment.Left
	msgLbl.TextYAlignment = Enum.TextYAlignment.Top
	msgLbl.TextWrapped = true
	msgLbl.AutomaticSize = Enum.AutomaticSize.Y
	msgLbl.ZIndex = 2
	msgLbl.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = frame

	task.defer(function()
		chatArea.CanvasPosition = Vector2.new(0, chatArea.AbsoluteCanvasSize.Y)
	end)

	return frame
end

-- Welcome
addChatMessage("system", "Welcome to AI Assistant for Roblox Studio!\n\nSupported AI providers (all free):\n  Groq - Fastest inference\n  Gemini - Best quality\n  Ollama - 100% local\n  HuggingFace - Many models\n  Claude - Smart AI by Anthropic\n  Mistral - Fast EU AI\n  DeepSeek - Code expert\n  SambaNova - Free Llama models\n\nSelect a provider above, configure your API key in Settings (⚙), then start chatting!\n\nThe AI can read, write, and modify your Roblox project.")

-- ============================================================
-- SEND MESSAGE
-- ============================================================
local function sendMessage()
	local text = inputBox.Text
	if text == "" or state.isThinking then return end
	inputBox.Text = ""

	addChatMessage("user", text)

	-- Local commands
	if text == "/clear" then
		for _, c in ipairs(chatArea:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		msgOrder = 0
		addChatMessage("system", "Chat cleared.")
		return
	end

	if text == "/help" then
		addChatMessage("system", "Commands:\n  /clear - Clear chat\n  /help  - Show this message\n\nJust type naturally! The AI can:\n  - Create, read, write scripts\n  - Modify properties\n  - Search the hierarchy\n  - Execute Lua code\n  - And more!")
		return
	end

	-- Send to AI server
	state.isThinking = true
	sendBtn.Text = "..."

	task.spawn(function()
		local ok, response = pcall(function()
			return HttpService:PostAsync(
				SERVER_URL .. "/chat",
				HttpService:JSONEncode({
					message = text,
					session = "roblox-studio"
				}),
				Enum.HttpContentType.ApplicationJson
			)
		end)

		state.isThinking = false
		sendBtn.Text = "Send"

		if ok then
			local data = HttpService:JSONDecode(response)

			if data.error then
				addChatMessage("error", data.error)
			else
				-- Show tool calls
				if data.toolCalls then
					for _, tc in ipairs(data.toolCalls) do
						addChatMessage("tool", tc.name)
					end
				end

				-- Show AI response
				if data.response and data.response ~= "" then
					addChatMessage("assistant", data.response)
				end
			end
		else
			addChatMessage("error", "Could not connect to server. Make sure the server is running:\n  npm start")
		end
	end)
end

sendBtn.MouseButton1Click:Connect(sendMessage)
inputBox.FocusLost:Connect(function(enter)
	if enter then sendMessage() end
end)

-- ============================================================
-- STATUS UPDATE LOOP
-- ============================================================
task.spawn(function()
	while widget.Parent do
		-- Check server health
		local ok, response = pcall(function()
			return HttpService:GetAsync(SERVER_URL .. "/health")
		end)

		if ok then
			local data = HttpService:JSONDecode(response)
			state.serverConnected = data.connected or false
		else
			state.serverConnected = false
		end

		-- Update status dot
		if state.isThinking then
			statusDot.BackgroundColor3 = COLORS.warning
		elseif state.serverConnected then
			statusDot.BackgroundColor3 = COLORS.success
		else
			statusDot.BackgroundColor3 = COLORS.error
		end

		-- Fetch providers
		pcall(function()
			local res = HttpService:GetAsync(SERVER_URL .. "/providers")
			local data = HttpService:JSONDecode(res)
			if data.providers then
				state.providers = data.providers
				for _, p in ipairs(data.providers) do
					if p.active then
						state.activeProvider = p.name
						dropdownBtn.Text = "  " .. p.name .. "  ▾"
					end
				end
			end
		end)

		task.wait(2)
	end
end)

-- ============================================================
-- HTTP POLLING LOOP (tool execution)
-- ============================================================
task.spawn(function()
	while state.running do
		local ok, response = pcall(function()
			return HttpService:GetAsync(SERVER_URL .. "/poll")
		end)

		if ok then
			local data = HttpService:JSONDecode(response)

			if not data.idle then
				local result = processRequest(data)

				pcall(function()
					HttpService:PostAsync(
						SERVER_URL .. "/result",
						HttpService:JSONEncode(result),
						Enum.HttpContentType.ApplicationJson
					)
				end)
			end
		end

		task.wait(POLL_INTERVAL)
	end
end)

-- ============================================================
-- TOOLBAR BUTTON
-- ============================================================
local toolbar = plugin:CreateToolbar("AI Assistant")
local btn = toolbar:CreateButton("AI Assistant", "Toggle AI chat panel", "rbxassetid://6031075938")
btn.Click:Connect(function() widget.Enabled = not widget.Enabled end)
widget.Enabled = true

print("[AI Assistant] Plugin loaded. Server: " .. SERVER_URL)
