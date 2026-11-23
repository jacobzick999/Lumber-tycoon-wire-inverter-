-- Wire Art Copier (local blueprint tool)
-- Scans visible, locally replicated wire-like BaseParts and exports a blueprint.
-- It does not fire remotes, change server state, or place/duplicate game objects.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

local RADIUS = 250
local KEYWORDS = {"wire", "cable", "connector", "wiring"}
local blueprint = {}
local previewFolder

local function isWirePart(part)
    local name = string.lower(part.Name)
    for _, word in ipairs(KEYWORDS) do
        if string.find(name, word, 1, true) then
            return true
        end
    end
    return false
end

local function setStatus(label, message)
    label.Text = message
end

local gui = Instance.new("ScreenGui")
gui.Name = "WireArtCopier"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(250, 218)
panel.Position = UDim2.new(0, 18, 0.35, 0)
panel.BackgroundColor3 = Color3.fromRGB(28, 31, 43)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 170, 255)
stroke.Thickness = 1.5
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -42, 0, 34)
title.Position = UDim2.fromOffset(10, 2)
title.BackgroundTransparency = 1
title.Text = "🌲 Wire Art Copier"
title.TextColor3 = Color3.fromRGB(235, 242, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(28, 26)
minimize.Position = UDim2.new(1, -34, 0, 5)
minimize.Text = "—"
minimize.TextColor3 = Color3.new(1, 1, 1)
minimize.BackgroundColor3 = Color3.fromRGB(55, 65, 85)
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 16
minimize.Parent = panel
Instance.new("UICorner", minimize).CornerRadius = UDim.new(0, 6)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 34)
status.Position = UDim2.fromOffset(10, 38)
status.BackgroundTransparency = 1
status.Text = "Ready. Stand near the wire art."
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(190, 205, 225)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.Parent = panel

local function makeButton(text, y, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -20, 0, 34)
    button.Position = UDim2.fromOffset(10, y)
    button.BackgroundColor3 = Color3.fromRGB(48, 105, 170)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.Parent = panel
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
    button.MouseButton1Click:Connect(callback)
    return button
end

local function clearPreview()
    if previewFolder then
        previewFolder:Destroy()
        previewFolder = nil
    end
end

makeButton("SCAN NEARBY WIRE ART", 78, function()
    character = player.Character or character
    root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        setStatus(status, "Character root not found.")
        return
    end

    table.clear(blueprint)
    local seen = {}
    for _, item in ipairs(Workspace:GetDescendants()) do
        if item:IsA("BasePart") and isWirePart(item) and not item:IsDescendantOf(character) then
            local distance = (item.Position - root.Position).Magnitude
            if distance <= RADIUS and not seen[item] then
                seen[item] = true
                local relative = root.CFrame:ToObjectSpace(item.CFrame)
                table.insert(blueprint, {
                    name = item.Name,
                    x = relative.Position.X, y = relative.Position.Y, z = relative.Position.Z,
                    rx = relative:ToOrientation(),
                    sx = item.Size.X, sy = item.Size.Y, sz = item.Size.Z,
                    r = math.floor(item.Color.R * 255 + 0.5),
                    g = math.floor(item.Color.G * 255 + 0.5),
                    b = math.floor(item.Color.B * 255 + 0.5),
                    material = item.Material.Name,
                    transparency = item.Transparency
                })
            end
        end
    end
    setStatus(status, "Scanned " .. #blueprint .. " matching parts. Set your position as the blueprint origin.")
end)

makeButton("COPY BLUEPRINT TO CLIPBOARD", 120, function()
    if #blueprint == 0 then
        setStatus(status, "Scan first. No blueprint parts found.")
        return
    end
    local payload = {
        format = "WireArtBlueprint",
        version = 1,
        source = "local visual scan",
        parts = blueprint
    }
    local encoded = HttpService:JSONEncode(payload)
    if typeof(setclipboard) == "function" then
        setclipboard(encoded)
        setStatus(status, "Copied " .. #blueprint .. " parts as JSON.")
    else
        setStatus(status, "Clipboard API unavailable. Use an executor with clipboard support or copy from output.")
        print(encoded)
    end
end)

makeButton("CLEAR SCAN", 162, function()
    table.clear(blueprint)
    clearPreview()
    setStatus(status, "Blueprint cleared.")
end)

minimize.MouseButton1Click:Connect(function()
    local minimized = panel:GetAttribute("Minimized") == true
    panel:SetAttribute("Minimized", not minimized)
    for _, child in ipairs(panel:GetChildren()) do
        if child ~= title and child ~= minimize and child:IsA("GuiObject") then
            child.Visible = minimized
        end
    end
    panel.Size = minimized and UDim2.fromOffset(250, 218) or UDim2.fromOffset(250, 38)
    minimize.Text = minimized and "—" or "+"
end)

-- Drag panel on mouse or touch.
local dragging, dragInput, dragStart, startPos
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
