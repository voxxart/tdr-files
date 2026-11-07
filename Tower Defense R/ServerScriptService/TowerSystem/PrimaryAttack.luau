local Match = require(game.ServerScriptService.Simulation.MatchService)
local DirectDamage = require(script.Parent.DirectDamage)
local Primary = {}
function Primary.new(context)
local tower, Towers = context.Tower, context.Towers
local isCorruptedTower, corruptionPrimaryAttack = context.IsCorrupted, context.CorruptionAttack
local Info, MobsFolder = context.Info, context.MobsFolder
local ReplicateEffectsEvent, animateTowerEvent = context.Effects, context.Animate
local os_clock, math_round, math_max, math_sqrt = os.clock, math.round, math.max, math.sqrt
local task_spawn = task.spawn
return function(newTower, player, config, targetOverride)
	if not (newTower and newTower.Parent and config and config.Parent) then return end
	if newTower:GetAttribute("ReaperSummoning") == true then return end
	local data = Towers[newTower]
	local generation = data and data.MatchGeneration or Match.Capture()
	if not Match.IsCurrent(generation) then return end
	local towerHealth = config:FindFirstChild('Health')
	if towerHealth and towerHealth:FindFirstChild('HealthValue') and towerHealth.HealthValue.Value <= 0 then return end
	if config:FindFirstChild('Stunned') then return end
	if isCorruptedTower(newTower) then
		return corruptionPrimaryAttack(newTower, player, config)
	end

	local dealtDamage = false

	local stunUntil = config:GetAttribute("StunnedUntil")
	if stunUntil and os_clock() < stunUntil then return end

	local targetMode = (config:FindFirstChild("TargetMode") and config.TargetMode.Value) or "First"
	local range      = config:FindFirstChild("Range") and config.Range.Value
	local target     = targetOverride or tower.FindTarget(newTower, range, targetMode)
	if not target or not target.Parent then return end
	local targetStats = target:FindFirstChild('EnemyStats')
	local targetHealth = targetStats and targetStats:FindFirstChild('Health')
	if not targetHealth or targetHealth.Value <= 0 then return end

	-- Remember this so DoSecondaryAttackLogic can shoot the same enemy
	-- instead of finding its own.
	local schedData = Towers[newTower]
	if schedData then schedData.lastPrimaryTarget = target end

	if not tower.Ammo(config, newTower) then return end

	-- Legacy stun value gate
	if config:FindFirstChild("Stunned") then return end

	local enemyStats = target:FindFirstChild("EnemyStats")
	if not enemyStats then return end

	local dmg = config:FindFirstChild("Damage") and config.Damage.Value

	-- Take a single mob snapshot for functions that iterate all mobs
	local mobSnapshot = nil

	if config:FindFirstChild("Splash") then
		tower.FireSplashProjectile(newTower, target, config)
	elseif config:FindFirstChild("Shocker") then
		tower.Shocker(target, newTower, player)
	else
		if enemyStats:FindFirstChild("Invincible") then
			local shield = target:FindFirstChild("Hitbox") and target.Hitbox:FindFirstChild("Shield")
			if shield then
				local sound = shield:FindFirstChild('Attack')
				if sound and sound:IsA('Sound') then sound:Play() end
			end
		elseif enemyStats:FindFirstChild("Lead") and not config:FindFirstChild("LeadDetection") then
			local ls = enemyStats:FindFirstChild("LeadSound")
			if ls then ls:Play() end
		else
			local finalDamage = dmg

			if config:FindFirstChild("BehemothStats") then
				local bs  = config.BehemothStats
				local dml = bs:FindFirstChild("DamageMultiplierLogic")
				if dml then
					local MinR = dml:FindFirstChild("MinRange")
					local MidR = dml:FindFirstChild("MidRange")
					local LngR = dml:FindFirstChild("LongRange")
					if MinR and MidR and LngR then
						local hitbox = target:FindFirstChild("Hitbox")
						local hrp    = newTower:FindFirstChild("HumanoidRootPart")
						if hitbox and hrp then
							local dx   = hitbox.Position.X - hrp.Position.X
							local dz   = hitbox.Position.Z - hrp.Position.Z
							local dist = math_sqrt(dx*dx + dz*dz)
							if dist <= MinR.Range.Value then
								finalDamage = math_round(dmg * MinR.Multiplier.Value)
							elseif dist <= MidR.Range.Value then
								finalDamage = math_round(dmg * MidR.Multiplier.Value)
							elseif dist <= LngR.Range.Value then
								finalDamage = math_round(dmg * LngR.Multiplier.Value)
							end
						end
					end
				end
			end

			dealtDamage = DirectDamage.Apply(target, config, finalDamage)
		end

		if config:FindFirstChild("TotalDamage") then
			config.TotalDamage.Value += dmg
		end
	end

	-- Cash reward (uses cached player list)
	do
		local noCash = enemyStats:FindFirstChild("NoCash")
		local inv    = enemyStats:FindFirstChild("Invincible")
		local shield = enemyStats:FindFirstChild("ShieldHealth")
		if dealtDamage and not noCash and not inv and not (shield and shield.Health.Value > 0) then
			local halfCash = Info:FindFirstChild("Modifiers")
				and Info.Modifiers:FindFirstChild("Half Cash")
				and Info.Modifiers["Half Cash"].Value == true
			for _, plr in ipairs(context.GetPlayers()) do
				local c = plr:FindFirstChild("Cash")
				if c then
					local reward = math_max(1, math_round(dmg * 0.55))
					if target:FindFirstChild("IsBoss") and halfCash then
						c.Value += math_round(reward * 0.3)
					elseif halfCash then
						c.Value += math_round(reward * 0.32)
					else
						c.Value += reward
					end
				end
			end
		end
	end

	-- Burn / melt / FX
	if config:FindFirstChild("BurnTime") then
		if config:FindFirstChild("Flamethrower") then
			ReplicateEffectsEvent:FireAllClients(newTower, target, "FireFlame")
		end
		mobSnapshot = mobSnapshot or MobsFolder:GetChildren()
		tower.Flamethrower(newTower, mobSnapshot)

		if config:FindFirstChild("DefenseMelt") and enemyStats:FindFirstChild("Defense") then
			task_spawn(function() tower.DefenseMelt(newTower, target) end)
		end
		if not target:FindFirstChild("IsBoss") then tower.Slowdown(newTower, target) end

		tower.Fire(newTower, target, config.BurnTime.Value, config.FireDamage.Value)
		ReplicateEffectsEvent:FireAllClients(newTower, target, "Fire", config.BurnTime.Value)
	end

	if config:FindFirstChild("Flying") then
		tower.HeliFaceTarget(newTower, target)
	elseif config:FindFirstChild("Aviator") then
	else
		tower.FaceTarget(newTower, target, 0)
	end
	animateTowerEvent:FireAllClients(newTower, "Attack", target)

	-- NOTE: target destruction is owned by mob.Move / mob.Explode on the server.
	-- DoAttackLogic must NOT call target:Destroy() to avoid a race condition.

	if config:FindFirstChild("Kills") then
		config.Kills.Value += 1
		if config:FindFirstChild("CashReward") then
			tower.Cowboy(config, player, newTower)
		end
	end

	if config:FindFirstChild("PelletCount") then
		tower.FaceTargetInstant(newTower, target)
		task.wait()
		if not Match.IsCurrent(generation) or not newTower.Parent or not config.Parent then return end
		tower.Shotgunner(config, player, newTower)
	end

	if config:FindFirstChild("CurrentAmmo") then
		config.CurrentAmmo.Value -= 1
	end

	if config:FindFirstChild("AOE") and config:FindFirstChild("MaxHits") then
		tower.AOE(target, newTower, config.MaxHits.Value)
	end
end

end
return Primary
