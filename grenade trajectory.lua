if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	return
end

local Mouse = LocalPlayer:GetMouse()

local CONFIG = {
	DEFAULT_THROW_SPEED = 150,
	EFFECTIVE_GRAVITY_SCALE = 0.55,
	DEFAULT_FUSE_TIME = 2.5,
	MAX_PREDICT_TIME = 6,
	UNTIL_SLOW_MAX_TIME = 8,
	SIMULATION_DT = 1 / 90,
	MAX_BOUNCES = 6,
	MAX_POINTS = 220,
	MIN_SPEED = 1.25,
	BASE_MIN_RESTITUTION = 0.012,
	BASE_MAX_RESTITUTION = 0.24,
	BASE_MIN_TANGENT_DAMPING = 0.45,
	BASE_MAX_TANGENT_DAMPING = 0.92,
	LOW_SPEED_RESTITUTION_CUTOFF = 22,
	LOW_SPEED_RESTITUTION_MULT = 0.35,
	THROW_DELAY_SAFETY = 0.55,
	PREVIEW_UPDATE_INTERVAL = 1 / 30,
	PREVIEW_COLOR = Color3.fromRGB(255, 60, 60),
	PREVIEW_TRANSPARENCY = 0.15,
	PREVIEW_THICKNESS = 0.11,
	FIRST_PERSON_START_OFFSET = 0.35,
	CAMERA_NEAR_CLIP_DISTANCE = 1.4,
	LIVE_COLOR = Color3.fromRGB(255, 170, 120),
	LIVE_TRANSPARENCY = 0.2,
	LIVE_THICKNESS = 0.1,
	LIVE_SAMPLE_DT = 1 / 60,
	LIVE_TTL = 0.55,
	MAX_LIVE_TIME = 6,
	FLIGHT_MIN_START_SPEED = 8,
}

local function randomName(prefix)
	local ok, guid = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	if ok and type(guid) == "string" then
		local cleaned = string.gsub(guid, "%-", "")
		return string.format("%s%s", prefix, string.sub(cleaned, 1, 12))
	end
	return string.format("%s%d", prefix, math.random(100000, 999999))
end

local rootParent = Workspace:FindFirstChild("Debris") or Workspace

local runTag = randomName("r_")
for _, child in ipairs(rootParent:GetChildren()) do
	if child:IsA("BasePart") and child:GetAttribute("gt_line") == true then
		child:Destroy()
	end
end

local previewParent = rootParent
local liveParent = rootParent

local function getCharacter()
	return LocalPlayer.Character
end

local function getHead(character)
	if not character then
		return nil
	end
	return character:FindFirstChild("Head")
end

local function getAimPoint()
	local global = rawget(_G, "GetMousePoint")
	if type(global) == "function" then
		local ok, point = pcall(global)
		if ok and typeof(point) == "Vector3" then
			return point
		end
	end

	if Mouse and Mouse.Hit then
		return Mouse.Hit.Position
	end

	local camera = Workspace.CurrentCamera
	if camera then
		return camera.CFrame.Position + (camera.CFrame.LookVector * 500)
	end

	return Vector3.zero
end

local function isThrowableTool(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end

	local handle = tool:FindFirstChild("Handle")
	local rightGrip = tool:FindFirstChild("RightGrip")
	local gripPart = (handle and handle:IsA("BasePart") and handle) or (rightGrip and rightGrip:IsA("BasePart") and rightGrip) or nil
	if not gripPart then
		return false
	end

	local event = tool:FindFirstChild("Event")
	if not (event and event:IsA("RemoteEvent")) then
		return false
	end

	local pin = tool:FindFirstChild("PinPulled")
	if not (pin and pin:IsA("BoolValue")) then
		return false
	end

	return tool:FindFirstChild("AnimsFolder") ~= nil
end

local function getGripPart(tool)
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle
	end

	local rightGrip = tool:FindFirstChild("RightGrip")
	if rightGrip and rightGrip:IsA("BasePart") then
		return rightGrip
	end

	return nil
end

local function findServerScript(tool)
	for _, child in ipairs(tool:GetChildren()) do
		if child:IsA("Script") then
			local low = string.lower(child.Name)
			if string.find(low, "server", 1, true) then
				return child
			end
		end
	end
	return nil
end

local function getScriptSource(scriptObject)
	if not scriptObject then
		return nil
	end
	local ok, source = pcall(function()
		return scriptObject.Source
	end)
	if ok and type(source) == "string" and #source > 0 then
		return source
	end
	return nil
end

local function parseSettings(source)
	local settings = {}
	local startPos = string.find(source, "local Settings%s*=%s*{")
	if not startPos then
		return settings
	end

	local braceStart = string.find(source, "{", startPos, true)
	if not braceStart then
		return settings
	end

	local depth = 0
	local braceEnd = nil
	for i = braceStart, #source do
		local ch = string.sub(source, i, i)
		if ch == "{" then
			depth += 1
		elseif ch == "}" then
			depth -= 1
			if depth == 0 then
				braceEnd = i
				break
			end
		end
	end

	if not braceEnd then
		return settings
	end

	local block = string.sub(source, braceStart + 1, braceEnd - 1)
	for key, raw in string.gmatch(block, "([%a_][%w_]*)%s*=%s*([^;\n,]+)") do
		local clean = string.gsub(raw, "%-%-.*", "")
		clean = string.gsub(clean, "%s+", "")
		local number = tonumber(clean)
		if number then
			settings[key] = number
		end
	end

	return settings
end

local function evalSimpleExpression(expr, settings)
	if not expr then
		return nil
	end

	local rewritten = string.gsub(expr, "Settings%.([%a_][%w_]*)", function(key)
		local v = settings[key]
		return v and tostring(v) or "0"
	end)
	rewritten = string.gsub(rewritten, "%s+", "")
	if rewritten == "" then
		return nil
	end

	local direct = tonumber(rewritten)
	if direct then
		return direct
	end

	local a, op, b = string.match(rewritten, "^(%-?[%d%.]+)([%+%-%*/])(%-?[%d%.]+)$")
	a = tonumber(a)
	b = tonumber(b)
	if not (a and b and op) then
		return nil
	end

	if op == "+" then
		return a + b
	elseif op == "-" then
		return a - b
	elseif op == "*" then
		return a * b
	elseif op == "/" then
		if b == 0 then
			return nil
		end
		return a / b
	end

	return nil
end

local function analyzeToolProfile(tool)
	local profile = {
		mode = "fallback",
		throwSpeed = CONFIG.DEFAULT_THROW_SPEED,
		maxPredictTime = CONFIG.MAX_PREDICT_TIME,
		throwFuse = CONFIG.DEFAULT_FUSE_TIME,
		pullFuse = nil,
		minFlight = 0,
		stopSpeed = nil,
		touchFuseDelay = nil,
		explodeOnTouch = false,
	}

	local handle = getGripPart(tool)
	local throwSoundId = nil
	local hasAttachmentX = false
	local hasClickDetector = false
	local hasBouncePack = false
	local hasSingleBounce = false
	if tool:FindFirstChild("Lighter") then
		profile.explodeOnTouch = true
	end
	if handle then
		hasAttachmentX = handle:FindFirstChild("X") ~= nil
		hasClickDetector = handle:FindFirstChild("ClickDetector") ~= nil
		hasBouncePack = handle:FindFirstChild("Bounce1") ~= nil
		hasSingleBounce = handle:FindFirstChild("Bounce") ~= nil

		if handle:FindFirstChild("ExtinguishS")
			or handle:FindFirstChild("FireIdle")
			or handle:FindFirstChild("Spark")
			or handle:FindFirstChild("CanForce")
		then
			profile.explodeOnTouch = true
		end

		local throwSound = handle:FindFirstChild("Throw")
		if throwSound and throwSound:IsA("Sound") then
			throwSoundId = tostring(throwSound.SoundId)
			if string.find(throwSoundId, "1657151608", 1, true) then
				profile.explodeOnTouch = true
			end
		end
	end

	local function applyStructuralFallback()
		if profile.explodeOnTouch then
			profile.mode = "fixed_after_pull"
			if tool:FindFirstChild("Lighter") then
				profile.pullFuse = 5
				profile.maxPredictTime = 3.5
			else
				profile.pullFuse = 7
				profile.maxPredictTime = 6.25
			end
			return
		end

		if hasBouncePack then
			if hasAttachmentX or hasClickDetector then
				profile.mode = "fixed_after_throw"
				profile.throwFuse = 2.5
				profile.maxPredictTime = 2.5
			else
				profile.mode = "fixed_after_throw"
				profile.throwFuse = 1.8 + CONFIG.THROW_DELAY_SAFETY
				profile.maxPredictTime = 1.8 + CONFIG.THROW_DELAY_SAFETY
			end
			return
		end

		if hasSingleBounce then
			if throwSoundId and string.find(throwSoundId, "360521794", 1, true) then
				profile.mode = "until_slow"
				profile.minFlight = 0.75
				profile.stopSpeed = 4
				profile.maxPredictTime = 4.8
			else
				profile.mode = "fixed_after_throw"
				profile.throwFuse = 1.8 + CONFIG.THROW_DELAY_SAFETY
				profile.maxPredictTime = 1.8 + CONFIG.THROW_DELAY_SAFETY
			end
		end
	end

	local serverScript = findServerScript(tool)
	local source = getScriptSource(serverScript)
	if not source then
		applyStructuralFallback()
		return profile
	end

	local settings = parseSettings(source)
	if settings.VELOCITY then
		profile.throwSpeed = settings.VELOCITY
	end

	if string.find(source, "Explode(Handle.CFrame,true)", 1, true)
		or string.find(source, "Explode(Handle.CFrame,\"Water\")", 1, true)
		or string.find(source, "Explode(\"Water\")", 1, true)
	then
		profile.explodeOnTouch = true
	end

	if string.find(source, "delay(Settings.ExplodeTime - Settings.PullTime", 1, true) and settings.ExplodeTime then
		profile.mode = "fixed_after_pull"
		profile.pullFuse = settings.ExplodeTime
		profile.maxPredictTime = math.max(0.2, settings.ExplodeTime)
		return profile
	end

	if string.find(source, "function DoTimer()", 1, true) and settings.ExplodeTime then
		profile.mode = "fixed_after_throw"
		profile.throwFuse = settings.ExplodeTime
		profile.maxPredictTime = math.max(0.2, settings.ExplodeTime)
		return profile
	end

	local minFlightExpr = string.match(source, "fastWait%(([^%)]+)%)%s*[\r\n]+%s*repeat%s+fastWait")
	local stopSpeedValue = tonumber(string.match(source, "until%s+Handle%.Velocity%.Magnitude%s*<=%s*([%d%.]+)"))
	local minFlightValue = evalSimpleExpression(minFlightExpr, settings)
	if stopSpeedValue and minFlightValue then
		profile.mode = "until_slow"
		profile.minFlight = math.max(0, minFlightValue)
		profile.stopSpeed = stopSpeedValue
		if stopSpeedValue <= 3 then
			profile.maxPredictTime = 5.1
		else
			profile.maxPredictTime = 4.6
		end
		return profile
	end

	local maxDelay = nil
	local minDelay = nil
	for expr in string.gmatch(source, "delay%(([^,]+),%s*function%s*%(") do
		local value = evalSimpleExpression(expr, settings)
		if value and value > 0 then
			if (not maxDelay) or value > maxDelay then
				maxDelay = value
			end
			if (not minDelay) or value < minDelay then
				minDelay = value
			end
		end
	end

	if maxDelay then
		profile.mode = "fixed_after_throw"
		profile.throwFuse = maxDelay + CONFIG.THROW_DELAY_SAFETY
		profile.maxPredictTime = math.max(0.2, maxDelay + CONFIG.THROW_DELAY_SAFETY)
		if minDelay and minDelay < maxDelay then
			profile.touchFuseDelay = minDelay
		end
	else
		applyStructuralFallback()
	end

	return profile
end

local function isFirstPerson(head)
	local camera = Workspace.CurrentCamera
	if not (camera and head) then
		return false
	end
	return (camera.CFrame.Position - head.Position).Magnitude <= 1.1
end

local function getSimulationWindow(state, nowTick)
	local profile = state.profile or {}
	local maxTime = profile.maxPredictTime or CONFIG.MAX_PREDICT_TIME
	local minFlight = 0
	local stopSpeed = nil
	local touchFuseDelay = profile.touchFuseDelay
	local explodeOnTouch = profile.explodeOnTouch == true

	if profile.mode == "fixed_after_throw" then
		maxTime = math.max(0.05, profile.throwFuse or CONFIG.DEFAULT_FUSE_TIME)
	elseif profile.mode == "fixed_after_pull" then
		local held = 0
		if state.pinPulledAt then
			held = nowTick - state.pinPulledAt
		end
		local remain = (profile.pullFuse or CONFIG.DEFAULT_FUSE_TIME) - held
		maxTime = math.max(0.05, remain)
	elseif profile.mode == "until_slow" then
		minFlight = profile.minFlight or 0
		stopSpeed = profile.stopSpeed
		maxTime = profile.maxPredictTime or CONFIG.UNTIL_SLOW_MAX_TIME
	end

	local timerValue = state.timerValue
	if timerValue and timerValue > 0 then
		if state.timerIsCountdown then
			maxTime = math.min(maxTime, math.max(0.05, timerValue))
		elseif profile.mode == "fallback" then
			maxTime = math.min(maxTime, timerValue)
		end
	end

	return maxTime, minFlight, stopSpeed, touchFuseDelay, explodeOnTouch
end

local function makeLineSegment(parent, color, transparency)
	local p = Instance.new("Part")
	p.Name = randomName("s_")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.new(0.08, 0.08, 0.08)
	p:SetAttribute("gt_line", true)
	p:SetAttribute("gt_run", runTag)
	p.Parent = parent
	return p
end

local function clearPool(pool)
	for i = 1, #pool do
		local part = pool[i]
		if part then
			part:Destroy()
		end
	end
	table.clear(pool)
end

local function placeSegment(part, p0, p1, thickness, color, transparency)
	local delta = p1 - p0
	local len = delta.Magnitude
	if len < 0.001 then
		part.Transparency = 1
		return
	end

	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.new(thickness, thickness, len)
	part.CFrame = CFrame.lookAt((p0 + p1) * 0.5, p1)
end

local function renderPath(points, pool, parent, color, transparency, thickness, clipNearCamera)
	local needed = math.max(0, #points - 1)
	local camera = clipNearCamera and Workspace.CurrentCamera or nil
	local skipUntil = 1
	if camera then
		local camPos = camera.CFrame.Position
		local near = CONFIG.CAMERA_NEAR_CLIP_DISTANCE
		while skipUntil < #points and (points[skipUntil] - camPos).Magnitude <= near do
			skipUntil += 1
		end
	end

	for i = 1, needed do
		local seg = pool[i]
		if not seg then
			seg = makeLineSegment(parent, color, transparency)
			pool[i] = seg
		elseif seg.Parent ~= parent then
			seg.Parent = parent
		end

		if i < skipUntil then
			seg.Parent = nil
			continue
		end

		placeSegment(seg, points[i], points[i + 1], thickness, color, transparency)
	end

	for i = needed + 1, #pool do
		local seg = pool[i]
		if seg then
			seg.Parent = nil
		end
	end
end

local function buildCastParams(ignoreTool)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false
	pcall(function()
		params.RespectCanCollide = true
	end)

	local cgName = rawget(_G, "CG_NCC")
	if type(cgName) == "string" and cgName ~= "" then
		local ok = pcall(function()
			params.CollisionGroup = cgName
		end)
		if not ok then
			local groupsOk, groups = pcall(function()
				return PhysicsService:GetRegisteredCollisionGroups()
			end)
			if groupsOk and type(groups) == "table" then
				for _, g in ipairs(groups) do
					if g and g.name == cgName then
						pcall(function()
							params.CollisionGroup = cgName
						end)
						break
					end
				end
			end
		end
	end

	local filter = {}
	local character = getCharacter()
	if character then
		table.insert(filter, character)
	end

	local chars = Workspace:FindFirstChild("Characters")
	if chars then
		table.insert(filter, chars)
	end

	if ignoreTool then
		table.insert(filter, ignoreTool)
	end

	params.FilterDescendantsInstances = filter
	return params
end

local function castWithRadius(origin, radius, direction, params)
	if typeof(Workspace.Spherecast) == "function" then
		return Workspace:Spherecast(origin, radius, direction, params)
	end
	return Workspace:Raycast(origin, direction, params)
end

local function pushPoint(points, point)
	local last = points[#points]
	if not last then
		points[1] = point
		return
	end
	if (last - point).Magnitude <= 0.01 then
		points[#points] = point
		return
	end
	table.insert(points, point)
end

local function simulateTrajectory(tool, state, nowTick)
	local character = getCharacter()
	local head = getHead(character)
	if not head then
		return {}
	end

	local startPos = head.Position
	local aimPoint = getAimPoint()
	local toAim = aimPoint - startPos
	if toAim.Magnitude < 0.001 then
		return {}
	end
	local direction = toAim.Unit
	local renderStartPos = startPos
	if isFirstPerson(head) then
		renderStartPos = startPos + (direction * CONFIG.FIRST_PERSON_START_OFFSET)
	end

	local handle = state.handle
	if not handle or not handle.Parent then
		return {}
	end

	local hb = handle:FindFirstChild("HB")
	local collisionPart = (hb and hb:IsA("BasePart")) and hb or handle
	local radius = math.max(collisionPart.Size.X, collisionPart.Size.Y, collisionPart.Size.Z) * 0.5
	local params = buildCastParams(tool)
	local profile = state.profile or {}
	local speed = state.learnedSpeed or profile.throwSpeed or CONFIG.DEFAULT_THROW_SPEED
	local gravity = Vector3.new(0, -Workspace.Gravity * CONFIG.EFFECTIVE_GRAVITY_SCALE, 0)
	local maxTime, minFlight, stopSpeed, touchFuseDelay, explodeOnTouch = getSimulationWindow(state, nowTick)
	maxTime = math.min(maxTime, CONFIG.UNTIL_SLOW_MAX_TIME)

	local points = {renderStartPos}
	local position = startPos
	local velocity = direction * speed
	local elapsed = 0
	local bounces = 0
	local dynamicMaxTime = maxTime

	while elapsed < dynamicMaxTime and #points < CONFIG.MAX_POINTS do
		local step = math.min(CONFIG.SIMULATION_DT, dynamicMaxTime - elapsed)
		local displacement = (velocity * step) + (0.5 * gravity * step * step)
		local hit = castWithRadius(position, radius, displacement, params)
		if hit and hit.Instance and hit.Instance ~= Workspace.Terrain and (not hit.Instance.CanCollide) then
			hit = nil
		end

		if hit then
			local travel = displacement.Magnitude
			local alpha = 1
			if travel > 1e-5 then
				alpha = math.clamp((hit.Position - position).Magnitude / travel, 0, 1)
			end

			local hitTime = step * alpha
			local centerAtHit = hit.Position + (hit.Normal * radius)
			pushPoint(points, centerAtHit)

			local impactVel = velocity + (gravity * hitTime)
			local normalSpeed = impactVel:Dot(hit.Normal)
			local normalVel = hit.Normal * normalSpeed
			local tangentVel = impactVel - normalVel

			if normalSpeed < 0 then
				local friction = state.surfaceFriction or 2
				local elasticity = state.surfaceElasticity or 0
				local upDot = math.abs(hit.Normal:Dot(Vector3.yAxis))
				local tangentDamping = math.clamp(1 - (friction * 0.15), CONFIG.BASE_MIN_TANGENT_DAMPING, CONFIG.BASE_MAX_TANGENT_DAMPING)
				local restitution = math.clamp(CONFIG.BASE_MIN_RESTITUTION + (elasticity * 0.85), CONFIG.BASE_MIN_RESTITUTION, CONFIG.BASE_MAX_RESTITUTION)

				if upDot > 0.75 then
					tangentDamping *= 0.9
					restitution *= 0.62
				elseif upDot < 0.35 then
					tangentDamping *= 0.78
					restitution *= 0.5
				else
					tangentDamping *= 0.84
					restitution *= 0.75
				end

				if impactVel.Magnitude <= CONFIG.LOW_SPEED_RESTITUTION_CUTOFF then
					restitution *= CONFIG.LOW_SPEED_RESTITUTION_MULT
				end

				velocity = (tangentVel * tangentDamping) - (normalVel * restitution)
			else
				local friction = state.surfaceFriction or 2
				local tangentDamping = math.clamp(1 - (friction * 0.15), CONFIG.BASE_MIN_TANGENT_DAMPING, CONFIG.BASE_MAX_TANGENT_DAMPING)
				velocity = impactVel * tangentDamping
			end

			position = centerAtHit + (hit.Normal * 0.02)

			if explodeOnTouch then
				dynamicMaxTime = math.min(dynamicMaxTime, elapsed + hitTime + 0.02)
				break
			end

			if touchFuseDelay then
				local touchFuseAt = elapsed + hitTime + touchFuseDelay
				if touchFuseAt < dynamicMaxTime then
					dynamicMaxTime = touchFuseAt
				end
			end

			bounces += 1
			if bounces >= CONFIG.MAX_BOUNCES then
				break
			end
		else
			position += displacement
			velocity += gravity * step
			pushPoint(points, position)
		end

		if velocity.Magnitude <= CONFIG.MIN_SPEED then
			break
		end

		if stopSpeed and elapsed >= minFlight and velocity.Magnitude <= stopSpeed then
			break
		end

		elapsed += step
	end

	return points
end

local toolStates = {}
local previewSegments = {}
local activeFlights = {}
local activeByPart = {}
local previewTool = nil
local lastPreviewTick = 0

local function addTool(tool)
	if toolStates[tool] or not isThrowableTool(tool) then
		return
	end

	local pin = tool:FindFirstChild("PinPulled")
	local timerObj = pin and pin:FindFirstChild("Timer")
	local handle = getGripPart(tool)
	local hb = handle and handle:FindFirstChild("HB")
	local collisionPart = (hb and hb:IsA("BasePart")) and hb or handle
	local friction = 2
	local elasticity = 0
	if collisionPart and collisionPart:IsA("BasePart") then
		local cpp = collisionPart.CustomPhysicalProperties
		if cpp then
			friction = cpp.Friction
			elasticity = cpp.Elasticity
		end
	end
	local state = {
		tool = tool,
		handle = handle,
		pin = pin,
		timerObj = timerObj,
		timerValue = (timerObj and timerObj:IsA("NumberValue")) and timerObj.Value or nil,
		lastTimerValue = (timerObj and timerObj:IsA("NumberValue")) and timerObj.Value or nil,
		timerIsCountdown = false,
		lastPin = pin and pin.Value or false,
		pinPulledAt = (pin and pin.Value) and os.clock() or nil,
		flightStarted = false,
		profile = analyzeToolProfile(tool),
		surfaceFriction = friction,
		surfaceElasticity = elasticity,
		learnedSpeed = nil,
	}
	if state.profile and state.profile.throwSpeed then
		state.learnedSpeed = state.profile.throwSpeed
	end
	toolStates[tool] = state
end

local function startFlight(state)
	local handle = state.handle
	if not handle or not handle:IsA("BasePart") or activeByPart[handle] then
		return
	end

	local flight = {
		part = handle,
		points = {},
		segments = {},
		lastSample = 0,
		startedAt = os.clock(),
	}
	activeByPart[handle] = flight
	table.insert(activeFlights, flight)

	local speedNow = handle.AssemblyLinearVelocity.Magnitude
	if speedNow > 40 then
		local base = (state.profile and state.profile.throwSpeed) or CONFIG.DEFAULT_THROW_SPEED
		state.learnedSpeed = math.clamp(speedNow, base * 0.85, base * 1.2)
	end
end

local function cleanupFlight(index)
	local flight = activeFlights[index]
	if not flight then
		return
	end
	activeByPart[flight.part] = nil
	clearPool(flight.segments)
	table.remove(activeFlights, index)
end

local function extractPositions(trailPoints)
	local out = table.create(#trailPoints)
	for i = 1, #trailPoints do
		out[i] = trailPoints[i].pos
	end
	return out
end

local function getEquippedThrowableTool()
	local character = getCharacter()
	if not character then
		return nil
	end

	for _, obj in ipairs(character:GetChildren()) do
		if obj:IsA("Tool") and toolStates[obj] then
			return obj
		end
	end
	return nil
end

local function scanForTools()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, obj in ipairs(backpack:GetChildren()) do
			addTool(obj)
		end
	end

	local character = getCharacter()
	if character then
		for _, obj in ipairs(character:GetChildren()) do
			addTool(obj)
		end
	end
end

RunService.RenderStepped:Connect(function()
	local nowTick = os.clock()
	scanForTools()

	local character = getCharacter()
	for tool, state in pairs(toolStates) do
		if not tool:IsDescendantOf(game) then
			if previewTool == tool then
				previewTool = nil
			end
			toolStates[tool] = nil
		else
			local pin = state.pin
			if pin and pin.Parent then
				if pin.Value ~= state.lastPin then
					state.lastPin = pin.Value
					if pin.Value then
						state.pinPulledAt = nowTick
					else
						state.pinPulledAt = nil
						state.flightStarted = false
						state.timerIsCountdown = false
						if state.timerObj and state.timerObj:IsA("NumberValue") then
							state.lastTimerValue = state.timerObj.Value
							state.timerValue = state.timerObj.Value
						end
					end
				end
			end

			if (not state.timerObj) or (not state.timerObj.Parent) then
				if pin and pin.Parent then
					local maybeTimer = pin:FindFirstChild("Timer")
					if maybeTimer and maybeTimer:IsA("NumberValue") then
						state.timerObj = maybeTimer
					end
				end
			end

			local timerObj = state.timerObj
			if timerObj and timerObj.Parent and timerObj:IsA("NumberValue") then
				local currentTimer = timerObj.Value
				local lastTimer = state.lastTimerValue
				state.timerValue = currentTimer
				if lastTimer and (currentTimer < (lastTimer - 0.01)) then
					state.timerIsCountdown = true
				end
				state.lastTimerValue = currentTimer
			else
				state.timerValue = nil
			end

			local handle = state.handle
			if handle and handle.Parent then
				if handle:IsDescendantOf(tool) then
					state.flightStarted = false
				elseif not state.flightStarted and handle:IsDescendantOf(Workspace) and (not character or not handle:IsDescendantOf(character)) then
					if handle.AssemblyLinearVelocity.Magnitude > CONFIG.FLIGHT_MIN_START_SPEED then
						state.flightStarted = true
						startFlight(state)
						if previewTool == tool then
							previewTool = nil
							renderPath({}, previewSegments, previewParent, CONFIG.PREVIEW_COLOR, CONFIG.PREVIEW_TRANSPARENCY, CONFIG.PREVIEW_THICKNESS, true)
						end
					end
				end
			end
		end
	end

	local equipped = getEquippedThrowableTool()
	if equipped ~= previewTool then
		previewTool = equipped
		lastPreviewTick = 0
	end

	if previewTool and (nowTick - lastPreviewTick >= CONFIG.PREVIEW_UPDATE_INTERVAL) then
		local state = toolStates[previewTool]
		if state then
			local points = simulateTrajectory(previewTool, state, nowTick)
			renderPath(points, previewSegments, previewParent, CONFIG.PREVIEW_COLOR, CONFIG.PREVIEW_TRANSPARENCY, CONFIG.PREVIEW_THICKNESS, true)
		end
		lastPreviewTick = nowTick
	elseif not previewTool then
		renderPath({}, previewSegments, previewParent, CONFIG.PREVIEW_COLOR, CONFIG.PREVIEW_TRANSPARENCY, CONFIG.PREVIEW_THICKNESS, true)
	end

	for i = #activeFlights, 1, -1 do
		local flight = activeFlights[i]
		local part = flight.part
		if (not part) or (not part.Parent) or (not part:IsDescendantOf(Workspace)) or (nowTick - flight.startedAt > CONFIG.MAX_LIVE_TIME) then
			cleanupFlight(i)
		else
			if nowTick - flight.lastSample >= CONFIG.LIVE_SAMPLE_DT then
				flight.lastSample = nowTick
				table.insert(flight.points, {pos = part.Position, t = nowTick})
			end

			while #flight.points > 0 and (nowTick - flight.points[1].t > CONFIG.LIVE_TTL) do
				table.remove(flight.points, 1)
			end

			if #flight.points <= 1 and part.AssemblyLinearVelocity.Magnitude < 1.2 and (nowTick - flight.startedAt > 0.25) then
				cleanupFlight(i)
			else
				renderPath(extractPositions(flight.points), flight.segments, liveParent, CONFIG.LIVE_COLOR, CONFIG.LIVE_TRANSPARENCY, CONFIG.LIVE_THICKNESS)
			end
		end
	end
end)
