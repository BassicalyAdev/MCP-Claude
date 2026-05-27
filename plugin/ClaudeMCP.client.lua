-- ClaudeMCP Client GUI Script
-- Creates a dockable plugin GUI in Roblox Studio with a chat interface
-- and connection status display

local plugin = plugin or getfenv().plugin
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

-- ============================================================
-- THEME COLORS
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
    userMsg = Color3.fromRGB(60, 80, 120),
    systemMsg = Color3.fromRGB(50, 50, 60),
    divider = Color3.fromRGB(55, 55, 55),
}

-- ============================================================
-- CREATE DOCK WIDGET
-- ============================================================
local widgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Right,   -- initial dock state
    false,                         -- initially enabled
    false,                         -- override previous state
    400, 600,                      -- float size
    350, 450                       -- min size
)

local widget = plugin:CreateDockWidgetPluginGui(
    "ClaudeMCP_Widget",
    widgetInfo
)
widget.Title = "Claude AI"
widget.Name = "ClaudeMCP_GUI"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ============================================================
-- MAIN FRAME
-- ============================================================
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundColor3 = COLORS.bg
mainFrame.BorderSizePixel = 0
mainFrame.Parent = widget

-- ============================================================
-- HEADER BAR
-- ============================================================
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = COLORS.bgDark
header.BorderSizePixel = 0
header.Parent = mainFrame

local headerDivider = Instance.new("Frame")
headerDivider.Size = UDim2.new(1, 0, 0, 1)
headerDivider.Position = UDim2.new(0, 0, 1, -1)
headerDivider.BackgroundColor3 = COLORS.divider
headerDivider.BorderSizePixel = 0
headerDivider.Parent = header

-- Logo / Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Claude AI"
titleLabel.TextColor3 = COLORS.text
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

-- Status indicator
local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(1, -20, 0.5, -4)
statusDot.BackgroundColor3 = COLORS.error
statusDot.BorderSizePixel = 0
statusDot.Parent = header

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(1, 0)
statusCorner.Parent = statusDot

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 80, 1, 0)
statusLabel.Position = UDim2.new(1, -105, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Disconnected"
statusLabel.TextColor3 = COLORS.textDim
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Right
statusLabel.Parent = header

-- ============================================================
-- CHAT AREA (ScrollingFrame)
-- ============================================================
local chatArea = Instance.new("ScrollingFrame")
chatArea.Size = UDim2.new(1, 0, 1, -100)
chatArea.Position = UDim2.new(0, 0, 0, 44)
chatArea.BackgroundColor3 = COLORS.bg
chatArea.BorderSizePixel = 0
chatArea.ScrollBarThickness = 6
chatArea.ScrollBarImageColor3 = COLORS.accent
chatArea.CanvasSize = UDim2.new(0, 0, 0, 0)
chatArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
chatArea.Parent = mainFrame

local chatLayout = Instance.new("UIListLayout")
chatLayout.Padding = UDim.new(0, 4)
chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
chatLayout.Parent = chatArea

local chatPadding = Instance.new("UIPadding")
chatPadding.PaddingLeft = UDim.new(0, 8)
chatPadding.PaddingRight = UDim.new(0, 8)
chatPadding.PaddingTop = UDim.new(0, 8)
chatPadding.PaddingBottom = UDim.new(0, 8)
chatPadding.Parent = chatArea

-- ============================================================
-- INPUT AREA
-- ============================================================
local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, 0, 0, 56)
inputFrame.Position = UDim2.new(0, 0, 1, -56)
inputFrame.BackgroundColor3 = COLORS.bgDark
inputFrame.BorderSizePixel = 0
inputFrame.Parent = mainFrame

local inputDivider = Instance.new("Frame")
inputDivider.Size = UDim2.new(1, 0, 0, 1)
inputDivider.BackgroundColor3 = COLORS.divider
inputDivider.BorderSizePixel = 0
inputDivider.Parent = inputFrame

local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(1, -80, 0, 36)
inputBox.Position = UDim2.new(0, 8, 0, 10)
inputBox.BackgroundColor3 = COLORS.bgLight
inputBox.BorderSizePixel = 0
inputBox.Text = ""
inputBox.PlaceholderText = "Type a message or command..."
inputBox.PlaceholderColor3 = COLORS.textDim
inputBox.TextColor3 = COLORS.text
inputBox.TextSize = 13
inputBox.Font = Enum.Font.Gotham
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.ClearTextOnFocus = false
inputBox.Parent = inputFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 6)
inputCorner.Parent = inputBox

local inputPadding = Instance.new("UIPadding")
inputPadding.PaddingLeft = UDim.new(0, 8)
inputPadding.PaddingRight = UDim.new(0, 8)
inputPadding.Parent = inputBox

local sendButton = Instance.new("TextButton")
sendButton.Size = UDim2.new(0, 60, 0, 36)
sendButton.Position = UDim2.new(1, -68, 0, 10)
sendButton.BackgroundColor3 = COLORS.accent
sendButton.BorderSizePixel = 0
sendButton.Text = "Send"
sendButton.TextColor3 = COLORS.text
sendButton.TextSize = 13
sendButton.Font = Enum.Font.GothamBold
sendButton.Parent = inputFrame

local sendCorner = Instance.new("UICorner")
sendCorner.CornerRadius = UDim.new(0, 6)
sendCorner.Parent = sendButton

-- ============================================================
-- HELPER: Create a chat message bubble
-- ============================================================
local messageOrder = 0

local function addMessage(role, text)
    messageOrder = messageOrder + 1

    local msgFrame = Instance.new("Frame")
    msgFrame.Size = UDim2.new(1, 0, 0, 0)
    msgFrame.AutomaticSize = Enum.AutomaticSize.Y
    msgFrame.BackgroundColor3 = role == "user" and COLORS.userMsg
        or role == "error" and Color3.fromRGB(60, 30, 30)
        or role == "tool" and COLORS.systemMsg
        or COLORS.systemMsg
    msgFrame.BorderSizePixel = 0
    msgFrame.LayoutOrder = messageOrder
    msgFrame.Parent = chatArea

    local msgCorner = Instance.new("UICorner")
    msgCorner.CornerRadius = UDim.new(0, 6)
    msgCorner.Parent = msgFrame

    local roleLabel = Instance.new("TextLabel")
    roleLabel.Size = UDim2.new(1, -16, 0, 18)
    roleLabel.Position = UDim2.new(0, 8, 0, 4)
    roleLabel.BackgroundTransparency = 1
    roleLabel.Text = role == "user" and "You"
        or role == "error" and "Error"
        or role == "tool" and "Tool"
        or "System"
    roleLabel.TextColor3 = role == "user" and COLORS.accentLight
        or role == "error" and COLORS.error
        or role == "tool" and COLORS.warning
        or COLORS.textDim
    roleLabel.TextSize = 11
    roleLabel.Font = Enum.Font.GothamBold
    roleLabel.TextXAlignment = Enum.TextXAlignment.Left
    roleLabel.Parent = msgFrame

    local msgLabel = Instance.new("TextLabel")
    msgLabel.Size = UDim2.new(1, -16, 0, 0)
    msgLabel.Position = UDim2.new(0, 8, 0, 22)
    msgLabel.BackgroundTransparency = 1
    msgLabel.Text = text
    msgLabel.TextColor3 = COLORS.text
    msgLabel.TextSize = 13
    msgLabel.Font = Enum.Font.Gotham
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.TextYAlignment = Enum.TextYAlignment.Top
    msgLabel.TextWrapped = true
    msgLabel.AutomaticSize = Enum.AutomaticSize.Y
    msgLabel.Parent = msgFrame

    local padding = Instance.new("UIPadding")
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent = msgFrame

    -- Auto-scroll to bottom
    task.defer(function()
        chatArea.CanvasPosition = Vector2.new(0, chatArea.AbsoluteCanvasSize.Y)
    end)
end

-- ============================================================
-- INITIAL WELCOME MESSAGE
-- ============================================================
addMessage("system", "Welcome to Claude AI for Roblox Studio!\n\nThis plugin connects to the Claude MCP server, allowing Claude to read and modify your project.\n\nMake sure the MCP server is running:\n  cd \"roblox-studio-mcp\"\n  npm start")

-- ============================================================
-- STATUS UPDATE LOOP
-- ============================================================
task.spawn(function()
    while widget.Parent do
        local data = _G.ClaudeMCP
        if data then
            if data.connected then
                statusDot.BackgroundColor3 = COLORS.success
                statusLabel.Text = "Connected"
            else
                statusDot.BackgroundColor3 = COLORS.error
                statusLabel.Text = "Disconnected"
            end
        end
        task.wait(0.5)
    end
end)

-- ============================================================
-- CHAT LOG MONITOR (shows tool calls from server script)
-- ============================================================
local lastLogCount = 0

task.spawn(function()
    while widget.Parent do
        local data = _G.ClaudeMCP
        if data and data.chatLog then
            if #data.chatLog > lastLogCount then
                for i = lastLogCount + 1, #data.chatLog do
                    local entry = data.chatLog[i]
                    addMessage(entry.role or "system", entry.content or "")
                end
                lastLogCount = #data.chatLog
            end
        end
        task.wait(0.3)
    end
end)

-- ============================================================
-- INPUT HANDLING
-- ============================================================
local function sendMessage()
    local text = inputBox.Text
    if text == "" then return end

    inputBox.Text = ""
    addMessage("user", text)

    -- Check for local commands
    if text == "/clear" then
        for _, child in ipairs(chatArea:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        messageOrder = 0
        lastLogCount = 0
        _G.ClaudeMCP.chatLog = {}
        addMessage("system", "Chat cleared.")
        return
    end

    if text == "/status" then
        local data = _G.ClaudeMCP or {}
        addMessage("system", string.format(
            "Connected: %s\nRequests processed: %d\nLast request: %s",
            tostring(data.connected),
            data.requestCount or 0,
            tostring(data.lastRequest or "none")
        ))
        return
    end

    if text == "/help" then
        addMessage("system", "Available commands:\n/clear - Clear chat\n/status - Show connection status\n/help - Show this help\n\nTo interact with Claude, use the MCP server through Claude Code CLI.")
        return
    end

    -- For non-commands, show a message that they need to use Claude CLI
    addMessage("system", "To chat with Claude, use the Claude Code CLI with this MCP server. The plugin handles Studio operations automatically.")
end

sendButton.MouseButton1Click:Connect(sendMessage)

inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        sendMessage()
    end
end)

-- ============================================================
-- TOOLBAR BUTTON
-- ============================================================
local toolbar = plugin:CreateToolbar("Claude AI")
local toggleButton = toolbar:CreateButton(
    "Claude AI",
    "Toggle Claude AI panel",
    "rbxassetid://6031075938"  -- Chat icon
)

toggleButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)

-- Auto-enable on load
widget.Enabled = true

print("[ClaudeMCP] GUI script loaded.")
