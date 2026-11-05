--// unit MODULE (Death/Explode optimized + spike-free cleanup)
--// Now supports optional ranged/melee attacking via EnemyStats.Attacks,
--// with NoStop (keep walking, torso-only swivel) vs stop-to-attack
--// (freeze position, full-body face) behavior. Ram-collision damage
--// logic is UNCHANGED — do not touch that block.

local ServerStorage = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")
local RepStorage = game:GetService("ReplicatedStorage")
local BezierPath = require(RepStorage.Modules.BezierPath)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local task_spawn = task.spawn
local task_wait  = task.wait
local math_max   = math.max
local math_round = math.round

local takeDamageevent = RepStorage.Events:FindFirstChild("BaseDamaged")

-- NEW: dedicated remotes for the two attack-facing behaviors.
-- UnitStopAttack = freeze position + face target with the WHOLE body
--                  (stop-to-attack units, i.e. Attacks=true, NoStop unset).
-- RotateTorso    = swivel only a Motor6D named "Torso" inside a "Pivot"
--                  part to face the target, movement is NOT affected
--                  (NoStop units).
local UnitStopAttackEvent = RepStorage.Events:WaitForChild("UnitStopAttack")
local RotateTorsoEvent    = RepStorage.Events:WaitForChild("RotateTorso")

-- A standalone death presentation remote. The DEAD UNIT itself remains
-- replicated briefly, so its actual rig plays DeathEffects.Animations.Death.
-- It is gameplay-inactive from the instant its health reaches zero.
local UnitDeathEvent = RepStorage.Events:FindFirstChild("UnitDeath")
if not UnitDeathEvent then
	UnitDeathEvent = Instance.new("RemoteEvent")
	UnitDeathEvent.Name = "UnitDeath"
	UnitDeathEvent.Parent = RepStorage.Events
end

local unit = {}
local Interval = 1/30

local function alive(newunit)
	if not (newunit and newunit.Parent) or newunit:GetAttribute("Dead") == true then
		return false
	end
	local stats = newunit:FindFirstChild("EnemyStats")
	local hp = stats and stats:FindFirstChild("Health")
	return hp ~= nil and hp.Value > 0
end

local function getGameSpeed()
	local v = workspace.Info.GameSpeed and workspace.Info.GameSpeed.Value or 1
	if v == 0 then v = 1 end
	return v
end

-- NEW: Adds damage dealt by a linked unit to the tower that owns it.
-- Uses the OwnerTower ObjectValue created by tower.Spawner().
-- If the unit is not linked, or the tower/TotalDamage doesn't exist,
-- this safely does nothing.
local function AddTowerDamage(newunit, damage)
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

local function DamageEnemy(stats, damage, isExplosion)
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

local function GiveDamageCash(damage)
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

-- Live mob set for attack-target searches (avoids GetChildren() per scan,
-- same pattern used in tower.lua / mine.lua). The existing ram-collision
-- block below still uses workspace.Mobs:GetChildren() directly — left
-- untouched intentionally.
local MobsFolder = workspace:WaitForChild("Mobs")
local MobSet = {}
for _, m in ipairs(MobsFolder:GetChildren()) do MobSet[m] = true end
MobsFolder.ChildAdded:Connect(function(m)   MobSet[m] = true  end)
MobsFolder.ChildRemoved:Connect(function(m) MobSet[m] = nil   end)

function unit.WayPointsLoad(map)
	local Positions = {}
	local folders = {}

	for i = 1, 4 do
		local folderName = (i == 1) and "UnitWaypoints" or "UnitWaypoints" .. i
		local folder = map:FindFirstChild(folderName)
		if folder then
			table.insert(folders, folder)
		end
	end

	if #folders == 0 then
		warn("No valid Waypoints folder found!")
		return nil, nil, nil
	end

	local waypointsFolder = folders[math.random(1, #folders)]

	local sortedWaypoints = waypointsFolder:GetChildren()
	table.sort(sortedWaypoints, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	for _, wp in ipairs(sortedWaypoints) do
		if wp:IsA("BasePart") then
			Positions[#Positions + 1] = wp.Position
		end
	end

	if #Positions < 2 then
		return nil, nil, nil
	end

	local path = BezierPath.new(Positions, 1.2)
	local pathLength = path:GetPathLength()

	return path, pathLength, Positions
end

-- ============================================================
-- FIND ATTACK TARGET (nearest mob in range, horizontal distance)
-- ============================================================
-- ============================================================
-- FIND ATTACK TARGET
-- Horizontal distance only + First targeting
-- ============================================================
local function findAttackTarget(newunit, hbPos, range)
	local rangeSq = range * range

	-- Default unit targeting.
	local mode = "First"

	-- If this unit belongs to a spawner, inherit the tower's
	-- current targeting mode.
	local ownerTowerValue = newunit:FindFirstChild("OwnerTower")

	if ownerTowerValue and ownerTowerValue.Value then
		local ownerTower = ownerTowerValue.Value
		local ownerConfig = ownerTower:FindFirstChild("Config")

		if ownerConfig then
			local targetMode = ownerConfig:FindFirstChild("TargetMode")

			if targetMode and targetMode:IsA("StringValue") then
				mode = targetMode.Value
			end
		end
	end

	local bestTarget = nil
	local bestDist = nil
	local bestAlpha = nil
	local bestHealth = nil

	for mob in pairs(MobSet) do
		local stats = mob:FindFirstChild("EnemyStats")
		local hitbox = mob:FindFirstChild("Hitbox")
		local alpha = mob:FindFirstChild("Alpha")

		if not (stats and hitbox and alpha) then
			continue
		end

		-- Don't target dead enemies.
		local health = stats:FindFirstChild("Health")
		if not health or health.Value <= 0 then
			continue
		end

		-- Units cannot target flying enemies.
		local flying = stats:FindFirstChild("Flying")
		if flying and flying.Value then
			continue
		end

		-- Horizontal distance only.
		local hitboxPos = hitbox.Position
		local dx = hitboxPos.X - hbPos.X
		local dz = hitboxPos.Z - hbPos.Z
		local distSq = dx * dx + dz * dz

		if distSq > rangeSq then
			continue
		end

		-- Aggro takes priority just like tower targeting.
		if stats:FindFirstChild("Aggro") then
			return mob
		end

		-- Beamer restriction.
		local ownerTower = ownerTowerValue and ownerTowerValue.Value
		local ownerConfig = ownerTower and ownerTower:FindFirstChild("Config")

		if ownerConfig and ownerConfig:FindFirstChild("BeamerSettings") then
			local maxHealth = stats:FindFirstChild("MaxHealth")

			if maxHealth and maxHealth.Value < 500 then
				continue
			end
		end

		-- ========================================================
		-- TARGETING MODES
		-- ========================================================

		if mode == "Near" then

			if not bestDist or distSq < bestDist then
				bestDist = distSq
				bestTarget = mob
			end

		elseif mode == "First" then

			local av = alpha.Value

			if not bestAlpha or av > bestAlpha then
				bestAlpha = av
				bestTarget = mob
			end

		elseif mode == "Last" then

			local av = alpha.Value

			if not bestAlpha or av < bestAlpha then
				bestAlpha = av
				bestTarget = mob
			end

		elseif mode == "Strong" then

			local hp = health.Value

			if not bestHealth or hp > bestHealth then
				bestHealth = hp
				bestTarget = mob
			end

		elseif mode == "Weak" then

			local hp = health.Value

			if not bestHealth or hp < bestHealth then
				bestHealth = hp
				bestTarget = mob
			end

		else
			-- Unknown targeting mode.
			-- Safely fall back to First.
			local av = alpha.Value

			if not bestAlpha or av > bestAlpha then
				bestAlpha = av
				bestTarget = mob
			end
		end
	end

	return bestTarget
end

-- ============================================================
-- PRIMARY ATTACK
-- EnemyStats.NoStop=true: keep advancing, torso tracks the enemy.
-- Otherwise: pause walking while firing and face with the whole rig.
-- Config.AOE=true: same BASE damage to additional enemies within
-- 3 studs of the primary target (individual defenses still apply).
-- ============================================================
local PRIMARY_AOE_RADIUS_SQ = 3 * 3

local function startAttackLoop(newunit, isAttackWindowRef)
	local stats = newunit:FindFirstChild("EnemyStats")
	local attacksFlag = stats and stats:FindFirstChild("Attacks")
	if not (attacksFlag and attacksFlag:IsA("BoolValue") and attacksFlag.Value) then
		return
	end

	local noStopFlag = stats:FindFirstChild("NoStop")
	local isNoStop = noStopFlag and noStopFlag:IsA("BoolValue") and noStopFlag.Value or false
	local config = newunit:FindFirstChild("Config")
	local RangeVal = config and config:FindFirstChild("Range")
	local DamageVal = config and config:FindFirstChild("Damage")
	local CooldownVal = config and config:FindFirstChild("Cooldown")
	if not (RangeVal and DamageVal and CooldownVal) then
		warn("[Unit]", newunit.Name, "missing Config.Range/Damage/Cooldown; attacks disabled")
		return
	end

	local function pauseForAttack(pause)
		if isNoStop then return end
		if isAttackWindowRef[1] == pause then return end
		isAttackWindowRef[1] = pause
		if newunit.Parent then
			newunit:SetAttribute("AttackPaused", pause)
			if not pause then
				UnitStopAttackEvent:FireAllClients(newunit, nil, 0)
			end
		end
	end

	local lastFacedTarget
	local function clearFacing()
		if not lastFacedTarget then return end
		lastFacedTarget = nil
		if not newunit.Parent then return end
		if isNoStop then
			RotateTorsoEvent:FireAllClients(newunit, nil, 0)
		end
		-- Stopping units are released in pauseForAttack(false), exactly once.
		-- An extra nil event here could restart the rotation-return tween.
	end

	local function eligibleTarget(mob)
		if not (mob and mob.Parent) then return false end
		local mobStats = mob:FindFirstChild("EnemyStats")
		local hp = mobStats and mobStats:FindFirstChild("Health")
		if not (hp and hp.Value > 0) then return false end
		if mobStats:FindFirstChild("Invincible") then return false end
		local fly = mobStats:FindFirstChild("Flying")
		if fly and fly.Value then return false end
		if mobStats:FindFirstChild("Lead") and not config:FindFirstChild("LeadDetection") then
			return false
		end
		return true
	end

	local function damageMob(mob)
		if not alive(newunit) or not eligibleTarget(mob) then return end
		local mobStats = mob:FindFirstChild("EnemyStats")
		local mobHealth = mobStats:FindFirstChild("Health")
		local damage = DamageVal.Value
		local defense = mobStats:FindFirstChild("Defense")
		local defenseValue = defense and defense:FindFirstChild("DefenseValue")
		if defenseValue then
			damage = math_round(damage / (1 + defenseValue.Value))
		end
		local actualDamage = DamageEnemy(mobStats, damage, false)
		AddTowerDamage(newunit, actualDamage)
		GiveDamageCash(actualDamage)
		if mobHealth.Value <= 0 and mob:IsDescendantOf(workspace) then
			mob:Destroy()
			local count = workspace.Info:FindFirstChild("EnemyInGame")
			if count then count.Value -= 1 end
		end
	end

	-- A stopping unit stays stationary while it has an attack target. After
	-- its LAST attack it waits at least 1.5 GAME seconds before walking again.
	-- Every new attack resets the timer, and death cancels the hold.
	-- The position/facing stay frozen during the hold, even when the target's
	-- Hitbox has been destroyed. NoStop units do not use this hold.
	local POST_ATTACK_HOLD = 1.5

	task_spawn(function()
		local lastAttackAt = nil

		while alive(newunit) do
			local hitbox = newunit:FindFirstChild("Hitbox")
			if not hitbox then break end
			local target = findAttackTarget(newunit, hitbox.Position, RangeVal.Value)

			if target and eligibleTarget(target) then
				local duration = math_max(CooldownVal.Value, 0.05) / math_max(getGameSpeed(), 0.05)
				if isNoStop then
					if lastFacedTarget ~= target then
						RotateTorsoEvent:FireAllClients(newunit, target, duration)
					end
				else
					pauseForAttack(true)
					local targetPart = target:FindFirstChild("Hitbox")
					-- Keep a snapshot as well as the live Hitbox. A one-shot
					-- target may be destroyed in THIS server tick, before any
					-- client can read targetPart.Position on RenderStepped.
					local targetPosition = targetPart and targetPart.Position
						or target:GetPivot().Position
					newunit:SetAttribute("AttackFacePosition", targetPosition)
					UnitStopAttackEvent:FireAllClients(
						newunit, targetPart, duration, targetPosition
					)
				end
				lastFacedTarget = target

				if not alive(newunit) then break end
				lastAttackAt = os.clock()
				RepStorage.Events.AnimateUnit:FireAllClients(newunit, "Attack", target)

				local victims = {target}
				local aoe = config:FindFirstChild("AOE")
				local primaryHitbox = target:FindFirstChild("Hitbox")
				if aoe and aoe:IsA("BoolValue") and aoe.Value and primaryHitbox then
					local center = primaryHitbox.Position
					for other in pairs(MobSet) do
						if other ~= target and eligibleTarget(other) then
							local otherHit = other:FindFirstChild("Hitbox")
							if otherHit and (otherHit.Position - center):Dot(otherHit.Position - center) <= PRIMARY_AOE_RADIUS_SQ then
								victims[#victims + 1] = other
							end
						end
					end
				end

				for _, mob in ipairs(victims) do
					if not alive(newunit) then break end
					damageMob(mob)
				end

				-- Do NOT release AttackPaused at the end of the cooldown.
				-- Only resume when the last target has been absent for the
				-- full post-attack hold. This avoids movement flicker between
				-- consecutive attacks on the same or different targets.
				task_wait(duration)
			elseif isNoStop then
				clearFacing()
				task_wait(0.1)
			elseif isAttackWindowRef[1] then
				-- Check the real time since the LAST attack, including time
				-- already spent in cooldown. Don't add another 1.5 seconds
				-- ON TOP of the cooldown; the user-facing hold is measured
				-- from the final shot, not from the next scan for targets.
				local sinceLastShot = lastAttackAt and (os.clock() - lastAttackAt)
					* math.max(getGameSpeed(), 0.05) or POST_ATTACK_HOLD
				if sinceLastShot >= POST_ATTACK_HOLD then
					pauseForAttack(false)
					clearFacing()
				else
					-- Keep checking for new enemies while paused. Another
					-- shot cancels the pending return and resets the clock.
					task_wait(0.05)
				end
			else
				clearFacing()
				task_wait(0.1)
			end
		end

		pauseForAttack(false)
		clearFacing()
	end)
end

local UnitSecondaryExplodeEvent = RepStorage.Events:WaitForChild("UnitSecondaryExplode")

-- ============================================================
-- SECONDARY ATTACK (always explosive/AOE) — gated purely on the
-- presence of a "SecondaryAttack" folder under the unit's Config,
-- independent of EnemyStats.Attacks/NoStop. Runs in parallel with
-- the primary attack loop (if any) on its own cooldown.
-- ============================================================
local function startSecondaryAttackLoop(newunit)
	local config = newunit:FindFirstChild("Config")
	local secondaryFolder = config and config:FindFirstChild("SecondaryAttack")
	if not secondaryFolder then return end

	local RangeVal        = secondaryFolder:FindFirstChild("Range")
	local DamageVal       = secondaryFolder:FindFirstChild("Damage")
	local CooldownVal     = secondaryFolder:FindFirstChild("Cooldown")
	local SplashRadiusVal = secondaryFolder:FindFirstChild("SplashRadius")

	if not (RangeVal and DamageVal and CooldownVal and SplashRadiusVal) then
		warn(
			"[Unit]",
			newunit.Name,
			"has a SecondaryAttack folder but is missing Range/Damage/Cooldown/SplashRadius — secondary attack disabled"
		)
		return
	end

	task_spawn(function()
		while alive(newunit) do

			if not newunit:FindFirstChild("Hitbox") then
				break
			end

			task_wait(
				math_max(CooldownVal.Value, 0.05) / getGameSpeed()
			)

			if not alive(newunit) or not newunit:FindFirstChild("Hitbox") then
				break
			end

			-- ============================================================
			-- Find ONE primary target.
			-- ============================================================
			local primaryTarget = findAttackTarget(
				newunit,
				newunit.Hitbox.Position,
				RangeVal.Value
			)

			if not primaryTarget then
				continue
			end

			local primaryHitbox = primaryTarget:FindFirstChild("Hitbox")
			if not primaryHitbox then
				continue
			end

			-- IMPORTANT:
			-- Capture the position ONCE before doing any damage.
			-- The target can die during the splash loop and the projectile
			-- will still have a valid destination.
			local blastPos = primaryHitbox.Position

			local radius = SplashRadiusVal.Value
			local dmg = DamageVal.Value
			local radiusSq = radius * radius

			-- ============================================================
			-- FIRE VISUALS ONCE.
			--
			-- AnimateUnit2 receives:
			--     newunit
			--     "Attack"
			--     blastPos
			--
			-- It does NOT get fired once per enemy hit by the splash.
			-- ============================================================
			RepStorage.Events.AnimateUnit2:FireAllClients(
				newunit,
				"Attack",
				blastPos
			)

			-- ============================================================
			-- SPLASH DAMAGE
			--
			-- This still checks every mob in the radius.
			-- ============================================================
			for mob in pairs(MobSet) do
				if not alive(newunit) then break end
				local mHit = mob:FindFirstChild("Hitbox")
				local mStats = mob:FindFirstChild("EnemyStats")

				if mHit and mStats then

					local flying = mStats:FindFirstChild("Flying")

					if flying and flying.Value then
						continue
					end

					if mStats:FindFirstChild("Invincible") then
						continue
					end

					local dx = mHit.Position.X - blastPos.X
					local dz = mHit.Position.Z - blastPos.Z

					if (dx * dx + dz * dz) <= radiusSq then

						local hp = mStats:FindFirstChild("Health")

						if hp and hp.Value > 0 then
							-- DamageEnemy applies ExplosionDefense once (not twice).
							local actualDamage = DamageEnemy(mStats, dmg, true)

							AddTowerDamage(
								newunit,
								actualDamage
							)

							GiveDamageCash(
								actualDamage
							)

							if hp.Value <= 0 and mob:IsDescendantOf(workspace) then
								mob:Destroy()

								if workspace.Info:FindFirstChild("EnemyInGame") then
									workspace.Info.EnemyInGame.Value -= 1
								end
							end
						end
					end
				end
			end
		end
	end)
end
--------------------------------------------------------------------------------
-- Explosion visual
--
-- IMPORTANT:
-- This function ONLY needs a Vector3 position.
-- It does NOT require the unit/enemy that caused the explosion to still exist.
--------------------------------------------------------------------------------
function unit.Explode(position, radius)
	if typeof(position) ~= "Vector3" then
		warn("[Unit] Explode called without a valid Vector3 position")
		return
	end

	radius = tonumber(radius) or 0

	if radius <= 0 then
		return
	end

	-- Create the visual independently of the unit/enemy.
	local explosionTemplate = RepStorage.Particle:FindFirstChild("Explosion")
	if not explosionTemplate then
		warn("[Unit] Missing RepStorage.Particle.Explosion")
		return
	end

	local newExplode = explosionTemplate:Clone()
	newExplode.Parent = workspace.Visual

	local inner = newExplode:FindFirstChild("Inner")
	local outer = newExplode:FindFirstChild("Outer")

	if not inner or not outer then
		warn("[Unit] Explosion is missing Inner or Outer")
		newExplode:Destroy()
		return
	end

	-- The position was already captured before the target was destroyed.
	inner.CFrame = CFrame.new(position)
	outer.CFrame = CFrame.new(position)

	local outerTween = TweenService:Create(
		outer,
		TweenInfo.new(
			0.3,
			Enum.EasingStyle.Cubic,
			Enum.EasingDirection.Out,
			0,
			true
		),
		{
			Size = Vector3.new(radius * 2, radius * 2, radius * 2)
		}
	)

	local innerTween = TweenService:Create(
		inner,
		TweenInfo.new(
			0.3,
			Enum.EasingStyle.Cubic,
			Enum.EasingDirection.Out,
			0,
			true
		),
		{
			Size = Vector3.new(radius, radius, radius)
		}
	)

	outerTween:Play()
	innerTween:Play()

	local attachment = inner:FindFirstChild("Attachment")

	if attachment then
		local embers = attachment:FindFirstChild("Embers")
		local fire = attachment:FindFirstChild("Fire")
		local smoke = attachment:FindFirstChild("Smoke")
		local streaks = attachment:FindFirstChild("Streaks")

		if embers then embers:Emit(25) end
		if fire then fire:Emit(25) end
		if smoke then smoke:Emit(25) end
		if streaks then streaks:Emit(25) end
	end

	local explosionSound = inner:FindFirstChild("Explosion")
	if explosionSound then
		explosionSound:Play()
	end

	-- Cleanup is completely independent of the unit/enemy.
	task_spawn(function()
		outerTween.Completed:Wait()

		if inner and inner.Parent then
			inner.Transparency = 1
		end

		if outer and outer.Parent then
			outer.Transparency = 1
		end

		task_wait(4)

		if newExplode and newExplode.Parent then
			newExplode:Destroy()
		end
	end)
end

--------------------------------------------------------------------------------
-- SINGLE DEATH / DESPAWN PATH
--------------------------------------------------------------------------------
-- Every unit increments Info.EnemyInGame on spawn. Only finishUnit may
-- decrement it, once. Health <= 0 is terminal immediately: it cannot
-- attack or ram again. The model is kept ONLY as a visual death rig while
-- DeathEffects plays; it is destroyed after the configured Duration.
local FinishedUnits = setmetatable({}, { __mode = "k" })
local RamInProgress = setmetatable({}, { __mode = "k" })
local HealthConnections = setmetatable({}, { __mode = "k" })

local function deathSplash(newunit, position)
	local maxHealth = newunit.EnemyStats:FindFirstChild("MaxHealth")
	if not maxHealth then return end
	local damage = math_round(maxHealth.Value * 0.15)
	local radiusSq = 3.5 * 3.5
	for enemy in pairs(MobSet) do
		local hit = enemy:FindFirstChild("Hitbox")
		local enemyStats = enemy:FindFirstChild("EnemyStats")
		local hp = enemyStats and enemyStats:FindFirstChild("Health")
		if hit and hp and hp.Value > 0 and not enemyStats:FindFirstChild("Invincible") then
			local flying = enemyStats:FindFirstChild("Flying")
			if not (flying and flying.Value) then
				local dx = hit.Position.X - position.X
				local dz = hit.Position.Z - position.Z
				if dx*dx + dz*dz <= radiusSq then
					local actual = DamageEnemy(enemyStats, damage, true)
					AddTowerDamage(newunit, actual)
					GiveDamageCash(actual)
					if hp.Value <= 0 and enemy:IsDescendantOf(workspace) then
						enemy:Destroy()
						local count = workspace.Info:FindFirstChild("EnemyInGame")
						if count then count.Value -= 1 end
					end
				end
			end
		end
	end
end

local function finishUnit(newunit, died)
	if not newunit or FinishedUnits[newunit] then return end
	FinishedUnits[newunit] = true

	-- This is the gameplay death. ALL combat and movement loops use alive(),
	-- so nothing can attack, ram or advance from this point onward.
	if newunit.Parent then
		newunit:SetAttribute("Dead", true)
		newunit:SetAttribute("AttackPaused", false)
		UnitStopAttackEvent:FireAllClients(newunit, nil, 0)
		RotateTorsoEvent:FireAllClients(newunit, nil, 0)
	end

	local healthConn = HealthConnections[newunit]
	if healthConn then healthConn:Disconnect() end
	HealthConnections[newunit] = nil

	local stats = newunit:FindFirstChild("EnemyStats")
	local hitbox = newunit:FindFirstChild("Hitbox")
	local root = newunit.PrimaryPart or newunit:FindFirstChild("HumanoidRootPart")
	-- Server position is stored on Hitbox. The visible model normally moves
	-- client-side, so its server-side root can still be near the spawn point.
	local deathCF = (hitbox and hitbox.CFrame) or (root and root.CFrame)
	local deathPos = deathCF and deathCF.Position

	local effects = died and newunit:FindFirstChild("DeathEffects")
	local holdSeconds = 0

	if died then
		local explodeFlag = stats and stats:FindFirstChild("Explode")
		local shouldExplode = explodeFlag and explodeFlag:IsA("BoolValue") and explodeFlag.Value
		if shouldExplode and deathPos then
			-- The intended EXPLOSION is the only possible damage at death;
			-- it happens once and only for units with Explode=true.
			if RamInProgress[newunit] then
				deathSplash(newunit, deathPos)
			end
			local radiusObject = stats:FindFirstChild("ExplosionRadius")
			local radius = radiusObject and tonumber(radiusObject.Value) or 3.5
			if radius > 0 then unit.Explode(deathPos, radius) end
		end

		if effects and effects:IsA("Folder") and deathCF then
			-- Default: 4 GAME seconds. Set DeathEffects.Duration on the unit
			-- to match long/short death animations (e.g. Duration=5).
			local configuredDuration = tonumber(effects:GetAttribute("Duration")) or 4
			holdSeconds = math.clamp(configuredDuration / math.max(getGameSpeed(), 0.05), 0.1, 60)

			-- Put the actual server rig where the client was rendering it.
			-- Without this, its anchored HumanoidRootPart can snap back to
			-- spawn as soon as client-side path animation stops.
			if newunit.PrimaryPart then
				newunit:PivotTo(deathCF)
			end

			-- No physical collision, touch-triggered damage or targetable
			-- hitboxes on a dead unit. The Motor6Ds remain intact for Death.
			for _, obj in ipairs(newunit:GetDescendants()) do
				if obj:IsA("BasePart") then
					obj.CanCollide = false
					obj.CanTouch = false
					obj.CanQuery = false
				elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
					obj.Enabled = false
				end
			end

			-- IMPORTANT: DO NOT reparent the animated rig at the same moment
			-- that Death plays. Moving workspace.Units -> workspace.Visual
			-- can interrupt client animation state/replication, leaving the
			-- original model stuck in its resting pose. It remains in Units,
			-- but Dead=true, Health=0, collisions disabled, and ALL server
			-- combat / movement loops have stopped. Unit counters update now.
			newunit:SetAttribute("UnitDeathPresentation", true)

			-- Also trigger the client via event; the client independently
			-- watches UnitDeathPresentation so it survives event ordering.
			UnitDeathEvent:FireAllClients(newunit, deathCF)
		end
	end

	RamInProgress[newunit] = nil
	local count = workspace.Info:FindFirstChild("EnemyInGame")
	if count then count.Value = math.max(0, count.Value - 1) end

	-- Remaining in workspace is VISUAL ONLY: Dead=true and Health<=0 stop
	-- server attack, ram and movement before this delay starts.
	if holdSeconds > 0 then
		task.delay(holdSeconds, function()
			if newunit and newunit.Parent then
				newunit:Destroy()
			end
		end)
	elseif newunit.Parent then
		newunit:Destroy()
	end
end

--------------------------------------------------------------------------------
-- Server unit movement
--------------------------------------------------------------------------------
function unit.Move(newunit, map, path, pathLength, offset)
	if not alive(newunit) then return end
	offset = offset or Vector3.new(0, 0, 0)
	local lastUpdateTime = tick()
	local height = newunit.EnemyStats.HipHeight.Value + newunit.PrimaryPart.Size.Y / 2
	local T = newunit:WaitForChild("Alpha").Value
	local hitbox = newunit:FindFirstChild("Hitbox")
	if not hitbox then finishUnit(newunit, false); return end
	hitbox.CFrame = path:CalculateUniformCFrame(T) + Vector3.new(0, height, 0) + offset

	-- Shared with the primary attack loop: stop-to-attack pauses both the
	-- server's Alpha and the client's path interpolation.
	local isAttackWindowRef = { false }
	startAttackLoop(newunit, isAttackWindowRef)
	startSecondaryAttackLoop(newunit)

	while T < 1 and alive(newunit) do
		local now = tick()
		if now - lastUpdateTime >= Interval then
			lastUpdateTime = now
			local alpha = newunit:FindFirstChild("Alpha")
			local hb = newunit:FindFirstChild("Hitbox")
			if not (alpha and hb) then break end
			alpha.Value = T
			hb.CFrame = path:CalculateUniformCFrame(T) + Vector3.new(0, height, 0) + offset
		end

		local dt = RunService.PostSimulation:Wait()
		if not alive(newunit) then break end
		if not isAttackWindowRef[1] then
			T += (newunit.EnemyStats.Speed.Value * workspace.Info.GameSpeed.Value * dt) / math.max(pathLength, 0.001)
		end
	end
	-- A death might have been handled already by the health Changed event.
	-- Reaching the end of the path is a despawn, not an animated death.
	if alive(newunit) then finishUnit(newunit, false) end
end

--------------------------------------------------------------------------------
-- Spawn
--------------------------------------------------------------------------------
function unit.Spawn(name, quantity, cooldown, healthMultiplier, speedMultiplier, map, ownerTower)
	local unitExists = RepStorage.Units:FindFirstChild(name)
	if not unitExists then
		warn("No unit found with name:", name)
		return
	end

	local info = workspace:WaitForChild("Info")
	local gsVal = info:FindFirstChild("GameSpeed")

	local function getGS()
		local v = gsVal and gsVal.Value or 1
		if v == 0 then v = 1 end
		return v
	end

	for i = 1, quantity do
		task.wait(cooldown / getGS())

		if info.Message.Value == "GAME OVER" then
			return
		end

		local newunit = unitExists:Clone()

		newunit.EnemyStats.MaxHealth.Value = math.round(newunit.EnemyStats.MaxHealth.Value * healthMultiplier)
		newunit.EnemyStats.Health.Value = math.round(newunit.EnemyStats.Health.Value * healthMultiplier)

		if newunit:FindFirstChild("IsFinalBoss") and info.EnemyMultiplier.Value > 1 then
			newunit.EnemyStats.MaxHealth.Value = math.round(newunit.EnemyStats.MaxHealth.Value * healthMultiplier) * 2
			newunit.EnemyStats.Health.Value = math.round(newunit.EnemyStats.Health.Value * healthMultiplier) * 2
		end

		newunit.EnemyStats.Speed.Value *= speedMultiplier
		newunit.EnemyStats.OrigSpeed.Value *= speedMultiplier

		if ownerTower then
			local ownerValue = Instance.new("ObjectValue")
			ownerValue.Name = "OwnerTower"
			ownerValue.Value = ownerTower
			ownerValue.Parent = newunit

			-- Keep a direct reference to the exact damage counter this unit should
			-- credit. ObjectValues do not create event connections, and this object
			-- is destroyed automatically with the unit, so there is no cleanup leak.
			local ownerConfig = ownerTower:FindFirstChild("Config")
			local totalDamage =
				ownerConfig
				and ownerConfig:FindFirstChild("TotalDamage")

			if totalDamage and totalDamage:IsA("ValueBase") then
				local damageValue = Instance.new("ObjectValue")
				damageValue.Name = "OwnerDamageValue"
				damageValue.Value = totalDamage
				damageValue.Parent = newunit
			end

			local linkedVal = Instance.new("BoolValue")
			linkedVal.Name = "LinkedToTower"
			linkedVal.Value = true
			linkedVal.Parent = newunit
		end

		local height = newunit.EnemyStats.HipHeight.Value + (newunit.PrimaryPart.Size.Y / 1.75)
		newunit.HumanoidRootPart.CFrame = map.UnitWaypoints["1"].CFrame + Vector3.new(0, height, 0)
		newunit.Parent = workspace.Units
		newunit.HumanoidRootPart.Anchored = true

		local alpha = Instance.new("NumberValue")
		alpha.Name = "Alpha"
		alpha.Parent = newunit

		for _, object in ipairs(newunit:GetDescendants()) do
			if object:IsA("BasePart") then
				object.CollisionGroup = "Unit"
			end
		end

		info.EnemyInGame.Value += 1
		newunit:SetAttribute("Dead", false)
		newunit:SetAttribute("AttackPaused", false)
		local hpValue = newunit.EnemyStats:FindFirstChild("Health")
		if hpValue then
			HealthConnections[newunit] = hpValue.Changed:Connect(function(hp)
				if hp <= 0 then finishUnit(newunit, true) end
			end)
		end

		-- The same contact damage as before, but now it cannot fire once
		-- Health <= 0. Ram and destruction use finishUnit exactly once.
		local DAMAGE_RANGE = newunit.EnemyStats.RamRange and newunit.EnemyStats.RamRange.Value or 5
		local runConnection
		runConnection = RunService.Heartbeat:Connect(function()
			if not alive(newunit) then
				if runConnection then runConnection:Disconnect(); runConnection = nil end
				return
			end
			local unitStats = newunit:FindFirstChild("EnemyStats")
			local unitHP = unitStats and unitStats:FindFirstChild("Health")
			local unitHitbox = newunit:FindFirstChild("Hitbox")
			if not (unitHP and unitHitbox) then return end

			for mobModel in pairs(MobSet) do
				if not alive(newunit) then break end
				local mobHitbox = mobModel:FindFirstChild("Hitbox")
				local mobStats = mobModel:FindFirstChild("EnemyStats")
				local mobHP = mobStats and mobStats:FindFirstChild("Health")
				if not (mobHitbox and mobHP and mobHP.Value > 0) then continue end
				local flying = mobStats:FindFirstChild("Flying")
				if flying and flying.Value then continue end
				local dx = mobHitbox.Position.X - unitHitbox.Position.X
				local dz = mobHitbox.Position.Z - unitHitbox.Position.Z
				if dx*dx + dz*dz > DAMAGE_RANGE*DAMAGE_RANGE then continue end

				-- Both impact amounts are snapshotted while both are alive.
				-- Resolve the direct impact on the enemy FIRST; the unit's
				-- own fatal damage happens afterward. That prevents a dead
				-- unit from making an extra attack during the death callback.
				local unitDamage = mobHP.Value
				local mobDamage = unitHP.Value
				local invincible = mobStats:FindFirstChild("Invincible") ~= nil
				local actual = 0
				if not invincible then
					actual = DamageEnemy(mobStats, mobDamage, false)
				end
				AddTowerDamage(newunit, actual)
				GiveDamageCash(actual)
				if mobHP.Value <= 0 and mobModel:IsDescendantOf(workspace) then
					mobModel:Destroy()
					local count = workspace.Info:FindFirstChild("EnemyInGame")
					if count then count.Value -= 1 end
				end

				-- This health change immediately invokes the terminal
				-- handler if it kills the unit. It handles optional death
				-- splash/explosion and death visuals, then destroys it.
				RamInProgress[newunit] = true
				unitHP.Value = math.max(0, unitHP.Value - (invincible and 5000 or unitDamage))
				RamInProgress[newunit] = nil
				break
			end
		end)

		local path, pathLength, positions = unit.WayPointsLoad(map)
		if path and pathLength and positions then
			local offset = Vector3.new(math.random(-35, 35)/100, 0, math.random(-35,35)/100)

			RepStorage.Events.ReplicateUnit:FireAllClients(
				newunit,
				positions,
				newunit.EnemyStats.HipHeight.Value + (newunit.PrimaryPart.Size.Y / 2),
				offset
			)

			task_spawn(unit.Move, newunit, map, path, pathLength, offset)
		else
			finishUnit(newunit, false)
		end
	end
end

return unit
