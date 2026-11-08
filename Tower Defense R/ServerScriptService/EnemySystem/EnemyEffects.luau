-- ServerScriptService/EnemySystem/EnemyEffects.lua
-- Timestamp effects; zero per-enemy loops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyData = require(ReplicatedStorage.GameModules:WaitForChild("EnemyData"))
local EnemyFlags = require(script.Parent:WaitForChild("EnemyFlags"))

local Match = require(game.ServerScriptService.Simulation.MatchService)
local EnemyEffects = {}

local FLAGS = EnemyData.Flags
local BURN_TICK = EnemyData.Settings.BurnTick or 1
local BLEED_TICK = EnemyData.Settings.BleedTick or 1

function EnemyEffects.ApplyBurn(runtime, duration, damage, now)
	if not runtime or runtime.Dead then return end
	if EnemyFlags.Has(runtime.Flags, FLAGS.Invincible) then return end

	now = now or Match.Now()

	runtime.BurnUntil = math.max(
		runtime.BurnUntil,
		now + math.max(duration or 0, 0)
	)

	if (damage or 0) >= runtime.BurnDamage then
		runtime.BurnDamage = damage or 0
	end

	if runtime.BurnNext <= now then
		runtime.BurnNext = now + BURN_TICK
	end
end

function EnemyEffects.ApplyBleed(runtime, duration, damage, multiplier, now)
	if not runtime or runtime.Dead then return end
	if EnemyFlags.Has(runtime.Flags, FLAGS.Invincible) then return end

	now = now or Match.Now()

	runtime.BleedUntil = math.max(
		runtime.BleedUntil,
		now + math.max(duration or 0, 0)
	)

	if (damage or 0) >= runtime.BleedDamage then
		runtime.BleedDamage = damage or 0
	end

	runtime.BleedMultiplier = math.max(
		runtime.BleedMultiplier or 1,
		multiplier or 1
	)

	if runtime.BleedNext <= now then
		runtime.BleedNext = now + BLEED_TICK
	end
end

function EnemyEffects.ApplyStun(runtime, duration, now)
	if not runtime or runtime.Dead then return end
	if EnemyFlags.Has(runtime.Flags, FLAGS.NoStun) then return end

	now = now or Match.Now()

	runtime.StunUntil = math.max(
		runtime.StunUntil,
		now + math.max(duration or 0, 0)
	)
end

function EnemyEffects.IsStunned(runtime, now)
	return runtime.StunUntil > (now or Match.Now())
end

function EnemyEffects.Update(runtime, now, damageCallback)
	if runtime.BurnUntil > 0 then
		if now >= runtime.BurnUntil then
			runtime.BurnUntil = 0
			runtime.BurnNext = 0
			runtime.BurnDamage = 0
		elseif now >= runtime.BurnNext then
			runtime.BurnNext += BURN_TICK
			damageCallback(runtime, runtime.BurnDamage, "Burn")
		end
	end

	if runtime.Dead or runtime.Cleaned then return end
	if runtime.BleedUntil > 0 then
		if now >= runtime.BleedUntil then
			runtime.BleedUntil = 0
			runtime.BleedNext = 0
			runtime.BleedDamage = 0
			runtime.BleedMultiplier = 1
		elseif now >= runtime.BleedNext then
			runtime.BleedNext += BLEED_TICK
			damageCallback(
				runtime,
				math.round(runtime.BleedDamage * runtime.BleedMultiplier),
				"Bleed"
			)
		end
	end
end

return EnemyEffects
