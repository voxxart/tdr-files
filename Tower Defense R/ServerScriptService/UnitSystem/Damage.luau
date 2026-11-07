local Players = game:GetService('Players')
local math_max, math_round = math.max, math.round
local EnemyRuntime = require(game.ServerScriptService.EnemySystem.EnemyRuntime)
local Damage = {}
function Damage.Credit(newunit, damage)
	if not newunit or damage <= 0 then
		return
	end

	-- Fast/reliable path:
	-- Each linked unit stores a direct ObjectValue to the exact TotalDamage
	-- ValueBase belonging to the tower that spawned it. This avoids repeatedly
	-- searching the tower hierarchy and also prevents same-name Config values
	-- from causing the unit to credit the wrong object.
	local damageLink = newunit:FindFirstChild("OwnerDamageValue")
	local linkedDamage = damageLink and damageLink.Value

	if linkedDamage
		and linkedDamage.Parent
		and linkedDamage:IsA("ValueBase")
	then
		linkedDamage.Value += damage
		return
	end

	-- Backwards-compatible fallback for units that were spawned before the
	-- direct damage link was added.
	local ownerTower = newunit:FindFirstChild("OwnerTower")
	local tower = ownerTower and ownerTower.Value
	if not tower then
		return
	end

	local config = tower:FindFirstChild("Config")
	if not config then
		return
	end

	local totalDamage = config:FindFirstChild("TotalDamage")
	if not totalDamage or not totalDamage:IsA("ValueBase") then
		return
	end

	totalDamage.Value += damage
end

function Damage.Apply(stats, damage, isExplosion, damageType)
	local runtime = stats.Parent and EnemyRuntime.Get(stats.Parent)
	if runtime then runtime.LastDamageType = damageType or (if isExplosion then 'Explosion' else 'None') end
	if damage <= 0 then
		return 0
	end

	local health = stats:FindFirstChild("Health")
	if not health or health.Value <= 0 then
		return 0
	end

	-- Explosion damage uses ExplosionDefense.
	if isExplosion then
		local expDef = stats:FindFirstChild("ExplosionDefense")

		if expDef and expDef:FindFirstChild("DefenseValue") then
			damage = math_round(
				damage / (1 + expDef.DefenseValue.Value)
			)
		end
	end

	-- Shield takes the hit first.
	local shield = stats:FindFirstChild("ShieldHealth")

	if shield then
		local shieldHealth = shield:FindFirstChild("Health")

		if shieldHealth and shieldHealth.Value > 0 then
			local actualShieldDamage =
				math.min(
					damage,
					shieldHealth.Value
				)

			shieldHealth.Value = math_max(
				0,
				shieldHealth.Value - damage
			)

			-- Shield damage is still real damage dealt by the unit, so it should
			-- count toward the owning tower's TotalDamage just like tower attacks.
			-- Damage does NOT overflow into Health; this preserves the existing
			-- shield behavior.
			return actualShieldDamage
		end
	end

	-- Damage actual Health.
	local actualDamage = math.min(damage, health.Value)

	health.Value = math_max(
		0,
		health.Value - damage
	)

	return actualDamage
end

function Damage.Reward(damage)
	if damage <= 0 then
		return
	end

	local cash = math_max(1, math_round(damage * 0.40))

	for _, plr in ipairs(Players:GetPlayers()) do
		local playerCash = plr:FindFirstChild("Cash")
		if playerCash then
			playerCash.Value += cash
		end
	end
end


return Damage
