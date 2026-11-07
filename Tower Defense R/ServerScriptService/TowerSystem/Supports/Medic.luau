local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Workspace = workspace
local Players = game:GetService('Players')
local Module = {}
function Module.Start(scope, context, newTower, player)
local tower = context.Tower
local animateTowerEvent = context.animateTowerEvent
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
local WaveValue = context.WaveValue
local ParticleFolder = context.ParticleFolder
local isCorruptedTower = context.isCorruptedTower
local getMedicBeam = context.getMedicBeam
local function run(newTower, player)
	scope:OnCancel(function()
		local beam, light = getMedicBeam(newTower)
		if beam then beam.Attachment1 = nil end
		if light then light.Enabled = false end
	end)
	local config = newTower:FindFirstChild("Config")
	if not config then
		return
	end

	if config.Health.HealthValue.Value <= 0 then
		return
	end

	local healPT =
		ParticleFolder:FindFirstChild("Heal")

	local mapFolder =
		Workspace:FindFirstChild("Map")

	local map =
		mapFolder
		and mapFolder:FindFirstChildOfClass("Folder")

	local base =
		map
		and map:FindFirstChild("Base")

	local baseStats =
		base
		and base:FindFirstChild("EnemyStats")

	local baseHead =
		base
		and base:FindFirstChild("Head")

	local baseMaxHP =
		baseStats
		and baseStats:FindFirstChild("MaxHealth")

	-- ========================================================
	-- BASE HEAL
	-- ========================================================

	local waveConn

	if baseStats then
		waveConn = scope:Connect(WaveValue.Changed, function()
			-- Medic was removed
			if not newTower.Parent then
				if waveConn then
					waveConn:Disconnect()
					waveConn = nil
				end

				return
			end

			if isCorruptedTower(newTower) then return end

			-- Read these LIVE because upgrades can add/change them.
			local healBaseFlag =
				config:FindFirstChild("HealBase")

			local baseHealVal =
				config:FindFirstChild("BaseHeal")

			local baseHealth =
				baseStats:FindFirstChild("Health")

			local overHealMax =
				baseStats:FindFirstChild("OverHealMaxHealth")

			-- Base overheal isn't unlocked yet.
			if not healBaseFlag
				or healBaseFlag.Value ~= true
				or not baseHealVal
				or not baseHealth
				or not overHealMax
			then
				return
			end

			if baseHealth.Value <= 0 then
				return
			end

			if baseHealth.Value < overHealMax.Value then
				baseHealth.Value =
					math_min(
						baseHealth.Value + baseHealVal.Value,
						overHealMax.Value
					)
			end
		end)
	end

	-- ========================================================
	-- MAIN MEDIC LOOP
	-- ========================================================

	while newTower.Parent do

		if isCorruptedTower(newTower) then
			local beam, lens = getMedicBeam(newTower)
			if beam then beam.Attachment1 = nil end
			if lens then lens.Enabled = false end
			task_wait(0.1)
			continue
		end

		-- Always get the CURRENT Weapon's beam.
		-- This is important because upgrades may replace Weapon.
		local beam, beamLight =
			getMedicBeam(newTower)

		if not beam or not beamLight then
			task_wait(0.05)
			continue
		end

		-- Read these live so upgrades immediately affect Medic.
		local range =
			(config:FindFirstChild("Range")
				and config.Range.Value)
			or 20

		local cd =
			(config:FindFirstChild("Cooldown")
				and config.Cooldown.Value)
			or 1

		local dmg =
			(config:FindFirstChild("Damage")
				and config.Damage.Value)
			or 1

		-- ====================================================
		-- STUNNED
		-- ====================================================

		if config:FindFirstChild("Stunned") then
			beamLight.Enabled = false
			beam.Attachment1 = nil

			task_wait(0.1)
			continue
		end

		-- ====================================================
		-- TARGET
		-- ====================================================

		local target = nil
		local healingBase = false

		if baseStats
			and baseHead
			and baseMaxHP
			and baseStats.Health.Value > 0
		then
			if baseStats.Health.Value < baseMaxHP.Value
				and (
					baseHead.Position
					- newTower.HumanoidRootPart.Position
				).Magnitude <= range
			then
				target = base
				healingBase = true
			end
		end

		if not target then
			target =
				tower.MedicFindTarget(
					newTower,
					range,
					config.TargetMode.Value
				)
		end

		-- ====================================================
		-- HEAL
		-- ====================================================

		if target and target.Parent then

			local attachPart =
				healingBase
				and baseHead
				or target:FindFirstChild(
					"HumanoidRootPart"
				)

			local healthValue
			local maxHealth
			local healAmount

			if healingBase then

				if baseStats then

					healthValue =
						baseStats:FindFirstChild("Health")

					maxHealth =
						baseMaxHP

					healAmount =
						(
							config:FindFirstChild(
								"HealAmount"
							)
							and config.HealAmount.Value
						)
						or dmg
				end

			else

				local targetConfig =
					target:FindFirstChild("Config")

				local hcfg =
					targetConfig
					and targetConfig:FindFirstChild(
						"Health"
					)

				if hcfg then

					healthValue =
						hcfg:FindFirstChild(
							"HealthValue"
						)

					maxHealth =
						hcfg:FindFirstChild(
							"MaxHealth"
						)

					healAmount = dmg
				end
			end

			if not healthValue
				or not maxHealth
				or healthValue.Value <= 0
			then
				task_wait(0.25)
				continue
			end

			-- =================================================
			-- FACE / ANIMATE
			-- =================================================

			tower.MedicFaceTarget(
				newTower,
				target,
				0.1
			)

			if not healingBase then
				animateTowerEvent:FireAllClients(
					newTower,
					"Attack",
					target
				)
			end

			-- =================================================
			-- HEAL PARTICLE
			-- =================================================

			local healParticle

			if healPT and attachPart then

				healParticle =
					attachPart:FindFirstChild(
						"HealParticle"
					)

				if not healParticle then

					healParticle =
						scope:Own(healPT:Clone())

					healParticle.Name =
						"HealParticle"

					healParticle.Parent =
						attachPart

					if healParticle:IsA(
						"ParticleEmitter"
						) then
						healParticle.Enabled = true
					end
				end
			end

			-- =================================================
			-- CONNECT BEAM
			-- =================================================

			local attachment =
				attachPart
				and (
					attachPart:FindFirstChild("Pivot")
					or attachPart:FindFirstChildWhichIsA(
						"Attachment"
					)
				)

			if attachment then
				beamLight.Enabled = true
				beam.Attachment1 = attachment
			end

			-- =================================================
			-- ACTUAL HEAL
			-- =================================================

			if not config:FindFirstChild("Stunned")
				and not isCorruptedTower(newTower)
				and (healingBase or not isCorruptedTower(target)) then
				healthValue.Value =
					math_min(
						healthValue.Value
						+ healAmount,

						maxHealth.Value
					)
			end

			task_wait(
				cd
			)

			-- =================================================
			-- IMPORTANT:
			-- Reacquire AFTER the wait too.
			--
			-- The Medic may have been upgraded during task_wait.
			-- =================================================

			local currentBeam,
				currentBeamLight =
				getMedicBeam(newTower)

			if currentBeam then
				currentBeam.Attachment1 = nil
			end

			if currentBeamLight then
				currentBeamLight.Enabled = false
			end

			if healParticle
				and healParticle.Parent
			then
				if healParticle:IsA(
					"ParticleEmitter"
					) then
					healParticle.Enabled = false
				end

				scope:Destroy(healParticle)
			end

		else
			task_wait(0.25)
		end
	end

	if waveConn then
		waveConn:Disconnect()
	end
end

return run(newTower, player)
end
return Module
