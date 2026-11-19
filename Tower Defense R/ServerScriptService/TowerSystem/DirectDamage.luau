local EnemyRuntime = require(game.ServerScriptService.EnemySystem.EnemyRuntime)
local Profiles = require(game.ReplicatedStorage.GameModules.CombatProfiles)
local Damage = {}
function Damage.Apply(target, config, amount)
	local stats = target:FindFirstChild('EnemyStats')
	local health = stats and stats:FindFirstChild('Health')
	if not health or health.Value <= 0 or stats:FindFirstChild('Invincible') then return false, 0 end
	local lead = stats:FindFirstChild('Lead')
	local detection = config:FindFirstChild('LeadDetection')
	if lead and lead.Value and not (detection and detection.Value == true) then return false, 0 end
	local defense = stats:FindFirstChild('Defense')
	if defense and defense:FindFirstChild('DefenseValue') then
		amount = math.round(amount / (1 + defense.DefenseValue.Value))
	end
	if amount <= 0 then return false, 0 end
	local damageType = config:FindFirstChild('DamageType')
	local kind = Profiles.Resolve('', damageType and damageType.Value)
	local runtime = EnemyRuntime.Get(target)
	if runtime then runtime.LastDamageType = kind end
	local shield = stats:FindFirstChild('ShieldHealth')
	if shield and shield.Health.Value > 0 then
		local actual = math.min(amount, shield.Health.Value)
		shield.Health.Value = math.max(0, shield.Health.Value - amount)
		return false, actual
	end
	local actual = math.min(amount, health.Value)
	health.Value = math.max(0, health.Value - amount)
	return true, actual
end
return Damage
