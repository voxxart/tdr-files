-- ServerScriptService/EnemySystem/EnemyRuntime.lua
-- Dense-array runtime storage.
-- Swap-remove avoids holes and avoids pairs() over hash tables every frame.

local EnemyRuntime = {}

local ByModel = setmetatable({}, { __mode = "k" })
local ById = {}
local Active = {}

local nextId = 0

function EnemyRuntime.Create(model, data)
	nextId += 1

	local runtime = {
		Id = nextId,
		Index = #Active + 1,

		Model = model,
		Name = data.Name or model.Name,
		Map = data.Map,

		PathData = data.PathData,
		PathId = data.PathId,
		PathLength = data.PathLength,

		Alpha = data.Alpha or 0,
		Height = data.Height or 0,
		OffsetX = data.OffsetX or 0,
		OffsetZ = data.OffsetZ or 0,

		MaxHealth = data.MaxHealth or 1,
		Health = data.Health or data.MaxHealth or 1,

		BaseSpeed = data.BaseSpeed or data.Speed or 0,
		Speed = data.Speed or data.BaseSpeed or 0,

		Flags = data.Flags or 0,

		NoBaseDamage = data.NoBaseDamage == true,

		-- Summoned enemies can be visually emerging while their gameplay
		-- progress is briefly paused. This is game-time, not real-time.
		SpawnDelayRemaining = data.SpawnDelayRemaining or 0,

		Dead = false,
		Cleaned = false,
		ReachedBase = false,

		-- Flat effect fields: avoids one nested table per enemy.
		BurnUntil = 0,
		BurnNext = 0,
		BurnDamage = 0,

		BleedUntil = 0,
		BleedNext = 0,
		BleedDamage = 0,
		BleedMultiplier = 1,

		StunUntil = 0,

		-- Cached Instances used by compatibility / bulk movement.
		Stats = data.Stats,
		HealthValue = data.HealthValue,
		MaxHealthValue = data.MaxHealthValue,
		SpeedValue = data.SpeedValue,
		OrigSpeedValue = data.OrigSpeedValue,
		AlphaValue = data.AlphaValue,
		Hitbox = data.Hitbox,

		Connections = {},
	}

	Active[runtime.Index] = runtime
	ByModel[model] = runtime
	ById[runtime.Id] = runtime

	return runtime
end

function EnemyRuntime.Get(model)
	return ByModel[model]
end

function EnemyRuntime.GetById(id)
	return ById[id]
end

function EnemyRuntime.GetActiveList()
	return Active
end

function EnemyRuntime.Remove(runtimeOrModel)
	local runtime = runtimeOrModel

	if typeof(runtimeOrModel) == "Instance" then
		runtime = ByModel[runtimeOrModel]
	end

	if not runtime or runtime.Cleaned then
		return
	end

	runtime.Cleaned = true

	for _, connection in ipairs(runtime.Connections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(runtime.Connections)

	local index = runtime.Index
	local lastIndex = #Active
	local last = Active[lastIndex]

	if index and index <= lastIndex then
		if index ~= lastIndex then
			Active[index] = last
			last.Index = index
		end
		Active[lastIndex] = nil
	end

	if runtime.Model then
		ByModel[runtime.Model] = nil
	end

	ById[runtime.Id] = nil
	runtime.Index = nil
end

return EnemyRuntime
