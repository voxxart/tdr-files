local EnemyRuntime = require(game.ServerScriptService.EnemySystem.EnemyRuntime)
local Profiles = require(game.ReplicatedStorage.GameModules.CombatProfiles)
local Damage = {}
function Damage.Apply(target, config, amount)
	local stats = target:FindFirstChild('EnemyStats')
	local health = stats and stats:FindFirstChild('Health')
	if not health or health.Value <= 0 then return false end
	local defense = stats:FindFirstChild('Defense')
	if defense and defense:FindFirstChild('DefenseValue') then
		amount = math.round(amount / (1 + defense.DefenseValue.Value))
	end
	local damageType = config:FindFirstChild('DamageType')
	local kind = Profiles.Resolve('', damageType and damageType.Value)
	local runtime = EnemyRuntime.Get(target)
	if runtime then runtime.LastDamageType = kind end
	local shield = stats:FindFirstChild('ShieldHealth')
	if shield and shield.Health.Value > 0 then
		shield.Health.Value = math.max(0, shield.Health.Value - amount)
		return false
	end
	health.Value = math.max(0, health.Value - amount)
	return true
end
return Damage
