local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Phaser = {}
function Phaser.new(context)
local Module = {}
local tower = context.Tower
local isCorruptedTower = context.IsCorrupted
local corruptionPrimaryAttack = context.CorruptionAttack
local corruptionDamage = context.corruptionDamage
local corruptionFace = context.corruptionFace
local corruptionTargetPart = context.corruptionTargetPart
local validCorruptionVictim = context.validCorruptionVictim
local Info = context.Info
local math_max, math_round, math_min = math.max, math.round, math.min
local getGameSpeed = context.GetGameSpeed
local function restorePhaserBaseDamage(data, settings)
	if not data then
		return
	end

	local baseDamage =
		data.phaserBaseDamage

	if baseDamage == nil then
		return
	end

	-- Once the Phaser is no longer LockedOn, the current ramp is over.
	-- Its next lock must begin from the newest TowerData base damage.
	data.phaserDamage =
		baseDamage

	local damageValue =
		settings
		and settings.DamageValue

	if damageValue
		and damageValue.Value ~= baseDamage
	then
		damageValue.Value =
			baseDamage
	end
end

function Module.Tick(newTower, data, now)
	local config = data.config
	if not (newTower and newTower.Parent and config and config.Parent) then
		return
	end
	if newTower:GetAttribute("ReaperSummoning") == true then return end

	local SentEvent = false
	local corrupted = isCorruptedTower(newTower)
	if data._lastPhaserCorrupted == nil then
		data._lastPhaserCorrupted = corrupted
	elseif data._lastPhaserCorrupted ~= corrupted then
		if data.phaserTarget then
			ReplicatedStorage.Events.Beamer.LostTarget:FireAllClients(newTower, data.phaserTarget)
		end
		data.phaserTarget = nil
		data.phaserPhase = "StandBy"
		data.phaserNextShot = nil
		data.phaserNextIncrease = nil
		data._lastPhaserCorrupted = corrupted
		if data.phaserSettings then restorePhaserBaseDamage(data, data.phaserSettings) end
	end

	-- Resolve/cached settings BEFORE stun handling.
	-- The previous version referenced `settings` in the stun branch before
	-- this local existed.
	local settings = data.phaserSettings

	if not settings then
		local BeamerSettings =
			config:FindFirstChild("BeamerSettings")

		if not BeamerSettings then
			return
		end

		local States =
			BeamerSettings:FindFirstChild("States")

		settings = {
			CooldownState =
				States
				and States:FindFirstChild("Cooldown"),

			ChargingState =
				States
				and States:FindFirstChild("Charging"),

			StandByState =
				States
				and States:FindFirstChild("StandBy"),

			LockedOnState =
				States
				and States:FindFirstChild("LockedOn"),

			ChargeCooldown =
				BeamerSettings:FindFirstChild("ChargeCooldown"),

			IncreaseTick =
				BeamerSettings:FindFirstChild("IncreaseTick"),

			Firerate =
				config:FindFirstChild("Cooldown"),

			IncreaseVal =
				BeamerSettings:FindFirstChild("IncreaseVal"),

			MaxDamage =
				BeamerSettings:FindFirstChild("MaxDamage"),

			OverHeatCooldown =
				BeamerSettings:FindFirstChild("OverHeatCooldown"),

			DamageValue =
				config:FindFirstChild("Damage"),
		}

		data.phaserSettings =
			settings
	end

	-- Backward/fallback initialization for any Phaser state that did not
	-- receive phaserBaseDamage when its attack loop was created.
	if data.phaserBaseDamage == nil then
		data.phaserBaseDamage =
			(settings.DamageValue and settings.DamageValue.Value)
			or 0
	end

	local stunUntil =
		config:GetAttribute("StunnedUntil")

	if stunUntil
		and os.clock() < stunUntil
	then
		local wasLockedOn =
			data.phaserPhase == "LockedOn"

		data.phaserPhase =
			"Cooldown"

		ReplicatedStorage.Events.Beamer.LostTarget:FireAllClients(
			newTower,
			data.phaserTarget
		)

		data.phaserPhaseEnd =
			now
			+ (
				(settings.OverHeatCooldown
					and settings.OverHeatCooldown.Value)
				or 0
			)

		if settings.LockedOnState then
			settings.LockedOnState.Value = false
		end

		if settings.CooldownState then
			settings.CooldownState.Value = true
		end

		-- If an upgrade happened during the lock, this is where its new
		-- base Damage finally becomes Config.Damage. The active beam never
		-- saw a mid-lock reset.
		if wasLockedOn then
			restorePhaserBaseDamage(
				data,
				settings
			)
		end

		data.phaserTarget = nil
		return
	end

	local hrp =
		newTower.HumanoidRootPart

	local radius =
		(
			config:FindFirstChild("Range")
			and config.Range.Value
		)
		or 0

	local phase =
		data.phaserPhase
		or "StandBy"

	local target =
		data.phaserTarget

	local targetStillValid
	if corrupted then
		local p = corruptionTargetPart(target)
		targetStillValid = validCorruptionVictim(newTower, target)
			and p and (hrp.Position - p.Position).Magnitude <= radius
	else
		targetStillValid =
			target
			and target.Parent
			and target:FindFirstChild("EnemyStats")
			and target.EnemyStats.Health.Value > 0
			and target:FindFirstChild("Hitbox")
			and (
				hrp.Position
				- target.Hitbox.Position
			).Magnitude <= radius
	end

	if phase == "StandBy" then
		if settings.StandByState then
			settings.StandByState.Value = true
		end

		if settings.ChargingState then
			settings.ChargingState.Value = false
		end

		if settings.LockedOnState then
			settings.LockedOnState.Value = false
		end

		if settings.CooldownState then
			settings.CooldownState.Value = false
		end

		local targetMode =
			(
				config:FindFirstChild("TargetMode")
				and config.TargetMode.Value
			)
			or "First"

		local function isValidPhaserTarget(enemy)
			if corrupted then return validCorruptionVictim(newTower, enemy) end
			if not enemy then
				return false
			end

			local stats =
				enemy:FindFirstChild("EnemyStats")

			if not stats then
				return false
			end

			local Maxhp =
				stats:FindFirstChild("MaxHealth")

			if not Maxhp then
				return false
			end

			-- Must be above 500 HP to be initially targeted.
			if Maxhp.Value <= 500 then
				return false
			end

			return true
		end

		local found =
			tower.FindTarget(
				newTower,
				radius,
				targetMode
			)

		if found
			and isValidPhaserTarget(found)
		then
			data.phaserTarget =
				found

			data.phaserPhase =
				"Charging"

			data.phaserPhaseEnd =
				now
				+ (
					(settings.ChargeCooldown
						and settings.ChargeCooldown.Value)
					or 0
				)
		end

		return
	end

	if phase == "Charging" then
		if settings.ChargingState then
			settings.ChargingState.Value = true
		end

		if settings.StandByState then
			settings.StandByState.Value = false
		end

		if not targetStillValid then
			data.phaserTarget = nil
			data.phaserPhase = "StandBy"
			return
		end

		if now >= data.phaserPhaseEnd then
			data.phaserPhase =
				"LockedOn"

			-- IMPORTANT:
			-- Start every new lock from the dedicated TowerData BASE damage,
			-- not whatever temporary/ramped number happens to be in Config.Damage.
			data.phaserDamage =
				data.phaserBaseDamage

			data.phaserNextTick =
				now

			if settings.ChargingState then
				settings.ChargingState.Value = false
			end

			if settings.LockedOnState then
				settings.LockedOnState.Value = true
			end
		end

		return
	end

	if phase == "LockedOn" then
		if not targetStillValid then
			data.phaserTarget = nil
			data.phaserPhase = "Cooldown"

			data.phaserPhaseEnd =
				now
				+ (
					(settings.OverHeatCooldown
						and settings.OverHeatCooldown.Value)
					or 0
				)

			if settings.LockedOnState then
				settings.LockedOnState.Value = false
			end

			if settings.CooldownState then
				settings.CooldownState.Value = true
			end

			-- This is the ONLY point where a base-damage upgrade that happened
			-- during LockedOn is committed to the live Config.Damage value.
			restorePhaserBaseDamage(
				data,
				settings
			)

			return
		end

		if corrupted then
			corruptionFace(newTower, target)
		else
			tower.FaceTargetInstant(newTower, target)
		end

		-- Initialize timers once.
		if not data.phaserNextShot then
			local fireRate =
				(
					settings.Firerate
					and settings.Firerate.Value
				)
				or 0.1

			local increaseTick =
				(
					settings.IncreaseTick
					and settings.IncreaseTick.Value
				)
				or 0.5

			data.phaserNextShot =
				now

			data.phaserNextIncrease =
				now
				+ (
					increaseTick

				)
		end

		local fireRate =
			(
				settings.Firerate
				and settings.Firerate.Value
			)
			or 0.1

		-- ========================================================
		-- DAMAGE TICKS
		--
		-- Actual Phaser DPS comes ONLY from data.phaserDamage.
		-- Upgrading while LockedOn never writes to this value.
		-- ========================================================

		if now >= data.phaserNextShot then
			local dmg =
				data.phaserDamage

			if corrupted then
				ReplicatedStorage.Events.Beamer.Beam:FireAllClients(newTower, target)
				local actual = corruptionDamage(newTower, target, dmg)
				local total = config:FindFirstChild("TotalDamage")
				if total then total.Value += actual end
				data.phaserNextShot = now + math_max(fireRate,0.01)
			else
				local enemyStats =
					target.EnemyStats

				if not enemyStats:FindFirstChild("Invincible") then
					ReplicatedStorage.Events.Beamer.Beam:FireAllClients(
						newTower,
						target
					)

					local sh =
						enemyStats:FindFirstChild("ShieldHealth")

					local dealt

					if sh
						and sh.Health.Value > 0
					then
						dealt =
							math_min(
								dmg,
								sh.Health.Value
							)

						sh.Health.Value -=
							dmg
					else
						dealt =
							math_min(
								dmg,
								enemyStats.Health.Value
							)

						enemyStats.Health.Value -=
							dmg
					end

					if config:FindFirstChild("TotalDamage") then
						config.TotalDamage.Value +=
							dmg
					end

					if not (
						sh
							and sh.Health.Value > 0
						)
							and not enemyStats:FindFirstChild("NoCash")
					then
						for _, plr in ipairs(context.GetPlayers()) do
							local c =
								plr:FindFirstChild("Cash")

							if c then
								c.Value +=
									math_max(
										1,
										math_round(dealt * 0.55)
									)
							end
						end
					end
				end

				data.phaserNextShot =
					now
					+ (
						fireRate

					)
			end -- corrupted beam damage / normal enemy damage
		end

		-- ========================================================
		-- DAMAGE RAMPING
		--
		-- Config.Damage mirrors the current ramp only for display/compatibility.
		-- phaserBaseDamage remains untouched until an upgrade changes the base.
		-- ========================================================

		if now >= (data.phaserNextIncrease or 0) then
			local incVal =
				(
					settings.IncreaseVal
					and settings.IncreaseVal.Value
				)
				or 0

			local maxDmg =
				(
					settings.MaxDamage
					and settings.MaxDamage.Value
				)
				or data.phaserDamage

			local increaseTick =
				(
					settings.IncreaseTick
					and settings.IncreaseTick.Value
				)
				or 0.5

			data.phaserDamage =
				math_min(
					data.phaserDamage + incVal,
					maxDmg
				)

			if settings.DamageValue
				and settings.DamageValue.Value
				~= data.phaserDamage
			then
				settings.DamageValue.Value =
					data.phaserDamage
			end

			data.phaserNextIncrease =
				now
				+ (
					increaseTick

				)
		end

		return
	end

	if phase == "Cooldown" then
		if settings.CooldownState then
			settings.CooldownState.Value = true
		end

		if SentEvent == false then
			ReplicatedStorage.Events.Beamer.LostTarget:FireAllClients(
				newTower,
				target
			)

			SentEvent = true
		end

		if now >= data.phaserPhaseEnd then
			data.phaserPhase =
				"StandBy"

			SentEvent =
				false
		end

		return
	end
end
-- ============================================================
-- COWBOY
-- ============================================================

function Module.Cancel(model, data)
	if data.phaserTarget then
		ReplicatedStorage.Events.Beamer.LostTarget:FireAllClients(model, data.phaserTarget)
	end
	data.phaserTarget = nil
	data.phaserPhase = 'StandBy'
	data.phaserNextShot, data.phaserNextIncrease = nil, nil
	restorePhaserBaseDamage(data, data.phaserSettings)
end
return Module
end
return Phaser
