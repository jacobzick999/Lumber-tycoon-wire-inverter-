-- Wire Art Lasso PRO: local visual blueprint capture only.
-- No remotes, server edits, automatic placement, or object duplication.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "WireArtLassoPRO"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 900
gui.Parent = player:WaitForChild("PlayerGui")

local points, blueprint, selected = {}, {}, {}
local highlights = {}
local previewFolder = nil
local trackerConnection = nil
local trackerActive = false
local trackerSeen = {}
local trackerPlaced = {}
local trackerBaseline = {}
local trackerBtn = nil
local drawing, activeInput, dragging, minimized = false, nil, false, false
local wireOnly = false
local MIN_POINTS, MAX_PARTS, MAX_HIGHLIGHTS = 5, 1500, 500
local KEYWORDS = {"wire","cable","connector","wiring"}

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(278, 282)
panel.Position = UDim2.new(0, 16, 0.28, 0)
panel.BackgroundColor3 = Color3.fromRGB(22,27,42)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner",panel).CornerRadius = UDim.new(0,12)
local edge = Instance.new("UIStroke",panel)
edge.Color = Color3.fromRGB(60,175,255)
edge.Thickness = 1.6

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-45,0,34)
title.Position = UDim2.fromOffset(10,3)
title.BackgroundTransparency = 1
title.Text = "✂ WIRE ART LASSO PRO"
title.TextColor3 = Color3.fromRGB(240,246,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(28,26)
minimize.Position = UDim2.new(1,-35,0,6)
minimize.Text = "—"
minimize.TextColor3 = Color3.new(1,1,1)
minimize.BackgroundColor3 = Color3.fromRGB(55,68,91)
minimize.Font = Enum.Font.GothamBold
minimize.Parent = panel
Instance.new("UICorner",minimize).CornerRadius = UDim.new(0,6)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-20,0,38)
status.Position = UDim2.fromOffset(10,38)
status.BackgroundTransparency = 1
status.Text = "Choose a filter, then draw around the design."
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(190,207,229)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.Parent = panel

local function say(s) status.Text = s end
local function wirePart(p)
    local n = string.lower(p.Name)
    for _,k in ipairs(KEYWORDS) do if string.find(n,k,1,true) then return true end end
    return false
end
local function button(label,y,color,fn)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-20,0,34)
    b.Position = UDim2.fromOffset(10,y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1,1,1)
    b.Text = label
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = panel
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,7)
    b.MouseButton1Click:Connect(fn)
    return b
end
local function clearLines()
    for _,v in ipairs(gui:GetChildren()) do if v.Name == "LassoLine" then v:Destroy() end end
end
local function clearHighlights()
    for _,h in ipairs(highlights) do if h.Parent then h:Destroy() end end
    table.clear(highlights)
end
local function removePreview()
    if previewFolder then
        previewFolder:Destroy()
        previewFolder = nil
    end
end
local function stopTracker()
    if trackerConnection then trackerConnection:Disconnect(); trackerConnection=nil end
    trackerActive=false
end
local function partMatches(part, data)
    if not part or not part:IsA("BasePart") then return false end
    local function close(a,b,t) return math.abs(a-b)<=t end
    if not (close(part.Size.X, data.sx, 0.12) and close(part.Size.Y, data.sy, 0.12) and close(part.Size.Z, data.sz, 0.12)) then return false end
    if part.Material.Name ~= tostring(data.material or "SmoothPlastic") then return false end
    if not (close(part.Color.R*255, data.r, 8) and close(part.Color.G*255, data.g, 8) and close(part.Color.B*255, data.b, 8)) then return false end
    if not close(part.Transparency, tonumber(data.transparency) or 0, 0.08) then return false end
    return true
end
local function updateTrackerStatus()
    local total=#blueprint
    local done=#trackerPlaced
    if trackerBtn then trackerBtn.Text=trackerActive and "STOP BUILD TRACKER" or "START BUILD TRACKER" end
    say("Build progress: "..done.." / "..total.." matching pieces detected. Detection checks new parts' size, color, and material; it does not verify exact placement.")
end
local function startTracker()
    if #blueprint==0 then say("Capture a blueprint before starting the build tracker."); return end
    stopTracker()
    table.clear(trackerSeen); table.clear(trackerPlaced); table.clear(trackerBaseline)
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then trackerBaseline[obj]=true end
    end
    trackerActive=true
    trackerConnection=Workspace.DescendantAdded:Connect(function(obj)
        if not trackerActive or not obj:IsA("BasePart") then return end
        if obj:IsDescendantOf(player.Character or gui) then return end
        if previewFolder and obj:IsDescendantOf(previewFolder) then return end
        if trackerSeen[obj] or trackerBaseline[obj] then return end
        trackerSeen[obj]=true
        for i,data in ipairs(blueprint) do
            local already=0
            for _,entry in ipairs(trackerPlaced) do if entry.index==i then already=already+1 end end
            local required=1
            for _,other in ipairs(blueprint) do
                if other.sx==data.sx and other.sy==data.sy and other.sz==data.sz and other.r==data.r and other.g==data.g and other.b==data.b and other.material==data.material then
                    -- Count identical blueprint pieces as separate requirements below.
                end
            end
            if already<required and partMatches(obj,data) then
                table.insert(trackerPlaced,{part=obj,index=i})
                updateTrackerStatus()
                break
            end
        end
    end)
    updateTrackerStatus()
end
local function toggleTracker()
    if trackerActive then stopTracker(); updateTrackerStatus() else startTracker() end
end
local function showPreview()
    if #blueprint == 0 then say("Capture a design before previewing it."); return end
    if previewFolder then
        removePreview()
        previewBtn.Text = "PREVIEW 3D BLUEPRINT"
        say("3D preview hidden.")
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then say("Camera not available."); return end

    local folder = Instance.new("Folder")
    folder.Name = "LocalWireArtBlueprintPreview"
    folder.Parent = Workspace
    previewFolder = folder

    -- Float the local-only preview in front of the camera, away from the real build.
    local origin = cam.CFrame * CFrame.new(0, 0, -18)
    for _, data in ipairs(blueprint) do
        local part = Instance.new("Part")
        part.Name = "Preview_" .. tostring(data.name or "Part")
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Size = Vector3.new(
            math.max(0.05, tonumber(data.sx) or 1),
            math.max(0.05, tonumber(data.sy) or 1),
            math.max(0.05, tonumber(data.sz) or 1)
        )
        part.Color = Color3.fromRGB(
            math.clamp(tonumber(data.r) or 180, 0, 255),
            math.clamp(tonumber(data.g) or 180, 0, 255),
            math.clamp(tonumber(data.b) or 180, 0, 255)
        )
        local material = Enum.Material[ tostring(data.material or "SmoothPlastic") ]
        if material then part.Material = material end
        part.Transparency = math.clamp(tonumber(data.transparency) or 0, 0, 0.65)
        part.CFrame = origin
            * CFrame.new(tonumber(data.x) or 0, tonumber(data.y) or 0, tonumber(data.z) or 0)
            * CFrame.Angles(tonumber(data.rx) or 0, tonumber(data.ry) or 0, tonumber(data.rz) or 0)
        part.Parent = folder
    end
    previewBtn.Text = "HIDE 3D PREVIEW"
    say("Showing local 3D preview: " .. #blueprint .. " parts. It is not placed in the world.")
end
local function segment(a,b,color)
    local d = b-a
    local line = Instance.new("Frame")
    line.Name = "LassoLine"
    line.AnchorPoint = Vector2.new(0,0.5)
    line.Position = UDim2.fromOffset(a.X,a.Y)
    line.Size = UDim2.fromOffset(d.Magnitude,3)
    line.Rotation = math.deg(math.atan2(d.Y,d.X))
    line.BackgroundColor3 = color or Color3.fromRGB(65,225,255)
    line.BorderSizePixel = 0
    line.ZIndex = 50
    line.Parent = gui
end
local function inside(p)
    local yes,j = false,#points
    for i=1,#points do
        local a,b = points[i],points[j]
        if (a.Y>p.Y) ~= (b.Y>p.Y) then
            local x = (b.X-a.X)*(p.Y-a.Y)/((b.Y-a.Y)+0.000001)+a.X
            if p.X<x then yes = not yes end
        end
        j=i
    end
    return yes
end
local function orient(a,b,c) return (b.X-a.X)*(c.Y-a.Y)-(b.Y-a.Y)*(c.X-a.X) end
local function crosses(a,b,c,d)
    local x1,x2,x3,x4=orient(a,b,c),orient(a,b,d),orient(c,d,a),orient(c,d,b)
    return ((x1>=0 and x2<=0) or (x1<=0 and x2>=0)) and ((x3>=0 and x4<=0) or (x3<=0 and x4>=0))
end
local function rectSelected(x1,y1,x2,y2)
    local c={Vector2.new(x1,y1),Vector2.new(x2,y1),Vector2.new(x2,y2),Vector2.new(x1,y2)}
    for _,p in ipairs(c) do if inside(p) then return true end end
    for _,p in ipairs(points) do if p.X>=x1 and p.X<=x2 and p.Y>=y1 and p.Y<=y2 then return true end end
    for i=1,#points do
        local a,b=points[i],points[i%#points+1]
        for j=1,4 do if crosses(a,b,c[j],c[j%4+1]) then return true end end
    end
    return false
end
local function touches(part,cam)
    local half=part.Size/2
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    local front=false
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local world=part.CFrame:PointToWorldSpace(Vector3.new(half.X*x,half.Y*y,half.Z*z))
        local v=cam:WorldToViewportPoint(world)
        if v.Z>0 then
            front=true
            minX,minY=math.min(minX,v.X),math.min(minY,v.Y)
            maxX,maxY=math.max(maxX,v.X),math.max(maxY,v.Y)
        end
    end end end
    if not front then return false end
    local center,visible=cam:WorldToViewportPoint(part.Position)
    if visible and inside(Vector2.new(center.X,center.Y)) then return true end
    return rectSelected(minX,minY,maxX,maxY)
end
local function start()
    table.clear(points); clearLines()
    drawing=true; activeInput=nil
    startBtn.Text="DRAW NOW — RELEASE TO SELECT"
    say("Trace around the art with your finger. Release to select.")
end
local function cancel()
    drawing=false; activeInput=nil; table.clear(points); clearLines()
    startBtn.Text="START LASSO"
    say("Lasso cancelled.")
end
local function capture()
    drawing=false; startBtn.Text="START LASSO"
    if #points<MIN_POINTS then clearLines(); say("Loop too small. Draw a larger outline."); return end
    local cam=Workspace.CurrentCamera
    if not cam then say("Camera not available."); return end
    local character=player.Character
    local parts={}
    for _,p in ipairs(Workspace:GetDescendants()) do
        if p:IsA("BasePart") and not (character and p:IsDescendantOf(character))
            and (not wireOnly or wirePart(p)) and touches(p,cam) then
            table.insert(parts,p)
            if #parts>=MAX_PARTS then break end
        end
    end
    if #parts==0 then clearLines(); say("No parts found. Try ALL PARTS or move closer."); return end

    local lo=Vector3.new(math.huge,math.huge,math.huge)
    local hi=Vector3.new(-math.huge,-math.huge,-math.huge)
    for _,p in ipairs(parts) do
        local v=p.Position
        lo=Vector3.new(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
        hi=Vector3.new(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
    end
    local origin=CFrame.new((lo+hi)/2)
    table.clear(blueprint)
    for _,p in ipairs(parts) do
        local rel=origin:ToObjectSpace(p.CFrame)
        local rx,ry,rz=rel:ToOrientation()
        table.insert(blueprint,{
            name=p.Name,x=rel.Position.X,y=rel.Position.Y,z=rel.Position.Z,
            rx=rx,ry=ry,rz=rz,sx=p.Size.X,sy=p.Size.Y,sz=p.Size.Z,
            r=math.floor(p.Color.R*255+0.5),g=math.floor(p.Color.G*255+0.5),
            b=math.floor(p.Color.B*255+0.5),material=p.Material.Name,
            transparency=p.Transparency
        })
    end
    clearHighlights(); removePreview(); previewBtn.Text = "PREVIEW 3D BLUEPRINT"; table.clear(selected)
    for _,p in ipairs(parts) do
        table.insert(selected,p)
        if #highlights<MAX_HIGHLIGHTS then
            local h=Instance.new("Highlight")
            h.Adornee=p; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
            h.FillColor=Color3.fromRGB(35,190,255); h.FillTransparency=0.78
            h.OutlineColor=Color3.fromRGB(180,245,255); h.Parent=gui
            table.insert(highlights,h)
        end
    end
    clearLines()
    say("Selected "..#parts.." parts. Blue outlines show what was captured.")
end

startBtn=button("START LASSO",82,Color3.fromRGB(35,120,195),start)
button("CANCEL LASSO",122,Color3.fromRGB(120,65,78),cancel)
local filterBtn
filterBtn=button("FILTER: ALL PARTS",162,Color3.fromRGB(65,83,115),function()
    wireOnly=not wireOnly
    filterBtn.Text=wireOnly and "FILTER: WIRE-NAMED ONLY" or "FILTER: ALL PARTS"
    say(wireOnly and "Only wire-named parts will be selected." or "Any visible part inside the lasso can be selected.")
end)
button("COPY BLUEPRINT JSON",202,Color3.fromRGB(35,145,115),function()
    if #blueprint==0 then say("Lasso a design first."); return end
    local json=HttpService:JSONEncode({format="WireArtBlueprint",version=3,origin="center of captured bounds",parts=blueprint})
    if typeof(setclipboard)=="function" then setclipboard(json); say("Copied "..#blueprint.." parts as JSON.")
    else print(json); say("Clipboard unavailable; JSON printed to output.") end
end)
previewBtn = button("PREVIEW 3D BLUEPRINT",242,Color3.fromRGB(35,125,145),showPreview)
trackerBtn = button("START BUILD TRACKER",282,Color3.fromRGB(120,105,45),toggleTracker)
button("CLEAR SELECTION",322,Color3.fromRGB(90,94,112),function()
    stopTracker(); table.clear(trackerPlaced); table.clear(trackerSeen); table.clear(blueprint); table.clear(selected); table.clear(points)
    if trackerBtn then trackerBtn.Text = "START BUILD TRACKER" end
    clearHighlights(); clearLines(); removePreview()
    previewBtn.Text = "PREVIEW 3D BLUEPRINT"
    say("Selection and blueprint cleared.")
end)
panel.Size = UDim2.fromOffset(278,362)

minimize.MouseButton1Click:Connect(function()
    minimized=not minimized
    for _,v in ipairs(panel:GetChildren()) do
        if v~=title and v~=minimize and v:IsA("GuiObject") then v.Visible=not minimized end
    end
    panel.Size=minimized and UDim2.fromOffset(278,40) or UDim2.fromOffset(278,362)
    minimize.Text=minimized and "+" or "—"
end)

UIS.InputBegan:Connect(function(input,processed)
    if not drawing or activeInput then return end
    if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    local p=Vector2.new(input.Position.X,input.Position.Y)
    local a,s=panel.AbsolutePosition,panel.AbsoluteSize
    if p.X>=a.X and p.X<=a.X+s.X and p.Y>=a.Y and p.Y<=a.Y+s.Y then return end
    activeInput=input; table.insert(points,p)
end)
UIS.InputChanged:Connect(function(input)
    if not drawing or not activeInput then return end
    local moving=(activeInput.UserInputType==Enum.UserInputType.Touch and input==activeInput)
        or (activeInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)
    if not moving then return end
    local p=Vector2.new(input.Position.X,input.Position.Y)
    local last=points[#points]
    if not last or (p-last).Magnitude>=3 then
        if last then segment(last,p) end
        table.insert(points,p)
    end
end)
UIS.InputEnded:Connect(function(input)
    if not drawing or not activeInput then return end
    if input==activeInput or (activeInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1) then
        activeInput=nil
        if #points>=3 then segment(points[#points],points[1],Color3.fromRGB(70,255,160)) end
        capture()
    end
end)

local dragStart,panelStart
title.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true; dragStart=input.Position; panelStart=panel.Position
        input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseMovement) then
        local d=input.Position-dragStart
        panel.Position=UDim2.new(panelStart.X.Scale,panelStart.X.Offset+d.X,panelStart.Y.Scale,panelStart.Y.Offset+d.Y)
    end
end)
