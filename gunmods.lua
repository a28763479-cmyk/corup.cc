repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

Players = game:GetService("Players")
ReplicatedStorage = game:GetService("ReplicatedStorage")
Debris = game:GetService("Debris")
RunService = game:GetService("RunService")
TweenService = game:GetService("TweenService")
Workspace = game:GetService("Workspace")
UserInputService = game:GetService("UserInputService")
Teams = game:GetService("Teams")

LocalPlayer = Players.LocalPlayer
Camera = Workspace.CurrentCamera

Events = ReplicatedStorage:WaitForChild("Events")
Events2 = ReplicatedStorage:WaitForChild("Events2")

Settings = {
    InstantBullet = false,
    InstantVelocity = 1550000,
    InstantRange = 100000,

    ModRecoil = false,
    RecoilAmount = 0,
    ModSpread = false,
    SpreadAmount = 0,
    ModEquip = false,
    EquipSpeed = 1,
    ModAim = false,
    AimSpeed = 1,
    InfiniteRange = false,
    NoSlowdown = false,
    InstantCharge = false,
    RapidFire = false,
    RapidFireMultiplier = 1.3,
    RapidFireMaxRate = 22,
    RapidFireLatencyReserve = 0.015,
    InstantReload = false,

    TracersSelf = false,
    TracersOthers = false,
    TracerSelfColor = Color3.fromRGB(80, 190, 255),
    TracerOthersColor = Color3.fromRGB(255, 80, 80),

    HitmanBriefcaseEnabled = false,
    HitmanBriefcasePhaseThroughWorld = true,
    HitmanBriefcaseObstaclePathing = true,
    HitmanBriefcaseAirDetourEnabled = true,
    HitmanBriefcaseQuickDetourEnabled = true,
    HitmanBriefcaseEmergencyWallBypass = true,
    HitmanBriefcaseLifeExtendOnClose = true,
    HitmanBriefcaseEndgameBoostEnabled = true,
    HitmanBriefcaseMapAdaptiveEnabled = true,
    HitmanBriefcaseTerrainAdaptiveEnabled = true,
    HitmanBriefcaseClutterAdaptiveEnabled = true,
    HitmanBriefcaseIgnoreTinyObstacleEnabled = true,
    HitmanBriefcasePreemptiveAvoidanceEnabled = true,
    HitmanBriefcaseRescueSteeringEnabled = true,
}

originalValues = setmetatable({}, { __mode = "k" })
trackedConfigs = setmetatable({}, { __mode = "k" })

tracerFolder = Instance.new("Folder")
tracerFolder.Name = "_RageTracers"
tracerFolder.Parent = Camera
tracerUnload = false
tracerRecentShots = {}
visualizeConnections = {}
visualizeBindableConnected = false
visualizeRemoteConnected = false
localShootTracerHooked = false
visualizeTracerHooked = false

projectileRemote = Events:FindFirstChild("ProjectileHandle")
projectileRemote2 = Events:FindFirstChild("ProjectileHandle2")
projectileHookInstalled = false
projectileHookRetryRunning = false
projectileHookInvokeWrapper = nil
projectileHookOriginalInvoke = nil
hookedProjectileFunctions = {}
hitmanRegisterProjectile = nil
hitmanClearProjectiles = nil
hitmanWallbangOriginalParents = {}
hitmanWallbangApplied = false
hitmanTrackedProjectileCount = 0

instantReloadLoopRunning = false
refreshTick = 0
projectileRefreshTick = 0
hitmanWallbangRefreshTick = 0

local function syncHitmanWallbangState(enabled)
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
            targets[#targets + 1] = map:FindFirstChild("ProximityShops")
            targets[#targets + 1] = map:FindFirstChild("SpawnedSupplyPlanes")
            targets[#targets + 1] = map:FindFirstChild("VendingMachines")

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
        end

        for i = 1, #targets do
            local target = targets[i]
            if target and target.Parent then
                if hitmanWallbangOriginalParents[target] == nil then
                    hitmanWallbangOriginalParents[target] = target.Parent
                end
                if target.Parent ~= characters then
                    target.Parent = characters
                end
            end
        end
        hitmanWallbangApplied = true
        return
    end

    for target, originalParent in pairs(hitmanWallbangOriginalParents) do
        if target and target.Parent and originalParent and originalParent.Parent and target.Parent ~= originalParent then
            target.Parent = originalParent
        end
    end
    table.clear(hitmanWallbangOriginalParents)
    hitmanWallbangApplied = false
end

local function isHitmanWallbangToolName(name)
    return name == "RPG-7"
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
        or name == "C4"
end

local function hasHitmanWallbangTool()
    local character = LocalPlayer and LocalPlayer.Character
    if character then
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") and isHitmanWallbangToolName(child.Name) then
                return true
            end
        end
    end

    local backpack = LocalPlayer and LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") and isHitmanWallbangToolName(child.Name) then
                return true
            end
        end
    end

    return false
end

local function shouldEnableHitmanWallbang()
    return Settings.HitmanBriefcaseEnabled and (hasHitmanWallbangTool() or hitmanTrackedProjectileCount > 0)
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copied = {}
    for key, nested in pairs(value) do
        copied[key] = deepCopy(nested)
    end
    return copied
end

local function remember(tbl, key)
    local byTable = originalValues[tbl]
    if not byTable then
        byTable = {}
        originalValues[tbl] = byTable
    end
    if byTable[key] == nil then
        byTable[key] = deepCopy(rawget(tbl, key))
    end
    return byTable[key]
end

local function setValue(tbl, key, value)
    if rawget(tbl, key) == nil then
        return
    end
    remember(tbl, key)
    pcall(function()
        tbl[key] = value
    end)
end

local function setNumber(tbl, key, value)
    if type(rawget(tbl, key)) ~= "number" then
        return
    end
    setValue(tbl, key, value)
end

local function setNumberFromBase(tbl, key, enabled, transformFn)
    if type(rawget(tbl, key)) ~= "number" then
        return
    end
    local base = remember(tbl, key)
    if type(base) ~= "number" then
        return
    end
    if enabled then
        setValue(tbl, key, transformFn(base))
    else
        setValue(tbl, key, base)
    end
end

local function setValueFromBase(tbl, key, enabled, enabledValue)
    if rawget(tbl, key) == nil then
        return
    end
    local base = remember(tbl, key)
    if enabled then
        setValue(tbl, key, enabledValue)
    else
        setValue(tbl, key, deepCopy(base))
    end
end

local function restoreConfigValues()
    for tbl, byKey in pairs(originalValues) do
        for key, value in pairs(byKey) do
            pcall(function()
                tbl[key] = deepCopy(value)
            end)
        end
    end
    originalValues = setmetatable({}, { __mode = "k" })
end

local function touchConfig(config)
    if type(config) ~= "table" then
        return
    end
    trackedConfigs[config] = true
end

local function applyInstant(config)
    if type(config) ~= "table" then
        return
    end

    local enabled = Settings.InstantBullet
    local speed = math.max(Settings.InstantVelocity, 1)

    if type(config.BulletSettings) == "table" then
        local bulletSpeedKeys = {
            "Velocity",
            "Speed",
            "BulletSpeed",
            "BulletVelocity",
            "MuzzleVelocity",
            "InitialSpeed",
        }
        for _, key in ipairs(bulletSpeedKeys) do
            setNumberFromBase(config.BulletSettings, key, enabled, function()
                return speed
            end)
        end

        if typeof(rawget(config.BulletSettings, "Acceleration")) == "Vector3" then
            setValueFromBase(config.BulletSettings, "Acceleration", enabled, Vector3.new(0, 0, 0))
        end
    end

    local rangeKeys = {
        "Range",
        "MaxRange",
        "EffectiveRange",
        "Distance",
    }
    for _, key in ipairs(rangeKeys) do
        setNumberFromBase(config, key, enabled, function()
            return Settings.InstantRange
        end)
    end

    local rootSpeedKeys = {
        "Velocity",
        "Speed",
        "BulletSpeed",
        "BulletVelocity",
    }
    for _, key in ipairs(rootSpeedKeys) do
        setNumberFromBase(config, key, enabled, function()
            return speed
        end)
    end

    setNumberFromBase(config, "DropoffDistance", enabled, function()
        return 1000000
    end)
    setNumberFromBase(config, "ProjectileVelocity", enabled, function()
        return math.max(speed, 50000)
    end)
    setNumberFromBase(config, "ProjectileSpeed", enabled, function()
        return math.max(speed, 50000)
    end)
    setNumberFromBase(config, "MissileSpeed", enabled, function()
        return math.max(speed, 50000)
    end)
    setNumberFromBase(config, "LauncherVelocity", enabled, function()
        return math.max(speed, 50000)
    end)
    setNumberFromBase(config, "RocketSpeed", enabled, function()
        return math.max(speed, 50000)
    end)
    setNumberFromBase(config, "GrenadeSpeed", enabled, function()
        return math.max(speed, 50000)
    end)
    setNumberFromBase(config, "RocketUpForce", enabled, function()
        return 0
    end)
    setNumberFromBase(config, "RocketUpForceMulti", enabled, function()
        return 0
    end)
    setNumberFromBase(config, "RotStartTime", enabled, function()
        return 0
    end)

    if type(config.ProjectileSettings) == "table" then
        setNumberFromBase(config.ProjectileSettings, "Velocity", enabled, function()
            return math.max(speed, 50000)
        end)
        setNumberFromBase(config.ProjectileSettings, "Speed", enabled, function()
            return math.max(speed, 50000)
        end)
        setNumberFromBase(config.ProjectileSettings, "MaxSpeed", enabled, function()
            return math.max(speed, 50000)
        end)
        setNumberFromBase(config.ProjectileSettings, "Acceleration", enabled, function()
            return 0
        end)
    end
end

local function applyClassic(config)
    if type(config) ~= "table" then
        return
    end

    local function rapidRateFromBase(base)
        local baseRate = tonumber(base)
        if not baseRate or baseRate <= 0 then
            return base
        end

        local desired = baseRate * math.max(Settings.RapidFireMultiplier, 1)
        local allowedByServer = desired

        local safeInterval = (1 / baseRate) - 0.05 - math.max(Settings.RapidFireLatencyReserve, 0)
        if safeInterval > 0 then
            allowedByServer = 1 / safeInterval
        else
            allowedByServer = baseRate * 1.15
        end

        local capped = math.min(desired, allowedByServer, math.max(Settings.RapidFireMaxRate, baseRate))
        return math.max(baseRate, capped)
    end

    setNumberFromBase(config, "Recoil", Settings.ModRecoil, function(base)
        return base * (Settings.RecoilAmount / 100)
    end)

    setNumberFromBase(config, "Spread", Settings.ModSpread, function(base)
        return base * (Settings.SpreadAmount / 100)
    end)

    if type(config.AimSettings) == "table" then
        setNumberFromBase(config.AimSettings, "Spread", Settings.ModSpread, function(base)
            return base * (Settings.SpreadAmount / 100)
        end)
        setNumberFromBase(config.AimSettings, "AimSpeed", Settings.ModAim, function(base)
            return base * (1 / math.max(Settings.AimSpeed, 0.01))
        end)
    end

    if type(config.SniperSettings) == "table" then
        setNumberFromBase(config.SniperSettings, "Spread", Settings.ModSpread, function(base)
            return base * (Settings.SpreadAmount / 100)
        end)
        setNumberFromBase(config.SniperSettings, "AimSpeed", Settings.ModAim, function(base)
            return base * (1 / math.max(Settings.AimSpeed, 0.01))
        end)
    end

    setNumberFromBase(config, "EquipTime", Settings.ModEquip, function(base)
        return base / math.max(Settings.EquipSpeed, 0.01)
    end)
    setNumberFromBase(config, "EquipAnimSpeed", Settings.ModEquip, function(base)
        return base * math.max(Settings.EquipSpeed, 0.01)
    end)

    setNumberFromBase(config, "Range", Settings.InfiniteRange, function()
        return 9e9
    end)

    if type(config.FireSlowDown) == "table" and type(rawget(config.FireSlowDown, "Enabled")) == "boolean" then
        setValueFromBase(config.FireSlowDown, "Enabled", Settings.NoSlowdown, false)
    end

    setValueFromBase(config, "ChargeupEnabled", Settings.InstantCharge, false)

    if type(config.ShotgunSettings) == "table" and rawget(config.ShotgunSettings, "FirePump") ~= nil then
        setValueFromBase(config.ShotgunSettings, "FirePump", Settings.InstantCharge, false)
    end

    setNumberFromBase(config, "FirePumpWait1", Settings.InstantCharge, function()
        return 0
    end)
    setNumberFromBase(config, "FirePumpWait2", Settings.InstantCharge, function()
        return 0
    end)

    if type(config.ChargeUpSettings) == "table" then
        setValueFromBase(config, "ChargeUpSettings", Settings.InstantCharge, { ChargeTime = 0, ChargeDB = 0 })
    end

    if type(config.FireModeSettings) == "table" then
        local fireModeKeys = {
            "FireMode",
            "Mode",
            "CurrentMode",
            "SelectedMode",
        }
        for _, key in ipairs(fireModeKeys) do
            if type(rawget(config.FireModeSettings, key)) == "string" then
                setValueFromBase(config.FireModeSettings, key, Settings.RapidFire, "Auto")
            end
        end
        if type(rawget(config.FireModeSettings, "CanSwitch")) == "boolean" then
            setValueFromBase(config.FireModeSettings, "CanSwitch", Settings.RapidFire, true)
        end
        if type(rawget(config.FireModeSettings, "DisplayMode")) == "string" then
            setValueFromBase(config.FireModeSettings, "DisplayMode", Settings.RapidFire, "Auto")
        end

        setNumberFromBase(config.FireModeSettings, "SemiRate", Settings.RapidFire, function(base)
            return rapidRateFromBase(base)
        end)
        setNumberFromBase(config.FireModeSettings, "BurstRate", Settings.RapidFire, function(base)
            return rapidRateFromBase(base)
        end)
        setNumberFromBase(config.FireModeSettings, "AutoRate", Settings.RapidFire, function(base)
            return rapidRateFromBase(base)
        end)
        setNumberFromBase(config.FireModeSettings, "FireRate", Settings.RapidFire, function(base)
            return rapidRateFromBase(base)
        end)
        setNumberFromBase(config.FireModeSettings, "BurstDRate", Settings.RapidFire, function(base)
            return rapidRateFromBase(base)
        end)
    end

    setNumberFromBase(config, "FireRate", Settings.RapidFire, function(base)
        return rapidRateFromBase(base)
    end)

end

local function applyAllMods(config)
    if type(config) ~= "table" then
        return
    end
    touchConfig(config)
    applyInstant(config)
    applyClassic(config)
end

local function refreshTrackedConfigs()
    for config in pairs(trackedConfigs) do
        applyAllMods(config)
    end
end

local function tracerShouldSkipShot(key, duplicateWindowSeconds)
    local now = os.clock()
    local prev = tracerRecentShots[key]
    tracerRecentShots[key] = now
    return prev and (now - prev) < (duplicateWindowSeconds or 0.02)
end

local function tracerShotKey(shooterId, shotCode, origin, direction)
    local originX = math.floor(origin.X * 10)
    local originY = math.floor(origin.Y * 10)
    local originZ = math.floor(origin.Z * 10)
    local directionX = math.floor(direction.X * 10)
    local directionY = math.floor(direction.Y * 10)
    local directionZ = math.floor(direction.Z * 10)
    return tostring(shooterId) .. "|" .. tostring(shotCode) .. "|" .. tostring(originX) .. "|" .. tostring(originY) .. "|" .. tostring(originZ) .. "|" .. tostring(directionX) .. "|" .. tostring(directionY) .. "|" .. tostring(directionZ)
end

local function tracerExtractDirection(value)
    if typeof(value) == "Vector3" then
        return value
    end
    if typeof(value) == "CFrame" then
        return value.LookVector
    end
    if type(value) == "table" then
        local first = value[1]
        if first == nil then
            first = value[next(value)]
        end
        if first ~= nil then
            return tracerExtractDirection(first)
        end
    end
    return nil
end

local function tracerIsToolOwnedByLocalPlayer(tool)
    if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
        return false
    end

    local character = LocalPlayer.Character
    if character and tool:IsDescendantOf(character) then
        return true
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack and tool:IsDescendantOf(backpack) then
        return true
    end

    return false
end

local function tracerIsSelfShot(firer, tool, isClient, position, extras)
    if typeof(firer) == "Instance" and firer:IsA("Player") then
        return firer == LocalPlayer
    end

    if tracerIsToolOwnedByLocalPlayer(tool) then
        return true
    end

    if type(extras) == "table" and tracerIsToolOwnedByLocalPlayer(extras.fpT) then
        return true
    end

    if isClient == true and typeof(position) == "Vector3" then
        local character = LocalPlayer.Character
        local head = character and character:FindFirstChild("Head")
        if head and (position - head.Position).Magnitude <= 18 then
            return true
        end
    end

    return false
end

local function tracerComputeEndPos(origin, direction, config)
    if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
        return nil
    end
    if direction.Magnitude <= 0.001 then
        return nil
    end

    local toMaybePoint = direction - origin
    if direction.Magnitude > 10 and toMaybePoint.Magnitude > 4 and toMaybePoint.Magnitude < 9000 then
        return direction
    end

    local maxDistance = 2200
    if type(config) == "table" then
        local range = tonumber(config.Range) or tonumber(config.MaxRange)
        if range then
            maxDistance = math.max(maxDistance, range)
        end
        local bulletSettings = config.BulletSettings
        if type(bulletSettings) == "table" then
            local velocity = tonumber(bulletSettings.Velocity) or tonumber(bulletSettings.Speed)
            if velocity then
                maxDistance = math.max(maxDistance, math.clamp(velocity * 3, 900, 7000))
            end
        end
    end
    maxDistance = math.clamp(maxDistance, 700, 8000)

    local castDir = direction.Unit * maxDistance
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    local ignore = { tracerFolder }
    local bulletsContainer = Camera and Camera:FindFirstChild("Bullets")
    if bulletsContainer then
        ignore[#ignore + 1] = bulletsContainer
    end
    if LocalPlayer.Character then
        ignore[#ignore + 1] = LocalPlayer.Character
    end
    if Camera then
        ignore[#ignore + 1] = Camera
    end
    params.FilterDescendantsInstances = ignore

    local hit = workspace:Raycast(origin, castDir, params)
    if hit then
        return hit.Position
    end
    return origin + castDir
end

local function tracerApplyNativeSettings(firer, tool, isClient, position, extras, config)
    if type(config) ~= "table" then
        return
    end
    local bulletSettings = config.BulletSettings
    if type(bulletSettings) ~= "table" then
        return
    end

    local isSelfShot = tracerIsSelfShot(firer, tool, isClient, position, extras)
    local tracerEnabledForShot = (isSelfShot and Settings.TracersSelf) or ((not isSelfShot) and Settings.TracersOthers)
    local tracerColorForShot = isSelfShot and Settings.TracerSelfColor or Settings.TracerOthersColor

    pcall(function()
        bulletSettings.TracerEnabled = tracerEnabledForShot
        bulletSettings.TracerChance = 1
        bulletSettings.TracerLifetime = 4
        bulletSettings.TracerTransparency = 0.05
        bulletSettings.Color = tracerColorForShot
        bulletSettings.LightColor = tracerColorForShot
    end)
end

local function tracerAttachTrailToBullet(bullet)
    if not (Settings.TracersSelf or Settings.TracersOthers) then
        return
    end
    if typeof(bullet) ~= "Instance" or not bullet:IsA("BasePart") then
        return
    end
    if bullet:GetAttribute("_RageTracerInternal") then
        return
    end
    if bullet.Name == "TracerLaser" then
        return
    end
    if bullet:GetAttribute("_RageTracerAttached") then
        return
    end
    bullet:SetAttribute("_RageTracerAttached", true)

    local isSelfBullet = false
    local character = LocalPlayer.Character
    local head = character and character:FindFirstChild("Head")
    if head and (bullet.Position - head.Position).Magnitude <= 22 then
        isSelfBullet = true
    end

    if isSelfBullet and not Settings.TracersSelf then
        return
    end
    if (not isSelfBullet) and not Settings.TracersOthers then
        return
    end

    local color = isSelfBullet and Settings.TracerSelfColor or Settings.TracerOthersColor
    local life = 4
    local halfZ = math.max(0.15, bullet.Size.Z * 0.5)

    local a0 = Instance.new("Attachment")
    a0.Name = "_RageTracerA0"
    a0.Position = Vector3.new(0, 0, halfZ)
    a0.Parent = bullet

    local a1 = Instance.new("Attachment")
    a1.Name = "_RageTracerA1"
    a1.Position = Vector3.new(0, 0, -halfZ)
    a1.Parent = bullet

    local trail = Instance.new("Trail")
    trail.Name = "_RageTracerTrail"
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.FaceCamera = true
    trail.LightEmission = 1
    trail.MinLength = 0
    trail.Lifetime = life
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, color),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.6, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Texture = "rbxassetid://446111271"
    trail.TextureMode = Enum.TextureMode.Wrap
    trail.TextureLength = 6
    trail.Enabled = true
    trail.Parent = bullet

    task.spawn(function()
        local lastPos = bullet.Position
        while (not tracerUnload) and bullet.Parent do
            task.wait(0.035)
            local currentPos = bullet.Position
            if (currentPos - lastPos).Magnitude > 0.12 then
                if tracerMakeBeamSegment then
                    tracerMakeBeamSegment(lastPos, currentPos, color, life)
                end
                lastPos = currentPos
            end
        end
    end)
end

local function tracerBindBulletFolder(folder)
    if tracerBulletAddedConnection then
        pcall(function()
            tracerBulletAddedConnection:Disconnect()
        end)
        tracerBulletAddedConnection = nil
    end

    tracerBulletFolder = folder
    if not folder or not folder:IsA("Folder") then
        return
    end

    tracerBulletAddedConnection = folder.ChildAdded:Connect(function(child)
        if tracerUnload then
            return
        end
        pcall(tracerAttachTrailToBullet, child)
    end)

    for _, child in ipairs(folder:GetChildren()) do
        pcall(tracerAttachTrailToBullet, child)
    end
end

local function tracerSyncToCamera()
    Camera = workspace.CurrentCamera
    if tracerFolder and Camera then
        tracerFolder.Parent = Camera
    end

    if tracerCameraChildAddedConnection then
        pcall(function()
            tracerCameraChildAddedConnection:Disconnect()
        end)
        tracerCameraChildAddedConnection = nil
    end

    if Camera then
        tracerCameraChildAddedConnection = Camera.ChildAdded:Connect(function(obj)
            if obj.Name == "Bullets" and obj:IsA("Folder") then
                tracerBindBulletFolder(obj)
            end
        end)
        tracerBindBulletFolder(Camera:FindFirstChild("Bullets"))
    else
        tracerBindBulletFolder(nil)
    end
end

tracerCameraChangedConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    tracerSyncToCamera()
end)
tracerSyncToCamera()

tracerMakeBeamSegment = function(origin, ending, color, lifetime)
    local delta = ending - origin
    if delta.Magnitude <= 0.1 then
        return
    end

    if not tracerFolder.Parent then
        tracerSyncToCamera()
    end
    if not tracerFolder.Parent then
        return
    end

    local holder = Instance.new("Part")
    holder.Name = "TracerLaser"
    holder.Anchored = true
    holder.CanCollide = false
    holder.CanQuery = false
    holder.CanTouch = false
    holder.Transparency = 1
    holder.Size = Vector3.new(0.05, 0.05, 0.05)
    holder.CFrame = CFrame.new((origin + ending) * 0.5)
    holder:SetAttribute("_RageTracerInternal", true)
    holder.Parent = tracerFolder

    local a0 = Instance.new("Attachment")
    a0.WorldPosition = origin
    a0.Parent = holder

    local a1 = Instance.new("Attachment")
    a1.WorldPosition = ending
    a1.Parent = holder

    local outer = Instance.new("Beam")
    outer.Attachment0 = a0
    outer.Attachment1 = a1
    outer.FaceCamera = true
    outer.LightEmission = 1
    outer.LightInfluence = 0
    outer.Brightness = 4
    outer.Width0 = 0.24
    outer.Width1 = 0.24
    outer.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, color),
    })
    outer.Transparency = NumberSequence.new(0.08)
    outer.Texture = "rbxassetid://446111271"
    outer.TextureMode = Enum.TextureMode.Wrap
    outer.TextureLength = 7
    outer.TextureSpeed = 14
    outer.Parent = holder

    local inner = Instance.new("Beam")
    inner.Attachment0 = a0
    inner.Attachment1 = a1
    inner.FaceCamera = true
    inner.LightEmission = 1
    inner.LightInfluence = 0
    inner.Brightness = 6
    inner.Width0 = 0.11
    inner.Width1 = 0.11
    inner.Color = ColorSequence.new(Color3.new(1, 1, 1))
    inner.Transparency = NumberSequence.new(0.22)
    inner.Texture = "rbxassetid://446111271"
    inner.TextureMode = Enum.TextureMode.Wrap
    inner.TextureLength = 5
    inner.TextureSpeed = 20
    inner.Parent = holder

    local fadeTime = math.clamp((tonumber(lifetime) or 4) * 0.45, 0.18, 2.6)
    local fadeDelay = math.max((tonumber(lifetime) or 4) - fadeTime, 0)
    task.delay(fadeDelay, function()
        if not holder.Parent then
            return
        end
        TweenService:Create(outer, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Width0 = 0,
            Width1 = 0,
            Brightness = 0,
            TextureSpeed = 0,
        }):Play()
        TweenService:Create(inner, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Width0 = 0,
            Width1 = 0,
            Brightness = 0,
            TextureSpeed = 0,
        }):Play()
    end)

    Debris:AddItem(holder, (tonumber(lifetime) or 4) + 0.1)
end

local function processShot(firer, shotCode, config, tool, isClient, position, directions, extras)
    if type(config) == "table" then
        applyAllMods(config)
        tracerApplyNativeSettings(firer, tool, isClient, position, extras, config)
    end

    if typeof(position) ~= "Vector3" then
        return
    end
    if type(directions) ~= "table" and typeof(directions) ~= "Vector3" and typeof(directions) ~= "CFrame" then
        return
    end
    if not (Settings.TracersSelf or Settings.TracersOthers) then
        return
    end

    local isSelfShot = tracerIsSelfShot(firer, tool, isClient, position, extras)
    if isSelfShot and not Settings.TracersSelf then
        return
    end
    if (not isSelfShot) and not Settings.TracersOthers then
        return
    end

    local tracerColor = isSelfShot and Settings.TracerSelfColor or Settings.TracerOthersColor
    local shooterId = (typeof(firer) == "Instance" and firer:IsA("Player")) and firer.UserId or -1
    if type(directions) ~= "table" then
        directions = { directions }
    end

    for _, direction in pairs(directions) do
        local directionVector = tracerExtractDirection(direction)
        if typeof(directionVector) == "Vector3" and directionVector.Magnitude > 0.001 then
            local key = tracerShotKey(shooterId, shotCode, position, directionVector)
            if not tracerShouldSkipShot(key, 0.03) then
                local endPosition = tracerComputeEndPos(position, directionVector, config)
                if endPosition then
                    tracerMakeBeamSegment(position, endPosition, tracerColor, 4)
                end
            end
        end
    end
end

local function connectVisualizeListeners()
    if not visualizeBindableConnected then
        local bindableVisualizeEvent = Events2:FindFirstChild("Visualize")
        if bindableVisualizeEvent and bindableVisualizeEvent:IsA("BindableEvent") then
            visualizeBindableConnected = true
            table.insert(visualizeConnections, bindableVisualizeEvent.Event:Connect(function(...)
                pcall(processShot, ...)
            end))
        end
    end

    if not visualizeRemoteConnected then
        local remoteVisualizeEvent = Events:FindFirstChild("Visualize")
        if remoteVisualizeEvent and remoteVisualizeEvent:IsA("RemoteEvent") then
            visualizeRemoteConnected = true
            table.insert(visualizeConnections, remoteVisualizeEvent.OnClientEvent:Connect(function(...)
                pcall(processShot, ...)
            end))
        end
    end
end

connectVisualizeListeners()
table.insert(visualizeConnections, Events.ChildAdded:Connect(function()
    connectVisualizeListeners()
end))
table.insert(visualizeConnections, Events2.ChildAdded:Connect(function()
    connectVisualizeListeners()
end))

local function installVisualizeTracerHook()
    if visualizeTracerHooked then
        return
    end
    if type(getgc) ~= "function" then
        return
    end

    local ok, gc = pcall(getgc, true)
    if not ok or type(gc) ~= "table" then
        ok, gc = pcall(getgc)
    end
    if not ok or type(gc) ~= "table" then
        return
    end

    for _, obj in ipairs(gc) do
        local visualizeFunc = type(obj) == "table" and rawget(obj, "VisualizeBullet") or nil
        if type(visualizeFunc) == "function" then
            local oldVisualize
            local wrapped = function(...)
                local args = { ... }
                pcall(processShot, args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])
                pcall(processShot, args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9])
                if oldVisualize then
                    return oldVisualize(...)
                end
                return nil
            end
            if type(newcclosure) == "function" then
                wrapped = newcclosure(wrapped)
            end
            if type(hookfunction) == "function" then
                local okHook, original = pcall(hookfunction, visualizeFunc, wrapped)
                if okHook and type(original) == "function" then
                    oldVisualize = original
                    visualizeTracerHooked = true
                    return
                end
            else
                local original = visualizeFunc
                local okAssign = pcall(function()
                    obj.VisualizeBullet = wrapped
                end)
                if okAssign and type(original) == "function" then
                    oldVisualize = original
                    visualizeTracerHooked = true
                    return
                end
            end
        end
    end
end

local function installLocalShootTracerHook()
    if localShootTracerHooked then
        return
    end
    if type(getgc) ~= "function" then
        return
    end

    local ok, gc = pcall(getgc, true)
    if not ok or type(gc) ~= "table" then
        ok, gc = pcall(getgc)
    end
    if not ok or type(gc) ~= "table" then
        return
    end

    local hookedAny = false
    for _, obj in ipairs(gc) do
        local shootFunc = type(obj) == "table" and rawget(obj, "Shoot") or nil
        if type(shootFunc) == "function" then
            local oldShoot = shootFunc
            local wrappedShoot = function(self, ...)
                local args = { ... }
                if Settings.TracersSelf then
                    task.spawn(function()
                        local origin = args[4]
                        local directionArgument = args[5] or args[6]
                        local directionVector = tracerExtractDirection(directionArgument)
                        if typeof(origin) == "Vector3" and typeof(directionVector) == "Vector3" and directionVector.Magnitude > 0.001 then
                            local key = tracerShotKey(LocalPlayer.UserId, "localshoot", origin, directionVector)
                            if not tracerShouldSkipShot(key, 0.012) then
                                local endPosition = tracerComputeEndPos(origin, directionVector, nil)
                                if endPosition then
                                    tracerMakeBeamSegment(origin, endPosition, Settings.TracerSelfColor, 4)
                                end
                            end
                        end
                    end)
                end
                return oldShoot(self, table.unpack(args))
            end
            local assigned = pcall(function()
                obj.Shoot = wrappedShoot
            end)
            if assigned then
                hookedAny = true
            end
        end
    end

    localShootTracerHooked = hookedAny
end

installVisualizeTracerHook()
installLocalShootTracerHook()
task.spawn(function()
    while (not visualizeTracerHooked) and (not tracerUnload) do
        task.wait(1)
        installVisualizeTracerHook()
    end
end)
task.spawn(function()
    while (not localShootTracerHooked) and (not tracerUnload) do
        task.wait(1)
        installLocalShootTracerHook()
    end
end)
task.spawn(function()
    while not tracerUnload do
        if not (Settings.TracersSelf or Settings.TracersOthers) then
            task.wait(0.35)
            continue
        end

        local currentCamera = workspace.CurrentCamera
        if currentCamera and currentCamera ~= Camera then
            tracerSyncToCamera()
            currentCamera = Camera
        end
        local bulletsFolder = currentCamera and currentCamera:FindFirstChild("Bullets")
        if bulletsFolder and bulletsFolder ~= tracerBulletFolder then
            tracerBindBulletFolder(bulletsFolder)
        end
        if bulletsFolder then
            for _, child in ipairs(bulletsFolder:GetChildren()) do
                pcall(tracerAttachTrailToBullet, child)
            end
        end
        task.wait(0.2)
    end
end)

local function raycastProjectile(part)
    if not part or not part.Parent then
        return nil
    end

    local origin = part.Position
    local direction = part.Velocity
    if direction.Magnitude < 1 then
        direction = part.CFrame.LookVector * Settings.InstantRange
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = { part, Camera, LocalPlayer.Character }
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, direction.Unit * Settings.InstantRange, params)
    if result then
        return result.Instance, result.Position, result.Normal
    end

    local fallbackPos = origin + direction.Unit * Settings.InstantRange
    return nil, fallbackPos, -direction.Unit
end

local function prepareInstantProjectile(part, ev, aC)
    if not part or not part.Parent then
        return
    end

    pcall(function()
        part:SetAttribute("RocketDontStop", true)
        part:SetAttribute("UseFullSize", true)

        local hitPart, hitPos, hitNormal = raycastProjectile(part)
        if hitPos then
            local origin = part.Position
            local flyDir = hitPos - origin
            if flyDir.Magnitude > 1 then
                local launchPos = hitPos - flyDir.Unit * 2
                part.CFrame = CFrame.new(launchPos, hitPos)
                part.Velocity = flyDir.Unit * math.max(Settings.InstantVelocity, 300000)
                part.AssemblyLinearVelocity = part.Velocity
            else
                part.CFrame = CFrame.new(hitPos, hitPos + hitNormal)
            end

            if ev and typeof(ev) == "Instance" and ev:IsA("RemoteEvent") then
                pcall(function()
                    ev:FireServer(part, hitPart and hitPart.CFrame or part.CFrame, hitPos, hitNormal, hitPart, nil)
                end)
            end
        else
            local dir = part.Velocity
            if dir.Magnitude < 1 then
                dir = part.CFrame.LookVector
            else
                dir = dir.Unit
            end
            part.Velocity = dir * math.max(Settings.InstantVelocity, 300000)
            part.AssemblyLinearVelocity = part.Velocity
        end
    end)
end

local function hookProjectileHandlersFromConnections()
    if not projectileRemote2 or not projectileRemote2:IsA("RemoteEvent") then
        return
    end

    if type(getconnections) ~= "function" or type(hookfunction) ~= "function" then
        return
    end

    local ok, cons = pcall(getconnections, projectileRemote2.OnClientEvent)
    if not ok or type(cons) ~= "table" then
        return
    end

    for _, connection in ipairs(cons) do
        local okFunc, func = pcall(function()
            return connection.Function
        end)
        if okFunc and type(func) == "function" and not hookedProjectileFunctions[func] then
            local original
            original = hookfunction(func, newcclosure(function(part, ev, aC)
                if Settings.HitmanBriefcaseEnabled and type(hitmanRegisterProjectile) == "function" then
                    pcall(hitmanRegisterProjectile, part, ev)
                end
                if Settings.InstantBullet then
                    prepareInstantProjectile(part, ev, aC)
                end
                return original(part, ev, aC)
            end))
            hookedProjectileFunctions[func] = true
        end
    end
end

local function installProjectileHook()
    if not projectileRemote or not projectileRemote:IsA("RemoteFunction") then
        return
    end

    local ok, currentInvoke = pcall(function()
        return projectileRemote.OnClientInvoke
    end)

    if not ok or type(currentInvoke) ~= "function" then
        return
    end

    if projectileHookInvokeWrapper and currentInvoke == projectileHookInvokeWrapper then
        projectileHookInstalled = true
        return
    end

    projectileHookOriginalInvoke = currentInvoke
    projectileHookInvokeWrapper = function(part, ev, aC)
        if Settings.HitmanBriefcaseEnabled and type(hitmanRegisterProjectile) == "function" then
            pcall(hitmanRegisterProjectile, part, ev)
        end
        if Settings.InstantBullet and part and part.Parent then
            local hitPart, hitPos, hitNormal = raycastProjectile(part)
            if hitPos then
                pcall(function()
                    part.CFrame = CFrame.new(hitPos, hitPos + hitNormal)
                    part.Anchored = true
                end)
                if ev then
                    pcall(function()
                        ev:FireServer(part, hitPart and hitPart.CFrame or part.CFrame, hitPos, hitNormal, hitPart, nil)
                    end)
                end
                return hitPart and hitPart.CFrame or part.CFrame, hitPos, hitNormal, hitPart, nil
            end
        end

        return projectileHookOriginalInvoke(part, ev, aC)
    end
    projectileRemote.OnClientInvoke = projectileHookInvokeWrapper

    projectileHookInstalled = true
end

local function ensureProjectileHookRetryLoop()
    if projectileHookInstalled or projectileHookRetryRunning then
        return
    end

    projectileHookRetryRunning = true
    task.spawn(function()
        while (not projectileHookInstalled) and (not tracerUnload) do
            installProjectileHook()
            task.wait(1)
        end
        projectileHookRetryRunning = false
    end)
end

local function installProjectileSpeedHook()
    if not projectileRemote2 or not projectileRemote2:IsA("RemoteEvent") then
        return
    end

    projectileRemote2.OnClientEvent:Connect(function(part, ev, aC)
        if Settings.HitmanBriefcaseEnabled and type(hitmanRegisterProjectile) == "function" then
            pcall(hitmanRegisterProjectile, part, ev)
        end
        if not Settings.InstantBullet then
            return
        end
        if not part or not part.Parent then
            return
        end

        prepareInstantProjectile(part, ev, aC)
    end)
end

local ProjectileProfiles = {
    ["at4_rocket"] = { life = 60, touchHitDistance = 2.4 },
    ["a_hallows_rocket3"] = { life = 10, touchHitDistance = 2.3 },
    ["fireworklauncher_rocket"] = { life = 10, touchHitDistance = 2.1 },
    ["flare_rocket"] = { life = 120, touchHitDistance = 2.0 },
    ["frostbitemk2_grenade"] = { life = 60, touchHitDistance = 1.9 },
    ["grenadelaunchergrenade"] = { life = 60, touchHitDistance = 2.35 },
    ["grenadelaunchergrenade2"] = { life = 60, touchHitDistance = 2.35 },
    ["grenadelauncher_custom"] = { life = 30, touchHitDistance = 1.95 },
    ["hallows_rocket"] = { life = 10, touchHitDistance = 2.3 },
    ["hallows_rocket2"] = { life = 10, touchHitDistance = 2.3 },
    ["hallows_rocket3"] = { life = 10, touchHitDistance = 2.3 },
    ["rpg_rocket"] = { life = 60, touchHitDistance = 2.4 },
    ["sbl_rocket"] = { life = 10, touchHitDistance = 2.2 },
    ["rpg18"] = { life = 60, touchHitDistance = 2.2 },
    ["_b__rpg_rocket"] = { life = 120, touchHitDistance = 2.4 },
    ["snowball"] = { life = 3, touchHitDistance = 1.35, keepTouch = true },
    ["spitball"] = { life = 3, touchHitDistance = 1.75, keepTouch = true },
}
local trackedProjectiles = {}
local cachedTargetPart
local nextTargetRefreshAt = 0
local lastHeartbeatErrorAt = 0
local hitmanEnemyPlayers = {}
local hitmanPlayerAddedConnection
local hitmanPlayerRemovingConnection
local hitmanDebrisSpitballConnection
local hitmanRaycastParams = RaycastParams.new()
local hitmanRaycastIgnore = table.create(32)
local hitmanOverlapParams = OverlapParams.new()
local hitmanOverlapIgnore = table.create(4)
local MapTuning = {
    ready = false,
    hasTerrainRegions = false,
    mapCount = 0,
}

hitmanRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
hitmanRaycastParams.IgnoreWater = true
hitmanOverlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function rebuildHitmanEnemyPlayers()
    table.clear(hitmanEnemyPlayers)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            hitmanEnemyPlayers[player] = true
        end
    end
end

rebuildHitmanEnemyPlayers()
hitmanPlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        hitmanEnemyPlayers[player] = true
    end
end)
hitmanPlayerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
    hitmanEnemyPlayers[player] = nil
end)

local function isAliveCharacter(character)
    if not character then
        return false
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function hasCharacterForceField(character)
    if not character or not character.Parent then
        return false
    end
    return character:FindFirstChildOfClass("ForceField") ~= nil
end

local function getHeadPart(model)
    if not model or not model:IsA("Model") then
        return nil
    end
    local head = model:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head
    end
    return nil
end

local function hasTeamObjects()
    return Teams:FindFirstChildOfClass("Team") ~= nil
end

local function isTeammate(otherPlayer)
    if not hasTeamObjects() then
        return false
    end

    local myTeam = LocalPlayer.Team
    local otherTeam = otherPlayer and otherPlayer.Team
    if not myTeam or not otherTeam then
        return false
    end

    return myTeam == otherTeam
end

local function isTargetableEnemyCharacter(character, ownerPlayer)
    if not character or not character:IsA("Model") then
        return false
    end
    if character == LocalPlayer.Character then
        return false
    end
    local owner = ownerPlayer or Players:GetPlayerFromCharacter(character)
    if not owner or owner == LocalPlayer or isTeammate(owner) then
        return false
    end
    if hasCharacterForceField(character) then
        return false
    end
    return isAliveCharacter(character)
end

local function bootstrapMapTuning()
    if not Settings.HitmanBriefcaseMapAdaptiveEnabled then
        MapTuning.ready = true
        return
    end

    local terrainCount = 0
    local topLevelMaps = 0
    local topChildren = Workspace:GetChildren()
    for i = 1, #topChildren do
        local item = topChildren[i]
        if item:IsA("Model") or item:IsA("Folder") then
            local n = string.lower(item.Name)
            if n ~= "characters" and n ~= "debris" and n ~= "audio" and n ~= "camera" then
                topLevelMaps = topLevelMaps + 1
            end
        end
    end

    local descendants = Workspace:GetDescendants()
    local scanStep = 220
    for i = 1, #descendants do
        local d = descendants[i]
        if d:IsA("TerrainRegion") then
            terrainCount = terrainCount + 1
        end
        if i % scanStep == 0 then
            task.wait()
        end
    end

    if Workspace:FindFirstChildOfClass("Terrain") then
        terrainCount = math.max(terrainCount, 1)
    end

    MapTuning.mapCount = topLevelMaps
    MapTuning.hasTerrainRegions = terrainCount > 0
    MapTuning.ready = true
end

local function isValidHeadPart(headPart)
    if typeof(headPart) ~= "Instance" or not headPart:IsA("BasePart") then
        return false
    end
    if not headPart.Parent then
        return false
    end
    if headPart.Name ~= "Head" then
        return false
    end

    local character = headPart.Parent
    if not character:IsA("Model") then
        return false
    end

    local ownerPlayer = Players:GetPlayerFromCharacter(character)
    return isTargetableEnemyCharacter(character, ownerPlayer)
end

local function getMousePosition()
    local pos = UserInputService:GetMouseLocation()
    return Vector2.new(pos.X, pos.Y)
end

local function getMouseAimedTargetHead(currentCamera, mousePos)
    if not currentCamera then
        return nil
    end

    local ray = currentCamera:ViewportPointToRay(mousePos.X, mousePos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    local ignore = {}
    if LocalPlayer.Character then
        ignore[#ignore + 1] = LocalPlayer.Character
    end
    ignore[#ignore + 1] = currentCamera
    params.FilterDescendantsInstances = ignore

    local result = Workspace:Raycast(ray.Origin, ray.Direction * 8192, params)
    if not result or not result.Instance then
        return nil
    end

    local character = result.Instance:FindFirstAncestorOfClass("Model")
    if not isTargetableEnemyCharacter(character) then
        return nil
    end

    return getHeadPart(character)
end

local function getNearestPlayerHeadToSelf()
    local myCharacter = LocalPlayer.Character
    if not myCharacter then
        return nil
    end
    local myRoot = myCharacter:FindFirstChild("HumanoidRootPart") or myCharacter:FindFirstChild("Head")
    if not myRoot then
        return nil
    end

    local bestHead
    local bestDist = math.huge
    for player in pairs(hitmanEnemyPlayers) do
        local character = player.Character
        if isTargetableEnemyCharacter(character, player) then
            local head = getHeadPart(character)
            if head then
                local dist = (head.Position - myRoot.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestHead = head
                end
            end
        end
    end

    return bestHead
end

local function getNearestTargetHeadToSelf()
    local myCharacter = LocalPlayer.Character
    if not myCharacter then
        return nil
    end
    local myRoot = myCharacter:FindFirstChild("HumanoidRootPart") or myCharacter:FindFirstChild("Head")
    if not myRoot then
        return nil
    end

    return getNearestPlayerHeadToSelf()
end

local getNearestTargetHeadByRadiusSearch

local function getNearestTargetHeadToPosition(fromPos)
    if typeof(fromPos) ~= "Vector3" then
        return getNearestTargetHeadToSelf()
    end

    local bestHead
    local bestDist = math.huge

    for player in pairs(hitmanEnemyPlayers) do
        local character = player.Character
        if isTargetableEnemyCharacter(character, player) then
            local head = getHeadPart(character)
            if head then
                local dist = (head.Position - fromPos).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestHead = head
                end
            end
        end
    end

    if not bestHead then
        bestHead = getNearestTargetHeadByRadiusSearch(fromPos, 760)
    end

    return bestHead
end

getNearestTargetHeadByRadiusSearch = function(fromPos, radius)
    if typeof(fromPos) ~= "Vector3" then
        return nil
    end

    local baseRadius = math.max(tonumber(radius) or 760, 24)
    local maxRadius = math.max(tonumber(2400) or baseRadius, baseRadius)
    local passes = math.max(1, math.floor(tonumber(3) or 1))
    local maxParts = math.max(80, math.floor(tonumber(700) or 220))

    table.clear(hitmanOverlapIgnore)
    if LocalPlayer.Character then
        hitmanOverlapIgnore[#hitmanOverlapIgnore + 1] = LocalPlayer.Character
    end
    if Camera then
        hitmanOverlapIgnore[#hitmanOverlapIgnore + 1] = Camera
    end
    hitmanOverlapParams.MaxParts = maxParts
    hitmanOverlapParams.FilterDescendantsInstances = hitmanOverlapIgnore

    local bestHead
    local bestDist = math.huge

    for pass = 1, passes do
        local passRadius = baseRadius * (1 + (pass - 1) * 0.9)
        if passRadius > maxRadius then
            passRadius = maxRadius
        end

        local ok, parts = pcall(Workspace.GetPartBoundsInRadius, Workspace, fromPos, passRadius, hitmanOverlapParams)
        if ok and type(parts) == "table" then
            for i = 1, #parts do
                local part = parts[i]
                if typeof(part) == "Instance" and part:IsA("BasePart") and part.Name == "Head" then
                    if isValidHeadPart(part) then
                        local dist = (part.Position - fromPos).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            bestHead = part
                        end
                    end
                end
            end
        end

        if bestHead then
            break
        end
    end

    return bestHead
end

local function scoreHeadOnScreen(headPart, currentCamera, mousePos, bestDistance)
    if not isValidHeadPart(headPart) then
        return nil, bestDistance
    end

    local screenPos, onScreen = currentCamera:WorldToViewportPoint(headPart.Position)
    if not onScreen or screenPos.Z <= 0 then
        return nil, bestDistance
    end

    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
    if dist < bestDistance then
        return headPart, dist
    end

    return nil, bestDistance
end

local function getClosestTargetHeadToMouse()
    local currentCamera = Workspace.CurrentCamera or Camera
    if not currentCamera then
        return nil
    end

    local mousePos = getMousePosition()
    local rayHead = getMouseAimedTargetHead(currentCamera, mousePos)
    if isValidHeadPart(rayHead) then
        return rayHead
    end
    local bestPart
    local bestDistance = math.huge

    for player in pairs(hitmanEnemyPlayers) do
        local character = player.Character
        if isTargetableEnemyCharacter(character, player) then
            local aimPart = getHeadPart(character)
            if aimPart then
                local candidate
                candidate, bestDistance = scoreHeadOnScreen(aimPart, currentCamera, mousePos, bestDistance)
                if candidate then
                    bestPart = candidate
                end
            end
        end
    end

    if bestPart and bestDistance <= 170 then
        return bestPart
    end

    if bestPart and bestDistance <= 520 then
        return bestPart
    end

    return getNearestTargetHeadToSelf()
end

local function normalizeProfileKey(name)
    return string.lower(tostring(name or "")):gsub("%s+", ""):gsub("%-", "_")
end

local function getProjectileProfile(partName, hasImpactRemote)
    local profileKey = normalizeProfileKey(partName)
    local profile = ProjectileProfiles[profileKey]
    local maxLife
    local touchHitDistance
    local keepTouch = false

    if profile then
        maxLife = profile.life
        touchHitDistance = profile.touchHitDistance
        keepTouch = profile.keepTouch == true
    else
        maxLife = 6 + 6
        touchHitDistance = 2.15
    end

    maxLife = math.max(maxLife, 0.05)
    maxLife = math.clamp(maxLife * math.max(1.2, 0.05), 0.05, math.max(180, 0.05))
    touchHitDistance = math.clamp(touchHitDistance, 1, 3.2)

    return maxLife, touchHitDistance, keepTouch
end

local function registerProjectile(part, ev)
    if not Settings.HitmanBriefcaseEnabled then
        return
    end
    if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
        return
    end
    if not part.Parent then
        return
    end

    local state = trackedProjectiles[part]
    if state then
        if typeof(ev) == "Instance" and ev:IsA("RemoteEvent") then
            state.ev = ev
            state.hasImpactRemote = true
            if Settings.HitmanBriefcasePhaseThroughWorld then
                pcall(function()
                    part.CanTouch = false
                    part.CanQuery = false
                end)
            end
        end
        return
    end

    local hasImpactRemote = (typeof(ev) == "Instance" and ev:IsA("RemoteEvent"))
    local profileKey = normalizeProfileKey(part.Name)
    local baseSpeed = math.max(part.AssemblyLinearVelocity.Magnitude, part.Velocity.Magnitude, 320)
    local maxLife, touchHitDistance, keepTouch = getProjectileProfile(part.Name, hasImpactRemote)

    pcall(function()
        part:SetAttribute("RocketDontStop", true)
        part:SetAttribute("UseFullSize", true)
    end)
    if Settings.HitmanBriefcasePhaseThroughWorld then
        pcall(function()
            part.CanCollide = false
            part.CanTouch = keepTouch
            part.CanQuery = not keepTouch
            part.Massless = true
        end)
    end

    local lockTarget = getClosestTargetHeadToMouse()
    if not isValidHeadPart(lockTarget) then
        lockTarget = getNearestTargetHeadToPosition(part.Position)
    end
    if not isValidHeadPart(lockTarget) then
        lockTarget = getNearestTargetHeadByRadiusSearch(part.Position, 760)
    end

    trackedProjectiles[part] = {
        ev = hasImpactRemote and ev or nil,
        hasImpactRemote = hasImpactRemote,
        startTick = os.clock(),
        lastImpactSend = 0,
        impactAttempts = 0,
        baseSpeed = baseSpeed,
        maxLife = maxLife,
        baseMaxLife = maxLife,
        lifeExtended = 0,
        touchHitDistance = touchHitDistance,
        hitSent = false,
        profileKey = profileKey,
        pathWaypoints = nil,
        pathIndex = 1,
        nextPathCalcAt = 0,
        nextBypassAt = 0,
        nextHeavySolveAt = 0,
        nextHardFallbackAt = 0,
        nextFarFallbackAt = 0,
        nextNoTargetRetryAt = 0,
        nextPreemptiveCheckAt = 0,
        nextStuckCheckAt = 0,
        nextAdaptiveScanAt = 0,
        localClutterScore = 0,
        localTerrainBias = MapTuning.hasTerrainRegions,
        dynamicPathDelay = 0.1,
        dynamicHopBonus = 0,
        dynamicBeamBonus = 0,
        dynamicBranchBonus = 0,
        lastDistanceToTarget = nil,
        stuckCount = 0,
        targetPart = lockTarget,
        pathBusy = false,
    }
    hitmanTrackedProjectileCount = hitmanTrackedProjectileCount + 1

    cachedTargetPart = isValidHeadPart(lockTarget) and lockTarget or getClosestTargetHeadToMouse()
    nextTargetRefreshAt = 0
end

local function cleanupProjectile(part)
    if trackedProjectiles[part] ~= nil then
        trackedProjectiles[part] = nil
        hitmanTrackedProjectileCount = math.max(0, hitmanTrackedProjectileCount - 1)
    end
end

local function clearTrackedProjectiles()
    table.clear(trackedProjectiles)
    hitmanTrackedProjectileCount = 0
    cachedTargetPart = nil
    nextTargetRefreshAt = 0
end

hitmanRegisterProjectile = registerProjectile
hitmanClearProjectiles = clearTrackedProjectiles

local function hookHitmanSpitballDebris()
    if hitmanDebrisSpitballConnection then
        return
    end

    local debrisFolder = Workspace:FindFirstChild("Debris")
    if not debrisFolder then
        return
    end

    hitmanDebrisSpitballConnection = debrisFolder.ChildAdded:Connect(function(child)
        if not Settings.HitmanBriefcaseEnabled then
            return
        end
        if typeof(child) ~= "Instance" or not child:IsA("BasePart") then
            return
        end
        if string.lower(child.Name) ~= "spitball" then
            return
        end
        registerProjectile(child, nil)
    end)

    for _, child in ipairs(debrisFolder:GetChildren()) do
        if typeof(child) == "Instance" and child:IsA("BasePart") and string.lower(child.Name) == "spitball" then
            registerProjectile(child, nil)
        end
    end
end

local function applyFinalSnap(projectilePart, targetPart)
    local toTarget = targetPart.Position - projectilePart.Position
    local distance = toTarget.Magnitude
    if distance > 18 or distance <= 0.001 then
        return
    end

    local dir = toTarget.Unit
    local currentSpeed = math.max(projectilePart.AssemblyLinearVelocity.Magnitude, projectilePart.Velocity.Magnitude, 320)
    local boostedSpeed = currentSpeed * (distance <= 6 and 1.6 or 1.3)
    local newVelocity = dir * boostedSpeed
    local snapOffset = distance <= 4 and 0.06 or (distance <= 10 and 0.2 or 0.6)

    projectilePart.AssemblyLinearVelocity = newVelocity
    projectilePart.Velocity = newVelocity
    projectilePart.CFrame = CFrame.new(targetPart.Position - dir * snapOffset, targetPart.Position + dir)
end

local function getPredictedPosition(projectilePart, targetPart)
    local projectilePos = projectilePart.Position
    local targetPos = targetPart.Position
    local toTarget = targetPos - projectilePos

    if toTarget.Magnitude <= 0.001 then
        return targetPos
    end

    local projectileVelocity = projectilePart.AssemblyLinearVelocity
    if projectileVelocity.Magnitude < 1 then
        projectileVelocity = projectilePart.Velocity
    end
    local speed = math.max(projectileVelocity.Magnitude, 320)
    local travelTime = (toTarget.Magnitude / speed) + 0.08
    local targetVelocity = targetPart.AssemblyLinearVelocity

    return targetPos + targetVelocity * travelTime
end

local function isTinyObstacle(part)
    if not Settings.HitmanBriefcaseIgnoreTinyObstacleEnabled then
        return false
    end
    if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
        return false
    end
    local myChar = LocalPlayer.Character
    if myChar and part:IsDescendantOf(myChar) then
        return false
    end
    local size = part.Size
    local maxAxis = math.max(size.X, size.Y, size.Z)
    if maxAxis > 1.15 then
        return false
    end
    local volume = size.X * size.Y * size.Z
    return volume <= 1.2
end

local function shouldIgnoreRayHit(part, ignoredTinyCount)
    if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
        return false
    end
    if isTinyObstacle(part) then
        local tinyCount = ignoredTinyCount or 0
        return tinyCount < 6
    end
    return not part.CanCollide
end

local function getBlockRayResultFrom(originPos, goalPos, projectilePart, targetPart, maxIgnoreOverride)
    local maxIgnoreHits = maxIgnoreOverride
    if type(maxIgnoreHits) ~= "number" then
        maxIgnoreHits = 12
    end
    maxIgnoreHits = math.max(1, math.floor(maxIgnoreHits or 1))
    local castOrigin = originPos
    local castDir = goalPos - castOrigin
    if castDir.Magnitude <= 0.001 then
        return nil
    end

    table.clear(hitmanRaycastIgnore)
    hitmanRaycastIgnore[1] = projectilePart
    if LocalPlayer.Character then
        hitmanRaycastIgnore[#hitmanRaycastIgnore + 1] = LocalPlayer.Character
    end
    if Camera then
        hitmanRaycastIgnore[#hitmanRaycastIgnore + 1] = Camera
    end
    if targetPart then
        hitmanRaycastIgnore[#hitmanRaycastIgnore + 1] = targetPart
        if targetPart.Parent then
            hitmanRaycastIgnore[#hitmanRaycastIgnore + 1] = targetPart.Parent
        end
    end
    hitmanRaycastParams.FilterDescendantsInstances = hitmanRaycastIgnore

    local ignoredTinyCount = 0
    for _ = 1, maxIgnoreHits do
        local result = Workspace:Raycast(castOrigin, castDir, hitmanRaycastParams)
        if not result then
            return nil
        end

        local hitPart = result.Instance
        local ignoreThisHit = shouldIgnoreRayHit(hitPart, ignoredTinyCount)
        if not ignoreThisHit then
            return result
        end
        if isTinyObstacle(hitPart) then
            ignoredTinyCount = ignoredTinyCount + 1
        end

        hitmanRaycastIgnore[#hitmanRaycastIgnore + 1] = hitPart
        hitmanRaycastParams.FilterDescendantsInstances = hitmanRaycastIgnore

        local dirMag = castDir.Magnitude
        if dirMag <= 0.001 then
            return nil
        end

        castOrigin = result.Position + castDir.Unit * 0.08
        castDir = goalPos - castOrigin
        if castDir.Magnitude <= 0.001 then
            return nil
        end
    end

    return Workspace:Raycast(castOrigin, castDir, hitmanRaycastParams)
end

local function getBlockRayResult(projectilePart, targetPart, goalPos)
    return getBlockRayResultFrom(projectilePart.Position, goalPos, projectilePart, targetPart)
end

local function isTerrainRayHit(result)
    return result and result.Instance and result.Instance:IsA("Terrain")
end

local function refreshAdaptiveObstacleState(state, projectilePart, targetPart, goalPos, now)
    if not Settings.HitmanBriefcaseClutterAdaptiveEnabled then
        state.localClutterScore = 0
        state.localTerrainBias = false
        state.dynamicPathDelay = 0.1
        state.dynamicHopBonus = 0
        state.dynamicBeamBonus = 0
        state.dynamicBranchBonus = 0
        return
    end
    if now < (state.nextAdaptiveScanAt or 0) then
        return
    end

    state.nextAdaptiveScanAt = now + 0.18
    local origin = projectilePart.Position
    local toGoal = goalPos - origin
    if toGoal.Magnitude <= 0.001 then
        return
    end

    local forward = toGoal.Unit
    local up = Vector3.new(0, 1, 0)
    local right = forward:Cross(up)
    if right.Magnitude <= 0.001 then
        right = projectilePart.CFrame.RightVector
    else
        right = right.Unit
    end

    local distance = math.max(42, math.min(toGoal.Magnitude, 67.2))
    local hits = 0
    local terrainHits = 0
    local probeGoal = origin + forward * distance
    local hit = getBlockRayResultFrom(origin, probeGoal, projectilePart, targetPart, 2)
    if hit then
        hits = hits + 1
        if isTerrainRayHit(hit) then
            terrainHits = terrainHits + 1
        end
    end
    probeGoal = origin + (forward + right * 0.55).Unit * distance
    hit = getBlockRayResultFrom(origin, probeGoal, projectilePart, targetPart, 2)
    if hit then
        hits = hits + 1
        if isTerrainRayHit(hit) then
            terrainHits = terrainHits + 1
        end
    end
    probeGoal = origin + (forward - right * 0.55).Unit * distance
    hit = getBlockRayResultFrom(origin, probeGoal, projectilePart, targetPart, 2)
    if hit then
        hits = hits + 1
        if isTerrainRayHit(hit) then
            terrainHits = terrainHits + 1
        end
    end
    probeGoal = origin + (forward + up * 0.48).Unit * distance
    hit = getBlockRayResultFrom(origin, probeGoal, projectilePart, targetPart, 2)
    if hit then
        hits = hits + 1
        if isTerrainRayHit(hit) then
            terrainHits = terrainHits + 1
        end
    end
    probeGoal = origin + (forward - up * 0.42).Unit * distance
    hit = getBlockRayResultFrom(origin, probeGoal, projectilePart, targetPart, 2)
    if hit then
        hits = hits + 1
        if isTerrainRayHit(hit) then
            terrainHits = terrainHits + 1
        end
    end
    probeGoal = origin + (forward + right * 0.35 + up * 0.25).Unit * distance
    hit = getBlockRayResultFrom(origin, probeGoal, projectilePart, targetPart, 2)
    if hit then
        hits = hits + 1
        if isTerrainRayHit(hit) then
            terrainHits = terrainHits + 1
        end
    end
    probeGoal = origin + (forward - right * 0.35 + up * 0.25).Unit * distance
    hit = getBlockRayResultFrom(origin, probeGoal, projectilePart, targetPart, 2)
    if hit then
        hits = hits + 1
        if isTerrainRayHit(hit) then
            terrainHits = terrainHits + 1
        end
    end
    probeGoal = origin + (forward + right * 0.35 - up * 0.2).Unit * distance
    hit = getBlockRayResultFrom(origin, probeGoal, projectilePart, targetPart, 2)
    if hit then
        hits = hits + 1
        if isTerrainRayHit(hit) then
            terrainHits = terrainHits + 1
        end
    end
    probeGoal = origin + (forward - right * 0.35 - up * 0.2).Unit * distance
    hit = getBlockRayResultFrom(origin, probeGoal, projectilePart, targetPart, 2)
    if hit then
        hits = hits + 1
        if isTerrainRayHit(hit) then
            terrainHits = terrainHits + 1
        end
    end

    local score = hits / 9
    state.localClutterScore = score
    state.localTerrainBias = (terrainHits > 0) or (Settings.HitmanBriefcaseTerrainAdaptiveEnabled and MapTuning.hasTerrainRegions)

    local high = score >= 0.58
    local delay = 0.1
    if high then
        delay = math.max(0.045, delay * 0.52)
    elseif score >= (0.58 * 0.7) then
        delay = math.max(0.045, delay * 0.72)
    end
    state.dynamicPathDelay = delay

    local hopBonus = 0
    local beamBonus = 0
    local branchBonus = 0
    if high then
        hopBonus = 2
        beamBonus = 1
        branchBonus = 1
        if score >= 0.75 then
            hopBonus = 3
            beamBonus = 2
            branchBonus = 2
        end
        if state.localTerrainBias then
            hopBonus = hopBonus + 1
        end
    elseif state.localTerrainBias then
        hopBonus = 1
    end

    state.dynamicHopBonus = math.clamp(hopBonus, 0, 4)
    state.dynamicBeamBonus = math.clamp(beamBonus, 0, 2)
    state.dynamicBranchBonus = math.clamp(branchBonus, 0, 2)
end

local function getPathingParams(state, projectilePart)
    local cached = state.pathingParams
    if cached then
        return cached
    end

    local size = projectilePart.Size
    local minAxis = math.min(size.X, size.Y, size.Z)
    local maxAxis = math.max(size.X, size.Y, size.Z)

    local radius = math.clamp(minAxis * 0.55, 0.08, 0.9)
    local height = math.clamp(maxAxis * 0.65, 0.2, 2.2)
    local spacing = math.clamp(maxAxis * 1.5, 2, 8)

    cached = {
        radius = radius,
        height = height,
        spacing = spacing,
    }
    state.pathingParams = cached
    return cached
end

local function buildDetourCandidatesFromOrigin(state, origin, projectilePart, targetPart, hitResult, goalPos, hopIndex, allowYield)
    local pathing = getPathingParams(state, projectilePart)
    local toGoal = goalPos - origin
    if toGoal.Magnitude <= 0.001 then
        return {}
    end

    local forward = toGoal.Unit
    local up = Vector3.new(0, 1, 0)
    local right = forward:Cross(up)
    if right.Magnitude <= 0.001 then
        right = projectilePart.CFrame.RightVector
    else
        right = right.Unit
    end

    local hop = math.max(tonumber(hopIndex) or 1, 1)
    local hopMul = 1 + (hop - 1) * 0.65
    local clutterScore = math.clamp(state.localClutterScore or 0, 0, 1)
    local clutterMul = 1 + clutterScore * 0.35
    local terrainLiftMul = 1
    local terrainSideMul = 1
    if Settings.HitmanBriefcaseTerrainAdaptiveEnabled and (isTerrainRayHit(hitResult) or state.localTerrainBias) then
        terrainLiftMul = math.max(1.45, 1)
        terrainSideMul = math.max(1.3, 1)
    end

    local sidePush = hitResult.Normal * ((2.2 + pathing.radius) * hopMul)
    local base = hitResult.Position + sidePush
    local dist = math.max(14, pathing.spacing * 1.25) * hopMul * math.max(1, clutterMul * 0.9)
    local lift = math.max(7, 4, 2 + pathing.height) * (1 + (hop - 1) * 0.3) * terrainLiftMul * clutterMul
    local lowLift = math.max(1.2, lift * 0.45)
    local side = math.max(12, dist) * terrainSideMul

    local candidates = {}
    local sideFactors = (hop <= 2)
        and { 1, -1, 1.6, -1.6, 2.25, -2.25 }
        or { 1, -1, 1.6, -1.6, 2.25, -2.25, 3, -3 }
    local upFactors = (hop <= 3)
        and { 0.45, 0.9, 1.35, -0.35 }
        or { 0.45, 0.9, 1.35, -0.35, 1.9 }
    for i = 1, #sideFactors do
        local sf = sideFactors[i]
        for j = 1, #upFactors do
            local uf = upFactors[j]
            candidates[#candidates + 1] = base
                + right * (side * sf)
                + up * (lift * uf)
                + forward * (dist * 0.25 * math.abs(sf))
        end
    end

    candidates[#candidates + 1] = base + up * (lift * 2.3)
    candidates[#candidates + 1] = base - up * (lowLift * 1.2)
    candidates[#candidates + 1] = base + forward * (dist * 1.35) + up * (lift * 0.7)
    candidates[#candidates + 1] = origin + right * (side * 0.85) + up * (lift * 1.2)
    candidates[#candidates + 1] = origin - right * (side * 0.85) + up * (lift * 1.2)
    candidates[#candidates + 1] = origin + forward * (dist * 0.7) + up * (lift * 0.8)
    candidates[#candidates + 1] = origin - forward * (dist * 0.7) + up * (lift * 0.9)
    candidates[#candidates + 1] = origin - forward * (dist * 1.2) + up * (lift * 1.3)
    candidates[#candidates + 1] = origin + forward * (dist * 1.1) + up * (lift * 1.15)
    candidates[#candidates + 1] = base + right * (side * 3.8) + up * (lift * 0.95)
    candidates[#candidates + 1] = base - right * (side * 3.8) + up * (lift * 0.95)
    if terrainLiftMul > 1 then
        candidates[#candidates + 1] = base + up * (lift * 2.9)
        candidates[#candidates + 1] = origin + up * (lift * 1.8) + right * (side * 1.2)
        candidates[#candidates + 1] = origin + up * (lift * 1.8) - right * (side * 1.2)
    end

    local infos = {}
    for i = 1, #candidates do
        local candidate = candidates[i]
        if (candidate - origin).Magnitude > 1 then
            local toCandidate = candidate - origin
            local forwardDot = toCandidate.Unit:Dot(forward)
            if not (forwardDot < -0.97 and hop <= 3) then
                local leg1 = getBlockRayResultFrom(origin, candidate, projectilePart, targetPart, 6)
                local blockedCount = (leg1 and 1 or 0)
                local leg2 = nil
                if not leg1 then
                    leg2 = getBlockRayResultFrom(candidate, goalPos, projectilePart, targetPart, 6)
                    blockedCount = blockedCount + (leg2 and 1 or 0)
                else
                    blockedCount = blockedCount + 1
                end
                local isClear = blockedCount == 0

                local score = blockedCount * 100000
                    + (candidate - goalPos).Magnitude
                    + (candidate - origin).Magnitude * 0.12
                if forwardDot < -0.85 then
                    score = score + 220000
                elseif forwardDot < -0.35 then
                    score = score + math.abs(forwardDot) * 60000
                elseif forwardDot < 0 then
                    score = score + math.abs(forwardDot) * 15000
                end

                infos[#infos + 1] = {
                    pos = candidate,
                    score = score,
                    isClear = isClear,
                    blockedCount = blockedCount,
                }
            end
        end

        if allowYield and (i % 10 == 0) then
            task.wait()
        end
    end

    table.sort(infos, function(a, b)
        return a.score < b.score
    end)

    return infos
end

local function chooseDetourWaypointFromOrigin(state, origin, projectilePart, targetPart, hitResult, goalPos, requireClear, hopIndex)
    local infos = buildDetourCandidatesFromOrigin(state, origin, projectilePart, targetPart, hitResult, goalPos, hopIndex, false)
    for i = 1, #infos do
        local info = infos[i]
        if (not requireClear) or info.isClear then
            return info.pos, info.isClear
        end
    end
    return nil, false
end

local function chooseDetourWaypoint(state, projectilePart, targetPart, hitResult, goalPos, requireClear)
    return chooseDetourWaypointFromOrigin(state, projectilePart.Position, projectilePart, targetPart, hitResult, goalPos, requireClear, 1)
end

local tryEmergencyBypass

local function tryBuildAirDetour(state, projectilePart, targetPart, hitResult, goalPos)
    if not Settings.HitmanBriefcaseAirDetourEnabled or not hitResult then
        return false
    end

    local pathing = getPathingParams(state, projectilePart)
    local liftBoost = 1
    if Settings.HitmanBriefcaseTerrainAdaptiveEnabled and (isTerrainRayHit(hitResult) or state.localTerrainBias) then
        liftBoost = math.max(1.45, 1)
    end
    local detourPos = hitResult.Position
        + hitResult.Normal * (2.2 + pathing.radius)
        + Vector3.new(0, (7 + pathing.height) * liftBoost, 0)

    local leg1Blocked = getBlockRayResultFrom(projectilePart.Position, detourPos, projectilePart, targetPart)
    local leg2Blocked = getBlockRayResultFrom(detourPos, goalPos, projectilePart, targetPart)
    if leg1Blocked or leg2Blocked then
        return false
    end

    state.pathWaypoints = { detourPos }
    state.pathIndex = 1
    return true
end

local function tryBuildQuickDetour(state, projectilePart, targetPart, hitResult, goalPos)
    if not Settings.HitmanBriefcaseQuickDetourEnabled or not hitResult then
        return false
    end

    local waypoint, isClear = chooseDetourWaypoint(state, projectilePart, targetPart, hitResult, goalPos, true)
    if waypoint and isClear then
        state.pathWaypoints = { waypoint }
        state.pathIndex = 1
        return true
    end
    return false
end

local function buildAdaptiveDetourWaypoints(state, projectilePart, targetPart, goalPos, allowYield)
    local hopBonus = math.floor(state.dynamicHopBonus or 0)
    local beamBonus = math.floor(state.dynamicBeamBonus or 0)
    local branchBonus = math.floor(state.dynamicBranchBonus or 0)
    local maxHops = math.max(1, math.floor(12 + hopBonus))
    local beamWidth = math.max(1, math.floor(7 + beamBonus))
    local branchPerNode = math.max(1, math.floor(4 + branchBonus))

    local function clonePath(path, nextPoint)
        local out = table.create(#path + 1)
        for i = 1, #path do
            out[i] = path[i]
        end
        out[#path + 1] = nextPoint
        return out
    end

    local beams = {
        {
            pos = projectilePart.Position,
            path = {},
            score = 0,
        },
    }

    local bestPartial

    for hop = 1, maxHops do
        local nextBeams = {}

        for i = 1, #beams do
            local beam = beams[i]
            local directHit = getBlockRayResultFrom(beam.pos, goalPos, projectilePart, targetPart)
            if not directHit then
                return beam.path, true
            end

            local infos = buildDetourCandidatesFromOrigin(state, beam.pos, projectilePart, targetPart, directHit, goalPos, hop, allowYield)
            local added = 0
            for j = 1, #infos do
                if added >= branchPerNode then
                    break
                end

                local info = infos[j]
                local nextPath = clonePath(beam.path, info.pos)
                nextBeams[#nextBeams + 1] = {
                    pos = info.pos,
                    path = nextPath,
                    score = beam.score + info.score + (#nextPath * 95),
                }
                added = added + 1
            end
        end

        if #nextBeams == 0 then
            break
        end

        table.sort(nextBeams, function(a, b)
            return a.score < b.score
        end)

        beams = {}
        local keep = math.min(#nextBeams, beamWidth)
        for i = 1, keep do
            beams[i] = nextBeams[i]
        end

        bestPartial = beams[1]

        if allowYield then
            task.wait()
        end
    end

    if bestPartial and #bestPartial.path > 0 then
        return bestPartial.path, false
    end
    return nil, false
end

local function startAsyncAdaptiveSolve(state, projectilePart, targetPart, fallbackGoal, now, hitResult)
    if state.pathBusy then
        return
    end

    state.pathBusy = true
    state.nextHeavySolveAt = now + 0.22

    task.spawn(function()
        local waypoints, clearDirect = buildAdaptiveDetourWaypoints(state, projectilePart, targetPart, fallbackGoal, true)

        if trackedProjectiles[projectilePart] ~= state then
            return
        end

        state.pathBusy = false
        if type(waypoints) == "table" and #waypoints > 0 then
            state.pathWaypoints = waypoints
            state.pathIndex = 1
            return
        end

        if clearDirect then
            state.pathWaypoints = nil
            state.pathIndex = 1
            return
        end

        if not tryEmergencyBypass(state, projectilePart, targetPart, fallbackGoal, os.clock(), hitResult) then
            state.pathWaypoints = nil
            state.pathIndex = 1
        end
    end)
end

tryEmergencyBypass = function(state, projectilePart, targetPart, goalPos, now, hitOverride)
    if not Settings.HitmanBriefcaseEmergencyWallBypass then
        return false
    end

    local tNow = now or os.clock()
    if tNow < (state.nextBypassAt or 0) then
        return false
    end

    local hitResult = hitOverride
    if not hitResult then
        local currentVelocity = projectilePart.AssemblyLinearVelocity
        if currentVelocity.Magnitude < 1 then
            currentVelocity = projectilePart.Velocity
        end

        local probeDirection
        if currentVelocity.Magnitude > 1 then
            probeDirection = currentVelocity.Unit
        else
            local toGoal = goalPos - projectilePart.Position
            if toGoal.Magnitude <= 0.001 then
                return false
            end
            probeDirection = toGoal.Unit
        end

        local speed = math.max(currentVelocity.Magnitude, 320)
        local probeDistance = math.max(9, speed * 0.08, 6)
        probeDistance = math.min(probeDistance, 30)
        local probeGoal = projectilePart.Position + probeDirection * probeDistance
        hitResult = getBlockRayResultFrom(projectilePart.Position, probeGoal, projectilePart, targetPart)
    end

    if not hitResult then
        return false
    end

    local waypoint = chooseDetourWaypoint(state, projectilePart, targetPart, hitResult, goalPos, false)
    if waypoint then
        state.pathWaypoints = { waypoint }
        state.pathIndex = 1
        state.nextBypassAt = tNow + 0.06
        return true
    end

    return false
end

local function getProjectileVelocity(projectilePart)
    local v = projectilePart.AssemblyLinearVelocity
    if v.Magnitude < 1 then
        v = projectilePart.Velocity
    end
    return v
end

local function tryPreemptiveAvoidance(state, projectilePart, targetPart, goalPos, now)
    if not Settings.HitmanBriefcasePreemptiveAvoidanceEnabled then
        return false
    end
    if now < (state.nextPreemptiveCheckAt or 0) then
        return false
    end
    state.nextPreemptiveCheckAt = now + 0.03

    local currentVelocity = getProjectileVelocity(projectilePart)
    local direction
    if currentVelocity.Magnitude > 1 then
        direction = currentVelocity.Unit
    else
        local toGoal = goalPos - projectilePart.Position
        if toGoal.Magnitude <= 0.001 then
            return false
        end
        direction = toGoal.Unit
    end

    local speed = math.max(currentVelocity.Magnitude, state.baseSpeed or 0, 320)
    local probeDistance = math.clamp(
        speed * 0.12,
        6,
        28
    )
    local probeGoal = projectilePart.Position + direction * probeDistance
    local hit = getBlockRayResultFrom(projectilePart.Position, probeGoal, projectilePart, targetPart, 2)
    if not hit then
        return false
    end

    local pathing = getPathingParams(state, projectilePart)
    local detour = hit.Position
        + hit.Normal * (8 + pathing.radius)
        + Vector3.new(0, 3.1 + pathing.height * 0.8, 0)
    local leg1 = getBlockRayResultFrom(projectilePart.Position, detour, projectilePart, targetPart, 2)
    local leg2 = getBlockRayResultFrom(detour, goalPos, projectilePart, targetPart, 2)
    if leg1 or leg2 then
        local side = direction:Cross(Vector3.new(0, 1, 0))
        if side.Magnitude > 0.001 then
            side = side.Unit
            local alt = detour + side * (8 * 1.3)
            local l1 = getBlockRayResultFrom(projectilePart.Position, alt, projectilePart, targetPart, 2)
            local l2 = getBlockRayResultFrom(alt, goalPos, projectilePart, targetPart, 2)
            if not l1 and not l2 then
                detour = alt
            else
                alt = detour - side * (8 * 1.3)
                l1 = getBlockRayResultFrom(projectilePart.Position, alt, projectilePart, targetPart, 2)
                l2 = getBlockRayResultFrom(alt, goalPos, projectilePart, targetPart, 2)
                if not l1 and not l2 then
                    detour = alt
                else
                    return false
                end
            end
        else
            return false
        end
    end

    state.pathWaypoints = { detour }
    state.pathIndex = 1
    state.nextPathCalcAt = now + 0.035
    return true
end

local function shouldRescueSteer(projectilePart, targetPart)
    if not Settings.HitmanBriefcaseRescueSteeringEnabled then
        return false, false
    end
    local toTarget = targetPart.Position - projectilePart.Position
    if toTarget.Magnitude <= 0.001 then
        return false, false
    end
    local v = getProjectileVelocity(projectilePart)
    if v.Magnitude <= 1 then
        return false, false
    end
    local dot = v.Unit:Dot(toTarget.Unit)
    if dot < -0.5 then
        return true, true
    end
    if dot < -0.12 then
        return true, false
    end
    return false, false
end

local function forceAcquireTargetForProjectile(state, projectilePart, now)
    if now < (state.nextNoTargetRetryAt or 0) and isValidHeadPart(state.targetPart) then
        return state.targetPart
    end

    state.nextNoTargetRetryAt = now + math.max(0.045, 0.01)

    local target = state.targetPart
    if isValidHeadPart(target) then
        return target
    end

    target = getNearestTargetHeadToPosition(projectilePart.Position)
    if not isValidHeadPart(target) then
        target = getNearestTargetHeadByRadiusSearch(projectilePart.Position, 760)
    end
    if not isValidHeadPart(target) then
        target = cachedTargetPart
    end
    if not isValidHeadPart(target) then
        target = getClosestTargetHeadToMouse()
    end

    state.targetPart = target
    return target
end

local function tryStuckRecovery(state, projectilePart, targetPart, goalPos, now)
    if not isValidHeadPart(targetPart) then
        return false
    end
    if now < (state.nextStuckCheckAt or 0) then
        return false
    end
    state.nextStuckCheckAt = now + math.max(0.055, 0.02)

    local currentDistance = (projectilePart.Position - targetPart.Position).Magnitude
    local lastDistance = state.lastDistanceToTarget
    state.lastDistanceToTarget = currentDistance
    if type(lastDistance) ~= "number" then
        state.stuckCount = 0
        return false
    end

    local progress = lastDistance - currentDistance
    if progress > math.max(0.7, 0.05) then
        state.stuckCount = math.max((state.stuckCount or 0) - 1, 0)
        return false
    end

    local currentVelocity = getProjectileVelocity(projectilePart)
    local probeDirection
    if currentVelocity.Magnitude > 1 then
        probeDirection = currentVelocity.Unit
    else
        local toGoal = goalPos - projectilePart.Position
        if toGoal.Magnitude <= 0.001 then
            return false
        end
        probeDirection = toGoal.Unit
    end

    local probeDistance = math.clamp(
        math.max(currentVelocity.Magnitude * 0.11, 6),
        6,
        math.max(28 * 1.4, 6 + 1)
    )
    local probeGoal = projectilePart.Position + probeDirection * probeDistance
    local aheadHit = getBlockRayResultFrom(projectilePart.Position, probeGoal, projectilePart, targetPart, 2)

    if aheadHit then
        state.stuckCount = (state.stuckCount or 0) + 1
    else
        state.stuckCount = math.max((state.stuckCount or 0) - 1, 0)
        return false
    end

    if (state.stuckCount or 0) < math.max(1, math.floor(3)) then
        return false
    end

    state.stuckCount = 0
    local pathing = getPathingParams(state, projectilePart)
    local up = Vector3.new(0, 1, 0)
    local right = probeDirection:Cross(up)
    if right.Magnitude <= 0.001 then
        right = projectilePart.CFrame.RightVector
    else
        right = right.Unit
    end

    local sideDistance = math.max(16, 8 * 1.8, pathing.spacing * 1.1)
    local lift = math.max(5.5, 3.1 * 1.2, pathing.height * 2)
    local base = aheadHit.Position + aheadHit.Normal * (8 + pathing.radius * 1.4)
    local candidates = {
        base + up * lift + right * sideDistance,
        base + up * lift - right * sideDistance,
        base + up * (lift * 1.45),
        projectilePart.Position + up * (lift * 1.15) + right * (sideDistance * 0.7),
        projectilePart.Position + up * (lift * 1.15) - right * (sideDistance * 0.7),
    }

    for i = 1, #candidates do
        local candidate = candidates[i]
        local leg1 = getBlockRayResultFrom(projectilePart.Position, candidate, projectilePart, targetPart, 2)
        local leg2 = getBlockRayResultFrom(candidate, goalPos, projectilePart, targetPart, 2)
        if not leg1 and not leg2 then
            state.pathWaypoints = { candidate }
            state.pathIndex = 1
            state.nextPathCalcAt = now + 0.02
            state.nextHeavySolveAt = 0
            return true
        end
    end

    return false
end

local function requestProjectilePath(state, projectilePart, targetPart, fallbackGoal, now)
    if not Settings.HitmanBriefcaseObstaclePathing then
        state.pathWaypoints = nil
        state.pathIndex = 1
        return
    end
    refreshAdaptiveObstacleState(state, projectilePart, targetPart, fallbackGoal, now)
    if now < (state.nextPathCalcAt or 0) then
        return
    end

    local hit = getBlockRayResult(projectilePart, targetPart, fallbackGoal)
    state.nextPathCalcAt = now + (state.dynamicPathDelay or 0.1)
    if not hit then
        state.pathWaypoints = nil
        state.pathIndex = 1
        return
    end

    local waypoints = state.pathWaypoints
    if type(waypoints) == "table" and #waypoints > 0 then
        local activeWp = waypoints[state.pathIndex or 1]
        if typeof(activeWp) == "Vector3" then
            local wpBlocked = getBlockRayResultFrom(projectilePart.Position, activeWp, projectilePart, targetPart)
            if not wpBlocked then
                return
            end
        end
    end

    if tryBuildQuickDetour(state, projectilePart, targetPart, hit, fallbackGoal) then
        return
    end

    if tryBuildAirDetour(state, projectilePart, targetPart, hit, fallbackGoal) then
        return
    end

    if state.pathBusy then
        if type(state.pathWaypoints) ~= "table" or #state.pathWaypoints == 0 then
            tryEmergencyBypass(state, projectilePart, targetPart, fallbackGoal, now, hit)
        end
        return
    end

    if now < (state.nextHeavySolveAt or 0) then
        if type(state.pathWaypoints) ~= "table" or #state.pathWaypoints == 0 then
            tryEmergencyBypass(state, projectilePart, targetPart, fallbackGoal, now, hit)
        end
        return
    end

    startAsyncAdaptiveSolve(state, projectilePart, targetPart, fallbackGoal, now, hit)
end

local function resolvePathGoal(state, projectilePart, fallbackGoal)
    local waypoints = state.pathWaypoints
    if type(waypoints) ~= "table" or #waypoints == 0 then
        return fallbackGoal
    end

    local index = state.pathIndex or 1
    if index < 1 then
        index = 1
    end
    local waypointReach = 7
    local pathing = getPathingParams(state, projectilePart)
    if pathing then
        waypointReach = math.clamp(
            pathing.spacing * 0.72,
            1.6,
            5.4
        )
    end

    while index <= #waypoints do
        local wp = waypoints[index]
        local toWp = wp - projectilePart.Position
        local toGoal = fallbackGoal - projectilePart.Position
        local wpHasDir = toWp.Magnitude > 0.001
        local goalHasDir = toGoal.Magnitude > 0.001
        local dot = 1
        if wpHasDir and goalHasDir then
            dot = toWp.Unit:Dot(toGoal.Unit)
        end

        if toWp.Magnitude <= waypointReach or dot < -0.82 then
            index = index + 1
        else
            break
        end
    end

    state.pathIndex = index
    if index > #waypoints then
        state.pathWaypoints = nil
        state.pathIndex = 1
        return fallbackGoal
    end

    return waypoints[index]
end

local function steerProjectile(projectilePart, state, goalPos, dt, speedScale)
    local direction = goalPos - projectilePart.Position
    if direction.Magnitude <= 0.001 then
        return
    end

    local currentVelocity = projectilePart.AssemblyLinearVelocity
    if currentVelocity.Magnitude < 1 then
        currentVelocity = projectilePart.Velocity
    end
    local desiredDirection = direction.Unit
    local baseSpeed = (state and state.baseSpeed) or 320
    local boostedBaseSpeed = baseSpeed * 1.2
    local scale = math.max(speedScale or 1, 1)
    local speed = math.max(currentVelocity.Magnitude, boostedBaseSpeed, 320) * scale
    local newVelocity = desiredDirection * speed

    projectilePart.AssemblyLinearVelocity = newVelocity
    projectilePart.Velocity = newVelocity
    projectilePart.CFrame = CFrame.new(projectilePart.Position, projectilePart.Position + desiredDirection)
end

local function sendImpactIfNeeded(projectilePart, targetPart, state, dt, impactScale)
    local ev = state.ev
    local scale = math.max(impactScale or 1, 1)
    if not state.hasImpactRemote then
        local distance = (projectilePart.Position - targetPart.Position).Magnitude
        local touchDistance = state.touchHitDistance or 1.35
        local aggressiveNoRemote = state.profileKey == "grenadelaunchergrenade"
            or state.profileKey == "grenadelaunchergrenade2"
            or state.profileKey == "grenadelauncher_custom"
        local nearDistance = math.max(touchDistance, aggressiveNoRemote and 5.2 or 3.4)
        if distance <= nearDistance then
            local toTarget = targetPart.Position - projectilePart.Position
            local dir = toTarget.Magnitude > 0.001 and toTarget.Unit or targetPart.CFrame.LookVector
            local touchSpeed = math.max((state.baseSpeed or 320) * (aggressiveNoRemote and 1.2 or 0.9), aggressiveNoRemote and 1100 or 700) * scale
            projectilePart.AssemblyLinearVelocity = dir * touchSpeed
            projectilePart.Velocity = dir * touchSpeed
            projectilePart.CFrame = CFrame.new(targetPart.Position - dir * (aggressiveNoRemote and 0.05 or 0.1), targetPart.Position + dir)
            state.touchCloseAt = state.touchCloseAt or os.clock()
            local closeTimeout = aggressiveNoRemote and 0.24 or 0.4
            if (os.clock() - state.touchCloseAt) > closeTimeout then
                cleanupProjectile(projectilePart)
            end
        else
            state.touchCloseAt = nil
        end
        return
    end
    if not ev or not ev:IsA("RemoteEvent") then
        return
    end
    if state.hitSent then
        return
    end
    if (state.impactAttempts or 0) >= 6 then
        state.hitSent = true
        cleanupProjectile(projectilePart)
        return
    end

    local distance = (projectilePart.Position - targetPart.Position).Magnitude
    local speed = math.max(projectilePart.AssemblyLinearVelocity.Magnitude, projectilePart.Velocity.Magnitude, 320)
    local extraCatchDistance = speed * math.max(dt or 0, 0) * 1.5 * scale
    local hitDistance = 16 + extraCatchDistance
    if distance > hitDistance then
        return
    end

    if distance <= 8 then
        local nearDir = (targetPart.Position - projectilePart.Position)
        if nearDir.Magnitude > 0.001 then
            nearDir = nearDir.Unit
            projectilePart.CFrame = CFrame.new(targetPart.Position - nearDir * 0.08, targetPart.Position + nearDir)
        end
    end

    local now = os.clock()
    if (now - state.lastImpactSend) < 0.02 then
        return
    end
    state.lastImpactSend = now

    local hitPos = targetPart.Position + targetPart.AssemblyLinearVelocity * math.clamp(math.max(dt or 0.016, 0.016), 0.016, 0.04)
    local normal = (projectilePart.Position - hitPos)
    if normal.Magnitude <= 0.001 then
        normal = -targetPart.CFrame.LookVector
    else
        normal = normal.Unit
    end

    local fired = pcall(function()
        ev:FireServer(projectilePart, targetPart.CFrame, hitPos, normal, targetPart, nil)
    end)
    if fired then
        state.impactAttempts = (state.impactAttempts or 0) + 1
    end

    if distance <= 2.4 or (state.impactAttempts or 0) >= 6 then
        state.hitSent = true
        cleanupProjectile(projectilePart)
    end
end

local function getEndgameScale(state, now)
    if not Settings.HitmanBriefcaseEndgameBoostEnabled then
        return 1
    end
    local maxLife = state.maxLife or 6
    local ttl = maxLife - (now - state.startTick)
    if ttl > 1.8 then
        return 1
    end
    local normalized = 1 - math.clamp(ttl / math.max(1.8, 0.001), 0, 1)
    return 1 + (math.max(2.1, 1) - 1) * (normalized * normalized)
end

local function tryExtendLife(state, projectilePart, targetPart, now)
    if not Settings.HitmanBriefcaseLifeExtendOnClose then
        return false
    end

    local maxLife = state.maxLife or 6
    if (now - state.startTick) <= maxLife then
        return false
    end

    local used = state.lifeExtended or 0
    local maxTotal = math.max(8, 0)
    if used >= maxTotal then
        return false
    end

    if not targetPart then
        return false
    end

    local distance = (projectilePart.Position - targetPart.Position).Magnitude
    if distance > math.max(90, 0) then
        return false
    end

    local add = math.min(math.max(1.6, 0), maxTotal - used)
    if add <= 0 then
        return false
    end

    state.maxLife = maxLife + add
    state.lifeExtended = used + add
    return true
end

RunService.Heartbeat:Connect(function(dt)
    local ok, err = pcall(function()
        if not Settings.HitmanBriefcaseEnabled then
            return
        end

        if next(trackedProjectiles) == nil then
            return
        end

        local now = os.clock()
        if now >= nextTargetRefreshAt or not isValidHeadPart(cachedTargetPart) then
            cachedTargetPart = getClosestTargetHeadToMouse()
            nextTargetRefreshAt = now + 0.05
        end

        for projectilePart, state in pairs(trackedProjectiles) do
            if typeof(projectilePart) ~= "Instance" or not projectilePart.Parent then
                cleanupProjectile(projectilePart)
            else
                local maxLife = state.maxLife or 6
                if (now - state.startTick) > maxLife then
                    local expireTarget = state.targetPart
                    if not isValidHeadPart(expireTarget) then
                        expireTarget = getNearestTargetHeadToPosition(projectilePart.Position)
                    end
                    if not tryExtendLife(state, projectilePart, expireTarget, now) then
                        cleanupProjectile(projectilePart)
                    elseif expireTarget then
                        state.targetPart = expireTarget
                    end
                end

                if trackedProjectiles[projectilePart] == state then
                    local targetPart = forceAcquireTargetForProjectile(state, projectilePart, now)
                    local speedScale = getEndgameScale(state, now)
                    if not isValidHeadPart(targetPart) then
                        local refreshed = getNearestTargetHeadToPosition(projectilePart.Position)
                        if not isValidHeadPart(refreshed) then
                            refreshed = getNearestTargetHeadByRadiusSearch(projectilePart.Position, 760)
                        end
                        if not isValidHeadPart(refreshed) then
                            refreshed = cachedTargetPart
                        end
                        if not isValidHeadPart(refreshed) then
                            refreshed = getClosestTargetHeadToMouse()
                        end
                        state.targetPart = refreshed
                        targetPart = refreshed
                    end

                    if not isValidHeadPart(targetPart) then
                        targetPart = forceAcquireTargetForProjectile(state, projectilePart, now)
                    end

                    if (not isValidHeadPart(targetPart)) and now >= (state.nextHardFallbackAt or 0) then
                        local hardTarget = getNearestTargetHeadByRadiusSearch(projectilePart.Position, 760)
                        state.nextHardFallbackAt = now + 0.16
                        if hardTarget then
                            state.targetPart = hardTarget
                            targetPart = hardTarget
                        end
                    end

                    if not isValidHeadPart(targetPart) then
                        if now >= (state.nextFarFallbackAt or 0) then
                            targetPart = getNearestTargetHeadByRadiusSearch(projectilePart.Position, 2400)
                            state.targetPart = targetPart
                            state.nextFarFallbackAt = now + 0.16
                        end
                    end

                    if isValidHeadPart(targetPart) then
                        if speedScale > 1 then
                            if (state.nextPathCalcAt or 0) > (now + 0.04) then
                                state.nextPathCalcAt = now + 0.04
                            end
                        end
                        local predictedPos = getPredictedPosition(projectilePart, targetPart)
                        local rescue, hardRescue = shouldRescueSteer(projectilePart, targetPart)
                        local handledDirect = false
                        if rescue then
                            state.pathWaypoints = nil
                            state.pathIndex = 1
                            state.nextPathCalcAt = 0
                            state.nextHeavySolveAt = 0
                            if hardRescue then
                                speedScale = math.max(speedScale, 1.35)
                                steerProjectile(projectilePart, state, predictedPos, dt, speedScale)
                                applyFinalSnap(projectilePart, targetPart)
                                sendImpactIfNeeded(projectilePart, targetPart, state, dt, speedScale * math.max(1.25, 1))
                                handledDirect = true
                            end
                        end
                        if not handledDirect then
                            if tryStuckRecovery(state, projectilePart, targetPart, predictedPos, now) then
                                state.nextPathCalcAt = 0
                            end
                            if tryPreemptiveAvoidance(state, projectilePart, targetPart, predictedPos, now) then
                                state.nextPathCalcAt = math.min(state.nextPathCalcAt or now, now + 0.02)
                            end
                            requestProjectilePath(state, projectilePart, targetPart, predictedPos, now)
                            local steerGoal = resolvePathGoal(state, projectilePart, predictedPos)
                            if tryEmergencyBypass(state, projectilePart, targetPart, steerGoal, now, nil) then
                                steerGoal = resolvePathGoal(state, projectilePart, predictedPos)
                            end
                            steerProjectile(projectilePart, state, steerGoal, dt, speedScale)
                            applyFinalSnap(projectilePart, targetPart)
                            sendImpactIfNeeded(projectilePart, targetPart, state, dt, speedScale * math.max(1.25, 1))
                        end
                    end
                end
            end
        end
    end)

    if not ok then
        local now = os.clock()
        if (now - lastHeartbeatErrorAt) > 1 then
            lastHeartbeatErrorAt = now
            warn("[HitmanBriefcase] Heartbeat error:", err)
        end
    end
end)

task.spawn(function()
    for _ = 1, 5 do
        bootstrapMapTuning()
        if MapTuning.mapCount > 0 or MapTuning.hasTerrainRegions then
            break
        end
        task.wait(1.2)
    end
end)

local function handleInstantReloadFromSource()
    if instantReloadLoopRunning then
        return
    end
    instantReloadLoopRunning = true

    local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
    local gnx_r = eventsFolder and eventsFolder:FindFirstChild("GNX_R")
    local conns = {}
    local charAddedConn
    local childAddedConn

    local function clearConns()
        for _, c in ipairs(conns) do
            if c and c.Connected then
                c:Disconnect()
            end
        end
        conns = {}
        if charAddedConn and charAddedConn.Connected then
            charAddedConn:Disconnect()
        end
        if childAddedConn and childAddedConn.Connected then
            childAddedConn:Disconnect()
        end
    end

    local function hookGun(tool)
        if tool and tool:FindFirstChild("IsGun") then
            local vals = tool:FindFirstChild("Values")
            if vals then
                local ammo = vals:FindFirstChild("SERVER_Ammo")
                local stored = vals:FindFirstChild("SERVER_StoredAmmo")
                if stored and gnx_r then
                    table.insert(conns, stored:GetPropertyChangedSignal("Value"):Connect(function()
                        if Settings.InstantReload and stored.Value > 0 then
                            gnx_r:FireServer(tick(), "KLWE89U0", tool)
                        end
                    end))
                end
                if ammo and stored and gnx_r then
                    table.insert(conns, ammo:GetPropertyChangedSignal("Value"):Connect(function()
                        if Settings.InstantReload and stored.Value > 0 then
                            gnx_r:FireServer(tick(), "KLWE89U0", tool)
                        end
                    end))
                end
            end
        end
    end

    local function setupCharacter(char)
        clearConns()
        hookGun(char:FindFirstChildOfClass("Tool"))
        childAddedConn = char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and child:FindFirstChild("IsGun") then
                hookGun(child)
            end
        end)
    end

    if LocalPlayer.Character then
        setupCharacter(LocalPlayer.Character)
    end
    charAddedConn = LocalPlayer.CharacterAdded:Connect(setupCharacter)

    while Settings.InstantReload do
        task.wait(0.1)
    end

    clearConns()
    instantReloadLoopRunning = false
end

local function processToolConfig(tool)
    if not tool or not tool:IsA("Tool") then
        return
    end

    local configModule = tool:FindFirstChild("Config")
    if not configModule or not configModule:IsA("ModuleScript") then
        return
    end

    local ok, config = pcall(require, configModule)
    if ok and type(config) == "table" then
        applyAllMods(config)
    end
end

local function refreshToolConfigs()
    local function scan(container)
        if not container then
            return
        end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") then
                processToolConfig(child)
            end
        end
    end

    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
end

local function scanContainerForTools(container)
    if not container then
        return
    end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") then
            processToolConfig(child)
        end
    end
end

local function attachCharacter(character)
    if charAddedConnection then
        charAddedConnection:Disconnect()
        charAddedConnection = nil
    end
    if charRemovedConnection then
        charRemovedConnection:Disconnect()
        charRemovedConnection = nil
    end
    if not character then
        return
    end

    charAddedConnection = character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            processToolConfig(child)
        end
    end)

    scanContainerForTools(character)
end

backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 10)
if backpack then
    backpackAddedConnection = backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            processToolConfig(child)
        end
    end)
    scanContainerForTools(backpack)
end

characterAddedConnection = LocalPlayer.CharacterAdded:Connect(attachCharacter)
attachCharacter(LocalPlayer.Character)
refreshToolConfigs()
refreshTrackedConfigs()

installProjectileHook()
ensureProjectileHookRetryLoop()
installProjectileSpeedHook()
hookProjectileHandlersFromConnections()
hookHitmanSpitballDebris()
syncHitmanWallbangState(shouldEnableHitmanWallbang())

Window = Library:CreateWindow({
    Title = "Eblo",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

Tabs = {
	Main = Window:AddTab("Main"),
	["UI Settings"] = Window:AddTab("UI Settings"),
}

GunModsGroup = Tabs.Main:AddLeftGroupbox("Gun Mods")

GunModsGroup:AddToggle("gm_instant", { Text = "Instant Bullet", Default = Settings.InstantBullet })
GunModsGroup:AddToggle("gm_hitman_briefcase", {
    Text = "Hitman Briefcase",
    Default = Settings.HitmanBriefcaseEnabled,
    Risky = true,
})
GunModsGroup:AddToggle("gm_instant_reload", { Text = "Instant Reload", Default = Settings.InstantReload })
GunModsGroup:AddToggle("gm_mod_recoil", { Text = "Modify Recoil", Default = Settings.ModRecoil })
GunModsGroup:AddSlider("gm_recoil_amount", { Text = "Recoil Amount", Default = Settings.RecoilAmount, Min = 0, Max = 100, Rounding = 0, Suffix = "%" })
GunModsGroup:AddToggle("gm_mod_spread", { Text = "Modify Spread", Default = Settings.ModSpread })
GunModsGroup:AddSlider("gm_spread_amount", { Text = "Spread Amount", Default = Settings.SpreadAmount, Min = 0, Max = 100, Rounding = 0, Suffix = "%" })
GunModsGroup:AddToggle("gm_mod_equip", { Text = "Equip Speed", Default = Settings.ModEquip })
GunModsGroup:AddSlider("gm_equip_speed", { Text = "Equip Multiplier", Default = Settings.EquipSpeed, Min = 0, Max = 2, Rounding = 2, Suffix = "x" })
GunModsGroup:AddToggle("gm_mod_aim", { Text = "Aim Speed", Default = Settings.ModAim })
GunModsGroup:AddSlider("gm_aim_speed", { Text = "Aim Multiplier", Default = Settings.AimSpeed, Min = 0, Max = 2, Rounding = 2, Suffix = "x" })
GunModsGroup:AddToggle("gm_infinite_range", { Text = "Infinite Range", Default = Settings.InfiniteRange })
GunModsGroup:AddToggle("gm_no_slowdown", { Text = "No Slowdown", Default = Settings.NoSlowdown })
GunModsGroup:AddToggle("gm_instant_charge", { Text = "Instant Charge", Default = Settings.InstantCharge })
GunModsGroup:AddToggle("gm_rapid_fire", { Text = "Rapid Fire", Default = Settings.RapidFire })
SelfTracerToggle = GunModsGroup:AddToggle("gm_tracers_self", { Text = "LocalPlayer Tracers", Default = Settings.TracersSelf })
SelfTracerToggle:AddColorPicker("gm_tracer_self_color", { Default = Settings.TracerSelfColor, Title = "My Tracer Color" })
OthersTracerToggle = GunModsGroup:AddToggle("gm_tracers_others", { Text = "Players Tracers", Default = Settings.TracersOthers })
OthersTracerToggle:AddColorPicker("gm_tracer_others_color", { Default = Settings.TracerOthersColor, Title = "Others Tracer Color" })

local function onConfigChanged()
    refreshToolConfigs()
    refreshTrackedConfigs()
end

task.wait()

Toggles.gm_instant:OnChanged(function()
    Settings.InstantBullet = Toggles.gm_instant.Value
    installProjectileHook()
    ensureProjectileHookRetryLoop()
    hookProjectileHandlersFromConnections()
    onConfigChanged()
end)

Toggles.gm_hitman_briefcase:OnChanged(function()
    Settings.HitmanBriefcaseEnabled = Toggles.gm_hitman_briefcase.Value
    syncHitmanWallbangState(shouldEnableHitmanWallbang())
    if not Settings.HitmanBriefcaseEnabled and type(hitmanClearProjectiles) == "function" then
        hitmanClearProjectiles()
    end
end)

Toggles.gm_instant_reload:OnChanged(function()
    Settings.InstantReload = Toggles.gm_instant_reload.Value
    if Settings.InstantReload then
        task.spawn(handleInstantReloadFromSource)
    end
end)


Toggles.gm_mod_recoil:OnChanged(function()
    Settings.ModRecoil = Toggles.gm_mod_recoil.Value
    onConfigChanged()
end)

Options.gm_recoil_amount:OnChanged(function()
    Settings.RecoilAmount = Options.gm_recoil_amount.Value
    onConfigChanged()
end)

Toggles.gm_mod_spread:OnChanged(function()
    Settings.ModSpread = Toggles.gm_mod_spread.Value
    onConfigChanged()
end)

Options.gm_spread_amount:OnChanged(function()
    Settings.SpreadAmount = Options.gm_spread_amount.Value
    onConfigChanged()
end)

Toggles.gm_mod_equip:OnChanged(function()
    Settings.ModEquip = Toggles.gm_mod_equip.Value
    onConfigChanged()
end)

Options.gm_equip_speed:OnChanged(function()
    Settings.EquipSpeed = Options.gm_equip_speed.Value
    onConfigChanged()
end)

Toggles.gm_mod_aim:OnChanged(function()
    Settings.ModAim = Toggles.gm_mod_aim.Value
    onConfigChanged()
end)

Options.gm_aim_speed:OnChanged(function()
    Settings.AimSpeed = Options.gm_aim_speed.Value
    onConfigChanged()
end)

Toggles.gm_infinite_range:OnChanged(function()
    Settings.InfiniteRange = Toggles.gm_infinite_range.Value
    onConfigChanged()
end)

Toggles.gm_no_slowdown:OnChanged(function()
    Settings.NoSlowdown = Toggles.gm_no_slowdown.Value
    onConfigChanged()
end)

Toggles.gm_instant_charge:OnChanged(function()
    Settings.InstantCharge = Toggles.gm_instant_charge.Value
    onConfigChanged()
end)

Toggles.gm_rapid_fire:OnChanged(function()
    Settings.RapidFire = Toggles.gm_rapid_fire.Value
    onConfigChanged()
end)

Toggles.gm_tracers_self:OnChanged(function()
    Settings.TracersSelf = Toggles.gm_tracers_self.Value
    if Settings.TracersSelf or Settings.TracersOthers then
        installVisualizeTracerHook()
        installLocalShootTracerHook()
    end
end)

Toggles.gm_tracers_others:OnChanged(function()
    Settings.TracersOthers = Toggles.gm_tracers_others.Value
    if Settings.TracersSelf or Settings.TracersOthers then
        installVisualizeTracerHook()
        installLocalShootTracerHook()
    end
end)

Options.gm_tracer_self_color:OnChanged(function()
    Settings.TracerSelfColor = Options.gm_tracer_self_color.Value
end)

Options.gm_tracer_others_color:OnChanged(function()
    Settings.TracerOthersColor = Options.gm_tracer_others_color.Value
end)

if Settings.InstantReload then
    task.spawn(handleInstantReloadFromSource)
end
refreshTick = 0
refreshConnection = RunService.Heartbeat:Connect(function(dt)
    refreshTick = refreshTick + dt
    if refreshTick < 0.1 then
        return
    end
    refreshTick = 0

    local shouldRefreshConfigs = Settings.InstantBullet
        or Settings.ModRecoil
        or Settings.ModSpread
        or Settings.ModEquip
        or Settings.ModAim
        or Settings.InfiniteRange
        or Settings.NoSlowdown
        or Settings.InstantCharge
        or Settings.RapidFire

    if shouldRefreshConfigs then
        refreshToolConfigs()
        refreshTrackedConfigs()
    end

    if Settings.InstantBullet or Settings.HitmanBriefcaseEnabled then
        projectileRefreshTick = projectileRefreshTick + 0.1
        if projectileRefreshTick >= 0.6 then
            projectileRefreshTick = 0
            installProjectileHook()
            hookProjectileHandlersFromConnections()
        end
    else
        projectileRefreshTick = 0
    end

    if Settings.TracersSelf or Settings.TracersOthers then
        if not visualizeTracerHooked then
            installVisualizeTracerHook()
        end
        if not localShootTracerHooked then
            installLocalShootTracerHook()
        end
    end

    if shouldEnableHitmanWallbang() then
        hitmanWallbangRefreshTick = hitmanWallbangRefreshTick + 0.1
        if hitmanWallbangRefreshTick >= 1 then
            hitmanWallbangRefreshTick = 0
            hookHitmanSpitballDebris()
            syncHitmanWallbangState(true)
        end
    else
        hitmanWallbangRefreshTick = 0
        if hitmanWallbangApplied then
            syncHitmanWallbangState(false)
        end
    end

end)

Menu = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
Menu:AddButton("Unload", function()
    Library:Unload()
end)
Menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "End", NoUI = true, Text = "Menu keybind" })

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("xyesos")
SaveManager:SetFolder("xyesos/pornhub")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

Library:OnUnload(function()
    tracerUnload = true
    restoreConfigValues()

    if refreshConnection then
        refreshConnection:Disconnect()
    end

    for _, connection in ipairs(visualizeConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    if tracerCameraChangedConnection then
        pcall(function()
            tracerCameraChangedConnection:Disconnect()
        end)
        tracerCameraChangedConnection = nil
    end
    if tracerCameraChildAddedConnection then
        pcall(function()
            tracerCameraChildAddedConnection:Disconnect()
        end)
        tracerCameraChildAddedConnection = nil
    end
    if tracerBulletAddedConnection then
        pcall(function()
            tracerBulletAddedConnection:Disconnect()
        end)
        tracerBulletAddedConnection = nil
    end

    if charAddedConnection then
        charAddedConnection:Disconnect()
        charAddedConnection = nil
    end
    if charRemovedConnection then
        charRemovedConnection:Disconnect()
        charRemovedConnection = nil
    end
    if backpackAddedConnection then
        backpackAddedConnection:Disconnect()
        backpackAddedConnection = nil
    end
    if backpackRemovedConnection then
        backpackRemovedConnection:Disconnect()
        backpackRemovedConnection = nil
    end
    if characterAddedConnection then
        characterAddedConnection:Disconnect()
        characterAddedConnection = nil
    end
    if hitmanPlayerAddedConnection then
        hitmanPlayerAddedConnection:Disconnect()
        hitmanPlayerAddedConnection = nil
    end
    if hitmanPlayerRemovingConnection then
        hitmanPlayerRemovingConnection:Disconnect()
        hitmanPlayerRemovingConnection = nil
    end
    if hitmanDebrisSpitballConnection then
        hitmanDebrisSpitballConnection:Disconnect()
        hitmanDebrisSpitballConnection = nil
    end
    Settings.InstantReload = false
    Settings.HitmanBriefcaseEnabled = false
    syncHitmanWallbangState(false)
    if type(hitmanClearProjectiles) == "function" then
        hitmanClearProjectiles()
    end
    if tracerFolder and tracerFolder.Parent then
        tracerFolder:Destroy()
    end
end)
