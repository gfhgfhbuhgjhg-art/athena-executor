--[[
    ATHENA EXPLORER
    A Studio-style DataModel explorer for executor environments.

    - Tree of every service / instance in the game (lazy expand)
    - Search by name or class, flat results with full paths
    - Property + attribute inspector
    - Copy path / copy script source / teleport to selected part
    - Highlight: select a Folder / Model / Part to outline everything inside
    - Open GUI: select any ScreenGui, Frame or a folder of GUIs to show it
    - Draggable + resizable, RightShift to show/hide

    Also connects this game to the OpenCode MCP bridge when it is running,
    so the agent can read and run code here.

    Works in Athena and Xeno. Execute it once; the explorer stays open.
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

--==============================================================
-- Parent container
--==============================================================
local function resolveParent()
    local ok, hui = pcall(function()
        return gethui and gethui()
    end)
    if ok and hui then
        return hui
    end
    local ok2, core = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok2 and core then
        return core
    end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local parent = resolveParent()
local previous = parent:FindFirstChild("AthenaExplorer")
if previous then
    previous:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "AthenaExplorer"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if syn and syn.protect_gui then
    pcall(syn.protect_gui, gui)
end

local attached = pcall(function()
    gui.Parent = parent
end)
if not attached then
    local player = Players.LocalPlayer
    if player then
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            pcall(function()
                gui.Parent = playerGui
            end)
        end
    end
end

--==============================================================
-- Theme + helpers
--==============================================================
local C = {
    bg = Color3.fromRGB(19, 20, 22),
    panel = Color3.fromRGB(26, 27, 30),
    panel2 = Color3.fromRGB(33, 34, 38),
    border = Color3.fromRGB(44, 45, 50),
    text = Color3.fromRGB(207, 208, 211),
    dim = Color3.fromRGB(140, 141, 146),
    bright = Color3.fromRGB(255, 255, 255),
    accent = Color3.fromRGB(122, 162, 247),
    sel = Color3.fromRGB(46, 55, 78),
    hover = Color3.fromRGB(38, 39, 43),
    green = Color3.fromRGB(128, 189, 138),
    red = Color3.fromRGB(208, 123, 123),
    gold = Color3.fromRGB(212, 174, 108),
}

local function make(class, props, par)
    local object = Instance.new(class)
    for key, value in pairs(props) do
        object[key] = value
    end
    object.Parent = par
    return object
end

local function round(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = object
    return corner
end

local function outline(object, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = object
    return stroke
end

local FONT = Enum.Font.Gotham
local FONT_MED = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local MONO = Enum.Font.Code

local function label(props, par)
    local base = {
        BackgroundTransparency = 1,
        Font = FONT,
        TextColor3 = C.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }
    for key, value in pairs(props) do
        base[key] = value
    end
    return make("TextLabel", base, par)
end

local function setClipboard(text)
    if setclipboard then
        pcall(setclipboard, tostring(text))
        return true
    end
    if toclipboard then
        pcall(toclipboard, tostring(text))
        return true
    end
    return false
end

local function classColor(className)
    local direct = {
        Workspace = Color3.fromRGB(212, 174, 108),
        Players = Color3.fromRGB(122, 162, 247),
        Lighting = Color3.fromRGB(230, 200, 120),
        ReplicatedStorage = Color3.fromRGB(167, 139, 250),
        ReplicatedFirst = Color3.fromRGB(139, 122, 247),
        ServerScriptService = Color3.fromRGB(208, 123, 123),
        ServerStorage = Color3.fromRGB(170, 90, 90),
        StarterGui = Color3.fromRGB(128, 189, 138),
        StarterPack = Color3.fromRGB(110, 180, 160),
        StarterPlayer = Color3.fromRGB(120, 190, 190),
        SoundService = Color3.fromRGB(220, 150, 190),
        Teams = Color3.fromRGB(122, 162, 247),
        Chat = Color3.fromRGB(155, 155, 160),
        TextChatService = Color3.fromRGB(155, 155, 160),
        MaterialService = Color3.fromRGB(190, 160, 120),
        CollectionService = Color3.fromRGB(190, 160, 120),
        Debris = Color3.fromRGB(190, 160, 120),
        RunService = Color3.fromRGB(190, 160, 120),
        TweenService = Color3.fromRGB(190, 160, 120),
        UserInputService = Color3.fromRGB(190, 160, 120),
        GuiService = Color3.fromRGB(190, 160, 120),
        ProximityPromptService = Color3.fromRGB(190, 160, 120),
        Part = Color3.fromRGB(150, 160, 175),
        MeshPart = Color3.fromRGB(150, 160, 175),
        WedgePart = Color3.fromRGB(150, 160, 175),
        Model = Color3.fromRGB(150, 160, 175),
        Folder = Color3.fromRGB(180, 180, 185),
        Script = Color3.fromRGB(122, 162, 247),
        LocalScript = Color3.fromRGB(122, 162, 247),
        ModuleScript = Color3.fromRGB(167, 139, 250),
        Humanoid = Color3.fromRGB(128, 189, 138),
        Camera = Color3.fromRGB(120, 190, 190),
    }
    local color = direct[className]
    if color then
        return color
    end
    if string.match(className, "Service$") then
        return C.gold
    end
    if string.match(className, "Script$") then
        return C.accent
    end
    if string.match(className, "Value$") then
        return C.gold
    end
    if string.find(className, "Light") then
        return Color3.fromRGB(230, 200, 120)
    end
    if string.find(className, "Gui") or string.find(className, "Frame") or string.find(className, "Label") or string.find(className, "Button") then
        return C.green
    end
    return C.dim
end

--==============================================================
-- Window shell
--==============================================================
local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local startWidth = math.min(940, math.max(640, viewport.X - 80))
local startHeight = math.min(620, math.max(420, viewport.Y - 100))

local main = make("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(startWidth, startHeight),
    Position = UDim2.fromOffset(math.floor((viewport.X - startWidth) / 2), math.floor((viewport.Y - startHeight) / 2)),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
round(main, 10)
outline(main, C.border, 1)

local titlebar = make("Frame", {
    Name = "Titlebar",
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, main)
round(titlebar, 10)
make("Frame", {
    Size = UDim2.new(1, 0, 0, 10),
    Position = UDim2.new(0, 0, 1, -10),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, titlebar)

local brandDot = make("Frame", {
    Size = UDim2.fromOffset(8, 8),
    Position = UDim2.fromOffset(14, 15),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0,
}, titlebar)
round(brandDot, 4)

label({
    Text = "ATHENA",
    Font = FONT_BOLD,
    TextSize = 12,
    TextColor3 = C.bright,
    Position = UDim2.fromOffset(30, 0),
    Size = UDim2.fromOffset(60, 38),
}, titlebar)

label({
    Text = "EXPLORER",
    Font = FONT_MED,
    TextSize = 11,
    TextColor3 = C.dim,
    Position = UDim2.fromOffset(86, 0),
    Size = UDim2.fromOffset(90, 38),
}, titlebar)

label({
    Text = "RightShift to toggle",
    Font = FONT,
    TextSize = 10,
    TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.new(1, -206, 0, 0),
    Size = UDim2.fromOffset(120, 38),
}, titlebar)

local function titleButton(text, x, color, par)
    local button = make("TextButton", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, x, 0, 6),
        BackgroundColor3 = C.panel2,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = text,
        Font = FONT_MED,
        TextSize = 15,
        TextColor3 = color or C.dim,
        AutoButtonColor = false,
        ZIndex = 5,
    }, par)
    round(button, 5)
    button.MouseEnter:Connect(function()
        button.BackgroundTransparency = 0
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundTransparency = 1
    end)
    return button
end

local closeButton = titleButton("×", -34, C.red, titlebar)
local minimizeButton = titleButton("–", -66, C.dim, titlebar)

local resizeHandle = make("Frame", {
    Name = "ResizeHandle",
    Size = UDim2.fromOffset(18, 18),
    Position = UDim2.new(1, -18, 1, -18),
    BackgroundTransparency = 1,
    Active = true,
    ZIndex = 10,
}, main)
label({
    Name = "Grip",
    Text = "◢",
    Font = FONT,
    TextSize = 12,
    TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextYAlignment = Enum.TextYAlignment.Bottom,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 11,
}, resizeHandle)

--==============================================================
-- Toolbar
--==============================================================
local toolbar = make("Frame", {
    Name = "Toolbar",
    Size = UDim2.new(1, -24, 0, 34),
    Position = UDim2.fromOffset(12, 44),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, main)
round(toolbar, 7)

local search = make("TextBox", {
    Size = UDim2.new(0, 280, 0, 24),
    Position = UDim2.fromOffset(6, 5),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    Font = FONT,
    TextSize = 12,
    TextColor3 = C.text,
    PlaceholderText = "Search name or class...",
    PlaceholderColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "",
    ClearTextOnFocus = false,
    ZIndex = 3,
}, toolbar)
round(search, 5)
outline(search, C.border, 1)
local function toolButton(text, width, x, color)
    local button = make("TextButton", {
        Size = UDim2.fromOffset(width, 24),
        Position = UDim2.fromOffset(x, 5),
        BackgroundColor3 = C.panel2,
        BorderSizePixel = 0,
        Font = FONT_MED,
        Text = text,
        TextSize = 11,
        TextColor3 = color or C.text,
        AutoButtonColor = false,
        ZIndex = 3,
    }, toolbar)
    round(button, 5)
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = C.hover
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = C.panel2
    end)
    return button
end

local refreshButton = toolButton("Refresh", 62, 294)
local expandButton = toolButton("Expand", 58, 362)
local collapseButton = toolButton("Collapse", 64, 424)
local nilButton = toolButton("Nil", 36, 494)

local countLabel = label({
    Name = "Count",
    Text = "0 items",
    Font = FONT,
    TextSize = 10,
    TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.new(1, -170, 0, 0),
    Size = UDim2.fromOffset(160, 34),
}, toolbar)

--==============================================================
-- Body: tree (left) + properties (right)
--==============================================================
local body = make("Frame", {
    Name = "Body",
    Size = UDim2.new(1, -24, 1, -122),
    Position = UDim2.fromOffset(12, 84),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, main)

local treePanel = make("Frame", {
    Name = "Hierarchy",
    Size = UDim2.new(0.56, -5, 1, 0),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, body)
round(treePanel, 8)
outline(treePanel, C.border, 1)

label({
    Text = "HIERARCHY",
    Font = FONT_BOLD,
    TextSize = 10,
    TextColor3 = C.dim,
    Position = UDim2.fromOffset(10, 4),
    Size = UDim2.fromOffset(200, 22),
}, treePanel)

local treeScroll = make("ScrollingFrame", {
    Name = "Rows",
    Size = UDim2.new(1, -8, 1, -34),
    Position = UDim2.fromOffset(4, 30),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = C.border,
    ScrollBarImageTransparency = 0.2,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    AutomaticCanvasSize = Enum.AutomaticSize.None,
}, treePanel)

local propsPanel = make("Frame", {
    Name = "Properties",
    Size = UDim2.new(0.44, -5, 1, 0),
    Position = UDim2.new(0.56, 5, 0, 0),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, body)
round(propsPanel, 8)
outline(propsPanel, C.border, 1)

label({
    Text = "PROPERTIES",
    Font = FONT_BOLD,
    TextSize = 10,
    TextColor3 = C.dim,
    Position = UDim2.fromOffset(10, 4),
    Size = UDim2.fromOffset(120, 22),
}, propsPanel)

local pathLabel = label({
    Name = "Path",
    Text = "Select an instance",
    Font = MONO,
    TextSize = 10,
    TextColor3 = C.dim,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Position = UDim2.fromOffset(78, 4),
    Size = UDim2.new(1, -86, 0, 22),
}, propsPanel)

local propFilter = make("TextBox", {
    Size = UDim2.new(1, -16, 0, 22),
    Position = UDim2.fromOffset(8, 30),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    Font = FONT,
    TextSize = 11,
    TextColor3 = C.text,
    PlaceholderText = "Filter properties...",
    PlaceholderColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "",
    ClearTextOnFocus = false,
}, propsPanel)
round(propFilter, 5)
outline(propFilter, C.border, 1)

local propsScroll = make("ScrollingFrame", {
    Name = "PropertyRows",
    Size = UDim2.new(1, -10, 1, -122),
    Position = UDim2.fromOffset(5, 56),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = C.border,
    ScrollBarImageTransparency = 0.2,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    AutomaticCanvasSize = Enum.AutomaticSize.None,
}, propsPanel)

local propActions = make("Frame", {
    Size = UDim2.new(1, -12, 0, 26),
    Position = UDim2.new(0, 6, 1, -32),
    BackgroundTransparency = 1,
}, propsPanel)

local propActions2 = make("Frame", {
    Name = "Actions2",
    Size = UDim2.new(1, -12, 0, 26),
    Position = UDim2.new(0, 6, 1, -62),
    BackgroundTransparency = 1,
}, propsPanel)

local function actionButton(text, x, width, color, holder)
    local button = make("TextButton", {
        Size = UDim2.fromOffset(width, 26),
        Position = UDim2.fromOffset(x, 0),
        BackgroundColor3 = C.panel2,
        BorderSizePixel = 0,
        Font = FONT_MED,
        Text = text,
        TextSize = 10,
        TextColor3 = color or C.text,
        AutoButtonColor = false,
    }, holder or propActions)
    round(button, 5)
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = C.hover
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = C.panel2
    end)
    return button
end

local copyPathButton = actionButton("Copy Path", 0, 70)
local copyNameButton = actionButton("Copy Name", 76, 70)
local copySourceButton = actionButton("Copy Source", 152, 82)
local teleportButton = actionButton("Teleport", 240, 66)

local highlightButton = actionButton("Highlight", 0, 78, C.text, propActions2)
local guiButton = actionButton("Open GUI", 84, 78, C.text, propActions2)

--==============================================================
-- Status bar
--==============================================================
local status = make("Frame", {
    Size = UDim2.new(1, -24, 0, 26),
    Position = UDim2.new(0, 12, 1, -38),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, main)
round(status, 6)

local statusLabel = label({
    Text = "Ready",
    Font = FONT,
    TextSize = 10,
    TextColor3 = C.dim,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -20, 1, 0),
}, status)

local function setStatus(text, color)
    statusLabel.Text = text
    statusLabel.TextColor3 = color or C.dim
end

--==============================================================
-- Tree state
--==============================================================
local ROW_HEIGHT = 22
local MAX_ROWS = 1500
local expanded = {}
local selected = nil
local rowFrames = {}
local showNil = false
local lastClickInstance = nil
local lastClickTime = 0

--==============================================================
-- MCP bridge (optional, same one Athena's Copilot uses)
--==============================================================
local genv = getgenv and getgenv() or {}
if not genv.MCP_Loaded and not genv.ATHENA_EXPLORER_NO_MCP then
    task.spawn(function()
        local hosts = {}
        local preferred = type(genv.BridgeURL) == "string" and genv.BridgeURL or ""
        preferred = string.gsub(preferred, "^%a+://", "")
        preferred = string.gsub(preferred, "/.*$", "")
        if preferred ~= "" then
            hosts[1] = preferred
        end
        hosts[#hosts + 1] = "127.0.0.1:16384"
        hosts[#hosts + 1] = "localhost:16384"

        for _, host in ipairs(hosts) do
            local ok, source = pcall(function()
                return game:HttpGet("http://" .. host .. "/script.luau")
            end)
            if ok and type(source) == "string" and #source > 1000 then
                local chunk = loadstring(source)
                if chunk then
                    local ran = pcall(chunk)
                    if ran and genv.MCP_Loaded then
                        return
                    end
                end
            end
            task.wait(0.2)
        end
    end)
end

--==============================================================
-- Highlight / ESP
--==============================================================
local MAX_HIGHLIGHTS = 200
local highlightFolder = nil
local highlightOwner = nil

local function clearHighlights(silent)
    if highlightFolder then
        pcall(function()
            highlightFolder:Destroy()
        end)
        highlightFolder = nil
    end
    highlightOwner = nil
    highlightButton.Text = "Highlight"
    highlightButton.TextColor3 = C.text
    if not silent then
        setStatus("Highlights cleared", C.dim)
    end
end

local function collectESP(root)
    local targets = {}
    local skipped = 0
    local truncated = false

    local function visit(obj)
        if #targets >= MAX_HIGHLIGHTS then
            truncated = true
            return
        end
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local ok, inWorld = pcall(function()
                return obj:IsDescendantOf(workspace)
            end)
            if ok and inWorld then
                targets[#targets + 1] = obj
            else
                skipped = skipped + 1
            end
            return
        end
        local ok, kids = pcall(obj.GetChildren, obj)
        if not ok then
            return
        end
        for _, kid in ipairs(kids) do
            visit(kid)
            if #targets >= MAX_HIGHLIGHTS then
                truncated = true
                return
            end
        end
    end

    visit(root)
    return targets, skipped, truncated
end

local function applyHighlight(root)
    local targets, skipped, truncated = collectESP(root)
    if #targets == 0 then
        setStatus("Nothing in Workspace to highlight here", C.red)
        return
    end
    clearHighlights(true)

    local folder = Instance.new("Folder")
    folder.Name = "AthenaHighlights"
    folder.Parent = parent

    local made = 0
    for _, target in ipairs(targets) do
        local ok = pcall(function()
            local h = Instance.new("Highlight")
            h.Name = "AthenaESP"
            h.Adornee = target
            h.FillColor = C.accent
            h.FillTransparency = 0.65
            h.OutlineColor = Color3.fromRGB(255, 255, 255)
            h.OutlineTransparency = 0
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = folder
        end)
        if ok then
            made = made + 1
        end
    end

    if made == 0 then
        pcall(function()
            folder:Destroy()
        end)
        setStatus("Highlight is not supported by this executor", C.red)
        return
    end

    highlightFolder = folder
    highlightOwner = root
    highlightButton.Text = "Clear"
    highlightButton.TextColor3 = C.green

    local note = tostring(made) .. " highlighted"
    if skipped > 0 then
        note = note .. ", " .. tostring(skipped) .. " skipped"
    end
    if truncated then
        note = note .. " (capped at " .. tostring(MAX_HIGHLIGHTS) .. ")"
    end
    setStatus(note, C.green)
end

--==============================================================
-- GUI activation
--==============================================================
local guiActions = {}
local guiOpen = false

local function localPlayerGui()
    local player = Players.LocalPlayer
    if not player then
        return nil
    end
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        playerGui = player:FindFirstChild("PlayerGui")
    end
    return playerGui
end

local function isCollector(obj)
    return obj:IsA("ScreenGui")
        or obj:IsA("BillboardGui")
        or obj:IsA("SurfaceGui")
        or obj:IsA("LayerCollector")
end

local function nearestCollector(obj)
    local node = obj
    while node and node ~= game do
        if isCollector(node) then
            return node
        end
        node = node.Parent
    end
    return nil
end

local function namePath(root, target)
    local names = {}
    local node = target
    while node and node ~= root do
        table.insert(names, 1, node.Name)
        node = node.Parent
    end
    if node ~= root then
        return nil
    end
    return names
end

local function revealNames(root, names)
    if not names then
        return
    end
    local node = root
    for _, name in ipairs(names) do
        local nextNode = node:FindFirstChild(name)
        if not nextNode then
            return
        end
        node = nextNode
        if node:IsA("GuiObject") then
            guiActions[#guiActions + 1] = { kind = "visible", object = node, previous = node.Visible }
            node.Visible = true
        end
    end
end

local function activateCollector(collector, focus)
    local playerGui = localPlayerGui()
    if not playerGui then
        return false
    end

    local names = focus and namePath(collector, focus) or nil
    local okLive, live = pcall(function()
        return collector:IsDescendantOf(playerGui)
    end)

    if okLive and live then
        guiActions[#guiActions + 1] = { kind = "enabled", object = collector, previous = collector.Enabled }
        collector.Enabled = true
        revealNames(collector, names)
        return true
    end

    local okClone, clone = pcall(function()
        return collector:Clone()
    end)
    if not okClone or not clone then
        return false
    end

    clone.Enabled = true
    if clone:IsA("ScreenGui") then
        clone.ResetOnSpawn = false
        if (clone.DisplayOrder or 0) < 999 then
            clone.DisplayOrder = 999
        end
    elseif clone:IsA("BillboardGui") and clone.Adornee == nil then
        local character = Players.LocalPlayer and Players.LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            clone.Adornee = rootPart
        end
    end
    pcall(function()
        clone.Parent = playerGui
    end)
    if clone.Parent ~= playerGui then
        pcall(function()
            clone:Destroy()
        end)
        return false
    end

    guiActions[#guiActions + 1] = { kind = "clone", object = clone }
    revealNames(clone, names)
    return true
end

local function activateBare(obj)
    local playerGui = localPlayerGui()
    if not playerGui then
        return false
    end
    local okClone, clone = pcall(function()
        return obj:Clone()
    end)
    if not okClone or not clone then
        return false
    end

    local holder = Instance.new("ScreenGui")
    holder.Name = "AthenaGuiPreview"
    holder.ResetOnSpawn = false
    holder.DisplayOrder = 999
    holder.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    clone.Parent = holder
    pcall(function()
        holder.Parent = playerGui
    end)
    if holder.Parent ~= playerGui then
        pcall(function()
            holder:Destroy()
        end)
        return false
    end

    guiActions[#guiActions + 1] = { kind = "clone", object = holder }
    if clone:IsA("GuiObject") then
        guiActions[#guiActions + 1] = { kind = "visible", object = clone, previous = clone.Visible }
        clone.Visible = true
    end
    return true
end

local function collectGuiTargets(root)
    local collectors = {}
    local bare = {}
    local seen = {}

    local function addCollector(collector)
        if not seen[collector] then
            seen[collector] = true
            collectors[#collectors + 1] = collector
        end
    end

    local function visit(obj)
        if isCollector(obj) then
            addCollector(obj)
            return
        end
        if obj:IsA("GuiObject") then
            local collector = nearestCollector(obj)
            if collector then
                addCollector(collector)
            else
                bare[#bare + 1] = obj
            end
            return
        end
        local ok, kids = pcall(obj.GetChildren, obj)
        if not ok then
            return
        end
        for _, kid in ipairs(kids) do
            visit(kid)
        end
    end

    visit(root)
    return collectors, bare
end

local function activateGui(root)
    if not localPlayerGui() then
        setStatus("No PlayerGui - join a game first", C.red)
        return
    end

    local count = 0
    if root:IsA("GuiObject") and not isCollector(root) then
        local collector = nearestCollector(root)
        if collector then
            if activateCollector(collector, root) then
                count = 1
            end
        elseif activateBare(root) then
            count = 1
        end
    elseif isCollector(root) then
        if activateCollector(root) then
            count = 1
        end
    else
        local collectors, bare = collectGuiTargets(root)
        for _, collector in ipairs(collectors) do
            if activateCollector(collector) then
                count = count + 1
            end
        end
        for _, obj in ipairs(bare) do
            if activateBare(obj) then
                count = count + 1
            end
        end
    end

    if count == 0 then
        setStatus("No GUI found in this selection", C.red)
        return
    end

    guiOpen = true
    guiButton.Text = "Close GUI"
    guiButton.TextColor3 = C.gold
    setStatus("Activated " .. tostring(count) .. " GUI" .. (count == 1 and "" or "s"), C.green)
end

local function closeGuis()
    for index = #guiActions, 1, -1 do
        local action = guiActions[index]
        if action.kind == "clone" then
            pcall(function()
                action.object:Destroy()
            end)
        elseif action.kind == "enabled" then
            pcall(function()
                action.object.Enabled = action.previous and true or false
            end)
        elseif action.kind == "visible" then
            pcall(function()
                action.object.Visible = action.previous and true or false
            end)
        end
    end
    guiActions = {}
    guiOpen = false
    guiButton.Text = "Open GUI"
    guiButton.TextColor3 = C.text
    setStatus("Closed activated GUIs", C.dim)
end

local function rootsFor(mode)
    if mode then
        local ok, nils = pcall(getnilinstances)
        if ok and type(nils) == "table" then
            local list = {}
            for index = 1, math.min(#nils, MAX_ROWS) do
                list[#list + 1] = nils[index]
            end
            table.sort(list, function(a, b)
                return string.lower(a.Name) < string.lower(b.Name)
            end)
            return list
        end
    end
    local ok, children = pcall(function()
        return game:GetChildren()
    end)
    if not ok or not children then
        return {}
    end
    table.sort(children, function(a, b)
        return string.lower(a.Name) < string.lower(b.Name)
    end)
    return children
end

local function safeChildren(instance)
    local ok, children = pcall(instance.GetChildren, instance)
    if ok and type(children) == "table" then
        table.sort(children, function(a, b)
            return string.lower(a.Name) < string.lower(b.Name)
        end)
        return children
    end
    return {}
end

local function rawChildren(instance)
    local ok, children = pcall(instance.GetChildren, instance)
    if ok and type(children) == "table" then
        return children
    end
    return {}
end

local function searchInstances(query)
    local results = {}
    local needle = string.lower(query)
    local queue = { game }
    local head = 1
    local visited = 0
    while head <= #queue and #results < 300 and visited < 15000 do
        local instance = queue[head]
        head = head + 1
        local children = rawChildren(instance)
        for index = 1, #children do
            local child = children[index]
            visited = visited + 1
            if string.find(string.lower(child.Name), needle, 1, true) or string.find(string.lower(child.ClassName), needle, 1, true) then
                results[#results + 1] = child
                if #results >= 300 then
                    break
                end
            end
            if #queue < 30000 then
                queue[#queue + 1] = child
            end
        end
    end
    return results
end

--==============================================================
-- Property helpers
--==============================================================
local COMMON_PROPS = { "Name", "ClassName", "Parent", "Archivable" }
local CLASS_PROPS = {
    BasePart = { "Position", "Size", "CFrame", "Anchored", "CanCollide", "CanTouch", "CanQuery", "Transparency", "Reflectance", "Material", "Color", "BrickColor", "Massless", "CastShadow" },
    Model = { "PrimaryPart", "LevelOfDetail", "ModelStreamingMode" },
    Humanoid = { "Health", "MaxHealth", "WalkSpeed", "JumpPower", "JumpHeight", "HipHeight", "DisplayName", "DisplayDistanceType", "AutoRotate" },
    Player = { "DisplayName", "UserId", "Team", "Character", "AccountAge", "MembershipType" },
    Team = { "TeamColor", "AutoAssignable" },
    Camera = { "CameraType", "FieldOfView", "CFrame", "Focus", "HeadLocked" },
    TextLabel = { "Text", "TextColor3", "TextSize", "TextScaled", "Font", "TextWrapped", "RichText", "TextStrokeTransparency" },
    TextButton = { "Text", "TextColor3", "TextSize", "TextScaled", "Font", "TextWrapped", "RichText", "AutoButtonColor" },
    TextBox = { "Text", "PlaceholderText", "TextColor3", "TextSize", "Font", "ClearTextOnFocus", "MultiLine" },
    GuiObject = { "Visible", "Size", "Position", "AnchorPoint", "BackgroundTransparency", "BackgroundColor3", "BorderSizePixel", "ZIndex", "LayoutOrder", "Rotation", "ClipsDescendants" },
    ValueBase = { "Value" },
    StringValue = { "Value" },
    NumberValue = { "Value" },
    BoolValue = { "Value" },
    IntValue = { "Value" },
    ObjectValue = { "Value" },
    CFrameValue = { "Value" },
    Vector3Value = { "Value" },
    Color3Value = { "Value" },
    BrickColorValue = { "Value" },
    Sound = { "SoundId", "Volume", "Playing", "Looped", "TimePosition", "PlaybackSpeed", "RollOffMode" },
    PointLight = { "Brightness", "Color", "Range", "Enabled", "Shadows" },
    SpotLight = { "Brightness", "Color", "Range", "Angle", "Enabled", "Shadows" },
    SurfaceLight = { "Brightness", "Color", "Range", "Angle", "Enabled", "Shadows" },
    ParticleEmitter = { "Enabled", "Rate", "Lifetime", "Speed", "Texture", "Color", "Size", "Transparency", "EmissionDirection" },
    Beam = { "Enabled", "Texture", "Color", "Width0", "Width1", "Transparency", "FaceCamera" },
    Trail = { "Enabled", "Texture", "Color", "Lifetime", "Transparency", "WidthScale" },
    Decal = { "Texture", "Transparency", "Face", "Color3" },
    Texture = { "Texture", "Transparency", "Face", "Color3", "StudsPerTileU", "StudsPerTileV" },
    MeshPart = { "MeshId", "TextureID", "RenderFidelity", "DoubleSided", "CollisionFidelity" },
    Animation = { "AnimationId" },
    ProximityPrompt = { "ActionText", "ObjectText", "HoldDuration", "MaxActivationDistance", "Enabled", "RequiresLineOfSight", "KeyboardKeyCode" },
    ClickDetector = { "MaxActivationDistance", "CursorIcon" },
    Tool = { "ToolTip", "CanBeDropped", "RequiresHandle", "Enabled" },
    Script = { "Enabled", "RunContext" },
    LocalScript = { "Enabled", "RunContext" },
    ModuleScript = {},
    BindableEvent = {},
    RemoteEvent = {},
    RemoteFunction = {},
}

local function getProperty(instance, name)
    local ok, value = pcall(function()
        return instance[name]
    end)
    if ok then
        return value
    end
    return nil
end

local function normalizeProperties(instance)
    local out = {}
    local seen = {}
    local ok, raw = pcall(function()
        return getproperties(instance)
    end)
    if ok and type(raw) == "table" then
        if #raw > 0 then
            for index = 1, #raw do
                local entry = raw[index]
                local name = nil
                local value = nil
                if type(entry) == "table" then
                    name = entry.Name or entry[1]
                    value = entry.Value
                    if value == nil and entry[2] ~= nil then
                        value = entry[2]
                    end
                elseif type(entry) == "string" then
                    name = entry
                    value = getProperty(instance, name)
                end
                if type(name) == "string" and not seen[name] then
                    seen[name] = true
                    out[#out + 1] = { name = name, value = value, kind = "property" }
                end
            end
        else
            for key, value in pairs(raw) do
                if type(key) == "string" and not seen[key] then
                    seen[key] = true
                    out[#out + 1] = { name = key, value = value, kind = "property" }
                end
            end
        end
    end
    if #out == 0 then
        local list = {}
        for index = 1, #COMMON_PROPS do
            list[#list + 1] = COMMON_PROPS[index]
        end
        local classList = CLASS_PROPS[instance.ClassName]
        if classList then
            for index = 1, #classList do
                list[#list + 1] = classList[index]
            end
        end
        for className, props in pairs(CLASS_PROPS) do
            if className ~= instance.ClassName then
                local okIsA, isA = pcall(function()
                    return instance:IsA(className)
                end)
                if okIsA and isA then
                    for index = 1, #props do
                        list[#list + 1] = props[index]
                    end
                end
            end
        end
        if instance:IsA("LuaSourceContainer") then
            list[#list + 1] = "Source"
        end
        for index = 1, #list do
            local name = list[index]
            if not seen[name] then
                seen[name] = true
                out[#out + 1] = { name = name, value = getProperty(instance, name), kind = "property" }
            end
        end
    end
    local okAttrs, attributes = pcall(function()
        return instance:GetAttributes()
    end)
    if okAttrs and type(attributes) == "table" then
        for key, value in pairs(attributes) do
            out[#out + 1] = { name = "@" .. key, value = value, kind = "attribute" }
        end
    end
    table.sort(out, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)
    return out
end

local function formatValue(value)
    local valueType = typeof(value)
    if value == nil then
        return "nil"
    elseif valueType == "string" then
        local text = string.gsub(value, "\n", "\\n")
        text = string.gsub(text, "\r", "")
        if #text > 320 then
            text = string.sub(text, 1, 320) .. "..."
        end
        return '"' .. text .. '"'
    elseif valueType == "Instance" then
        return value:GetFullName()
    elseif valueType == "number" then
        if value ~= value then
            return "nan"
        end
        return tostring(value)
    elseif valueType == "boolean" then
        return tostring(value)
    elseif valueType == "Vector3" then
        return string.format("Vector3(%.2f, %.2f, %.2f)", value.X, value.Y, value.Z)
    elseif valueType == "Vector2" then
        return string.format("Vector2(%.2f, %.2f)", value.X, value.Y)
    elseif valueType == "CFrame" then
        local position = value.Position
        return string.format("CFrame(%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
    elseif valueType == "Color3" then
        return string.format("RGB(%d, %d, %d)", math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5))
    elseif valueType == "BrickColor" then
        return value.Name .. " (" .. tostring(value.Number) .. ")"
    elseif valueType == "EnumItem" then
        return tostring(value)
    elseif valueType == "table" then
        local count = #value
        return "table [" .. tostring(count) .. "]"
    elseif valueType == "UDim2" then
        return "UDim2(" .. tostring(value.X.Scale) .. ", " .. tostring(value.X.Offset) .. ", " .. tostring(value.Y.Scale) .. ", " .. tostring(value.Y.Offset) .. ")"
    elseif valueType == "UDim" then
        return "UDim(" .. tostring(value.Scale) .. ", " .. tostring(value.Offset) .. ")"
    end
    local ok, text = pcall(tostring, value)
    if ok then
        return text
    end
    return "<" .. valueType .. ">"
end

local function valueColor(value)
    local valueType = typeof(value)
    if valueType == "string" then
        return Color3.fromRGB(180, 210, 170)
    elseif valueType == "number" then
        return Color3.fromRGB(190, 200, 240)
    elseif valueType == "boolean" then
        return value and C.green or C.red
    elseif valueType == "Instance" then
        return C.accent
    elseif valueType == "EnumItem" then
        return C.gold
    elseif valueType == "nil" then
        return C.dim
    end
    return C.text
end

--==============================================================
-- Renderers
--==============================================================
local currentProps = {}

local function rowsContainer()
    return propsScroll
end

local function renderProperties(instance, filter)
    propsScroll:ClearAllChildren()
    currentProps = {}
    local props = normalizeProperties(instance)
    local needle = string.lower(filter or "")
    local y = 0
    local shown = 0
    for index = 1, #props do
        local entry = props[index]
        if needle == "" or string.find(string.lower(entry.name), needle, 1, true) then
            if shown >= 400 then
                break
            end
            shown = shown + 1
            currentProps[#currentProps + 1] = entry
            local row = make("Frame", {
                Size = UDim2.new(1, -4, 0, 20),
                Position = UDim2.fromOffset(2, y),
                BackgroundColor3 = (shown % 2 == 0) and C.panel2 or C.panel,
                BackgroundTransparency = (shown % 2 == 0) and 0.55 or 1,
                BorderSizePixel = 0,
            }, propsScroll)
            label({
                Text = entry.name,
                Font = FONT,
                TextSize = 11,
                TextColor3 = (entry.kind == "attribute") and C.gold or C.dim,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Size = UDim2.new(0, 150, 1, 0),
                Position = UDim2.fromOffset(6, 0),
            }, row)
            local valueLabel = label({
                Text = formatValue(entry.value),
                Font = MONO,
                TextSize = 10,
                TextColor3 = valueColor(entry.value),
                TextTruncate = Enum.TextTruncate.AtEnd,
                Size = UDim2.new(1, -166, 1, 0),
                Position = UDim2.fromOffset(160, 0),
                Active = true,
            }, row)
            valueLabel.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if setClipboard(formatValue(entry.value)) then
                        setStatus("Copied value of " .. entry.name, C.green)
                    end
                end
            end)
            y = y + 20
        end
    end
    if shown == 0 then
        label({
            Text = "No matching properties",
            Font = FONT,
            TextSize = 11,
            TextColor3 = C.dim,
            Position = UDim2.fromOffset(8, 4),
            Size = UDim2.new(1, -16, 0, 20),
        }, propsScroll)
        y = 24
    end
    propsScroll.CanvasSize = UDim2.new(0, 0, 0, y + 6)
end

local function toggleExpanded(instance)
    if expanded[instance] then
        expanded[instance] = nil
    else
        expanded[instance] = true
    end
end

local selectInstance

local function renderTree(query, keepScroll)
    local previousScroll = treeScroll.CanvasPosition.Y
    treeScroll:ClearAllChildren()
    rowFrames = {}
    expanded[game] = true

    local rows = {}
    if query and query ~= "" then
        local results = searchInstances(query)
        for index = 1, #results do
            rows[#rows + 1] = { instance = results[index], depth = 0, search = true }
        end
    else
        local roots = rootsFor(showNil)
        local function walk(instance, depth)
            if #rows >= MAX_ROWS then
                return
            end
            rows[#rows + 1] = { instance = instance, depth = depth }
            if expanded[instance] then
                local children = safeChildren(instance)
                for index = 1, #children do
                    walk(children[index], depth + 1)
                    if #rows >= MAX_ROWS then
                        return
                    end
                end
            end
        end
        for index = 1, #roots do
            walk(roots[index], 0)
            if #rows >= MAX_ROWS then
                break
            end
        end
    end

    local y = 0
    for index = 1, #rows do
        local entry = rows[index]
        local instance = entry.instance
        local depth = entry.depth
        local isSelected = instance == selected
        local row = make("TextButton", {
            Size = UDim2.new(1, -6, 0, ROW_HEIGHT - 2),
            Position = UDim2.fromOffset(2, y),
            BackgroundColor3 = isSelected and C.sel or C.hover,
            BackgroundTransparency = isSelected and 0 or 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 2,
        }, treeScroll)
        y = y + ROW_HEIGHT

        local childOk, childList = pcall(instance.GetChildren, instance)
        local hasChildren = childOk and type(childList) == "table" and #childList > 0
        local indent = depth * 12

        if hasChildren and not entry.search then
            local arrow = make("TextButton", {
                Size = UDim2.fromOffset(14, ROW_HEIGHT - 2),
                Position = UDim2.fromOffset(indent + 2, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Text = expanded[instance] and "▾" or "▸",
                Font = FONT,
                TextSize = 12,
                TextColor3 = C.dim,
                AutoButtonColor = false,
                ZIndex = 3,
            }, row)
            arrow.MouseButton1Click:Connect(function()
                toggleExpanded(instance)
                renderTree(search.Text, true)
            end)
        end

        local iconX = indent + 18
        if not hasChildren or entry.search then
            iconX = indent + 6
        end
        local icon = make("Frame", {
            Size = UDim2.fromOffset(14, 14),
            Position = UDim2.fromOffset(iconX, 4),
            BackgroundColor3 = classColor(instance.ClassName),
            BackgroundTransparency = 0.1,
            BorderSizePixel = 0,
            ZIndex = 3,
        }, row)
        round(icon, 3)
        label({
            Text = string.upper(string.sub(instance.ClassName, 1, 1)),
            Font = FONT_BOLD,
            TextSize = 9,
            TextColor3 = C.bg,
            TextXAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 4,
        }, icon)

        local nameX = iconX + 20
        local name = label({
            Text = instance.Name,
            Font = (instance == game) and FONT_MED or FONT,
            TextSize = 12,
            TextColor3 = isSelected and C.bright or C.text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(nameX, 0),
            Size = UDim2.new(1, -(nameX + 132), 1, 0),
            ZIndex = 3,
        }, row)

        label({
            Text = instance.ClassName,
            Font = FONT,
            TextSize = 10,
            TextColor3 = C.dim,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Right,
            Position = UDim2.new(1, -128, 0, 0),
            Size = UDim2.fromOffset(124, ROW_HEIGHT - 2),
            ZIndex = 3,
        }, row)

        row.MouseEnter:Connect(function()
            if instance ~= selected then
                row.BackgroundTransparency = 0
                row.BackgroundColor3 = C.hover
            end
        end)
        row.MouseLeave:Connect(function()
            if instance ~= selected then
                row.BackgroundTransparency = 1
            end
        end)
        row.MouseButton1Click:Connect(function()
            local now = os.clock()
            local doubleClick = lastClickInstance == instance and (now - lastClickTime) < 0.35
            lastClickInstance = instance
            lastClickTime = now
            selectInstance(instance)
            if doubleClick then
                toggleExpanded(instance)
                renderTree(search.Text, true)
            end
        end)
        rowFrames[instance] = { frame = row, name = name }
    end

    if #rows >= MAX_ROWS then
        label({
            Text = "Row limit reached - use search to narrow down",
            Font = FONT,
            TextSize = 10,
            TextColor3 = C.gold,
            Position = UDim2.fromOffset(8, y + 2),
            Size = UDim2.new(1, -16, 0, 20),
        }, treeScroll)
        y = y + 24
    end

    treeScroll.CanvasSize = UDim2.new(0, 0, 0, y + 4)
    if keepScroll then
        local maxScroll = math.max(0, y + 4 - treeScroll.AbsoluteWindowSize.Y)
        treeScroll.CanvasPosition = Vector2.new(0, math.min(previousScroll, maxScroll))
    else
        treeScroll.CanvasPosition = Vector2.new(0, 0)
    end
    countLabel.Text = tostring(#rows) .. (#rows == 1 and " item" or " items")
end

selectInstance = function(instance)
    if highlightOwner and highlightOwner ~= instance then
        clearHighlights(true)
    end

    local previous = selected
    selected = instance

    if previous and previous ~= instance then
        local oldRow = rowFrames[previous]
        if oldRow and oldRow.frame and oldRow.frame.Parent then
            oldRow.frame.BackgroundColor3 = C.hover
            oldRow.frame.BackgroundTransparency = 1
            oldRow.name.TextColor3 = C.text
        end
    end

    local newRow = rowFrames[instance]
    if newRow and newRow.frame and newRow.frame.Parent then
        newRow.frame.BackgroundColor3 = C.sel
        newRow.frame.BackgroundTransparency = 0
        newRow.name.TextColor3 = C.bright
    end

    pathLabel.Text = instance:GetFullName()
    renderProperties(instance, propFilter.Text)
    copySourceButton.Visible = instance:IsA("LuaSourceContainer")
    teleportButton.Visible = instance:IsA("BasePart")
end

--==============================================================
-- Events
--==============================================================
local searchToken = 0
search:GetPropertyChangedSignal("Text"):Connect(function()
    searchToken = searchToken + 1
    local token = searchToken
    task.delay(0.16, function()
        if token ~= searchToken then
            return
        end
        renderTree(search.Text)
    end)
end)

local propToken = 0
propFilter:GetPropertyChangedSignal("Text"):Connect(function()
    propToken = propToken + 1
    local token = propToken
    task.delay(0.12, function()
        if token ~= propToken then
            return
        end
        if selected then
            renderProperties(selected, propFilter.Text)
        end
    end)
end)

refreshButton.MouseButton1Click:Connect(function()
    expanded[game] = true
    renderTree(search.Text, true)
    if selected then
        renderProperties(selected, propFilter.Text)
    end
    setStatus("Refreshed", C.green)
end)

expandButton.MouseButton1Click:Connect(function()
    expanded = { [game] = true }
    local roots = rootsFor(false)
    local opened = 0
    for index = 1, #roots do
        local root = roots[index]
        expanded[root] = true
        local okChildren, children = pcall(root.GetChildren, root)
        if okChildren and #children <= 40 then
            for childIndex = 1, #children do
                local child = children[childIndex]
                local okGrand, grand = pcall(child.GetChildren, child)
                if okGrand and #grand > 0 and #grand <= 40 then
                    expanded[child] = true
                    opened = opened + 1
                end
            end
        end
    end
    search.Text = ""
    renderTree("", false)
    setStatus("Expanded " .. tostring(opened) .. " nodes", C.green)
end)

collapseButton.MouseButton1Click:Connect(function()
    expanded = {}
    renderTree(search.Text)
    setStatus("Collapsed", C.dim)
end)

nilButton.MouseButton1Click:Connect(function()
    showNil = not showNil
    nilButton.TextColor3 = showNil and C.gold or C.text
    expanded = {}
    renderTree(search.Text)
    setStatus(showNil and "Showing nil instances" or "Showing DataModel", C.dim)
end)

copyPathButton.MouseButton1Click:Connect(function()
    if not selected then
        setStatus("Nothing selected", C.red)
        return
    end
    if setClipboard(selected:GetFullName()) then
        setStatus("Copied path", C.green)
    else
        setStatus("Clipboard unavailable", C.red)
    end
end)

copyNameButton.MouseButton1Click:Connect(function()
    if not selected then
        setStatus("Nothing selected", C.red)
        return
    end
    if setClipboard(selected.Name) then
        setStatus("Copied name", C.green)
    else
        setStatus("Clipboard unavailable", C.red)
    end
end)

copySourceButton.MouseButton1Click:Connect(function()
    if not selected or not selected:IsA("LuaSourceContainer") then
        setStatus("Select a script first", C.red)
        return
    end
    local ok, source = pcall(function()
        return selected.Source
    end)
    if ok and type(source) == "string" then
        if setClipboard(source) then
            setStatus("Copied source (" .. tostring(#source) .. " chars)", C.green)
        else
            setStatus("Clipboard unavailable", C.red)
        end
    else
        setStatus("Source is not readable", C.red)
    end
end)

teleportButton.MouseButton1Click:Connect(function()
    if not selected or not selected:IsA("BasePart") then
        setStatus("Select a part first", C.red)
        return
    end
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    if not character then
        setStatus("No character", C.red)
        return
    end
    local ok = pcall(function()
        character:PivotTo(selected.CFrame * CFrame.new(0, 4, 0))
    end)
    if ok then
        setStatus("Teleported to " .. selected.Name, C.green)
    else
        setStatus("Teleport failed", C.red)
    end
end)

highlightButton.MouseButton1Click:Connect(function()
    if not selected then
        setStatus("Select a folder, model or part first", C.red)
        return
    end
    if highlightOwner == selected and highlightFolder then
        clearHighlights()
    else
        applyHighlight(selected)
    end
end)

guiButton.MouseButton1Click:Connect(function()
    if guiOpen then
        closeGuis()
    elseif not selected then
        setStatus("Select a GUI or a folder with GUIs", C.red)
    else
        activateGui(selected)
    end
end)

closeButton.MouseButton1Click:Connect(function()
    clearHighlights(true)
    if guiOpen then
        closeGuis()
    end
    gui:Destroy()
end)

local savedSize = nil

minimizeButton.MouseButton1Click:Connect(function()
    if body.Visible then
        savedSize = main.Size
        body.Visible = false
        toolbar.Visible = false
        status.Visible = false
        resizeHandle.Visible = false
        main.Size = UDim2.fromOffset(main.AbsoluteSize.X, 38)
    else
        body.Visible = true
        toolbar.Visible = true
        status.Visible = true
        resizeHandle.Visible = true
        main.Size = savedSize or UDim2.fromOffset(940, 620)
    end
end)

--==============================================================
-- Drag + resize
--==============================================================
local dragging = false
local dragStart = nil
local dragOrigin = nil

local dragRegion = make("Frame", {
    Name = "DragRegion",
    Size = UDim2.new(1, -96, 1, 0),
    BackgroundTransparency = 1,
    Active = true,
    ZIndex = 1,
}, titlebar)

dragRegion.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        dragOrigin = main.Position
    end
end)

local resizing = false
local resizeStart = nil
local resizeOrigin = nil

resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        resizeOrigin = main.AbsoluteSize
    end
end)

UIS.InputChanged:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    if dragging and dragStart then
        local delta = input.Position - dragStart
        main.Position = UDim2.fromOffset(dragOrigin.X.Offset + delta.X, dragOrigin.Y.Offset + delta.Y)
    elseif resizing and resizeStart then
        local delta = input.Position - resizeStart
        main.Size = UDim2.fromOffset(math.max(640, resizeOrigin.X + delta.X), math.max(420, resizeOrigin.Y + delta.Y))
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        resizing = false
        dragStart = nil
        resizeStart = nil
    end
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        gui.Enabled = not gui.Enabled
    end
end)

--==============================================================
-- Initial render
--==============================================================
expanded[game] = true
renderTree("")
setStatus("Ready - select an instance, RightShift to toggle", C.dim)

