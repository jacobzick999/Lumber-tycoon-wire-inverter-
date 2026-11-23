-- Wire Art Lasso Copier - local visual blueprint capture only.
-- Draw a lasso around visible wire-art pieces, then export a blueprint.
-- No remotes, server changes, automatic placement, or duplication are performed.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local gui = Instance.new("ScreenGui")
gui.Name = "WireArtLasso"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local KEYWORDS = {"wire", "cable", "connector", "wiring"}
local LASSO_MIN_POINTS = 8
local LASSO_POINT_SPACING = 5
local blueprint = {}
local polygon = {}
local drawing = false
local minimized = false

local function isWirePart(part)
    local n = string.lower(part.Name)
    for _, word in ipairs(KEYWORDS) do
        if string.find(n, word, 1, true) then return true end
    end
    return false
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(255, 204)
panel.Position = UDim2.new(0, 16, 0.32, 0)
panel.BackgroundColor3 = Color3.fromRGB(25, 29, 43)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local outline = Instance.new("UIStroke", panel)
outline.Color = Color3.fromRGB(70, 170, 255)
outline.Thickness = 1.5

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -42, 0, 32)
title.Position = UDim2.fromOffset(10, 2)
title.BackgroundTransparency = 1
title.Text = "✂ Wire Art Lasso"
title.TextColor3 = Color3.fromRGB(240, 245, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local mini = Instance.new("TextButton")
mini.Size = UDim2.fromOffset(28, 25)
mini.Position = UDim2.new(1, -34, 0, 5)
mini.Text = "—"
mini.TextColor3 = Color3.new(1,1,1)
mini.BackgroundColor3 = Color3.fromRGB(58, 69, 91)
mini.Font = Enum.Font.GothamBold
mini.Parent = panel
Instance.new("UICorner", mini).CornerRadius = UDim.new(0, 5)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -18, 0, 36)
status.Position = UDim2.fromOffset(9, 35)
status.BackgroundTransparency = 1
status.Text = "Tap START LASSO, then draw around the artwork."
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(195, 207, 225)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.Parent = panel

local function button(label, y, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -18, 0, 34)
    b.Position = UDim2.fromOffset(9, y)
    b.BackgroundColor3 = Color3.fromRGB(45, 105, 175)
    b.TextColor3 = Color3.new(1,1,1)
    b.Text = label
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    b.MouseButton1Click:Connect(callback)
    return b
end

local lassoButton
local function clearLines()
    for _, obj in ipairs(gui:GetChildren()) do
        if obj.Name == "LassoSegment" or obj.Name == "LassoPoint" then obj:Destroy() end
    end
end

local function addSegment(a, b)
    local delta = b - a
    local line = Instance.new("Frame")
    line.Name = "LassoSegment"
    line.AnchorPoint = Vector2.new(0, 0.5)
    line.Position = UDim2.fromOffset(a.X, a.Y)
    line.Size = UDim2.fromOffset(delta.Magnitude, 2)
    line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    line.BackgroundColor3 = Color3.fromRGB(70, 220, 255)
    line.BorderSizePixel = 0
    line.ZIndex = 20
    line.Parent = gui
end

local function pointInPolygon(point, points)
    local inside = false
    local j = #points
    for i = 1, #points do
        local a, b = points[i], points[j]
        if ((a.Y > point.Y) ~= (b.Y > point.Y)) then
            local crossX = (b.X - a.X) * (point.Y - a.Y) / ((b.Y - a.Y) + 0.00001) + a.X
            if point.X < crossX then inside = not inside end
        end
        j = i
    end
    return inside
end

local function startLasso()
    table.clear(polygon)
    clearLines()
    drawing = true
    status.Text = "DRAW around the design. Release to capture."
    lassoButton.Text = "DRAWING..."
end

local function capture()
    drawing = false
    lassoButton.Text = "START LASSO"
    if #polygon < LASSO_MIN_POINTS then
        status.Text = "Lasso too small. Try drawing a larger loop."
        return
    end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        status.Text = "Character not ready. Try again."
        return
    end

    table.clear(blueprint)
    local count = 0
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and isWirePart(part) and not (char and part:IsDescendantOf(char)) then
            local screen, onScreen = camera:WorldToViewportPoint(part.Position)
            if onScreen and screen.Z > 0 and pointInPolygon(Vector2.new(screen.X, screen.Y), polygon) then
                local relative = root.CFrame:ToObjectSpace(part.CFrame)
                local rx, ry, rz = relative:ToOrientation()
                table.insert(blueprint, {
                    name = part.Name,
                    x = relative.Position.X, y = relative.Position.Y, z = relative.Position.Z,
                    rx = rx, ry = ry, rz = rz,
                    sx = part.Size.X, sy = part.Size.Y, sz = part.Size.Z,
                    r = math.floor(part.Color.R * 255 + 0.5),
                    g = math.floor(part.Color.G * 255 + 0.5),
                    b = math.floor(part.Color.B * 255 + 0.5),
                    material = part.Material.Name,
                    transparency = part.Transparency
                })
                count = count + 1
            end
        end
    end
    status.Text = "Captured " .. count .. " visible named wire parts. Copy blueprint to save."
    clearLines()
end

lassoButton = button("START LASSO", 77, startLasso)
button("COPY BLUEPRINT JSON", 117, function()
    if #blueprint == 0 then
        status.Text = "Nothing captured yet. Draw a lasso first."
        return
    end
    local json = HttpService:JSONEncode({
        format = "WireArtBlueprint",
        version = 2,
        coordinateOrigin = "character at capture time",
        parts = blueprint
    })
    if typeof(setclipboard) == "function" then
        setclipboard(json)
        status.Text = "Copied " .. #blueprint .. " parts as JSON."
    else
        print(json)
        status.Text = "Clipboard unavailable; blueprint printed to output."
    end
end)
button("CLEAR BLUEPRINT", 157, function()
    table.clear(blueprint)
    table.clear(polygon)
    clearLines()
    status.Text = "Blueprint cleared."
end)

mini.MouseButton1Click:Connect(function()
    minimized = not minimized
    for _, child in ipairs(panel:GetChildren()) do
        if child ~= title and child ~= mini and child:IsA("GuiObject") then
            child.Visible = not minimized
        end
    end
    panel.Size = minimized and UDim2.fromOffset(255, 38) or UDim2.fromOffset(255, 204)
    mini.Text = minimized and "+" or "—"
end)

-- Touch and mouse lasso input. Begin in the world, not on the panel.
local activeInput
UserInputService.InputBegan:Connect(function(input, processed)
    if not drawing or processed then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        local p = Vector2.new(input.Position.X, input.Position.Y)
        if p.X < panel.AbsolutePosition.X + panel.AbsoluteSize.X and
           p.Y < panel.AbsolutePosition.Y + panel.AbsoluteSize.Y and
           p.X >= panel.AbsolutePosition.X and p.Y >= panel.AbsolutePosition.Y then
            return
        end
        activeInput = input
        table.insert(polygon, p)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not drawing or not activeInput then return end
    local isMove = input.UserInputType == Enum.UserInputType.MouseMovement or input == activeInput
    if isMove then
        local p = Vector2.new(input.Position.X, input.Position.Y)
        local last = polygon[#polygon]
        if not last or (p - last).Magnitude >= LASSO_POINT_SPACING then
            if last then addSegment(last, p) end
            table.insert(polygon, p)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if drawing and activeInput and
       (input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
        activeInput = nil
        if #polygon >= 3 then
            addSegment(polygon[#polygon], polygon[1])
        end
        capture()
    end
end)

-- Drag panel by its title bar.
local dragStart, panelStart, dragging
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        panelStart = panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        panel.Position = UDim2.new(panelStart.X.Scale, panelStart.X.Offset + d.X, panelStart.Y.Scale, panelStart.Y.Offset + d.Y)
    end
end)
