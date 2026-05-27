-- ClaudeMCP Server Script
-- Handles communication with the MCP bridge server via HttpService polling
-- and executes Roblox Studio API operations

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Configuration
local BRIDGE_URL = "http://localhost:3636"
local POLL_INTERVAL = 0.1

-- Shared state (communicates with client GUI script via _G)
_G.ClaudeMCP = _G.ClaudeMCP or {}
_G.ClaudeMCP.connected = false
_G.ClaudeMCP.lastRequest = nil
_G.ClaudeMCP.requestCount = 0
_G.ClaudeMCP.chatLog = _G.ClaudeMCP.chatLog or {}

-- Utility: Resolve a dot-path string to a Roblox instance
local function resolvePath(pathStr)
    if pathStr == "game" then
        return game
    end

    local parts = string.split(pathStr, ".")
    local current = game

    for i, part in ipairs(parts) do
        if i == 1 and part == "game" then
            continue
        end

        local child = current:FindFirstChild(part)
        if not child then
            return nil, "Instance not found: " .. pathStr .. " (stuck at '" .. part .. "')"
        end
        current = child
    end

    return current
end

-- Utility: Get the full path string of an instance
local function getPathString(instance)
    if instance == game then
        return "game"
    end

    local parts = {}
    local current = instance
    while current and current ~= game do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end
    table.insert(parts, 1, "game")
    return table.concat(parts, ".")
end

-- Utility: Serialize a value to a JSON-safe format
local function serializeValue(value, depth)
    depth = depth or 0
    if depth > 5 then
        return tostring(value)
    end

    local t = typeof(value)

    if t == "string" or t == "number" or t == "boolean" then
        return value
    elseif t == "nil" then
        return nil
    elseif t == "Vector3" then
        return { __type = "Vector3", X = value.X, Y = value.Y, Z = value.Z }
    elseif t == "CFrame" then
        local pos = value.Position
        local rx, ry, rz = value:ToEulerAnglesXYZ()
        return { __type = "CFrame", X = pos.X, Y = pos.Y, Z = pos.Z, RX = rx, RY = ry, RZ = rz }
    elseif t == "Color3" then
        return { __type = "Color3", R = value.R, G = value.G, B = value.B }
    elseif t == "BrickColor" then
        return { __type = "BrickColor", Name = value.Name }
    elseif t == "UDim2" then
        return { __type = "UDim2", XScale = value.X.Scale, XOffset = value.X.Offset, YScale = value.Y.Scale, YOffset = value.Y.Offset }
    elseif t == "UDim" then
        return { __type = "UDim", Scale = value.Scale, Offset = value.Offset }
    elseif t == "EnumItem" then
        return tostring(value)
    elseif t == "Instance" then
        return { __type = "Instance", Path = getPathString(value), ClassName = value.ClassName, Name = value.Name }
    elseif t == "table" then
        -- Check if it's an array
        local isArray = #value > 0
        if isArray then
            local arr = {}
            for _, v in ipairs(value) do
                table.insert(arr, serializeValue(v, depth + 1))
            end
            return arr
        else
            local obj = {}
            for k, v in pairs(value) do
                obj[tostring(k)] = serializeValue(v, depth + 1)
            end
            return obj
        end
    else
        return tostring(value)
    end
end

-- Build hierarchy tree
local function buildHierarchy(instance, depth, maxDepth)
    if depth > maxDepth then
        return { name = instance.Name, class = instance.ClassName, children = "..." }
    end

    local children = {}
    for _, child in ipairs(instance:GetChildren()) do
        table.insert(children, buildHierarchy(child, depth + 1, maxDepth))
    end

    return {
        name = instance.Name,
        class = instance.ClassName,
        path = getPathString(instance),
        children = children
    }
end

-- Tool handlers
local handlers = {}

function handlers.get_hierarchy(args)
    local path = args.path or "game"
    local depth = args.depth or 3

    local instance, err = resolvePath(path)
    if not instance then
        return { error = err }
    end

    local tree = buildHierarchy(instance, 0, depth)
    return tree
end

function handlers.read_script(args)
    local path = args.path
    local instance, err = resolvePath(path)
    if not instance then
        return { error = err }
    end

    if not instance:IsA("LuaSourceContainer") then
        return { error = "Instance is not a script (class: " .. instance.ClassName .. ")" }
    end

    return { source = instance.Source, className = instance.ClassName }
end

function handlers.write_script(args)
    local path = args.path
    local source = args.source

    local instance, err = resolvePath(path)
    if not instance then
        return { error = err }
    end

    if not instance:IsA("LuaSourceContainer") then
        return { error = "Instance is not a script (class: " .. instance.ClassName .. ")" }
    end

    ChangeHistoryService:SetWaypoint("ClaudeMCP_WriteScript")
    instance.Source = source
    ChangeHistoryService:SetWaypoint("ClaudeMCP_WriteScript_Done")

    -- Notify GUI
    _G.ClaudeMCP.lastRequest = "Wrote script: " .. path

    return { success = true, path = path }
end

function handlers.create_script(args)
    local parentPath = args.parent
    local name = args.name
    local className = args.className or "Script"
    local source = args.source or ""

    local parent, err = resolvePath(parentPath)
    if not parent then
        return { error = err }
    end

    ChangeHistoryService:SetWaypoint("ClaudeMCP_CreateScript")

    local newScript = Instance.new(className)
    newScript.Name = name
    newScript.Source = source
    newScript.Parent = parent

    ChangeHistoryService:SetWaypoint("ClaudeMCP_CreateScript_Done")

    _G.ClaudeMCP.lastRequest = "Created: " .. parentPath .. "." .. name

    return {
        success = true,
        path = parentPath .. "." .. name,
        className = className
    }
end

function handlers.delete_instance(args)
    local path = args.path
    local instance, err = resolvePath(path)
    if not instance then
        return { error = err }
    end

    if instance == game then
        return { error = "Cannot delete the game instance" }
    end

    ChangeHistoryService:SetWaypoint("ClaudeMCP_Delete")
    instance:Destroy()
    ChangeHistoryService:SetWaypoint("ClaudeMCP_Delete_Done")

    _G.ClaudeMCP.lastRequest = "Deleted: " .. path

    return { success = true, deleted = path }
end

function handlers.get_properties(args)
    local path = args.path
    local instance, err = resolvePath(path)
    if not instance then
        return { error = err }
    end

    local properties = {}
    local success, props = pcall(function()
        return instance:GetProperties()
    end)

    if success then
        for _, propName in ipairs(props) do
            local ok, value = pcall(function()
                return instance[propName]
            end)
            if ok then
                properties[propName] = serializeValue(value)
            end
        end
    else
        -- Fallback: list common properties
        for _, propName in ipairs({"Name", "ClassName", "Parent", "Archivable"}) do
            local ok, value = pcall(function()
                return instance[propName]
            end)
            if ok then
                properties[propName] = serializeValue(value)
            end
        end
    end

    return {
        path = path,
        className = instance.ClassName,
        properties = properties
    }
end

function handlers.set_property(args)
    local path = args.path
    local property = args.property
    local value = args.value

    local instance, err = resolvePath(path)
    if not instance then
        return { error = err }
    end

    -- Parse the value based on the property type
    local parsedValue
    local currentVal = instance[property]

    if typeof(currentVal) == "number" then
        parsedValue = tonumber(value)
    elseif typeof(currentVal) == "boolean" then
        parsedValue = value == "true"
    elseif typeof(currentVal) == "Vector3" then
        local parts = string.split(value, ",")
        if #parts == 3 then
            parsedValue = Vector3.new(tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3]))
        end
    elseif typeof(currentVal) == "Color3" then
        local parts = string.split(value, ",")
        if #parts == 3 then
            parsedValue = Color3.new(tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3]))
        end
    elseif typeof(currentVal) == "CFrame" then
        parsedValue = loadstring("return CFrame.new(" .. value .. ")")()
    else
        parsedValue = value
    end

    if parsedValue == nil then
        return { error = "Could not parse value: " .. tostring(value) }
    end

    ChangeHistoryService:SetWaypoint("ClaudeMCP_SetProperty")
    local ok, setErr = pcall(function()
        instance[property] = parsedValue
    end)
    ChangeHistoryService:SetWaypoint("ClaudeMCP_SetProperty_Done")

    if not ok then
        return { error = "Failed to set property: " .. tostring(setErr) }
    end

    _G.ClaudeMCP.lastRequest = "Set " .. path .. "." .. property .. " = " .. value

    return { success = true, path = path, property = property, value = serializeValue(parsedValue) }
end

function handlers.execute_lua(args)
    local code = args.code

    -- Try loadstring first (works in Studio command bar context)
    local fn, compileErr = loadstring(code)
    if not fn then
        return { error = "Compilation error: " .. tostring(compileErr) }
    end

    -- Set the script context so game:GetService etc. work
    setfenv(fn, getfenv())

    ChangeHistoryService:SetWaypoint("ClaudeMCP_ExecuteLua")
    local results = { pcall(fn) }
    ChangeHistoryService:SetWaypoint("ClaudeMCP_ExecuteLua_Done")

    local success = table.remove(results, 1)
    if not success then
        return { error = "Runtime error: " .. tostring(results[1]) }
    end

    -- Serialize return values
    local serialized = {}
    for i, v in ipairs(results) do
        serialized[i] = serializeValue(v)
    end

    _G.ClaudeMCP.lastRequest = "Executed Lua code"

    if #serialized == 0 then
        return { success = true, message = "Code executed successfully (no return value)" }
    elseif #serialized == 1 then
        return { success = true, result = serialized[1] }
    else
        return { success = true, results = serialized }
    end
end

function handlers.search_instances(args)
    local className = args.className
    local name = args.name
    local rootPath = args.root or "game"
    local maxResults = args.maxResults or 50

    local root, err = resolvePath(rootPath)
    if not root then
        return { error = err }
    end

    local results = {}
    local function search(parent)
        if #results >= maxResults then return end
        for _, child in ipairs(parent:GetChildren()) do
            if #results >= maxResults then break end

            local matches = true
            if className and child.ClassName ~= className then
                matches = false
            end
            if name and not string.find(child.Name:lower(), name:lower()) then
                matches = false
            end

            if matches then
                table.insert(results, {
                    name = child.Name,
                    class = child.ClassName,
                    path = getPathString(child)
                })
            end

            search(child)
        end
    end

    search(root)
    return { results = results, count = #results }
end

function handlers.get_selection(_args)
    local selected = Selection:Get()
    local paths = {}
    for _, instance in ipairs(selected) do
        table.insert(paths, getPathString(instance))
    end
    return { selection = paths, count = #paths }
end

function handlers.set_selection(args)
    local paths = args.paths
    local instances = {}

    for _, path in ipairs(paths) do
        local instance, err = resolvePath(path)
        if instance then
            table.insert(instances, instance)
        else
            return { error = err }
        end
    end

    Selection:Set(instances)
    return { success = true, selected = paths }
end

-- HTTP Polling Loop
local function processRequest(requestData)
    local tool = requestData.tool
    local args = requestData.args or {}
    local id = requestData.id

    _G.ClaudeMCP.lastRequest = tool
    _G.ClaudeMCP.requestCount = _G.ClaudeMCP.requestCount + 1

    -- Log to chat
    table.insert(_G.ClaudeMCP.chatLog, {
        role = "system",
        content = "[Tool Call] " .. tool,
        time = os.time()
    })

    local handler = handlers[tool]
    if not handler then
        return { id = id, error = "Unknown tool: " .. tool }
    end

    local ok, result = pcall(handler, args)
    if not ok then
        return { id = id, error = "Handler error: " .. tostring(result) }
    end

    return { id = id, result = result }
end

-- Main polling loop
local running = true

local function pollLoop()
    while running do
        local ok, response = pcall(function()
            return HttpService:GetAsync(BRIDGE_URL .. "/poll")
        end)

        if ok then
            _G.ClaudeMCP.connected = true
            local data = HttpService:JSONDecode(response)

            if not data.idle then
                -- Process the request
                local resultData = processRequest(data)

                -- Send result back
                pcall(function()
                    HttpService:PostAsync(
                        BRIDGE_URL .. "/result",
                        HttpService:JSONEncode(resultData),
                        Enum.HttpContentType.ApplicationJson
                    )
                end)
            end
        else
            _G.ClaudeMCP.connected = false
        end

        task.wait(POLL_INTERVAL)
    end
end

-- Start polling
task.spawn(pollLoop)

-- Cleanup on script destruction
script.Destroying:Connect(function()
    running = false
end)

print("[ClaudeMCP] Server script started. Polling " .. BRIDGE_URL)
