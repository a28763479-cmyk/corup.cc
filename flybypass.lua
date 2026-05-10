FLYING = false
QEfly = true
getgenv().flyspeed = 1

if getgenv().flyRotateWithCamera == nil then
    getgenv().flyRotateWithCamera = true
end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Mouse      = Players.LocalPlayer:GetMouse()
local Event      = ReplicatedStorage:WaitForChild("Events"):WaitForChild("__RZDONL")

local flyKeyDown, flyKeyUp
local preSimConn, postSimConn
local toggleInputConn
local remoteSpamToken = 0
local noFallDamageEnabled = false
local noFallHookInstalled = false
local oldNamecall
local frozenBodyCFrames = {}
local bodyOffsets = {}
local lastFlyCFrame

local funcs = {}

local function freezeBodyPartsExceptTorso(char, torso, keepSavedCFrames)
    if not char then
        return
    end

    for _, inst in ipairs(char:GetChildren()) do
        if inst:IsA("BasePart") and inst ~= torso and inst.Name ~= "HumanoidRootPart" then
            if keepSavedCFrames then
                frozenBodyCFrames[inst] = frozenBodyCFrames[inst] or inst.CFrame
                inst.CFrame = frozenBodyCFrames[inst]
            end

            inst.AssemblyLinearVelocity = Vector3.zero
            inst.AssemblyAngularVelocity = Vector3.zero
            inst.Velocity = Vector3.zero
            inst.RotVelocity = Vector3.zero
        end
    end
end

local function placeBodyPartsOnTorso(char, torso)
    if not char or not torso then
        return
    end

    for _, inst in ipairs(char:GetChildren()) do
        if inst:IsA("BasePart") and inst ~= torso and inst.Name ~= "HumanoidRootPart" then
            inst.CFrame = bodyOffsets[inst] and (torso.CFrame * bodyOffsets[inst]) or torso.CFrame
            inst.AssemblyLinearVelocity = Vector3.zero
            inst.AssemblyAngularVelocity = Vector3.zero
            inst.Velocity = Vector3.zero
            inst.RotVelocity = Vector3.zero
        end
    end
end

local function installNoFallDamageHook()
    if noFallHookInstalled or not hookmetamethod or not getnamecallmethod then
        return
    end

    local function namecallHook(self, remoteName, ...)
        local method = getnamecallmethod()

        if noFallDamageEnabled
            and tostring(method):lower() == "fireserver"
            and (not checkcaller or not checkcaller())
            and (
                remoteName == "FllH"
                or remoteName == "FallH"
                or remoteName == "FallD"
                or remoteName == "FlllD"
            )
        then
            return
        end

        if oldNamecall then
            return oldNamecall(self, remoteName, ...)
        end
    end

    if newcclosure then
        namecallHook = newcclosure(namecallHook)
    end

    local ok, original = pcall(hookmetamethod, game, "__namecall", namecallHook)
    if ok then
        oldNamecall = original
        noFallHookInstalled = true
    end
end

function funcs.sFLY()
    if FLYING then
        return
    end

    repeat task.wait() until
        Players.LocalPlayer
        and Players.LocalPlayer.Character
        and Players.LocalPlayer.Character:FindFirstChild("Torso")
        and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    repeat task.wait() until Mouse

    if flyKeyDown then flyKeyDown:Disconnect() end
    if flyKeyUp   then flyKeyUp:Disconnect()   end

    if preSimConn  then preSimConn:Disconnect();  preSimConn  = nil end
    if postSimConn then postSimConn:Disconnect(); postSimConn = nil end

    local char  = Players.LocalPlayer.Character
    local Torso = char:WaitForChild("Torso")
    local hum   = char:FindFirstChildOfClass("Humanoid")

    if hum then
        hum.PlatformStand = true
    end

    local CONTROL  = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
    local lCONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
    local SPEED    = 0

    local flyCF      = Torso.CFrame
    local desiredVel = Vector3.zero
    frozenBodyCFrames = {}
    bodyOffsets = {}
    lastFlyCFrame = flyCF

    for _, inst in ipairs(char:GetChildren()) do
        if inst:IsA("BasePart") and inst ~= Torso and inst.Name ~= "HumanoidRootPart" then
            bodyOffsets[inst] = Torso.CFrame:ToObjectSpace(inst.CFrame)
        end
    end

    freezeBodyPartsExceptTorso(char, Torso, true)

    local function FLY()
        FLYING = true
        noFallDamageEnabled = true
        installNoFallDamageHook()

        remoteSpamToken += 1
        local token = remoteSpamToken

        task.spawn(function()
            while FLYING and token == remoteSpamToken do
                local c = Players.LocalPlayer.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")

                if hrp then
                    pcall(function()
                        Event:FireServer("-r__r3", Vector3.new(0, 0, 0), hrp.CFrame)
                    end)
                end

                RunService.Heartbeat:Wait()
            end
        end)
        
        local torsoAttachment = Torso:FindFirstChildOfClass("Attachment")
        if not torsoAttachment then
            torsoAttachment = Instance.new("Attachment")
            torsoAttachment.Name = "FlyAttachment"
            torsoAttachment.Parent = Torso
        end

        local BG = Instance.new("AlignOrientation")
        local BV = Instance.new("LinearVelocity")

        BG.RigidityEnabled = true
        BG.Parent = workspace
        BG.Attachment0 = torsoAttachment
        BG.Mode = Enum.OrientationAlignmentMode.OneAttachment
        BG.CFrame = flyCF

        BV.Parent = workspace
        BV.Attachment0 = torsoAttachment
        BV.VectorVelocity = Vector3.zero
        BV.MaxForce = math.huge

        local function updateFlyCFOrientation()
            if not getgenv().flyRotateWithCamera then
                return
            end

            local cam = workspace.CurrentCamera
            if not cam then
                return
            end

            local pos  = flyCF.Position
            local look = cam.CFrame.LookVector
            local flatLook = Vector3.new(look.X, 0, look.Z)

            if flatLook.Magnitude < 1e-3 then
                return
            end

            flyCF = CFrame.lookAt(pos, pos + flatLook)
        end

        preSimConn = RunService.PreSimulation:Connect(function(dt)
            if not FLYING then return end

            local c = Players.LocalPlayer.Character
            if not c then return end
            local t = c:FindFirstChild("Torso")
            if not t then return end

            flyCF = flyCF + (desiredVel * dt)
            updateFlyCFOrientation()
            lastFlyCFrame = flyCF

            t.CFrame = flyCF

            BG.CFrame         = flyCF
            BV.VectorVelocity = desiredVel

            t.Velocity    = Vector3.new(50, 50, 50)
            t.RotVelocity = Vector3.zero
            freezeBodyPartsExceptTorso(c, t, true)

            local h = c:FindFirstChildOfClass("Humanoid")
            if h then
                h.PlatformStand = true
            end
        end)

        postSimConn = RunService.PostSimulation:Connect(function()
            if not FLYING then return end

            local c = Players.LocalPlayer.Character
            if not c then return end
            local t = c:FindFirstChild("Torso")
            if not t then return end

            updateFlyCFOrientation()
            lastFlyCFrame = flyCF
            t.CFrame = flyCF

            t.AssemblyLinearVelocity  = desiredVel
            t.AssemblyAngularVelocity = Vector3.zero

            t.Velocity    = Vector3.new(50, 50, 50)
            t.RotVelocity = Vector3.zero
            freezeBodyPartsExceptTorso(c, t, true)
        end)

        task.spawn(function()
            local last = tick()
            while FLYING do
                local now = tick()
                local dt  = now - last
                last = now

                if CONTROL.L + CONTROL.R ~= 0
                or CONTROL.F + CONTROL.B ~= 0
                or CONTROL.Q + CONTROL.E ~= 0 then
                    SPEED = 50
                elseif SPEED ~= 0 then
                    SPEED = 0
                end

                local cam = workspace.CurrentCamera

                if (CONTROL.L + CONTROL.R) ~= 0
                or (CONTROL.F + CONTROL.B) ~= 0
                or (CONTROL.Q + CONTROL.E) ~= 0 then
                    desiredVel =
                        ((cam.CFrame.LookVector * (CONTROL.F + CONTROL.B))
                         + ((cam.CFrame
                                * CFrame.new(
                                    CONTROL.L + CONTROL.R,
                                    (CONTROL.F + CONTROL.B + CONTROL.Q + CONTROL.E) * 0.2,
                                    0
                                ).Position)
                            - cam.CFrame.Position)
                        ) * SPEED

                    lCONTROL = {
                        F = CONTROL.F, B = CONTROL.B,
                        L = CONTROL.L, R = CONTROL.R,
                        Q = CONTROL.Q, E = CONTROL.E
                    }
                elseif SPEED ~= 0 then
                    desiredVel =
                        ((cam.CFrame.LookVector * (lCONTROL.F + lCONTROL.B))
                         + ((cam.CFrame
                                * CFrame.new(
                                    lCONTROL.L + lCONTROL.R,
                                    (lCONTROL.F + lCONTROL.B + CONTROL.Q + CONTROL.E) * 0.2,
                                    0
                                ).Position)
                            - cam.CFrame.Position)
                        ) * SPEED
                else
                    desiredVel = Vector3.zero
                end

                local c = Players.LocalPlayer.Character
                if c then
                    local t = c:FindFirstChild("Torso")
                    if t then
                        t.Velocity = Vector3.new(50, 50, 50)
                        freezeBodyPartsExceptTorso(c, t, true)
                    end
                end

                RunService.Heartbeat:Wait()
            end

            CONTROL  = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
            lCONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
            SPEED    = 0
            desiredVel = Vector3.zero

            BG:Destroy()
            BV:Destroy()

            if preSimConn  then preSimConn:Disconnect();  preSimConn  = nil end
            if postSimConn then postSimConn:Disconnect(); postSimConn = nil end
        end)
    end

    flyKeyDown = Mouse.KeyDown:Connect(function(KEY)
        KEY = KEY:lower()
        if KEY == "w" then
            CONTROL.F = getgenv().flyspeed
        elseif KEY == "s" then
            CONTROL.B = -getgenv().flyspeed
        elseif KEY == "a" then
            CONTROL.L = -getgenv().flyspeed
        elseif KEY == "d" then
            CONTROL.R = getgenv().flyspeed
        elseif QEfly and KEY == "e" then
            CONTROL.Q = getgenv().flyspeed * 2
        elseif QEfly and KEY == "q" then
            CONTROL.E = -getgenv().flyspeed * 2
        end
        pcall(function()
            workspace.CurrentCamera.CameraType = Enum.CameraType.Track
        end)
    end)

    flyKeyUp = Mouse.KeyUp:Connect(function(KEY)
        KEY = KEY:lower()
        if KEY == "w" then
            CONTROL.F = 0
        elseif KEY == "s" then
            CONTROL.B = 0
        elseif KEY == "a" then
            CONTROL.L = 0
        elseif KEY == "d" then
            CONTROL.R = 0
        elseif KEY == "e" then
            CONTROL.Q = 0
        elseif KEY == "q" then
            CONTROL.E = 0
        end
    end)

    FLY()
end

function funcs.NOFLY()
    FLYING = false
    noFallDamageEnabled = false
    remoteSpamToken += 1

    if flyKeyDown then flyKeyDown:Disconnect(); flyKeyDown = nil end
    if flyKeyUp   then flyKeyUp:Disconnect();   flyKeyUp   = nil end

    if preSimConn  then preSimConn:Disconnect();  preSimConn  = nil end
    if postSimConn then postSimConn:Disconnect(); postSimConn = nil end

    local char = Players.LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = true
        end

        local t = char:FindFirstChild("Torso")
        if t then
            if lastFlyCFrame then
                t.CFrame = lastFlyCFrame
            end

            placeBodyPartsOnTorso(char, t)

            t.AssemblyLinearVelocity  = Vector3.zero
            t.AssemblyAngularVelocity = Vector3.zero
            t.Velocity                = Vector3.zero
            t.RotVelocity             = Vector3.zero
        end

        if hum then
            task.defer(function()
                RunService.Heartbeat:Wait()
                if hum.Parent then
                    hum.PlatformStand = false
                end
            end)
        end
    end

    frozenBodyCFrames = {}
    bodyOffsets = {}
    lastFlyCFrame = nil

    pcall(function()
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end)

end

function funcs.BindToggle()
    if toggleInputConn then
        toggleInputConn:Disconnect()
        toggleInputConn = nil
    end

    toggleInputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or input.KeyCode ~= Enum.KeyCode.K then
            return
        end

        if FLYING then
            funcs.NOFLY()
        else
            funcs.sFLY()
        end
    end)
end

function funcs.UnbindToggle()
    if toggleInputConn then
        toggleInputConn:Disconnect()
        toggleInputConn = nil
    end
end

funcs.BindToggle()

return funcs
