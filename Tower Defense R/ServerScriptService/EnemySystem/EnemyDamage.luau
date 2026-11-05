-- ServerScriptService/EnemySystem/EnemyDamage.lua

local EnemyDamage = {}

function EnemyDamage.SyncHealth(runtime)
	local health = runtime.HealthValue
	local maxHealth = runtime.MaxHealthValue

	if health and health.Parent and health.Value ~= runtime.Health then
		health.Value = runtime.Health
	end

	if maxHealth and maxHealth.Parent and maxHealth.Value ~= runtime.MaxHealth then
		maxHealth.Value = runtime.MaxHealth
	end
end

function EnemyDamage.Damage(runtime, amount)
	if runtime.Dead or amount <= 0 then
		return 0
	end

	local before = runtime.Health

	runtime.Health = math.max(
		0,
		runtime.Health - amount
	)

	EnemyDamage.SyncHealth(runtime)

	return before - runtime.Health
end

function EnemyDamage.Heal(runtime, amount)
	if runtime.Dead or amount <= 0 then
		return 0
	end

	local before = runtime.Health

	runtime.Health = math.min(
		runtime.MaxHealth,
		runtime.Health + amount
	)

	EnemyDamage.SyncHealth(runtime)

	return runtime.Health - before
end

return EnemyDamage
