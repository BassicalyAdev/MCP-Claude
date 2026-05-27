-- ClaudeMCP Plugin for Roblox Studio
-- Single unified plugin that handles HTTP communication with the MCP bridge
-- and provides a dockable GUI panel
--
-- Install: Place this file in your Roblox Studio plugins folder
--   Windows: %LOCALAPPDATA%\Roblox\Plugins\
--   macOS: ~/Documents/Roblox/Plugins/
--
-- Usage:
--   1. Start the MCP server: npm start
--   2. Open Roblox Studio - the plugin auto-connects
--   3. Use Claude Code CLI to interact with your project

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local TweenService = game:GetService("TweenService")

-- ============================================================
-- CONFIGURATION
-- ============================================================
local BRIDGE_URL = "http://localhost:3636"
local POLL_INTERVAL = 0.15

-- ============================================================
-- THEME
-- ============================================================
local COLORS = {
    bg = Color3.fromRGB(30, 30, 30),
    bgLight = Color3.fromRGB(40, 40, 40),
    bgDark = Color3.fromRGB(22, 22, 22),
    accent = Color3.fromRGB(120, 90, 220),
    accentLight = Color3.fromRGB(150, 120, 255),
    text = Color3.fromRGB(230, 230, 230),
    textDim = Color3.fromRGB(160, 160, 160),
    success = Color3.fromRGB(80, 200, 120),
    error = Color3.fromRGB(220, 80, 80),
    warning = Color3.fromRGB(220, 180, 60),
    userMsg = Color3.fromRGB(50, 65, 100),
    systemMsg = Color3.fromRGB(45, 45, 55),
    toolMsg = Color3.fromRGB(55, 50, 35),
    divider = Color3.fromRGB(55, 55, 55),
}

-- ============================================================
-- STATE
-- ============================================================
local state = {
    connected = false,
    lastRequest = nil,
    requestCount = 0,
    running = true,
}

-- ============================================================
-- UTILITY: Resolve dot-path to instance
-- ============================================================
local function resolvePath(pathStr)
    if pathStr == "game" then return game end

    local parts = string.split(pathStr, ".")
    local current = game

    for i, part in ipairs(parts) do
        if i == 1 and part == "game" then continue end
        local child = current:FindFirstChild(part)
        if not child then
            return nil, "Instance not found: " .. pathStr .. " (at '" .. part .. "')"
        end
        current = child
    end
    return current
end

-- ============================================================
-- UTILITY: Get full path of instance
-- ============================================================
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

-- ============================================================
-- UTILITY: Serialize value for JSON
-- ============================================================
local function serializeValue(value, depth)
    depth = depth or 0
    if depth > 4 then return tostring(value) end

    local t = typeof(value)
    if t == "string" or t == "number" or t == "boolean" then return value end
    if t == "nil" then return nil end

    if t == "Vector3" then
        return { __type = "Vector3", x = value.X, y = value.Y, z = value.Z }
    elseif t == "CFrame" then
        local p = value.Position
        return { __type = "CFrame", x = p.X, y = p.Y, z = p.Z }
    elseif t == "Color3" then
        return { __type = "Color3", r = value.R, g = value.G, b = value.B }
    elseif t == "BrickColor" then
        return { __type = "BrickColor", name = value.Name }
    elseif t == "UDim2" then
        return { __type = "UDim2", xs = value.X.Scale, xo = value.X.Offset, ys = value.Y.Scale, yo = value.Y.Offset }
    elseif t == "Instance" then
        return { __type = "Instance", path = getPathString(value), className = value.ClassName, name = value.Name }
    elseif t == "table" then
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

-- ============================================================
-- BUILD HIERARCHY TREE
-- ============================================================
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
    local instance, err = resolvePath(path)
    if not instance then return { error = err } end
    return buildHierarchy(instance, 0, depth)
end

function handlers.read_script(args)
    local instance, err = resolvePath(args.path)
    if not instance then return { error = err } end
    if not instance:IsA("LuaSourceContainer") then
        return { error = "Not a script (class: " .. instance.ClassName .. ")" }
    end
    return { source = instance.Source, className = instance.ClassName, path = args.path }
end

function handlers.write_script(args)
    local instance, err = resolvePath(args.path)
    if not instance then return { error = err } end
    if not instance:IsA("LuaSourceContainer") then
        return { error = "Not a script (class: " .. instance.ClassName .. ")" }
    end
    ChangeHistoryService:SetWaypoint("Claude_WriteScript")
    instance.Source = args.source
    ChangeHistoryService:SetWaypoint("Claude_WriteScript_Done")
    state.lastRequest = "Wrote: " .. args.path
    return { success = true, path = args.path }
end

function handlers.create_script(args)
    local parent, err = resolvePath(args.parent)
    if not parent then return { error = err } end
    ChangeHistoryService:SetWaypoint("Claude_CreateScript")
    local s = Instance.new(args.className or "Script")
    s.Name = args.name
    s.Source = args.source or ""
    s.Parent = parent
    ChangeHistoryService:SetWaypoint("Claude_CreateScript_Done")
    state.lastRequest = "Created: " .. args.parent .. "." .. args.name
    return { success = true, path = args.parent .. "." .. args.name, className = s.ClassName }
end

function handlers.delete_instance(args)
    local instance, err = resolvePath(args.path)
    if not instance then return { error = err } end
    if instance == game then return { error = "Cannot delete game" } end
    ChangeHistoryService:SetWaypoint("Claude_Delete")
    local name = args.path
    instance:Destroy()
    ChangeHistoryService:SetWaypoint("Claude_Delete_Done")
    state.lastRequest = "Deleted: " .. name
    return { success = true, deleted = name }
end

function handlers.get_properties(args)
    local instance, err = resolvePath(args.path)
    if not instance then return { error = err } end
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
    local instance, err = resolvePath(args.path)
    if not instance then return { error = err } end
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

    ChangeHistoryService:SetWaypoint("Claude_SetProp")
    local ok, setErr = pcall(function() instance[prop] = parsed end)
    ChangeHistoryService:SetWaypoint("Claude_SetProp_Done")
    if not ok then return { error = "Failed: " .. tostring(setErr) } end
    state.lastRequest = prop .. " = " .. val
    return { success = true, path = args.path, property = prop }
end

function handlers.execute_lua(args)
    local fn, cerr = loadstring(args.code)
    if not fn then return { error = "Compile error: " .. tostring(cerr) } end
    setfenv(fn, getfenv())
    ChangeHistoryService:SetWaypoint("Claude_ExecuteLua")
    local results = { pcall(fn) }
    ChangeHistoryService:SetWaypoint("Claude_ExecuteLua_Done")
    local ok = table.remove(results, 1)
    if not ok then return { error = "Runtime error: " .. tostring(results[1]) } end
    state.lastRequest = "Executed Lua"
    if #results == 0 then return { success = true, message = "No return value" } end
    local ser = {}
    for i, v in ipairs(results) do ser[i] = serializeValue(v) end
    return #ser == 1 and { result = ser[1] } or { results = ser }
end

function handlers.search_instances(args)
    local root, err = resolvePath(args.root or "game")
    if not root then return { error = err } end
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
        local inst, err = resolvePath(path)
        if not inst then return { error = err } end
        table.insert(instances, inst)
    end
    Selection:Set(instances)
    return { success = true, selected = args.paths }
end

-- ============================================================
-- PROCESS REQUEST
-- ============================================================
local function processRequest(data)
    local handler = handlers[data.tool]
    if not handler then return { id = data.id, error = "Unknown tool: " .. data.tool } end
    state.requestCount = state.requestCount + 1
    state.lastRequest = data.tool

    local ok, result = pcall(handler, data.args or {})
    if not ok then return { id = data.id, error = "Handler error: " .. tostring(result) } end
    return { id = data.id, result = result }
end

-- ============================================================
-- GUI
-- ============================================================
local widgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Right, false, false, 420, 620, 350, 450
)

local widget = plugin:CreateDockWidgetPluginGui("ClaudeMCP_Widget", widgetInfo)
widget.Title = "Claude AI"
widget.Name = "ClaudeMCP_GUI"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main frame
local main = Instance.new("Frame")
main.Size = UDim2.new(1, 0, 1, 0)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Parent = widget

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = COLORS.bgDark
header.BorderSizePixel = 0
header.Parent = main

Instance.new("Frame", header).Size = UDim2.new(1, 0, 0, 1)
header:FindFirstChildWhichIsA("Frame").Position = UDim2.new(0, 0, 1, -1)
header:FindFirstChildWhichIsA("Frame").BackgroundColor3 = COLORS.divider
header:FindFirstChildWhichIsA("Frame").BorderSizePixel = 0

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.5, -10, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Claude AI"
title.TextColor3 = COLORS.text
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

-- Status dot
local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 10, 0, 10)
dot.Position = UDim2.new(1, -22, 0.5, -5)
dot.BackgroundColor3 = COLORS.error
dot.BorderSizePixel = 0
dot.Parent = header
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(0, 90, 1, 0)
statusText.Position = UDim2.new(1, -118, 0, 0)
statusText.BackgroundTransparency = 1
statusText.Text = "Disconnected"
statusText.TextColor3 = COLORS.textDim
statusText.TextSize = 11
statusText.Font = Enum.Font.Gotham
statusText.TextXAlignment = Enum.TextXAlignment.Right
statusText.Parent = header

-- Request counter
local counterText = Instance.new("TextLabel")
counterText.Size = UDim2.new(1, -14, 0, 16)
counterText.Position = UDim2.new(0, 14, 0, 48)
counterText.BackgroundTransparency = 1
counterText.Text = "Requests: 0"
counterText.TextColor3 = COLORS.textDim
counterText.TextSize = 10
counterText.Font = Enum.Font.Gotham
counterText.TextXAlignment = Enum.TextXAlignment.Left
counterText.Parent = main

-- Chat area
local chat = Instance.new("ScrollingFrame")
chat.Size = UDim2.new(1, 0, 1, -120)
chat.Position = UDim2.new(0, 0, 0, 66)
chat.BackgroundColor3 = COLORS.bg
chat.BorderSizePixel = 0
chat.ScrollBarThickness = 5
chat.ScrollBarImageColor3 = COLORS.accent
chat.CanvasSize = UDim2.new(0, 0, 0, 0)
chat.AutomaticCanvasSize = Enum.AutomaticSize.Y
chat.Parent = main

local chatLayout = Instance.new("UIListLayout", chat)
chatLayout.Padding = UDim.new(0, 4)
chatLayout.SortOrder = Enum.SortOrder.LayoutOrder

local chatPad = Instance.new("UIPadding", chat)
chatPad.PaddingLeft = UDim.new(0, 8)
chatPad.PaddingRight = UDim.new(0, 8)
chatPad.PaddingTop = UDim.new(0, 6)
chatPad.PaddingBottom = UDim.new(0, 6)

-- Input area
local inputArea = Instance.new("Frame")
inputArea.Size = UDim2.new(1, 0, 0, 54)
inputArea.Position = UDim2.new(0, 0, 1, -54)
inputArea.BackgroundColor3 = COLORS.bgDark
inputArea.BorderSizePixel = 0
inputArea.Parent = main

local inputDiv = Instance.new("Frame", inputArea)
inputDiv.Size = UDim2.new(1, 0, 0, 1)
inputDiv.BackgroundColor3 = COLORS.divider
inputDiv.BorderSizePixel = 0

local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(1, -76, 0, 34)
inputBox.Position = UDim2.new(0, 8, 0, 10)
inputBox.BackgroundColor3 = COLORS.bgLight
inputBox.BorderSizePixel = 0
inputBox.Text = ""
inputBox.PlaceholderText = "Type /help for commands..."
inputBox.PlaceholderColor3 = COLORS.textDim
inputBox.TextColor3 = COLORS.text
inputBox.TextSize = 13
inputBox.Font = Enum.Font.Gotham
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.ClearTextOnFocus = false
inputBox.Parent = inputArea
Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 6)
Instance.new("UIPadding", inputBox).PaddingLeft = UDim.new(0, 8)

local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.new(0, 58, 0, 34)
sendBtn.Position = UDim2.new(1, -66, 0, 10)
sendBtn.BackgroundColor3 = COLORS.accent
sendBtn.BorderSizePixel = 0
sendBtn.Text = "Send"
sendBtn.TextColor3 = COLORS.text
sendBtn.TextSize = 13
sendBtn.Font = Enum.Font.GothamBold
sendBtn.Parent = inputArea
Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 6)

-- ============================================================
-- CHAT MESSAGE HELPER
-- ============================================================
local msgOrder = 0

local function addMsg(role, text)
    msgOrder = msgOrder + 1

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BorderSizePixel = 0
    frame.LayoutOrder = msgOrder
    frame.Parent = chat

    if role == "user" then
        frame.BackgroundColor3 = COLORS.userMsg
    elseif role == "error" then
        frame.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    elseif role == "tool" then
        frame.BackgroundColor3 = COLORS.toolMsg
    else
        frame.BackgroundColor3 = COLORS.systemMsg
    end

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local roleLbl = Instance.new("TextLabel")
    roleLbl.Size = UDim2.new(1, -16, 0, 16)
    roleLbl.Position = UDim2.new(0, 8, 0, 4)
    roleLbl.BackgroundTransparency = 1
    roleLbl.TextSize = 10
    roleLbl.Font = Enum.Font.GothamBold
    roleLbl.TextXAlignment = Enum.TextXAlignment.Left
    roleLbl.Parent = frame

    if role == "user" then
        roleLbl.Text = "You"
        roleLbl.TextColor3 = COLORS.accentLight
    elseif role == "error" then
        roleLbl.Text = "Error"
        roleLbl.TextColor3 = COLORS.error
    elseif role == "tool" then
        roleLbl.Text = "Tool"
        roleLbl.TextColor3 = COLORS.warning
    else
        roleLbl.Text = "System"
        roleLbl.TextColor3 = COLORS.textDim
    end

    local msgLbl = Instance.new("TextLabel")
    msgLbl.Size = UDim2.new(1, -16, 0, 0)
    msgLbl.Position = UDim2.new(0, 8, 0, 20)
    msgLbl.BackgroundTransparency = 1
    msgLbl.Text = text
    msgLbl.TextColor3 = COLORS.text
    msgLbl.TextSize = 12
    msgLbl.Font = Enum.Font.Gotham
    msgLbl.TextXAlignment = Enum.TextXAlignment.Left
    msgLbl.TextYAlignment = Enum.TextYAlignment.Top
    msgLbl.TextWrapped = true
    msgLbl.AutomaticSize = Enum.AutomaticSize.Y
    msgLbl.Parent = frame

    local pad = Instance.new("UIPadding", frame)
    pad.PaddingBottom = UDim.new(0, 8)

    task.defer(function()
        chat.CanvasPosition = Vector2.new(0, chat.AbsoluteCanvasSize.Y)
    end)
end

-- Welcome message
addMsg("system", "Claude AI for Roblox Studio\n\nConnects to the MCP server so Claude can read and modify your project.\n\nStart the MCP server first:\n  npm start\n\nCommands:\n  /help    - Show commands\n  /status  - Connection info\n  /clear   - Clear chat")

-- ============================================================
-- INPUT HANDLING
-- ============================================================
local function sendMessage()
    local text = inputBox.Text
    if text == "" then return end
    inputBox.Text = ""

    addMsg("user", text)

    if text == "/clear" then
        for _, c in ipairs(chat:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        msgOrder = 0
        addMsg("system", "Chat cleared.")
        return
    end

    if text == "/status" then
        addMsg("system", string.format(
            "Connected: %s\nRequests: %d\nLast: %s",
            tostring(state.connected), state.requestCount, tostring(state.lastRequest or "none")
        ))
        return
    end

    if text == "/help" then
        addMsg("system", "Commands:\n  /clear   - Clear chat\n  /status  - Show connection info\n  /help    - This message\n\nInteract via Claude Code CLI with this MCP server. The plugin handles Studio operations automatically.")
        return
    end

    addMsg("system", "Use Claude Code CLI to interact. This panel shows status and tool calls.")
end

sendBtn.MouseButton1Click:Connect(sendMessage)
inputBox.FocusLost:Connect(function(enter) if enter then sendMessage() end end)

-- ============================================================
-- STATUS UPDATE LOOP
-- ============================================================
task.spawn(function()
    while widget.Parent do
        if state.connected then
            dot.BackgroundColor3 = COLORS.success
            statusText.Text = "Connected"
        else
            dot.BackgroundColor3 = COLORS.error
            statusText.Text = "Disconnected"
        end
        counterText.Text = "Requests: " .. state.requestCount .. (state.lastRequest and (" | " .. state.lastRequest) or "")
        task.wait(0.5)
    end
end)

-- ============================================================
-- HTTP POLLING LOOP
-- ============================================================
task.spawn(function()
    while state.running do
        local ok, response = pcall(function()
            return HttpService:GetAsync(BRIDGE_URL .. "/poll")
        end)

        if ok then
            state.connected = true
            local data = HttpService:JSONDecode(response)

            if not data.idle then
                local result = processRequest(data)

                -- Show tool call in GUI
                addMsg("tool", data.tool)

                pcall(function()
                    HttpService:PostAsync(
                        BRIDGE_URL .. "/result",
                        HttpService:JSONEncode(result),
                        Enum.HttpContentType.ApplicationJson
                    )
                end)
            end
        else
            state.connected = false
        end

        task.wait(POLL_INTERVAL)
    end
end)

-- ============================================================
-- TOOLBAR BUTTON
-- ============================================================
local toolbar = plugin:CreateToolbar("Claude AI")
local btn = toolbar:CreateButton("Claude AI", "Toggle Claude AI panel", "rbxassetid://6031075938")
btn.Click:Connect(function() widget.Enabled = not widget.Enabled end)
widget.Enabled = true

print("[ClaudeMCP] Plugin loaded. Polling " .. BRIDGE_URL)
