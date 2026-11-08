-- StarterPlayerScripts/EnemyRenderer.client.lua
-- Shared renderer with bounded sync, spawn recovery, and distance update rates.
--   * one PreRender connection
--   * sampled paths
--   * dense arrays
--   * one BulkMoveTo call per frame
--   * bounded timestamped sync packets; stale records rejected
--   * no per-enemy render coroutine
--   * no per-enemy cleanup connection

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BezierPath = require(ReplicatedStorage.Modules:WaitForChild("BezierPath"))
local EnemyData = require(ReplicatedStorage.GameModules:WaitForChild("EnemyData"))
local SyncCodec = require(ReplicatedStorage.GameModules:WaitForChild("EnemySyncCodec"))

local Settings = EnemyData.Settings
local SAMPLE_COUNT = Settings.PathSampleCount or 512

local Events = ReplicatedStorage:WaitForChild("Events")
local ReplicateMob = Events:WaitForChild("ReplicateMob")
local RotateMob = Events:WaitForChild("RotateMob")
local EnemySync = Events:WaitForChild("EnemySync")

local Info = Workspace:WaitForChild("Info")
local GameSpeedValue = Info:WaitForChild("GameSpeed")

local gameSpeed = math.max(GameSpeedValue.Value, 0)
GameSpeedValue:GetPropertyChangedSignal("Value"):Connect(function()
	gameSpeed = math.max(GameSpeedValue.Value, 0)
end)
local visualGameTime = 0
local summonEffectsBudget = Settings.SummonEffectsPerFrame or 8
local function running()
	return Info.GameRunning.Value and Info.Message.Value ~= 'VICTORY' and Info.Message.Value ~= 'GAME OVER'
end

local MobsFolder = Workspace:WaitForChild("Mobs")
local ArrowsFolder = Workspace:FindFirstChild("Arrows")

local Active = {}
local ById = {}
local ByModel = setmetatable({}, { __mode = "k" })

local PathCache = setmetatable({}, { __mode = "k" })
local PathRetryAt = setmetatable({}, { __mode = "k" })

local moveParts = {}
local moveCFrames = {}
local previousMoveCount = 0
local Pending = {}
local PendingByModel = {}
local pendingCursor = 1
local function queueMob(model,args)
	if not model or not model.Parent or not running() then return end
	local existing=PendingByModel[model]
	if existing then if args then existing.Args=args end; return end
	local record={Model=model,Args=args,Deadline=os.clock()+(Settings.RegistrationTimeout or 10),Index=#Pending+1}
	Pending[record.Index]=record; PendingByModel[model]=record
end
local function removePending(record)
	if not record or not record.Index then return end
	local last=Pending[#Pending]
	Pending[record.Index]=last; last.Index=record.Index
	Pending[#Pending]=nil; PendingByModel[record.Model]=nil; record.Index=nil
end

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
	removePending(PendingByModel[model])
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

	if not summonEffects or summonEffectsBudget <= 0 then return end
	summonEffectsBudget -= 1

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
	if not model or not model.Parent or not id or not running() then return false end
	if ByModel[model] and ByModel[model].Id == id then return true end
	if ByModel[model] then removeState(ByModel[model]) end
	if ById[id] then removeState(ById[id]) end

	local map = currentMap()
	if not map then
		return
	end

	local pathData = buildPathCache(map)[pathId]
	if not pathData and os.clock() >= (PathRetryAt[map] or 0) then
		PathRetryAt[map] = os.clock() + 0.5
		PathCache[map] = nil
		pathData = buildPathCache(map)[pathId]
	end

	if not pathData then
		return
	end

	local root = model.PrimaryPart
	if not root or not root.Parent then
		root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
	end
	if not root or not root.Parent then return false end

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
		NextRender = 0,
		Position = root.Position,
		Offset = Vector3.new(
			(offsetX or 0) / 100,
			height or 0,
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
			+ state.Offset

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
	return true
end

ReplicateMob.OnClientEvent:Connect(function(model,...)
	if not registerMob(model,...) then queueMob(model,table.pack(...)) end
end)
local function observeFolder(folder)
	if not folder then return end
	folder.ChildAdded:Connect(function(model) queueMob(model) end)
	for _,model in folder:GetChildren() do queueMob(model) end
end
observeFolder(MobsFolder)
if ArrowsFolder ~= MobsFolder then observeFolder(ArrowsFolder) end
local function recoverMob(model)
	local stats=model:FindFirstChild('EnemyStats')
	local speed=stats and stats:FindFirstChild('Speed')
	local alpha=model:FindFirstChild('Alpha')
	local id,pathId=model:GetAttribute('EnemyId'),model:GetAttribute('PathId')
	local height=model:GetAttribute('EnemyHeight')
	if not id or not pathId or not height or not speed or not alpha then return false end
	-- Recover current movement only; joining/streaming must not replay spawn VFX.
	return registerMob(model,id,pathId,height,model:GetAttribute('EnemyOffsetX'),model:GetAttribute('EnemyOffsetZ'),alpha.Value,speed.Value)
end
local function processPending()
	local attempts=math.min(#Pending,Settings.RegistrationBudget or 64)
	for _=1,attempts do
		if #Pending==0 then break end
		if pendingCursor>#Pending then pendingCursor=1 end
		local record=Pending[pendingCursor]
		local model=record.Model
		local done=not model.Parent or os.clock()>=record.Deadline
		if not done then
			if record.Args then done=registerMob(model,table.unpack(record.Args,1,record.Args.n))
			else done=recoverMob(model) end
		end
		if done then removePending(record) else pendingCursor+=1 end
	end
end
local function clearRenderer()
	if running() then return end
	for index=#Active,1,-1 do removeState(Active[index]) end
	table.clear(Pending); table.clear(PendingByModel); pendingCursor=1
	table.clear(PathCache); table.clear(PathRetryAt); table.clear(moveParts); table.clear(moveCFrames); previousMoveCount=0
end
Info.GameRunning.Changed:Connect(function()
	clearRenderer()
	if running() then
		for _,model in MobsFolder:GetChildren() do queueMob(model) end
		if ArrowsFolder and ArrowsFolder~=MobsFolder then for _,model in ArrowsFolder:GetChildren() do queueMob(model) end end
	end
end)
Info.Message.Changed:Connect(clearRenderer)

RotateMob.OnClientEvent:Connect(function(model, part, duration)
	local state = ByModel[model]

	if not state then
		return
	end

	if part then
		state.RotationTarget = part
		state.RotationEndTime =
			visualGameTime + (duration or 0)
	else
		state.RotationTarget = nil
		state.RotationEndTime = 0
	end
end)

local function applySync(id,alpha,speed,sequence,timestamp)
	local state=ById[id]
	if not state or not SyncCodec.IsNewer(sequence,state.Sequence) then return end
	state.Sequence=sequence
	local age=math.clamp(Workspace:GetServerTimeNow()-timestamp,0,0.5)
	if state.EmergenceProgress>=1 and state.PathData.Length>0 then
		alpha=math.clamp(alpha+speed*gameSpeed*age/state.PathData.Length,0,1)
	end
	local errorAmount=alpha-state.Alpha
	if math.abs(errorAmount)>0.06 then state.Alpha=alpha else state.Alpha+=errorAmount*0.35 end
	if state.EmergenceProgress>=1 or speed~=0 then state.Speed=speed end
end
EnemySync.OnClientEvent:Connect(function(packet) SyncCodec.Decode(packet,applySync) end)

RunService.PreRender:Connect(function(dt)
	if not running() then clearRenderer(); return end
	processPending()
	summonEffectsBudget = Settings.SummonEffectsPerFrame or 8
	visualGameTime += dt * gameSpeed
	local now = visualGameTime
	local wall = os.clock()
	local camera = Workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position
	local count = 0

	for i = #Active, 1, -1 do
		local state = Active[i]
		local model = state.Model
		local root = state.Root

		if state.Removed or not model or not model.Parent or not root or not root.Parent then
			if model and model.Parent then queueMob(model) end
			removeState(state)
		else
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

			if wall < state.NextRender then continue end
			local hz = Settings.NearRenderHz or 60
			if cameraPosition then
				local delta = state.Position-cameraPosition
				local distanceSquared = delta:Dot(delta)
				if distanceSquared > (Settings.FarRenderDistance or 260)^2 then hz = Settings.FarRenderHz or 10
				elseif distanceSquared > (Settings.NearRenderDistance or 120)^2 then hz = Settings.MidRenderHz or 30 end
				if delta:Dot(camera.CFrame.LookVector) < 0 then hz = Settings.FarRenderHz or 10 end
			end
			if emerging or state.RotationTarget then hz = Settings.NearRenderHz or 60 end
			local interval = 1/math.max(hz,1)
			if state.RenderHz ~= hz then
				state.NextRender = wall + interval*(0.25+0.75*((state.Id*0.61803398875)%1))
				state.RenderHz = hz
			else
				state.NextRender += interval*math.max(1,math.floor((wall-state.NextRender)/interval)+1)
			end

			local baseCFrame =
				sampleCFrame(
					state.PathData,
					state.Alpha
				)
				+ state.Offset

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

			state.Position = baseCFrame.Position
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
