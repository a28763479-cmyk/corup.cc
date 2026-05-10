Players = game:GetService("Players")
Workspace = game:GetService("Workspace")
RunService = game:GetService("RunService")
UserInputService = game:GetService("UserInputService")
TweenService = game:GetService("TweenService")
DebrisService = game:GetService("Debris")
SoundService = game:GetService("SoundService")

projectilesControlEnabled = false
projectilesControlSpeed = 200

me = Players.LocalPlayer
camera = Workspace.CurrentCamera
Debris = Workspace:WaitForChild("Debris")
VParts = Debris:WaitForChild("VParts")

forward = 0
sideways = 0
wallbangRefreshTick = 0
wallbangOriginalParents = {}
wallbangApplied = false

isProjectileControlToolName = function(name)
    return name == "C4"
        or name == "RPG-7"
        or name == "RPG-29"
        or name == "M320-1"
        or name == "SCAR-H-X"
        or name == "SBL-MK3"
        or name == "HL-MK3"
        or name == "A-HL-MK3"
        or name == "A-HL-MK4"
        or name == "HL-MK2"
        or name == "FireworkLauncher"
        or name == "A-FW-L"
        or name == "HallowsLauncher"
        or name == "AT4"
        or name == "AT4_"
        or name == "Panzerfaust-3"
        or name == "AUTO-PANZER"
        or name == "RPG-18"
        or name == "FlareGun"
        or name == "Plasma-Rocket-Launcher"
end

hasProjectileControlItem = function()
    local character = me and me.Character
    if character then
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") and isProjectileControlToolName(child.Name) then
                return true
            end
        end
    end

    local backpack = me and me:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") and isProjectileControlToolName(child.Name) then
                return true
            end
        end
    end

    return false
end

shouldEnableProjectileWallbang = function()
    return projectilesControlEnabled and hasProjectileControlItem()
end

syncWallbangState = function(enabled)
    local characters = Workspace:FindFirstChild("Characters")
    if enabled then
        if not characters then
            return
        end

        local targets = {}
        local filter = Workspace:FindFirstChild("Filter")
        if filter then
            targets[#targets + 1] = filter:FindFirstChild("Snow")
            targets[#targets + 1] = filter:FindFirstChild("WaterCurrents")

            local filterParts = filter:FindFirstChild("Parts")
            if filterParts then
                local filterPartsChildren = filterParts:GetChildren()
                for i = 1, #filterPartsChildren do
                    local item = filterPartsChildren[i]
                    if item and item.Name ~= "AA_COPYRIGHT" then
                        targets[#targets + 1] = item
                    end
                end
            end
        end

        local map = Workspace:FindFirstChild("Map")
        if map then
            targets[#targets + 1] = map:FindFirstChild("ATMz")
            targets[#targets + 1] = map:FindFirstChild("BredMakurz")
            targets[#targets + 1] = map:FindFirstChild("Doors")
            targets[#targets + 1] = map:FindFirstChild("MysteryBoxes")
            targets[#targets + 1] = map:FindFirstChild("StreetLights")
            local mapParts = map:FindFirstChild("Parts")
            if mapParts then
                local mapPartsChildren = mapParts:GetChildren()
                for i = 1, #mapPartsChildren do
                    local item = mapPartsChildren[i]
                    if item and item.Name ~= "AA_COPYRIGHT" then
                        targets[#targets + 1] = item
                    end
                end
            end
            targets[#targets + 1] = map:FindFirstChild("ProximityShops")
            targets[#targets + 1] = map:FindFirstChild("SpawnedSupplyPlanes")
            targets[#targets + 1] = map:FindFirstChild("VendingMachines")
        end

        for i = 1, #targets do
            local target = targets[i]
            if target and target.Parent then
                if wallbangOriginalParents[target] == nil then
                    wallbangOriginalParents[target] = target.Parent
                end
                if target.Parent ~= characters then
                    pcall(function()
                        target.Parent = characters
                    end)
                end
            end
        end
        wallbangApplied = true
        return
    end

    for target, originalParent in pairs(wallbangOriginalParents) do
        if target and target.Parent and originalParent and originalParent.Parent and target.Parent ~= originalParent then
            pcall(function()
                target.Parent = originalParent
            end)
        end
    end
    table.clear(wallbangOriginalParents)
    wallbangApplied = false
end

syncWallbangState(shouldEnableProjectileWallbang())

ensureControlCamera = function()
    camera = Workspace.CurrentCamera or camera
    if not camera then
        for _ = 1, 10 do
            task.wait()
            camera = Workspace.CurrentCamera
            if camera then
                break
            end
        end
        if not camera then
            return false
        end
    end
    if not cameraWasOverridden then
        savedCameraType = camera.CameraType
        savedCameraSubject = camera.CameraSubject
        savedCameraCFrame = camera.CFrame
        cameraWasOverridden = true
        savedMouseBehavior = UserInputService.MouseBehavior
        savedMouseIconEnabled = UserInputService.MouseIconEnabled
    end
    camera.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false
    return true
end

applyControlCameraFrame = function()
    if not currentObject or not cameraLookDir then
        return
    end

    camera = Workspace.CurrentCamera or camera
    if not camera then
        return
    end
    camera.CameraType = Enum.CameraType.Scriptable

    local projectileCFrame
    if not pcall(function()
        projectileCFrame = currentObject.CFrame
    end) or not projectileCFrame then
        return
    end

    local desiredCamPos = projectileCFrame.Position - cameraLookDir * 7 + Vector3.new(0, 2.4, 0)
    if not cameraFollowPos then
        cameraFollowPos = desiredCamPos
    else
        cameraFollowPos = cameraFollowPos:Lerp(desiredCamPos, 0.25)
    end
    local lookPos = projectileCFrame.Position + cameraLookDir * 18 + Vector3.new(0, 0.8, 0)
    camera.CFrame = CFrame.lookAt(cameraFollowPos, lookPos)
end

markShot = function(projectileName)
    recentShots = recentShots or {}
    recentShots[projectileName] = os.clock()
end

isControllableProjectileName = function(projectileName)
    return projectileName == "TransIgnore"
        or projectileName == "RPG_Rocket"
        or projectileName == "GrenadeLauncherGrenade"
        or projectileName == "SBL_Rocket"
        or projectileName == "Hallows_Rocket3"
        or projectileName == "A_Hallows_Rocket3"
        or projectileName == "Hallows_Rocket2"
        or projectileName == "FireworkLauncher_Rocket"
        or projectileName == "Hallows_Rocket"
        or projectileName == "AT4_Rocket"
        or projectileName == "Flare_Rocket"
        or projectileName == "Rpg18"
        or projectileName == "_B__RPG_Rocket"
        or projectileName == "_B__RPG_Rocket2"
end

isRecentShot = function(projectileName)
    if not recentShots then
        return false
    end
    local t = recentShots[projectileName]
    local window = 1.3
    if projectileName == "TransIgnore" then
        window = 1.6
    elseif projectileName == "GrenadeLauncherGrenade" then
        window = 1.4
    end
    if t and (os.clock() - t) <= window then
        return true
    end
    if not isControllableProjectileName(projectileName) then
        return false
    end
    local anyShot = recentShots["__any"]
    return anyShot and (os.clock() - anyShot) <= 1.2
end

markToolShot = function(toolName)
    markShot("__any")
    if toolName == "RPG-7" or toolName == "RPG-29" then
        markShot("RPG_Rocket")
        markShot("_B__RPG_Rocket")
        markShot("_B__RPG_Rocket2")
    elseif toolName == "M320-1" or toolName == "SCAR-H-X" then
        markShot("GrenadeLauncherGrenade")
    elseif toolName == "SBL-MK3" then
        markShot("SBL_Rocket")
    elseif toolName == "HL-MK3" or toolName == "A-HL-MK4" then
        markShot("Hallows_Rocket3")
    elseif toolName == "A-HL-MK3" then
        markShot("A_Hallows_Rocket3")
        markShot("Hallows_Rocket3")
    elseif toolName == "HL-MK2" then
        markShot("Hallows_Rocket2")
    elseif toolName == "FireworkLauncher" or toolName == "A-FW-L" then
        markShot("FireworkLauncher_Rocket")
    elseif toolName == "HallowsLauncher" then
        markShot("Hallows_Rocket")
    elseif toolName == "AT4" or toolName == "AT4_" or toolName == "Panzerfaust-3" or toolName == "AUTO-PANZER" then
        markShot("AT4_Rocket")
    elseif toolName == "FlareGun" then
        markShot("Flare_Rocket")
    elseif toolName == "RPG-18" then
        markShot("Rpg18")
    elseif toolName == "Plasma-Rocket-Launcher" then
        markShot("_B__RPG_Rocket")
        markShot("_B__RPG_Rocket2")
        markShot("RPG_Rocket")
    end
end

clearShotToolConns = function()
    shotToolConns = shotToolConns or {}
    for i = 1, #shotToolConns do
        local c = shotToolConns[i]
        if c then
            pcall(function()
                c:Disconnect()
            end)
        end
    end
    table.clear(shotToolConns)
end

bindShotTool = function(tool)
    if not tool or not tool:IsA("Tool") then
        return
    end
    local n = tool.Name
    if isProjectileControlToolName(n) and n ~= "C4" then
        shotToolConns = shotToolConns or {}
        shotToolConns[#shotToolConns + 1] = tool.Activated:Connect(function()
            markToolShot(n)
        end)
    end
end

bindCharacterShotTools = function(char)
    clearShotToolConns()
    if not char then
        return
    end
    for _, child in ipairs(char:GetChildren()) do
        bindShotTool(child)
    end
end

startC4FlySound = function(projectile)
    if c4FlySound then
        pcall(function()
            c4FlySound:Stop()
            c4FlySound:Destroy()
        end)
        c4FlySound = nil
    end
    if not projectile or projectile.Name ~= "TransIgnore" then
        return
    end

    local s = Instance.new("Sound")
    s.Name = "_C4ControlFlySound"
    s.SoundId = "rbxassetid://114037851906101"
    s.Looped = true
    s.Volume = 1.35
    s.RollOffMaxDistance = 140
    s.RollOffMinDistance = 8
    s.Parent = projectile
    pcall(function()
        s:Play()
    end)
    c4FlySound = s
end

stopC4FlySound = function()
    if c4FlySound then
        pcall(function()
            c4FlySound:Stop()
            c4FlySound:Destroy()
        end)
        c4FlySound = nil
    end
end

playC4ExplosionSound = function()
    local now = os.clock()
    if (now - (lastC4ExplosionSoundAt or 0)) < 0.2 then
        return
    end
    lastC4ExplosionSoundAt = now
    local ids = {
        "rbxassetid://9114086405",
        "rbxassetid://9114086455",
        "rbxassetid://9114086744",
    }
    local s = Instance.new("Sound")
    s.SoundId = ids[math.random(1, #ids)]
    s.Volume = 1.75
    s.Parent = SoundService
    pcall(function()
        s:Play()
    end)
    DebrisService:AddItem(s, 4)
end

hideC4Part = function(inst)
    c4Hidden = c4Hidden or {}
    c4HiddenLookup = c4HiddenLookup or {}
    if not inst or c4HiddenLookup[inst] then
        return
    end
    if c4VisualModel and inst:IsDescendantOf(c4VisualModel) then
        return
    end
    if inst:IsA("BasePart") then
        c4Hidden[#c4Hidden + 1] = { inst, inst.Transparency, inst.LocalTransparencyModifier }
        c4HiddenLookup[inst] = true
        pcall(function()
            inst.Transparency = 1
            inst.LocalTransparencyModifier = 1
        end)
    elseif inst:IsA("Decal") or inst:IsA("Texture") then
        c4Hidden[#c4Hidden + 1] = { inst, inst.Transparency }
        c4HiddenLookup[inst] = true
        pcall(function()
            inst.Transparency = 1
        end)
    end
end

hideC4Assembly = function(part)
    if not part or not part.Parent then
        return
    end

    local connected = {}
    local ok = pcall(function()
        connected = part:GetConnectedParts(true)
    end)
    if not ok or type(connected) ~= "table" or #connected == 0 then
        connected = { part }
    end

    for i = 1, #connected do
        local base = connected[i]
        if base and base:IsA("BasePart") then
            hideC4Part(base)
            local descendants = base:GetDescendants()
            for j = 1, #descendants do
                local d = descendants[j]
                if d:IsA("Decal") or d:IsA("Texture") then
                    hideC4Part(d)
                end
            end
        end
    end
end

showC4Assembly = function()
    if not c4Hidden then
        return
    end
    for i = 1, #c4Hidden do
        local item = c4Hidden[i]
        local inst = item and item[1]
        if inst and inst.Parent then
            if inst:IsA("BasePart") then
                pcall(function()
                    inst.Transparency = item[2]
                    inst.LocalTransparencyModifier = item[3]
                end)
            elseif inst:IsA("Decal") or inst:IsA("Texture") then
                pcall(function()
                    inst.Transparency = item[2]
                end)
            end
        end
    end
    table.clear(c4Hidden)
    if c4HiddenLookup then
        table.clear(c4HiddenLookup)
    end
end

DRONE1_BLUEPRINT = {
    { class = "Part", name = "Axis", size = Vector3.new(0.100000, 0.101587, 0.101587), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, shape = Enum.PartType.Cylinder, transparency = 0, offset = CFrame.new(-1.268616, 0.299652, -0.809448, 0, -0.342014, 0.939695, 1, 0, 0, 0, 0.939695, 0.342014) },
    { class = "Part", name = "Axis", size = Vector3.new(0.100000, 0.101587, 0.101587), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, shape = Enum.PartType.Cylinder, transparency = 0, offset = CFrame.new(-1.294495, -0.000336, 0.946899, 0, 0.342009, 0.939697, 1, 0, 0, 0, 0.939697, -0.342009) },
    { class = "Part", name = "Axis", size = Vector3.new(0.100000, 0.076190, 0.076191), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, shape = Enum.PartType.Cylinder, transparency = 0, offset = CFrame.new(1.243103, -0.000336, 0.946899, 0, -0.342009, 0.939697, 1, 0, 0, 0, 0.939697, 0.342009) },
    { class = "Part", name = "Axis", size = Vector3.new(0.100000, 0.101587, 0.101587), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, shape = Enum.PartType.Cylinder, transparency = 0, offset = CFrame.new(1.269104, 0.299652, -0.809448, 0, 0.342009, 0.939697, 1, 0, 0, 0, 0.939697, -0.342008) },
    { class = "Part", name = "FPCam", size = Vector3.new(0.250031, 0.250012, 0.200195), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, transparency = 1, offset = CFrame.new(0.000305, -0.124969, -0.875122, 1, 0, 0, 0, 1, 0, 0, 0, 1) },
    { class = "Part", name = "Main", size = Vector3.new(0.750000, 0.500000, 0.700000), color = Color3.new(0.639216, 0.635294, 0.647059), material = Enum.Material.Plastic, shape = Enum.PartType.Block, transparency = 1, offset = CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1) },
    { class = "Part", name = "Main", size = Vector3.new(1.650639, 0.065001, 0.140015), color = Color3.new(0.066667, 0.066667, 0.066667), material = Enum.Material.Sand, transparency = 0, offset = CFrame.new(-1.294678, -0.000336, 0.946655, 1, 0, 0, 0, 1, 0, 0, 0, 1) },
    { class = "Part", name = "Main", size = Vector3.new(1.650639, 0.065001, 0.140015), color = Color3.new(0.066667, 0.066667, 0.066667), material = Enum.Material.Sand, transparency = 0, offset = CFrame.new(1.269287, 0.299652, -0.809326, 1, 0, 0, 0, 1, 0, 0, 0, 1) },
    { class = "Part", name = "Main", size = Vector3.new(1.650639, 0.065001, 0.140015), color = Color3.new(0.066667, 0.066667, 0.066667), material = Enum.Material.Sand, transparency = 0, offset = CFrame.new(1.243286, -0.000336, 0.946655, 1, 0, 0, 0, 1, 0, 0, 0, 1) },
    { class = "Part", name = "Main", size = Vector3.new(1.650639, 0.065001, 0.140015), color = Color3.new(0.066667, 0.066667, 0.066667), material = Enum.Material.Sand, transparency = 0, offset = CFrame.new(-1.268677, 0.299652, -0.809326, 1, 0, 0, 0, 1, 0, 0, 0, 1) },
    { class = "Part", name = "Part", size = Vector3.new(4.000000, 0.853449, 0.714277), color = Color3.new(0.639216, 0.635294, 0.647059), material = Enum.Material.Plastic, shape = Enum.PartType.Block, transparency = 1, offset = CFrame.new(-0.018188, -0.050293, -0.205750, 0, 0, 1, -0.001643, -1, 0, 1, -0.001643, 0) },
    { class = "Part", name = "Part", size = Vector3.new(1.750031, 0.500012, 0.700195), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, transparency = 0, offset = CFrame.new(0.000305, 0.000031, -0.000122, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
    { class = "Part", name = "Part", size = Vector3.new(0.050000, 0.083333, 0.083333), color = Color3.new(0.066667, 0.066667, 0.066667), material = Enum.Material.Glass, shape = Enum.PartType.Cylinder, transparency = 0.75, offset = CFrame.new(-0.149658, 0.150024, -0.835938, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
    { class = "Part", name = "Part", size = Vector3.new(0.400000, 0.100000, 0.540000), color = Color3.new(0.298039, 0.298039, 0.298039), material = Enum.Material.Metal, shape = Enum.PartType.Block, transparency = 0, offset = CFrame.new(0.000244, 0.100006, 0.277344, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
    { class = "Part", name = "Part", size = Vector3.new(0.050000, 0.083333, 0.083333), color = Color3.new(0.066667, 0.066667, 0.066667), material = Enum.Material.Glass, shape = Enum.PartType.Cylinder, transparency = 0.75, offset = CFrame.new(0.150330, 0.150024, -0.835938, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
    { class = "Part", name = "Part", size = Vector3.new(0.050000, 0.100000, 0.200000), color = Color3.new(0.066667, 0.066667, 0.066667), material = Enum.Material.Glass, shape = Enum.PartType.Block, transparency = 0.75, offset = CFrame.new(0.000305, 0.079651, 0.827637, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
    { class = "Part", name = "Union", size = Vector3.new(0.300000, 0.228777, 1.264832), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, transparency = 0, offset = CFrame.new(0.756531, -0.100342, 0.769653, 0, -0.342009, 0.939697, 1, 0, 0, 0, 0.939697, 0.342009) },
    { class = "Part", name = "Union", size = Vector3.new(0.339798, 0.264786, 0.500061), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, transparency = 0, offset = CFrame.new(0.000183, -0.234131, 0.652771, 0, 0, 1, -0.258824, 0.965925, 0, -0.965925, -0.258824, 0) },
    { class = "Part", name = "Union", size = Vector3.new(0.299999, 0.228824, 1.264949), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, transparency = 0, offset = CFrame.new(-0.781860, 0.199646, -0.632446, 0, -0.342014, 0.939695, 1, 0, 0, 0, 0.939695, 0.342014) },
    { class = "Part", name = "Union", size = Vector3.new(0.500137, 0.496275, 0.501221), color = Color3.new(0.066667, 0.066667, 0.066667), material = Enum.Material.Glass, transparency = 0.55, offset = CFrame.new(0.000916, -0.000458, -0.496338, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
    { class = "Part", name = "Union", size = Vector3.new(0.299998, 0.231187, 1.264694), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, transparency = 0, offset = CFrame.new(0.782654, 0.199646, -0.631287, 0, 0.342009, 0.939697, 1, 0, 0, 0, 0.939697, -0.342008) },
    { class = "Part", name = "Union", size = Vector3.new(0.300000, 0.228774, 1.264450), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, transparency = 0, offset = CFrame.new(-0.808105, -0.100342, 0.769653, 0, 0.342009, 0.939697, 1, 0, 0, 0, 0.939697, -0.342009) },
    { class = "Part", name = "Union", size = Vector3.new(0.400024, 0.250000, 0.700134), color = Color3.new(0.388235, 0.372549, 0.384314), material = Enum.Material.Metal, transparency = 0, offset = CFrame.new(0.000244, -0.124969, 0.677368, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
}

createC4DroneVisual = function(part)
    if not part or not part.Parent then
        return
    end
    if c4VisualModel then
        pcall(function()
            c4VisualModel:Destroy()
        end)
        c4VisualModel = nil
    end

    local model = Instance.new("Model")
    model.Name = "Drone1"
    model.Parent = part.Parent

    for i = 1, #DRONE1_BLUEPRINT do
        local d = DRONE1_BLUEPRINT[i]
        local p = Instance.new("Part")
        p.Name = d.name
        p.Size = d.size
        p.CFrame = part.CFrame * d.offset
        p.Color = d.color
        p.Material = d.material
        p.Transparency = d.transparency
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Anchored = false
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.Massless = true
        if d.shape then
            p.Shape = d.shape
        end
        p.Parent = model

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = p
        weld.Part1 = part
        weld.Parent = p
    end

    c4VisualModel = model
end

releaseControl = function()
    forward = 0
    sideways = 0
    breakControl = false

    if currentBodyVelocity then
        pcall(function()
            currentBodyVelocity:Destroy()
        end)
    end
    if currentBodyGyro then
        pcall(function()
            currentBodyGyro:Destroy()
        end)
    end

    currentBodyVelocity = nil
    currentBodyGyro = nil
    currentObject = nil
    if c4VisualModel then
        pcall(function()
            c4VisualModel:Destroy()
        end)
        c4VisualModel = nil
    end
    stopC4FlySound()
    showC4Assembly()

    if me.Character and me.Character:FindFirstChild("HumanoidRootPart") then
        me.Character.HumanoidRootPart.Anchored = false
    end
    camera = Workspace.CurrentCamera or camera
    if camera and cameraWasOverridden then
        local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
        camera.CameraType = Enum.CameraType.Custom
        if hum then
            camera.CameraSubject = hum
        elseif savedCameraSubject and savedCameraSubject.Parent then
            camera.CameraSubject = savedCameraSubject
        end
        if savedCameraCFrame then
            camera.CFrame = savedCameraCFrame
        end
    end
    cameraWasOverridden = false
    savedCameraType = nil
    savedCameraSubject = nil
    savedCameraCFrame = nil
    cameraLookDir = nil
    cameraFollowPos = nil
    cameraYaw = nil
    cameraPitch = nil
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    if savedMouseBehavior ~= nil then
        UserInputService.MouseBehavior = savedMouseBehavior
    end
    if savedMouseIconEnabled ~= nil then
        UserInputService.MouseIconEnabled = savedMouseIconEnabled
    end
    task.defer(function()
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
    end)
    task.delay(0.08, function()
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
    end)
    task.delay(0.2, function()
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
    end)
    savedMouseBehavior = nil
    savedMouseIconEnabled = nil
end

getMapPart = function()
    local map = Workspace:FindFirstChild("Map")
    if not map then
        return nil
    end
    for _, inst in ipairs(map:GetDescendants()) do
        if inst:IsA("BasePart") then
            return inst
        end
    end
end

airDetonateC4 = function()
    if not currentObject or currentObject.Name ~= "TransIgnore" then
        return
    end
    local detonatingObject = currentObject
    if not c4EventRemote or not c4EventRemote:IsA("RemoteEvent") then
        return
    end
    local mapPart = getMapPart()
    pendingC4ExplosionUntil = os.clock() + 1.25
    if mapPart then
        pcall(function()
            c4EventRemote:FireServer("Do", mapPart, currentObject.CFrame)
        end)
    end
    pcall(function()
        c4EventRemote:FireServer("Detonate")
    end)
    task.delay(0.55, function()
        if currentObject and currentObject == detonatingObject then
            releaseControl()
        end
    end)
end

bindC4Tool = function(char)
    if c4ToolConn then
        pcall(function()
            c4ToolConn:Disconnect()
        end)
        c4ToolConn = nil
    end
    c4EventRemote = nil
    if not char then
        return
    end

    local c4Tool = char:FindFirstChild("C4")
    if c4Tool and c4Tool:IsA("Tool") then
        local ev = c4Tool:FindFirstChild("Event")
        if ev and ev:IsA("RemoteEvent") then
            c4EventRemote = ev
        end
        c4ToolConn = c4Tool.Activated:Connect(function()
            if currentObject and currentObject.Name == "TransIgnore" then
                airDetonateC4()
            else
                markShot("TransIgnore")
            end
        end)
    end
end

registerProjectile = function(projectile)
    if not projectilesControlEnabled then
        return
    end
    if currentObject then
        return
    end

    task.wait()
    if not me.Character then
        return
    end
    if not projectile then
        return
    end
    if not isRecentShot(projectile.Name) then
        return
    end

    local myRoot = me.Character:FindFirstChild("HumanoidRootPart") or me.Character:FindFirstChild("Head")
    if myRoot then
        local projectilePos
        if pcall(function()
            projectilePos = projectile.Position
        end) and projectilePos then
            if (projectilePos - myRoot.Position).Magnitude > 30 then
                return
            end
        else
            return
        end
    end

    if projectile.Name == "TransIgnore" then
        hideC4Assembly(projectile)
        createC4DroneVisual(projectile)
        startC4FlySound(projectile)
    else
        if projectile.Name == "RPG_Rocket" then
            if not (me.Character:FindFirstChild("RPG-7") or me.Character:FindFirstChild("RPG-29")) then
                return
            end
        elseif projectile.Name == "_B__RPG_Rocket" or projectile.Name == "_B__RPG_Rocket2" then
            if not (me.Character:FindFirstChild("Plasma-Rocket-Launcher") or me.Character:FindFirstChild("RPG-29")) then
                return
            end
        elseif projectile.Name == "GrenadeLauncherGrenade" then
            if not (me.Character:FindFirstChild("M320-1") or me.Character:FindFirstChild("SCAR-H-X")) then
                return
            end
        elseif projectile.Name == "SBL_Rocket" then
            if not me.Character:FindFirstChild("SBL-MK3") then
                return
            end
        elseif projectile.Name == "Hallows_Rocket3" then
            if not (me.Character:FindFirstChild("HL-MK3") or me.Character:FindFirstChild("A-HL-MK4") or me.Character:FindFirstChild("A-HL-MK3")) then
                return
            end
        elseif projectile.Name == "A_Hallows_Rocket3" then
            if not (me.Character:FindFirstChild("A-HL-MK3") or me.Character:FindFirstChild("A-HL-MK4")) then
                return
            end
        elseif projectile.Name == "Hallows_Rocket2" then
            if not me.Character:FindFirstChild("HL-MK2") then
                return
            end
        elseif projectile.Name == "FireworkLauncher_Rocket" then
            if not (me.Character:FindFirstChild("FireworkLauncher") or me.Character:FindFirstChild("A-FW-L")) then
                return
            end
        elseif projectile.Name == "Hallows_Rocket" then
            if not me.Character:FindFirstChild("HallowsLauncher") then
                return
            end
        elseif projectile.Name == "AT4_Rocket" then
            if not (me.Character:FindFirstChild("AT4") or me.Character:FindFirstChild("AT4_") or me.Character:FindFirstChild("Panzerfaust-3") or me.Character:FindFirstChild("AUTO-PANZER")) then
                return
            end
        elseif projectile.Name == "Flare_Rocket" then
            if not me.Character:FindFirstChild("FlareGun") then
                return
            end
        elseif projectile.Name == "Rpg18" then
            if not me.Character:FindFirstChild("RPG-18") then
                return
            end
        else
            return
        end
    end

    if not ensureControlCamera() then
        return
    end
    if me.Character and me.Character:FindFirstChild("HumanoidRootPart") then
        me.Character.HumanoidRootPart.Anchored = true
    end

    local startCf
    if pcall(function()
        startCf = projectile.CFrame
    end) and startCf then
        local baseLook = startCf.LookVector
        if camera then
            baseLook = camera.CFrame.LookVector
        end
        cameraLookDir = baseLook
        if cameraLookDir.Magnitude > 0.001 then
            cameraLookDir = cameraLookDir.Unit
        else
            cameraLookDir = Vector3.new(0, 0, -1)
        end
        cameraPitch = math.asin(math.clamp(cameraLookDir.Y, -1, 1))
        cameraYaw = math.atan2(-cameraLookDir.X, -cameraLookDir.Z)
        cameraFollowPos = startCf.Position - cameraLookDir * 7 + Vector3.new(0, 2.4, 0)
        if camera then
            local lookPos = startCf.Position + cameraLookDir * 18 + Vector3.new(0, 0.8, 0)
            camera.CFrame = CFrame.lookAt(cameraFollowPos, lookPos)
        end
    else
        cameraLookDir = Vector3.new(0, 0, -1)
        cameraPitch = 0
        cameraYaw = 0
        cameraFollowPos = nil
    end

    pcall(function()
        if projectile:FindFirstChild("BodyForce") then
            projectile.BodyForce:Destroy()
        end
        if projectile:FindFirstChild("BodyAngularVelocity") then
            projectile.BodyAngularVelocity:Destroy()
        end
        if projectile:FindFirstChild("Sound") then
            projectile.Sound:Destroy()
        end
        if projectile:FindFirstChild("RotPart") and projectile.RotPart:FindFirstChild("BodyAngularVelocity") then
            projectile.RotPart.BodyAngularVelocity:Destroy()
        end
    end)

    currentBodyVelocity = Instance.new("BodyVelocity")
    currentBodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    currentBodyVelocity.Velocity = Vector3.new()
    currentBodyVelocity.Parent = projectile

    currentBodyGyro = Instance.new("BodyGyro")
    currentBodyGyro.P = 9e4
    currentBodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    currentBodyGyro.Parent = projectile

    currentObject = projectile
    task.defer(function()
        if currentObject == projectile and currentObject.Parent and projectilesControlEnabled then
            if ensureControlCamera() then
                applyControlCameraFrame()
            end
        end
    end)
    if recentShots then
        recentShots[projectile.Name] = nil
    end
end

VParts.ChildAdded:Connect(registerProjectile)
for _, projectile in ipairs(VParts:GetChildren()) do
    task.spawn(registerProjectile, projectile)
end

Debris.ChildAdded:Connect(function(result)
    task.wait()
    if not me.Character then
        return
    end

    pcall(function()
        if result.Name == "C4Explosion" and os.clock() <= (pendingC4ExplosionUntil or 0) then
            pendingC4ExplosionUntil = 0
            playC4ExplosionSound()
            if currentObject and currentObject.Name == "TransIgnore" then
                breakControl = true
                task.delay(0.05, releaseControl)
            end
            return
        end
        if not currentObject then
            return
        end
        if
            (me.Character:FindFirstChild("RPG-7") and (result.Name == "RPG_Explosion_Long" or result.Name == "RPG_Explosion_Short")) or
            ((me.Character:FindFirstChild("M320-1") or me.Character:FindFirstChild("SCAR-H-X")) and (result.Name == "GL_Explosion_Long" or result.Name == "GL_Explosion_Short")) or
            (me.Character:FindFirstChild("SBL-MK3") and result.Name == "SBL_Explosion") or
            (me.Character:FindFirstChild("HL-MK3") and (result.Name == "Hallows_Explosion2_Long" or result.Name == "Hallows_Explosion2_Short")) or
            (me.Character:FindFirstChild("HL-MK2") and result.Name == "Hallows_Explosion") or
            (me.Character:FindFirstChild("FireworkLauncher") and result.Name == "Firework_Explosion") or
            (me.Character:FindFirstChild("HallowsLauncher") and result.Name == "Hallows_Explosion") or
            (me.Character:FindFirstChild("RPG-G") and result.Name == "VortexExplosion") or
            (me.Character:FindFirstChild("AT4") and (result.Name == "Panzer_Explosion_Long" or result.Name == "Panzer_Explosion_Short")) or
            (me.Character:FindFirstChild("RPG-29") and (result.Name == "Panzer_Explosion_Long" or result.Name == "Panzer_Explosion_Short")) or
            (me.Character:FindFirstChild("RPG-18") and result.Name == "BigExplosion2") then
            breakControl = true
            task.delay(0.05, releaseControl)
        end
    end)
end)

UserInputService.InputBegan:Connect(function(key, gameProcessed)
    if gameProcessed then
        return
    end
    if key.KeyCode == Enum.KeyCode.K then
        projectilesControlEnabled = not projectilesControlEnabled
        syncWallbangState(shouldEnableProjectileWallbang())
        if not projectilesControlEnabled then
            releaseControl()
        end
    elseif key.KeyCode == Enum.KeyCode.W then
        forward = 1
    elseif key.KeyCode == Enum.KeyCode.S then
        forward = -1
    elseif key.KeyCode == Enum.KeyCode.D then
        sideways = 1
    elseif key.KeyCode == Enum.KeyCode.A then
        sideways = -1
    end
end)

UserInputService.InputEnded:Connect(function(key)
    if key.KeyCode == Enum.KeyCode.W or key.KeyCode == Enum.KeyCode.S then
        forward = 0
    elseif key.KeyCode == Enum.KeyCode.D or key.KeyCode == Enum.KeyCode.A then
        sideways = 0
    end
end)

me.CharacterRemoving:Connect(function()
    releaseControl()
end)

if charChildConn then
    pcall(function()
        charChildConn:Disconnect()
    end)
end
if charAddedConn then
    pcall(function()
        charAddedConn:Disconnect()
    end)
end

if me.Character then
    bindC4Tool(me.Character)
    bindCharacterShotTools(me.Character)
    charChildConn = me.Character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child.Name == "C4" then
            bindC4Tool(me.Character)
        end
        if child:IsA("Tool") then
            bindShotTool(child)
        end
    end)
end

charAddedConn = me.CharacterAdded:Connect(function(char)
    releaseControl()
    bindC4Tool(char)
    bindCharacterShotTools(char)
    if charChildConn then
        pcall(function()
            charChildConn:Disconnect()
        end)
    end
    charChildConn = char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child.Name == "C4" then
            bindC4Tool(char)
        end
        if child:IsA("Tool") then
            bindShotTool(child)
        end
    end)
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    camera = Workspace.CurrentCamera
    if camera and currentObject and currentObject.Parent then
        ensureControlCamera()
        applyControlCameraFrame()
    end
end)

RunService.RenderStepped:Connect(function()
    if not projectilesControlEnabled then
        return
    end
    if not currentObject or not currentObject.Parent then
        return
    end
    if ensureControlCamera() then
        applyControlCameraFrame()
    end
end)

RunService.Heartbeat:Connect(function()
    if shouldEnableProjectileWallbang() then
        wallbangRefreshTick = wallbangRefreshTick + 1
        if wallbangRefreshTick >= 45 then
            wallbangRefreshTick = 0
            syncWallbangState(true)
        end
    else
        wallbangRefreshTick = 0
        if wallbangApplied then
            syncWallbangState(false)
        end
    end

    if currentObject and (not currentBodyVelocity or not currentBodyGyro) then
        releaseControl()
        return
    end
    if not currentObject then
        return
    end
    if not projectilesControlEnabled then
        releaseControl()
        return
    end
    if not currentObject.Parent then
        releaseControl()
        return
    end
    if not ensureControlCamera() then
        return
    end

    local projectileCFrame
    local okCFrame = pcall(function()
        projectileCFrame = currentObject.CFrame
    end)
    if not okCFrame then
        releaseControl()
        return
    end

    if currentObject.Name == "TransIgnore" then
        pcall(function()
            hideC4Assembly(currentObject)
        end)
    end

    local mouseDelta = UserInputService:GetMouseDelta()
    local sens = 0.0024
    cameraYaw = (cameraYaw or 0) - mouseDelta.X * sens
    cameraPitch = math.clamp((cameraPitch or 0) - mouseDelta.Y * sens, -1.22, 1.1)

    local desiredDir = Vector3.new(
        -math.sin(cameraYaw) * math.cos(cameraPitch),
        math.sin(cameraPitch),
        -math.cos(cameraYaw) * math.cos(cameraPitch)
    )
    if desiredDir.Magnitude <= 0.001 then
        desiredDir = Vector3.new(0, 0, -1)
    else
        desiredDir = desiredDir.Unit
    end

    if not cameraLookDir then
        cameraLookDir = desiredDir
    else
        cameraLookDir = cameraLookDir:Lerp(desiredDir, 0.35)
        if cameraLookDir.Magnitude > 0.001 then
            cameraLookDir = cameraLookDir.Unit
        else
            cameraLookDir = desiredDir
        end
    end

    local rightDir = cameraLookDir:Cross(Vector3.new(0, 1, 0))
    if rightDir.Magnitude <= 0.001 then
        rightDir = Vector3.new(1, 0, 0)
    else
        rightDir = rightDir.Unit
    end

    local moveDir = (cameraLookDir * forward) + (rightDir * sideways)
    if moveDir.Magnitude > 1 then
        moveDir = moveDir.Unit
    end

    local speed = projectilesControlSpeed
    TweenService:Create(
        currentBodyVelocity,
        TweenInfo.new(0),
        { Velocity = moveDir * speed }
    ):Play()

    currentBodyGyro.CFrame = CFrame.lookAt(projectileCFrame.Position, projectileCFrame.Position + cameraLookDir)

    applyControlCameraFrame()

    if breakControl then
        releaseControl()
    end
end)
