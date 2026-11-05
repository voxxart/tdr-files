-- StarterPlayerScripts/EnemyRenderer.client.lua
-- Maximum-performance renderer:
--   * one PreRender connection
--   * sampled paths
--   * dense arrays
--   * one BulkMoveTo call per frame
--   * one compressed sync packet for ALL enemies
--   * no per-enemy render coroutine
--   * no per-enemy cleanup connection

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BezierPath = require(ReplicatedStorage.Modules:WaitForChild("BezierPath"))
local EnemyData = require(ReplicatedStorage.GameModules:WaitForChild("EnemyData"))

local Settings = EnemyData.Settings
local SAMPLE_COUNT = Settings.PathSampleCount or 512

local Events = ReplicatedStorage:WaitForChild("Events")
local ReplicateMob = Events:WaitForChild("ReplicateMob")
local RotateMob = Events:WaitForChild("RotateMob")
local EnemySync = Events:WaitForChild("EnemySync")

local Info = Workspace:WaitForChild("Info")
local GameSpeedValue = Info:WaitForChild("GameSpeed")

local gameSpeed =
	GameSpeedValue.Value ~= 0
	and GameSpeedValue.Value
	or 1

GameSpeedValue:GetPropertyChangedSignal("Value"):Connect(function()
	gameSpeed =
		GameSpeedValue.Value ~= 0
		and GameSpeedValue.Value
		or 1
end)

local MobsFolder = Workspace:WaitForChild("Mobs")
local ArrowsFolder = Workspace:FindFirstChild("Arrows")

local Active = {}
local ById = {}
local ByModel = setmetatable({}, { __mode = "k" })

local PathCache = setmetatable({}, { __mode = "k" })

local moveParts = {}
local moveCFrames = {}
local previousMoveCount = 0

local function currentMap()
	local mapContainer = Workspace:FindFirstChild("Map")

	if not mapContainer then
		return nil
	end

	return mapContainer:FindFirstChildOfClass("Folder")
		or mapContainer
end

local function sortedWaypoints(folder)
	local children = folder:GetChildren()

	table.sort(children, function(a, b)
		return (tonumber(a.Name) or math.huge)
			< (tonumber(b.Name) or math.huge)
	end)

	return children
end

local function buildPathCache(map)
	local cached = PathCache[map]

	if cached then
		return cached
	end

	cached = {}

	for id = 1, 4 do
		local folderName =
			(id == 1)
			and "Waypoints"
			or ("Waypoints" .. id)

		local folder = map:FindFirstChild(folderName)

		if folder then
			local positions = {}

			for _, waypoint in ipairs(sortedWaypoints(folder)) do
				if waypoint:IsA("BasePart") then
					positions[#positions + 1] = waypoint.Position
				end
			end

			if #positions >= 2 then
				local curve = BezierPath.new(
					positions,
					Settings.PathCurveResolution or 1.2
				)

				local samples = table.create(SAMPLE_COUNT + 1)

				for i = 0, SAMPLE_COUNT do
					samples[i + 1] =
						curve:CalculateUniformCFrame(i / SAMPLE_COUNT)
				end

				cached[id] = {
					Length = curve:GetPathLength(),
					Samples = samples,
					SampleCount = SAMPLE_COUNT,
				}
			end
		end
	end

	PathCache[map] = cached
	return cached
end

local function sampleCFrame(pathData, alpha)
	alpha = math.clamp(alpha, 0, 1)

	local scaled = alpha * pathData.SampleCount
	local lower = math.floor(scaled)
	local upper = math.min(lower + 1, pathData.SampleCount)
	local blend = scaled - lower

	local a = pathData.Samples[lower + 1]

	if upper == lower then
		return a
	end

	return a:Lerp(
		pathData.Samples[upper + 1],
		blend
	)
end

local function removeState(state)
	if not state or state.Removed then
		return
	end

	state.Removed = true

	ById[state.Id] = nil

	if state.Model then
		ByModel[state.Model] = nil
	end

	local index = state.Index
	local lastIndex = #Active
	local last = Active[lastIndex]

	if index and index <= lastIndex then
		if index ~= lastIndex then
			Active[index] = last
			last.Index = index
		end

		Active[lastIndex] = nil
	end

	state.Index = nil
	state.Model = nil
	state.Root = nil
	state.PathData = nil
	state.RotationTarget = nil
end

local function removeByModel(model)
	local state = ByModel[model]

	if state then
		removeState(state)
	end
end

local function createSummonEffectAnchor(cframe)
	local anchor = Instance.new("Part")
	anchor.Name = "EnemySummonFX"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CFrame = cframe
	anchor.Parent =
		Workspace:FindFirstChild("Visual")
		or Workspace

	return anchor
end

local function playOptionalSummonEffects(model, cframe, enemyId)
	local summonEffects =
		model:FindFirstChild("SummonEffects")

	if not summonEffects then
		return
	end

	local anchor =
		createSummonEffectAnchor(cframe)

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	for _, object in ipairs(summonEffects:GetDescendants()) do
		if object:IsA("ParticleEmitter") then
			local emitter = object:Clone()
			local emitCount =
				object:GetAttribute("EmitCount")
				or 20

			emitter.Enabled = false
			emitter.Parent = attachment
			emitter:Emit(
				math.max(
					0,
					math.floor(emitCount)
				)
			)
		end
	end

	local soundsFolder =
		summonEffects:FindFirstChild("Sounds")

	if soundsFolder then
		local sounds = {}

		for _, object in ipairs(soundsFolder:GetDescendants()) do
			if object:IsA("Sound") then
				sounds[#sounds + 1] = object
			end
		end

		if #sounds > 0 then
			local random =
				Random.new(
					tonumber(enemyId) or 0
				)

			local sound =
				sounds[
			random:NextInteger(
				1,
				#sounds
			)
			]:Clone()

			sound.PlaybackSpeed *= gameSpeed
			sound.Parent = anchor
			sound:Play()
		end
	end

	Debris:AddItem(anchor, 3)
end

MobsFolder.ChildRemoved:Connect(removeByModel)

if ArrowsFolder and ArrowsFolder ~= MobsFolder then
	ArrowsFolder.ChildRemoved:Connect(removeByModel)
end

local function registerMob(
	model,
	id,
	pathId,
	height,
	offsetX,
	offsetZ,
	alpha,
	speed,
	spawnStyle,
	emergenceDuration,
	emergenceDepth
)
	if not model or not id then
		return
	end

	local map = currentMap()
	if not map then
		return
	end

	local pathData = buildPathCache(map)[pathId]

	if not pathData then
		warn("[EnemyRenderer] Missing path:", pathId)
		return
	end

	local root =
		model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildWhichIsA("BasePart")

	if not root then
		return
	end

	model.PrimaryPart = root

	local state = {
		Id = id,
		Index = #Active + 1,

		Model = model,
		Root = root,

		PathData = pathData,

		Alpha = alpha or 0,
		Speed = speed or 0,

		SpawnStyle = spawnStyle,
		EmergenceDuration =
			math.max(
				0.01,
				emergenceDuration or 0.65
			),
		EmergenceDepth =
			math.max(
				0,
				emergenceDepth or 3.5
			),
		EmergenceProgress =
			(spawnStyle == "GroundSummon")
			and 0
			or 1,

		Height = height or 0,
		Offset = Vector3.new(
			(offsetX or 0) / 100,
			0,
			(offsetZ or 0) / 100
		),

		RotationTarget = nil,
		RotationEndTime = 0,

		Removed = false,
	}

	Active[state.Index] = state
	ById[id] = state
	ByModel[model] = state

	if state.SpawnStyle == "GroundSummon" then
		local groundCFrame =
			sampleCFrame(
				state.PathData,
				state.Alpha
			)
			+ Vector3.new(
				state.Offset.X,
				state.Height,
				state.Offset.Z
			)

		-- Move it underground immediately so there is no one-frame pop at
		-- ground level before PreRender starts.
		root.CFrame =
			groundCFrame
			+ Vector3.new(
				0,
				-state.EmergenceDepth,
				0
			)

		playOptionalSummonEffects(
			model,
			CFrame.new(
				groundCFrame.Position
			),
			id
		)
	end
end

ReplicateMob.OnClientEvent:Connect(registerMob)

RotateMob.OnClientEvent:Connect(function(model, part, duration)
	local state = ByModel[model]

	if not state then
		return
	end

	if part then
		state.RotationTarget = part
		state.RotationEndTime =
			os.clock() + (duration or 0)
	else
		state.RotationTarget = nil
		state.RotationEndTime = 0
	end
end)

EnemySync.OnClientEvent:Connect(function(packet)
	if typeof(packet) ~= "buffer" then
		return
	end

	local length = buffer.len(packet)

	if length < 2 then
		return
	end

	local count = buffer.readu16(packet, 0)
	local offset = 2

	for _ = 1, count do
		if offset + 7 >= length then
			break
		end

		local id = buffer.readu32(packet, offset)
		local alphaQ = buffer.readu16(packet, offset + 4)
		local speedQ = buffer.readi16(packet, offset + 6)

		offset += 8

		local state = ById[id]

		if state then
			local authoritativeAlpha = alphaQ / 65535
			local authoritativeSpeed = speedQ / 100

			local errorAmount =
				authoritativeAlpha - state.Alpha

			if math.abs(errorAmount) > 0.06 then
				state.Alpha = authoritativeAlpha
			else
				state.Alpha += errorAmount * 0.35
			end

			-- The server intentionally reports 0 speed while a summoned
			-- enemy is emerging. Keep the original movement speed locally so
			-- it can start immediately when the emergence finishes.
			if state.EmergenceProgress >= 1
				or authoritativeSpeed ~= 0
			then
				state.Speed = authoritativeSpeed
			end
		end
	end
end)

RunService.PreRender:Connect(function(dt)
	local now = os.clock()
	local count = 0

	for i = 1, #Active do
		local state = Active[i]
		local model = state.Model
		local root = state.Root

		if not (
			state.Removed
				or not model
				or not model.Parent
				or not root
				or not root.Parent
			) then
			local emerging =
				state.EmergenceProgress < 1

			if emerging then
				state.EmergenceProgress =
					math.min(
						1,
						state.EmergenceProgress
						+ (
							dt
							* gameSpeed
							/ state.EmergenceDuration
						)
					)
			elseif state.Speed ~= 0
				and state.PathData.Length > 0
			then
				state.Alpha +=
					(state.Speed * gameSpeed * dt)
					/ state.PathData.Length
			end

			local baseCFrame =
				sampleCFrame(
					state.PathData,
					state.Alpha
				)
				+ Vector3.new(
					state.Offset.X,
					state.Height,
					state.Offset.Z
				)

			if emerging then
				local progress =
					state.EmergenceProgress

				-- Fast quartic ease-out:
				-- starts deep underground, rises quickly, then gently settles.
				local inverse = 1 - progress
				local eased =
					1 - (
						inverse
						* inverse
						* inverse
						* inverse
					)

				-- Small soft "pop" near the surface without changing gameplay
				-- position. Ends exactly at zero offset.
				local settle =
					math.sin(
						progress * math.pi
					)
					* 0.16
					* inverse

				local riseOffset =
					(-state.EmergenceDepth * (1 - eased))
					+ settle

				baseCFrame +=
					Vector3.new(
						0,
						riseOffset,
						0
					)
			end

			local rotationTarget = state.RotationTarget

			if rotationTarget
				and rotationTarget.Parent
				and now < state.RotationEndTime
			then
				local lookPos = Vector3.new(
					rotationTarget.Position.X,
					baseCFrame.Position.Y,
					rotationTarget.Position.Z
				)

				baseCFrame = CFrame.lookAt(
					baseCFrame.Position,
					lookPos
				)
			else
				state.RotationTarget = nil
			end

			count += 1
			moveParts[count] = root
			moveCFrames[count] = baseCFrame
		end
	end

	for i = count + 1, previousMoveCount do
		moveParts[i] = nil
		moveCFrames[i] = nil
	end

	previousMoveCount = count

	if count > 0 then
		Workspace:BulkMoveTo(
			moveParts,
			moveCFrames,
			Enum.BulkMoveMode.FireCFrameChanged
		)
	end
end)
