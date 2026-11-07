local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Workspace = workspace
local Players = game:GetService('Players')
local Module = {}
function Module.Start(scope, context, newTower, player)
local tower = context.Tower
local getGameSpeed = context.GetGameSpeed
local task = scope.Task
local task_spawn, task_wait, task_delay, task_defer = task.spawn, task.wait, task.delay, task.defer
local os_clock = os.clock
local math_max = math.max
local math_min = math.min
local math_round = math.round
local math_sqrt = math.sqrt
local math_random = math.random
local math_floor = math.floor
local math_clamp = math.clamp
local math_abs = math.abs
local math_rad = math.rad
local math_sin = math.sin
local math_cos = math.cos
local math_atan2 = math.atan2
local UnitMod = context.UnitMod
local SpawnerStates = setmetatable({}, { __mode = "k" })

local function getSpawnerNames(index)
	if index == 1 then
		return "Unit", "SpawnCooldown", "SpawnTimer"
	end

	return
		"Unit" .. index,
		"SpawnCooldown" .. index,
		"SpawnTimer" .. index
end

local function getSpawnerPlacementCooldown(config)
	local value = config:FindFirstChild("PlacementCooldown")

	if value and value:IsA("ValueBase") and typeof(value.Value) == "number" then
		return math_max(0, value.Value)
	end

	return 1
end

local function ensureSpawnerTimer(config, timerName)
	local timer = config:FindFirstChild(timerName)

	if timer and timer:IsA("ValueBase") then
		return timer
	end

	if timer then
		-- Do not destroy an authored non-Value object with the same name.
		warn(
			"[Spawner] Cannot create",
			timerName,
			"because a non-Value object already uses that name in",
			config:GetFullName()
		)
		return nil
	end

	timer = Instance.new("NumberValue")
	timer.Name = timerName
	timer.Value = 0
	timer.Parent = config

	return timer
end

local function readSpawnerSlot(config, index)
	local unitNameValue, cooldownNameValue =
		getSpawnerNames(index)

	local unitValue =
		config:FindFirstChild(unitNameValue)

	local cooldownValue =
		config:FindFirstChild(cooldownNameValue)

	local unitName = ""
	if unitValue
		and unitValue:IsA("ValueBase")
		and typeof(unitValue.Value) == "string"
	then
		unitName = unitValue.Value
	end

	local cooldown = nil
	if cooldownValue
		and cooldownValue:IsA("ValueBase")
		and typeof(cooldownValue.Value) == "number"
		and cooldownValue.Value > 0
	then
		cooldown = cooldownValue.Value
	end

	return unitName, cooldown
end

local function run(newTower, player)
	if not newTower or SpawnerStates[newTower] then
		return
	end

	local config = newTower:FindFirstChild("Config")
	if not config then
		return
	end

	local mapFolder = Workspace:FindFirstChild("Map")
	local map = mapFolder and mapFolder:FindFirstChildOfClass("Folder")
	if not map then
		return
	end

	local state = {
		Alive = true,
		Slots = {},
		AncestryConnection = nil,
	}

	SpawnerStates[newTower] = state

	local function cleanupSpawner()
		if not state.Alive then
			return
		end

		for _, slot in pairs(state.Slots) do
			if slot.Timer and slot.Timer.Parent then slot.Timer.Value = 0 end
		end
		state.Alive = false
		SpawnerStates[newTower] = nil

		if state.AncestryConnection then
			state.AncestryConnection:Disconnect()
			state.AncestryConnection = nil
		end
	end

	state.AncestryConnection =
		scope:Connect(newTower.AncestryChanged, function(_, parent)
			if parent == nil then
				cleanupSpawner()
			end
		end)

	scope:OnCancel(cleanupSpawner)

	-- ========================================================
	-- SPAWN ONE UNIT
	-- Multipliers are deliberately read at the moment the unit spawns so
	-- in-place upgrades affect the very next vehicle.
	-- ========================================================

	local function spawnOneLinkedUnit(unitName)
		if not state.Alive
			or not newTower.Parent
			or not unitName
			or unitName == ""
		then
			return
		end

		local ok, err = pcall(
			UnitMod.Spawn,
			unitName,
			1,
			0,
			1,
			1,
			map,
			newTower,
			function() return scope:Active() end
		)

		if not ok then
			warn(
				"[Spawner]",
				newTower:GetFullName(),
				"failed to spawn:",
				unitName,
				err
			)
		end
	end

	-- ========================================================
	-- RECONCILE ONE SLOT AGAINST CURRENT CONFIG
	--
	-- This is polled by the single spawner loop instead of wiring several
	-- Changed connections. That means an entire TowerData upgrade finishes
	-- first, then we observe the final Unit/Cooldown values together.
	-- ========================================================

	local function reconcileSlot(index)
		local _, _, timerName =
			getSpawnerNames(index)

		local currentUnit, currentCooldown =
			readSpawnerSlot(config, index)

		local currentlyActive =
			currentUnit ~= ""
			and currentCooldown ~= nil

		local slot = state.Slots[index]

		if not slot then
			slot = {
				Initialized = false,
				Active = false,
				UnitName = "",
				Cooldown = nil,
				Remaining = nil,
				Timer = nil,
			}

			state.Slots[index] = slot
		end

		-- First observation = actual tower placement state.
		if not slot.Initialized then
			slot.Initialized = true
			slot.Active = currentlyActive
			slot.UnitName = currentUnit
			slot.Cooldown = currentCooldown

			if currentlyActive then
				slot.Timer =
					ensureSpawnerTimer(
						config,
						timerName
					)

				slot.Remaining =
					getSpawnerPlacementCooldown(config)

				if slot.Timer then
					slot.Timer.Value =
						slot.Remaining
				end
			end

			return
		end

		-- Slot is currently unavailable / disabled.
		if not currentlyActive then
			if slot.Timer then
				slot.Timer.Value = 0
			end

			slot.Active = false
			slot.UnitName = currentUnit
			slot.Cooldown = currentCooldown
			slot.Remaining = nil

			return
		end

		-- A slot that did not previously exist has just been unlocked.
		-- OR an existing slot changed to a different vehicle.
		-- Either case gets PlacementCooldown for the first spawn.
		local unlockedNewSlot =
			not slot.Active

		local changedUnit =
			slot.Active
			and currentUnit ~= slot.UnitName

		if unlockedNewSlot or changedUnit then
			slot.Timer =
				slot.Timer
				or ensureSpawnerTimer(
					config,
					timerName
				)

			slot.Active = true
			slot.UnitName = currentUnit
			slot.Cooldown = currentCooldown
			slot.Remaining =
				getSpawnerPlacementCooldown(config)

			if slot.Timer then
				slot.Timer.Value =
					slot.Remaining
			end

			return
		end

		-- Same unit, but its normal cooldown changed.
		--
		-- Example:
		--   old cooldown = 40
		--   new cooldown = 30
		--   current timer = 24
		--
		--   difference = -10
		--   new timer = 14
		--
		-- If that would go below zero, clamp the upgrade adjustment to 1.
		if currentCooldown ~= slot.Cooldown then
			local oldCooldown =
				slot.Cooldown
				or currentCooldown

			local difference =
				currentCooldown
			- oldCooldown

			local currentRemaining =
				slot.Remaining
				or currentCooldown

			slot.Remaining =
				math_max(
					1,
					currentRemaining
					+ difference
				)

			slot.Cooldown =
				currentCooldown

			if slot.Timer then
				slot.Timer.Value =
					slot.Remaining
			end
		end

		-- Keep the snapshots current.
		slot.Active = true
		slot.UnitName = currentUnit
		slot.Cooldown = currentCooldown

		if not slot.Timer then
			slot.Timer =
				ensureSpawnerTimer(
					config,
					timerName
				)

			if slot.Timer
				and slot.Remaining
			then
				slot.Timer.Value =
					slot.Remaining
			end
		end
	end

	-- Observe the placement state immediately so the timers appear without
	-- waiting for the first scheduler tick.
	for index = 1, 3 do
		reconcileSlot(index)
	end

	-- ========================================================
	-- ONE LOOP FOR ALL SPAWNER SLOTS
	-- ========================================================

	task_spawn(function()
		while state.Alive
			and newTower.Parent
			and config.Parent
		do
			local dt =
				task_wait(0.1)

			if not state.Alive
				or not newTower.Parent
			then
				break
			end

			-- First reconcile all TowerData-driven changes.
			for index = 1, 3 do
				reconcileSlot(index)
			end

			local elapsedGameTime =
				dt

			for index = 1, 3 do
				local slot =
					state.Slots[index]

				if not slot
					or not slot.Active
					or not slot.Remaining
					or not slot.Cooldown
				then
					continue
				end

				slot.Remaining -=
					elapsedGameTime

				if slot.Remaining > 0 then
					if slot.Timer then
						slot.Timer.Value =
							slot.Remaining
					end

					continue
				end

				-- Spawn the CURRENT unit for this slot.
				-- If an upgrade changed the unit, reconcileSlot already reset
				-- this timer to PlacementCooldown before we can reach here.
				if slot.Timer then
					slot.Timer.Value = 0
				end

				spawnOneLinkedUnit(
					slot.UnitName
				)

				-- After the first/new-unit spawn, all following spawns use the
				-- normal current SpawnCooldown.
				slot.Remaining =
					slot.Cooldown

				if slot.Timer then
					slot.Timer.Value =
						slot.Remaining
				end
			end
		end

		for _, slot in pairs(state.Slots) do
			if slot.Timer
				and slot.Timer.Parent
			then
				slot.Timer.Value = 0
			end
		end

		cleanupSpawner()
	end)
end

return run(newTower, player)
end
return Module
