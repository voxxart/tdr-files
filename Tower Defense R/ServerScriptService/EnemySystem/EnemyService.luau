-- ServerScriptService/EnemySystem/EnemyService.lua
-- Shared enemy simulation with bounded replication and legacy compatibility.
--
-- Biggest differences from the previous version:
--   * NO CorrectMob remote fired once per enemy.
--   * Compressed EnemySync packets bounded below the unreliable payload limit.
--   * NO repeated Bezier evaluation during movement.
--   * ONE server scheduler.
--   * ONE BulkMoveTo call per server position tick.
--   * Speed is mirrored only when it CHANGES.
--   * Alpha compatibility writes are throttled.
--   * Dense runtime array, swap-removal, cached Instance refs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyData = require(ReplicatedStorage.GameModules:WaitForChild("EnemyData"))

local EnemyRuntime = require(script.Parent:WaitForChild("EnemyRuntime"))
local EnemyPaths = require(script.Parent:WaitForChild("EnemyPaths"))
local EnemyFlags = require(script.Parent:WaitForChild("EnemyFlags"))
local EnemyEffects = require(script.Parent:WaitForChild("EnemyEffects"))
local EnemyDamage = require(script.Parent:WaitForChild("EnemyDamage"))
local LegacyEffects = require(script.Parent.LegacyEffects)
local SyncCodec = require(ReplicatedStorage.GameModules.EnemySyncCodec)

local TowerDeath = require(game.ServerScriptService.Main:WaitForChild("TowerDeath"))

local Match = require(game.ServerScriptService.Simulation.MatchService)
local EnemyService = {}

local Settings = EnemyData.Settings
local FLAGS = EnemyData.Flags

local Events = ReplicatedStorage:WaitForChild("Events")
local ReplicateMob = Events:WaitForChild("ReplicateMob")
local RotateMob = Events:WaitForChild("RotateMob")
local BaseDamaged = Events:FindFirstChild("BaseDamaged")

local function getOrCreateRemote(name, className)
	local existing = Events:FindFirstChild(name)
	if existing then
		return existing
	end

	local remote

	if className == "UnreliableRemoteEvent" then
		local ok, result = pcall(Instance.new, "UnreliableRemoteEvent")

		if ok then
			remote = result
		else
			remote = Instance.new("RemoteEvent")
		end
	else
		remote = Instance.new(className)
	end

	remote.Name = name
	remote.Parent = Events
	return remote
end

local EnemySync = getOrCreateRemote("EnemySync", "UnreliableRemoteEvent")
local EnemyExplosion = getOrCreateRemote("EnemyExplosion", "RemoteEvent")
local EnemyDeath = getOrCreateRemote("EnemyDeath", "RemoteEvent")

local Info = Workspace:WaitForChild("Info")
local MobsFolder = Workspace:WaitForChild("Mobs")
local ArrowsFolder = Workspace:FindFirstChild("Arrows") or MobsFolder
local TowersFolder = Workspace:WaitForChild("Towers")

local SERVER_POS_INTERVAL = 1 / math.max(Settings.ServerPositionHz or 10, 1)
local CLIENT_SYNC_INTERVAL = 1 / math.max(Settings.ClientSyncHz or 5, 1)
local ALPHA_MIRROR_HZ = Settings.AlphaMirrorHz or 0
local ALPHA_MIRROR_INTERVAL =
	(ALPHA_MIRROR_HZ > 0)
	and (1 / ALPHA_MIRROR_HZ)
	or math.huge

local HealthMultiPlr = {
	[1] = 1,
	[2] = 1.16,
	[3] = 1.32,
	[4] = 1.5,
}

local towerCount = #TowersFolder:GetChildren()

TowersFolder.ChildAdded:Connect(function()
	towerCount += 1
end)

TowersFolder.ChildRemoved:Connect(function()
	towerCount = math.max(0, towerCount - 1)
end)

local GameSpeedValue = Info:FindFirstChild("GameSpeed")
local GameSpeed = GameSpeedValue and GameSpeedValue.Value or 1

if GameSpeedValue then
	GameSpeedValue:GetPropertyChangedSignal("Value"):Connect(function()
		GameSpeed = math.max(GameSpeedValue.Value, 0)
	end)
end

local function getGameSpeed()
	return math.max(GameSpeed, 0)
end

local function incrementEnemyCount()
	local value = Info:FindFirstChild("EnemyInGame")
	if value then
		value.Value += 1
	end
end

local function decrementEnemyCount()
	local value = Info:FindFirstChild("EnemyInGame")
	if value then
		value.Value = math.max(0, value.Value - 1)
	end
end

local function addPlayerKill()
	for _, player in ipairs(Players:GetPlayers()) do
		local kills = player:FindFirstChild("Kills")
		if kills then
			kills.Value += 1
		end
	end
end

local function setCollisionGroup(model, group)
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.CollisionGroup = group
		end
	end
end

local function effectiveSpeed(runtime, now)
	if runtime.SpawnDelayRemaining > 0 then
		return 0
	end

	if runtime.StunUntil > now then
		return 0
	end

	return runtime.Speed
end

local function runtimeCFrame(runtime)
	return EnemyPaths.SampleCFrame(
		runtime.PathData,
		runtime.Alpha
	) + Vector3.new(
		runtime.OffsetX / 100,
		runtime.Height,
		runtime.OffsetZ / 100
	)
end

local function mirrorSpeed(runtime, value)
	if runtime.SpeedValue
		and runtime.SpeedValue.Parent
		and runtime.SpeedValue.Value ~= value
	then
		runtime.SpeedValue.Value = value
	end
end

local function createCompatibilityEffects(model)
	local effects = model:FindFirstChild("Effects")

	if not effects then
		effects = Instance.new("Folder")
		effects.Name = "Effects"
		effects.Parent = model
	end

	local function ensure(className, name, default)
		local value = effects:FindFirstChild(name)

		if not value then
			value = Instance.new(className)
			value.Name = name
			value.Value = default
			value.Parent = effects
		end

		return value
	end

	ensure("BoolValue", "IsBurning", false)
	ensure("NumberValue", "BurnTime", 0)
	ensure("NumberValue", "FireDamage", 0)

	ensure("BoolValue", "IsBleeding", false)
	ensure("NumberValue", "BleedTime", 0)
	ensure("NumberValue", "BleedDamage", 0)
	ensure("NumberValue", "BleedMultiplier", 1)

	ensure("BoolValue", "IsStunned", false)
	ensure("NumberValue", "StunTime", 0)

	ensure("NumberValue", "DefenseMelted", 0)
	ensure("BoolValue", "MeltActive", false)
	ensure("BoolValue", "HasBeenSlowed", false)

	return effects
end

local function bindCompatibility(runtime)
	LegacyEffects.Bind(runtime, createCompatibilityEffects(runtime.Model))
end

local function calculateBaseStats(template, healthMultiplier, speedMultiplier)
	local modelStats = template:FindFirstChild("EnemyStats")
	if not modelStats then
		return nil
	end

	local maxHealth = modelStats:FindFirstChild("MaxHealth")
	local speed = modelStats:FindFirstChild("Speed")
	local hip = modelStats:FindFirstChild("HipHeight")

	if not (maxHealth and speed and hip) then
		return nil
	end

	local definition = EnemyData.Enemies[template.Name]

	-- EnemyData is an OPTIONAL static balance override.
	-- Missing fields safely fall back to the values authored on the enemy model.
	local baseMaxHealth =
		definition
		and typeof(definition.MaxHealth) == "number"
		and definition.MaxHealth
		or maxHealth.Value

	local baseSpeed =
		definition
		and typeof(definition.Speed) == "number"
		and definition.Speed
		or speed.Value

	-- HipHeight is rig/model geometry, not balance data.
	-- Always trust the template so adding an EnemyData entry can never
	-- accidentally sink or raise an enemy.
	local hipHeight = hip.Value

	local flags =
		definition
		and typeof(definition.Flags) == "number"
		and definition.Flags
		or EnemyFlags.FromEnemyStats(modelStats)

	local playerCount = math.clamp(Info.PlrValue.Value, 1, 4)
	local playerMultiplier = HealthMultiPlr[playerCount] or 1

	local hpMultiplier =
		(healthMultiplier or 1)
		* Info.EnemyHPMultiplier.Value
		* playerMultiplier

	local maxHealth = math.round(baseMaxHealth * hpMultiplier)

	if template:FindFirstChild("IsFinalBoss")
		and Info.EnemyMultiplier.Value > 1
	then
		maxHealth *= 2
		flags = EnemyFlags.Add(flags, FLAGS.FinalBoss)
	end

	return {
		MaxHealth = maxHealth,
		Speed = baseSpeed * (speedMultiplier or 1),
		HipHeight = hipHeight,
		Flags = flags,
	}
end

local function applyDeathWish(runtime)
	local modifiers = Info:FindFirstChild("Modifiers")
	local deathWish = modifiers and modifiers:FindFirstChild("Death Wish")

	if not (deathWish and deathWish.Value) then
		return
	end

	local stats = runtime.Stats

	if stats then
		local defense = stats:FindFirstChild("Defense")

		if defense then
			local percent = defense:FindFirstChild("DefensePercentValue")
			local value = defense:FindFirstChild("DefenseValue")

			if percent then percent.Value += 20 end
			if value then value.Value += 0.20 end
		end
	end

	local playerCount = math.max(1, Info.PlrValue.Value)

	runtime.BaseSpeed *= 1.05 * playerCount
	runtime.Speed = runtime.BaseSpeed

	if runtime.OrigSpeedValue then
		runtime.OrigSpeedValue.Value = runtime.BaseSpeed
	end

	mirrorSpeed(runtime, runtime.Speed)
end

function EnemyService.Destroy(runtime, reason)
	if not runtime or runtime.Cleaned then
		return
	end

	runtime.Dead = true

	local model = runtime.Model

	EnemyRuntime.Remove(runtime)

	if model and model.Parent then
		model:Destroy()
	end

	decrementEnemyCount()

	if reason == "Killed" or reason == "ReachedBase" then
		addPlayerKill()
	end

	runtime.Model = nil
	runtime.PathData = nil
	runtime.Map = nil
end

function EnemyService.Damage(runtimeOrModel, amount, damageType)
	local runtime = runtimeOrModel

	if typeof(runtimeOrModel) == "Instance" then
		runtime = EnemyRuntime.Get(runtimeOrModel)
	end

	if not runtime or runtime.Dead then
		return 0
	end

	local dealt = EnemyDamage.Damage(runtime, amount)

	if runtime.Health <= 0 then
		EnemyService.OnDeath(runtime)
	end

	return dealt
end

local function fireDeathPresentation(runtime)
	-- Death presentation is entirely client-side.
	-- The server gameplay object can therefore disappear immediately.
	local templateFolder = ReplicatedStorage:FindFirstChild("Mobs")
	local template =
		templateFolder
		and templateFolder:FindFirstChild(runtime.Name)

	if not template
		or not template:FindFirstChild("DeathEffects")
	then
		return
	end

	EnemyDeath:FireAllClients(
		runtime.Name,
		runtimeCFrame(runtime),
		runtime.Id
	)
end

function EnemyService.OnDeath(runtime)
	if not runtime or runtime.Dead or runtime.Cleaned then
		return
	end

	-- Mark dead BEFORE doing anything else so movement/effects can never
	-- process this enemy again in the same Heartbeat.
	runtime.Dead = true
	runtime.Health = 0

	if runtime.HealthValue
		and runtime.HealthValue.Parent
		and runtime.HealthValue.Value ~= 0
	then
		runtime.HealthValue.Value = 0
	end

	local stats = runtime.Stats
	local radiusValue = stats and stats:FindFirstChild("ExplosionRadius")

	if radiusValue and radiusValue.Value > 0 then
		EnemyService.Explode(runtime, radiusValue.Value)
	end

	fireDeathPresentation(runtime)

	-- Gameplay model dies NOW. Clients recreate an optional lightweight
	-- death presentation from ReplicatedStorage, so dead enemies cannot
	-- keep walking or remain targetable.
	EnemyService.Destroy(runtime, "Killed")
end

function EnemyService.FacePart(runtimeOrModel, part, duration)
	local runtime = runtimeOrModel

	if typeof(runtimeOrModel) == "Instance" then
		runtime = EnemyRuntime.Get(runtimeOrModel)
	end

	if runtime and runtime.Model then
		RotateMob:FireAllClients(
			runtime.Model,
			part,
			duration
		)
	end
end

function EnemyService.ApplyBurn(runtimeOrModel, duration, damage)
	local runtime = runtimeOrModel

	if typeof(runtimeOrModel) == "Instance" then
		runtime = EnemyRuntime.Get(runtimeOrModel)
	end

	if runtime then
		EnemyEffects.ApplyBurn(runtime, duration, damage)
	end
end

function EnemyService.ApplyBleed(runtimeOrModel, duration, damage, multiplier)
	local runtime = runtimeOrModel

	if typeof(runtimeOrModel) == "Instance" then
		runtime = EnemyRuntime.Get(runtimeOrModel)
	end

	if runtime then
		EnemyEffects.ApplyBleed(runtime, duration, damage, multiplier)
	end
end

function EnemyService.ApplyStun(runtimeOrModel, duration)
	local runtime = runtimeOrModel

	if typeof(runtimeOrModel) == "Instance" then
		runtime = EnemyRuntime.Get(runtimeOrModel)
	end

	if runtime then
		EnemyEffects.ApplyStun(runtime, duration)
	end
end

function EnemyService.Explode(runtimeOrModel, radius)
	local runtime = runtimeOrModel

	if typeof(runtimeOrModel) == "Instance" then
		runtime = EnemyRuntime.Get(runtimeOrModel)
	end

	if not runtime then return end

	local origin = runtimeCFrame(runtime).Position
	local radiusSq = radius * radius

	-- Damage towers only when towers actually exist.
	if towerCount > 0 then
		for _, tower in ipairs(TowersFolder:GetChildren()) do
			local root = tower.PrimaryPart or tower:FindFirstChild("HumanoidRootPart")
			if not root then continue end

			local delta = root.Position - origin
			local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z

			if distSq > radiusSq then
				continue
			end

			local config = tower:FindFirstChild("Config")
			local healthFolder = config and config:FindFirstChild("Health")
			local health = healthFolder and healthFolder:FindFirstChild("HealthValue")
			local maxHealth = healthFolder and healthFolder:FindFirstChild("MaxHealth")

			local flying =
				config
				and (
					config:FindFirstChild("Aviator")
					or config:FindFirstChild("Flying")
				)

			if config and not flying then
				local stunned = config:FindFirstChild("Stunned")

				if not stunned then
					stunned = Instance.new("NumberValue")
					stunned.Name = "Stunned"
					stunned.Parent = config
				end

				stunned.Value = math.max(stunned.Value, 3)
			end

			if health and maxHealth and not flying then
				health.Value = math.max(
					0,
					health.Value - math.round(maxHealth.Value * 0.125)
				)
			end

			if health and health.Value <= 0 then
				local ownerName =
					config
					and config:FindFirstChild("Owner")
					and config.Owner.Value

				local ownerPlayer =
					ownerName
					and Players:FindFirstChild(ownerName)

				local deathEvent = Events:FindFirstChild("AnimateTowerDeath")

				if deathEvent then
					deathEvent:FireAllClients(
						tower,
						"TowerDeath",
						tower
					)
				end

				Match.After(
					runtime.MatchGeneration, 0.5,
					function()
						if tower and tower.Parent then
							TowerDeath.KillTower(
								tower,
								ownerPlayer
							)
						end
					end
				)
			end
		end
	end

	EnemyExplosion:FireAllClients(origin, radius)
end

local function registerEnemy(model, map, pathData, options)
	if not Match.IsCurrent(Match.Capture()) then
		model:Destroy()
		return nil
	end
	options = options or {}

	local scaled = calculateBaseStats(
		model,
		options.HealthMultiplier or 1,
		options.SpeedMultiplier or 1
	)

	if not scaled then
		model:Destroy()
		return nil
	end

	local stats = model:FindFirstChild("EnemyStats")
	local hitbox = model:FindFirstChild("Hitbox")
	local root =
		model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildWhichIsA("BasePart")

	if not (stats and hitbox and root) then
		model:Destroy()
		return nil
	end

	model.PrimaryPart = root

	-- The old enemy mover explicitly anchored HumanoidRootPart.
	-- Keep that behavior: the server only moves the authoritative Hitbox,
	-- while EnemyRenderer moves the visible root locally. If the root is not
	-- anchored, gravity/physics can pull the visible rig away while the Hitbox
	-- continues down the path, making the enemy appear to vanish.
	root.Anchored = true
	hitbox.Anchored = true

	local healthValue = stats:FindFirstChild("Health")
	local maxHealthValue = stats:FindFirstChild("MaxHealth")
	local speedValue = stats:FindFirstChild("Speed")
	local origSpeedValue = stats:FindFirstChild("OrigSpeed")
	local hipHeightValue = stats:FindFirstChild("HipHeight")

	if not (healthValue and maxHealthValue and speedValue and hipHeightValue) then
		model:Destroy()
		return nil
	end

	local alphaValue = model:FindFirstChild("Alpha")

	if not alphaValue then
		alphaValue = Instance.new("NumberValue")
		alphaValue.Name = "Alpha"
		alphaValue.Parent = model
	end

	local height =
		scaled.HipHeight
		+ (root.Size.Y / 2)

	local runtime = EnemyRuntime.Create(
		model,
		{
			Name = model.Name,
			Map = map,

			PathData = pathData,
			PathId = pathData.Id,
			PathLength = pathData.Length,

			Alpha = options.Alpha or 0,
			Height = height,
			OffsetX = options.OffsetX or 0,
			OffsetZ = options.OffsetZ or 0,

			MaxHealth = scaled.MaxHealth,
			Health = scaled.MaxHealth,

			BaseSpeed = scaled.Speed,
			Speed = scaled.Speed,

			Flags = scaled.Flags,
			NoBaseDamage = options.NoBaseDamage == true,
			SpawnDelayRemaining = options.SpawnDelayRemaining or 0,

			Stats = stats,
			HealthValue = healthValue,
			MaxHealthValue = maxHealthValue,
			SpeedValue = speedValue,
			OrigSpeedValue = origSpeedValue,
			AlphaValue = alphaValue,
			Hitbox = hitbox,
		}
	)

	runtime.MatchGeneration = Match.Capture()
	maxHealthValue.Value = runtime.MaxHealth
	healthValue.Value = runtime.Health
	speedValue.Value = runtime.Speed
	alphaValue.Value = runtime.Alpha

	if origSpeedValue then
		origSpeedValue.Value = runtime.BaseSpeed
	end

	model:SetAttribute("EnemyId", runtime.Id)
	model:SetAttribute("PathId", runtime.PathId)
	model:SetAttribute("EnemyHeight", runtime.Height)
	model:SetAttribute("EnemyOffsetX", runtime.OffsetX)
	model:SetAttribute("EnemyOffsetZ", runtime.OffsetZ)

	applyDeathWish(runtime)
	bindCompatibility(runtime)

	setCollisionGroup(model, "Mob")

	local startCFrame = runtimeCFrame(runtime)

	root.CFrame = startCFrame
	hitbox.CFrame = startCFrame

	model.Parent = options.Parent or MobsFolder

	incrementEnemyCount()

	-- One reliable spawn event per enemy.
	-- Continuous state is NOT sent this way.
	ReplicateMob:FireAllClients(
		model,
		runtime.Id,
		runtime.PathId,
		runtime.Height,
		runtime.OffsetX,
		runtime.OffsetZ,
		runtime.Alpha,
		runtime.Speed,

		-- Optional spawn presentation. Normal enemies simply send nil here.
		options.SpawnStyle,
		options.EmergenceDuration,
		options.EmergenceDepth
	)

	return runtime
end

-- Shared across regular waves, arrows, and summons; yield before cloning a rig.
local spawnsThisFrame = 0
local function claimSpawn(generation, canContinue)
	local limit = math.max(1, Settings.SpawnBudgetPerFrame or 32)
	while Match.IsCurrent(generation) and (spawnsThisFrame >= limit or getGameSpeed() <= 0) do
		if canContinue and not canContinue() then return false end
		RunService.Heartbeat:Wait()
	end
	if not Match.IsCurrent(generation) or (canContinue and not canContinue()) then return false end
	spawnsThisFrame += 1
	return true
end

function EnemyService.Spawn(name, quantity, cooldown, healthMultiplier, speedMultiplier, map)
	local generation = Match.Capture()
	if not Match.IsCurrent(generation) then return end
	local template = ReplicatedStorage.Mobs:FindFirstChild(name)

	if not template then
		warn("No mob found:", name)
		return
	end

	local noMultiply = template:FindFirstChild("NoMultiply")

	local multiplier =
		(noMultiply and noMultiply.Value)
		and 1
		or math.round(Info.EnemyMultiplier.Value)

	for _ = 1, quantity * multiplier do
		if not Match.Wait(generation, cooldown or 0) then return end

		if not Match.IsCurrent(generation) then
			return
		end

		local pathData = EnemyPaths.GetRandomPath(map)

		if not pathData then
			warn("No valid enemy path")
			return
		end

		if not claimSpawn(generation) then return end
		registerEnemy(
			template:Clone(),
			map,
			pathData,
			{
				HealthMultiplier = healthMultiplier,
				SpeedMultiplier = speedMultiplier,
				OffsetX = math.random(-35, 35),
				OffsetZ = math.random(-35, 35),
				Alpha = 0,
				Parent = MobsFolder,
			}
		)
	end
end

function EnemyService.ArrowSpawn(name, quantity, cooldown, healthMultiplier, speedMultiplier, map)
	local generation = Match.Capture()
	if not Match.IsCurrent(generation) then return end
	local template = ReplicatedStorage.Mobs:FindFirstChild(name)

	if not template then
		warn("No mob found:", name)
		return
	end

	for _ = 1, quantity do
		if not Match.Wait(generation, cooldown or 0) then return end

		local pathData = EnemyPaths.GetRandomPath(map)
		if not pathData then return end

		if not claimSpawn(generation) then return end
		registerEnemy(
			template:Clone(),
			map,
			pathData,
			{
				HealthMultiplier = healthMultiplier,
				SpeedMultiplier = speedMultiplier,
				Alpha = 0,
				Parent = ArrowsFolder,
				NoBaseDamage = true,
			}
		)
	end
end

function EnemyService.GetClosestWaypointPath(map, hostCFrame, hostAlpha)
	local pathData, resolvedAlpha =
		EnemyPaths.GetClosestPath(
			map,
			hostCFrame.Position,
			hostAlpha
		)

	if not pathData then
		return nil, nil, nil, nil
	end

	-- Existing callers can keep using the first 3 returns.
	-- The fourth return is useful when the caller did not already know alpha.
	return
		pathData,
		pathData.Length,
		pathData.Positions,
		resolvedAlpha
end

local function getSummonNumberSetting(folder, template, name, fallback)
	if folder then
		local attribute = folder:GetAttribute(name)

		if typeof(attribute) == "number" then
			return attribute
		end
	end

	local templateAttribute =
		template:GetAttribute("Summon" .. name)

	if typeof(templateAttribute) == "number" then
		return templateAttribute
	end

	return fallback
end

function EnemyService.Summon(
	name,
	quantity,
	cooldown,
	healthMultiplier,
	speedMultiplier,
	map,
	movingToValue,
	hostCFrame,
	path,
	pathLength,
	positions,
	canContinue
)
	local generation = Match.Capture()
	if not Match.IsCurrent(generation) or (canContinue and not canContinue()) then return end

	local template = ReplicatedStorage.Mobs:FindFirstChild(name)

	if not template then
		warn("No mob found:", name)
		return
	end

	-- ========================================================
	-- DUAL / MULTI-LANE PATH + SPAWN POSITION RESOLUTION
	-- ========================================================
	--
	-- `movingToValue` is kept in the function signature for compatibility,
	-- but it is only a throttled mirror of the authoritative runtime Alpha.
	-- It can be stale (and can remain 0 when Alpha mirroring is skipped), so
	-- it must NOT decide where a summon actually appears.
	--
	-- If the caller supplied PathData, keep that exact lane. Otherwise choose
	-- the path physically nearest the summoner. Then derive Alpha from the
	-- summoner's current authoritative Hitbox world position on that path.
	local pathData

	if type(path) == "table"
		and path.Samples
		and path.Length
	then
		pathData = path
	else
		pathData = select(
			1,
			EnemyPaths.GetClosestPath(
				map,
				hostCFrame.Position
			)
		)
	end

	if not pathData then
		return
	end

	local spawnAlpha =
		EnemyPaths.GetClosestAlphaOnPath(
			pathData,
			hostCFrame.Position
		)

	-- ========================================================
	-- HOARD + EMERGENCE SETTINGS
	-- ========================================================
	--
	-- Add an optional "SummonEffects" Folder to the summoned enemy template.
	-- Attributes:
	--   Duration       = 0.65  -- seconds to rise out of the ground
	--   Depth          = 3.5   -- studs below ground
	--   HoardDuration  = 0.35  -- whole group appears inside this window
	--   Spread         = 0.65  -- small X/Z cluster spread in studs
	--
	-- No folder is required; these defaults are used automatically.
	local summonEffects =
		template:FindFirstChild("SummonEffects")

	local emergenceDuration =
		math.max(
			0,
			getSummonNumberSetting(
				summonEffects,
				template,
				"Duration",
				0.65
			)
		)

	local emergenceDepth =
		math.max(
			0,
			getSummonNumberSetting(
				summonEffects,
				template,
				"Depth",
				3.5
			)
		)

	local hoardDuration =
		math.max(
			0,
			getSummonNumberSetting(
				summonEffects,
				template,
				"HoardDuration",
				0.35
			)
		)

	local spread =
		math.max(
			0,
			getSummonNumberSetting(
				summonEffects,
				template,
				"Spread",
				0.65
			)
		)

	quantity = math.max(0, math.floor(quantity or 0))

	if quantity <= 0 then
		return
	end

	-- Instead of old behavior:
	--   wait cooldown, spawn one, wait cooldown, spawn one...
	--
	-- the entire group now erupts as a hoard inside HoardDuration.
	local perUnitDelay =
		(quantity > 1)
		and (hoardDuration / (quantity - 1))
		or 0

	for index = 1, quantity do
		if index > 1 and perUnitDelay > 0 then
			if not Match.Wait(generation, perUnitDelay) then return end
		end

		if not Match.IsCurrent(generation) or (canContinue and not canContinue()) then
			return
		end

		-- Small radial spread keeps a hoard from occupying literally one
		-- identical visual point while still keeping every unit on the
		-- correct gameplay lane.
		local angle = math.random() * math.pi * 2
		local radius = math.sqrt(math.random()) * spread

		local offsetX =
			math.round(
				math.cos(angle)
				* radius
				* 100
			)

		local offsetZ =
			math.round(
				math.sin(angle)
				* radius
				* 100
			)

		if not claimSpawn(generation, canContinue) then return end
		registerEnemy(
			template:Clone(),
			map,
			pathData,
			{
				HealthMultiplier = healthMultiplier,
				SpeedMultiplier = speedMultiplier,

				Alpha = spawnAlpha,

				OffsetX = offsetX,
				OffsetZ = offsetZ,

				Parent = MobsFolder,

				-- Server movement pauses while the client visual emerges.
				SpawnDelayRemaining = emergenceDuration,

				SpawnStyle = "GroundSummon",
				EmergenceDuration = emergenceDuration,
				EmergenceDepth = emergenceDepth,
			}
		)
	end
end

local function reachBase(runtime)
	if runtime.ReachedBase or runtime.Dead then
		return
	end

	runtime.ReachedBase = true

	if runtime.NoBaseDamage then
		EnemyService.Destroy(runtime, "ReachedBase")
		return
	end

	local map = runtime.Map
	local base = map and map:FindFirstChild("Base")
	local baseStats = base and base:FindFirstChild("EnemyStats")
	local baseHealth = baseStats and baseStats:FindFirstChild("Health")

	if baseHealth then
		if EnemyFlags.Has(runtime.Flags, FLAGS.InstaKill) then
			baseHealth.Value = 0
		else
			baseHealth.Value -= math.round(runtime.Health)
		end
	end

	if BaseDamaged then
		BaseDamaged:FireAllClients()
	end

	EnemyService.Destroy(runtime, "ReachedBase")
end

-- Reused arrays: no table allocation each position tick.
local bulkParts = {}
local bulkCFrames = {}
local previousBulkCount = 0

local function updateServerPositions()
	local active = EnemyRuntime.GetActiveList()
	local count = 0

	for i = 1, #active do
		local runtime = active[i]
		local hitbox = runtime.Hitbox

		if hitbox and hitbox.Parent then
			count += 1
			bulkParts[count] = hitbox
			bulkCFrames[count] = runtimeCFrame(runtime)
		end
	end

	for i = count + 1, previousBulkCount do
		bulkParts[i] = nil
		bulkCFrames[i] = nil
	end

	previousBulkCount = count

	if count > 0 then
		Workspace:BulkMoveTo(
			bulkParts,
			bulkCFrames,
			Enum.BulkMoveMode.FireCFrameChanged
		)
	end
end

local function mirrorAlphaValues()
	-- Alpha exists only because the current tower targeter reads it.
	-- Don't spend this cost if there are zero towers.
	if towerCount <= 0 then
		return
	end

	local active = EnemyRuntime.GetActiveList()

	for i = 1, #active do
		local runtime = active[i]
		local alphaValue = runtime.AlphaValue

		if alphaValue
			and alphaValue.Parent
			and math.abs(alphaValue.Value - runtime.Alpha) > 0.002
		then
			alphaValue.Value = runtime.Alpha
		end
	end
end

local syncSequence = 0
local lastSyncPackets, lastSyncBytes = 0, 0
local function sendSyncPacket(packet)
	lastSyncPackets += 1; lastSyncBytes += buffer.len(packet)
	EnemySync:FireAllClients(packet)
end
local function syncSpeed(runtime) return effectiveSpeed(runtime, Match.Now()) end
local function sendCompressedSync()
	lastSyncPackets, lastSyncBytes = 0, 0
	syncSequence = (syncSequence + 1) % 4294967296
	SyncCodec.Encode(EnemyRuntime.GetActiveList(), syncSequence, Workspace:GetServerTimeNow(), syncSpeed, sendSyncPacket, Settings.SyncPacketBytes)
end
local function applyEffectDamage(enemy, amount, damageType)
	EnemyService.Damage(enemy, amount, damageType)
end

local positionAccumulator = 0
local syncAccumulator = 0
local alphaAccumulator = 0
local heartbeatConnection

function EnemyService.Start()
	if heartbeatConnection then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		spawnsThisFrame = 0
		local now = Match.Now()
		local gameSpeed = getGameSpeed()
		local active = EnemyRuntime.GetActiveList()

		-- Main numeric simulation. No CFrame work in this loop.
		for i = #active, 1, -1 do
			local runtime = active[i]

			if runtime.Dead or runtime.Cleaned then
				continue
			end

			if not Match.IsCurrent(runtime.MatchGeneration) then
				EnemyService.Destroy(runtime, "MatchEnded")
				continue
			end

			local model = runtime.Model

			if not (model and model.Parent) then
				EnemyService.Destroy(runtime, "Removed")
				continue
			end

			-- ============================================================
			-- LEGACY VALUE BRIDGE
			-- ============================================================
			-- A lot of the current tower code still does:
			--     enemy.EnemyStats.Health.Value -= damage
			--
			-- Runtime health is authoritative, so consume that legacy Value
			-- here in the ONE shared scheduler. A <=0 Value always kills the
			-- enemy before movement gets another chance to run.
			local healthValue = runtime.HealthValue

			if healthValue and healthValue.Parent then
				local legacyHealth = healthValue.Value

				if legacyHealth <= 0 then
					runtime.Health = 0
					EnemyService.OnDeath(runtime)
					continue
				elseif legacyHealth ~= runtime.Health then
					runtime.Health = math.clamp(
						legacyHealth,
						0,
						runtime.MaxHealth
					)
				end
			end

			-- Same idea for old slowdown code that writes Speed.Value.
			local speedValue = runtime.SpeedValue

			if speedValue
				and speedValue.Parent
				and speedValue.Value ~= runtime.Speed
			then
				runtime.Speed = speedValue.Value
			end

			LegacyEffects.Poll(runtime, now)
			if gameSpeed > 0 and (runtime.BurnUntil > 0 or runtime.BleedUntil > 0) then
				EnemyEffects.Update(runtime, now, applyEffectDamage)
			end

			if runtime.Dead then
				continue
			end

			if runtime.SpawnDelayRemaining > 0 then
				runtime.SpawnDelayRemaining =
					math.max(
						0,
						runtime.SpawnDelayRemaining
						- (dt * gameSpeed)
					)
			end

			local speed = effectiveSpeed(runtime, now)

			if runtime.PathLength > 0 and speed ~= 0 then
				runtime.Alpha +=
					(speed * gameSpeed * dt)
					/ runtime.PathLength
			end

			if gameSpeed > 0 and runtime.Alpha >= 1 then
				runtime.Alpha = 1
				reachBase(runtime)
			end
		end

		positionAccumulator += dt
		syncAccumulator += dt
		alphaAccumulator += dt

		if positionAccumulator >= SERVER_POS_INTERVAL then
			positionAccumulator %= SERVER_POS_INTERVAL
			updateServerPositions()
		end

		if alphaAccumulator >= ALPHA_MIRROR_INTERVAL then
			alphaAccumulator %= ALPHA_MIRROR_INTERVAL
			mirrorAlphaValues()
		end

		if syncAccumulator >= CLIENT_SYNC_INTERVAL then
			syncAccumulator %= CLIENT_SYNC_INTERVAL
			sendCompressedSync()
		end
	end)
end

function EnemyService.GetDiagnostics()
	return {
		ActiveEnemies = #EnemyRuntime.GetActiveList(),
		LastSyncPackets = lastSyncPackets, LastSyncBytesPerClient = lastSyncBytes,
		LastMovedHitboxes = previousBulkCount,
		LegacyEffectConnectionsPerEnemy = 0,
	}
end

function EnemyService.Stop()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	table.clear(bulkParts); table.clear(bulkCFrames); previousBulkCount = 0
	positionAccumulator, syncAccumulator, alphaAccumulator = 0, 0, 0
end

EnemyService.Start()

return EnemyService
