for _, value in next, getgc(true) do 
    if typeof(value) == 'table' then
        if rawget(value, "indexInstance") or rawget(value, "newindexInstance") or rawget(value, "namecallInstance") or rawget(value, "newIndexInstance") then 
            value.tvk = {"kick", function() return task.wait(9e9) end} 
        end
    end
end

local silentaimenabled = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local TARGET_PART_NAME = "HumanoidRootPart"
local FOV_RADIUS = 130

local function getMousePosition()
    return UserInputService:GetMouseLocation()
end

local function getPositionOnScreen(vector)
    local vec3, onScreen = Camera:WorldToScreenPoint(vector)
    return Vector2.new(vec3.X, vec3.Y), onScreen
end

local function ValidateArguments(args, argCountRequired, ...)
    local expectedTypes = {...}
    local matches = 0
    if #args < argCountRequired then
        return false
    end
    for pos, argument in next, args do
        if expectedTypes[pos] and typeof(argument) == expectedTypes[pos] then
            matches = matches + 1
        end
    end
    return matches >= argCountRequired
end

local function getDirection(origin, position)
    return (position - origin).Unit * 1000
end

local function getClosestTargetPart()
    local closest
    local distanceToMouse

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then
            continue
        end

        local character = player.Character
        if not character then
            continue
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local targetPart = character:FindFirstChild(TARGET_PART_NAME)
        if not humanoid or humanoid.Health <= 0 or not targetPart then
            continue
        end

        local screenPosition, onScreen = getPositionOnScreen(targetPart.Position)
        if not onScreen then
            continue
        end

        local distance = (getMousePosition() - screenPosition).Magnitude
        if distance <= (distanceToMouse or FOV_RADIUS) then
            closest = targetPart
            distanceToMouse = distance
        end
    end

    return closest
end

local fovCircle = Drawing.new("Circle")
fovCircle.Filled = false
fovCircle.NumSides = 100
fovCircle.Thickness = 1
fovCircle.Transparency = 1
fovCircle.ZIndex = 999
fovCircle.Radius = FOV_RADIUS
fovCircle.Visible = true
fovCircle.Color = Color3.fromRGB(255, 255, 0)

local cachedTargetPart = nil

RunService.RenderStepped:Connect(function()
    if Camera ~= workspace.CurrentCamera then
        Camera = workspace.CurrentCamera
    end
    cachedTargetPart = getClosestTargetPart()
    fovCircle.Position = getMousePosition()
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local method = getnamecallmethod()
    local arguments = {...}
    local self = arguments[1]

    if silentaimenabled and self == workspace and not checkcaller() then
        if method == "Raycast" then
            if ValidateArguments(arguments, 3, "Instance", "Vector3", "Vector3", "RaycastParams") then
                local A_Origin = arguments[2]
                local HitPart = cachedTargetPart
                if HitPart then
                    arguments[3] = getDirection(A_Origin, HitPart.Position)
                    return oldNamecall(unpack(arguments))
                end
            end
        end
    end

    return oldNamecall(...)
end))
