--// mine MODULE — stationary proximity mines
--// Placed by MineLayer towers; explode independently on proximity —
--// each mine only cares about mobs within its own TriggerRange, so a
--// mob stepping on multiple mines at once sets off all of them, but
--// mines never trigger each other.
--// Range checks are HORIZONTAL ONLY (XZ) so tall/large bosses whose
--// Hitbox sits high above the ground still trigger/take damage from
--// mines directly beneath them.

local PhysicsService = game:GetService("PhysicsService")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local Players         = game:GetService("Players")

local Workspace = workspace
local MobsFolder = Workspace:WaitForChild("Mobs")
local MinesFolder = Workspace.GameDependencies:WaitForChild("Mines")
local Info = Workspace:WaitForChild("Info")
local GameSpeedValue = Info:FindFirstChild("GameSpeed")

local events   = RepStorage:WaitForChild("Events")
local MLevents = events:WaitForChild("MinelayerEvents")
local ExplodeMineEvent = MLevents:WaitForChild("ExplodeMine")

local task_spawn = task.spawn
local task_wait  = task.wait
local math_max   = math.max
local math_min   = math.min
local math_round = math.round
local math_sqrt  = math.sqrt

local mine = {}

local function getGameSpeed()
	local v = GameSpeedValue and GameSpeedValue.Value or 1
	if v == 0 then v = 1 end
	return v
end

-- Horizontal-only distance (ignores Y) so tall/large mobs whose Hitbox
-- sits well above ground level still register as "on top of" a mine.
local function horizontalDistance(posA, posB)
	local dx = posA.X - posB.X
	local dz = posA.Z - posB.Z
	return math_sqrt(dx*dx + dz*dz)
end

-- Live mob set (no GetChildren per proximity check)
local MobSet = {}
for _, m in ipairs(MobsFolder:GetChildren()) do MobSet[m] = true end
MobsFolder.ChildAdded:Connect(function(m)   MobSet[m] = true  end)
MobsFolder.ChildRemoved:Connect(function(m) MobSet[m] = nil   end)

-- Cached player list (refreshed on join/leave only — same pattern as tower.lua)
local CachedPlayers = Players:GetPlayers()
Players.PlayerAdded:Connect(function()   CachedPlayers = Players:GetPlayers() end)
Players.PlayerRemoving:Connect(function() CachedPlayers = Players:GetPlayers() end)

-- Boss Buster damage multiplier tiers, keyed off the boss mob's health.
-- Ranges are inclusive on both ends as specified:
--   0–12,499 -> 3x | 12,500–99,999 -> 6x | 100,000–199,999 -> 8x
--   200,000–299,999 -> 10x | 300,000–399,999 -> 12x | 400,000–499,999 -> 14x
--   500,000+ -> 16x
local function getBossMultiplier(hp)
	if hp <= 12499 then
		return 4
	elseif hp <= 99999 then
		return 7
	elseif hp <= 199999 then
		return 9
	elseif hp <= 299999 then
		return 11
	elseif hp <= 399999 then
		return 13
	elseif hp <= 499999 then
		return 16
	else
		return 20
	end
end

-- name, world position, owner tower model, owner config, owner's CurrentMines
-- IntValue, and whether this is a Boss Buster mine (changes damage math
-- against IsBoss mobs only — everything else is damaged identically).
function mine.Spawn(name, position, ownerTower, ownerConfig, currentMinesValue, isBossBuster)
	local function decrement()
		if currentMinesValue and currentMinesValue.Parent then
			currentMinesValue.Value = math_max(0, currentMinesValue.Value - 1)
		end
	end

	local mineTemplate = RepStorage.Mines:FindFirstChild(name)
	if not mineTemplate then
		warn("[Mine] No mine template found in ReplicatedStorage.Mines named:", name)
		decrement()
		return
	end
	if not (ownerTower and ownerTower.Parent and ownerConfig and ownerConfig.Parent) then
		warn("[Mine] Owner tower or config was gone before mine could spawn")
		decrement()
		return
	end

	local newMine = mineTemplate:Clone()
	local stats   = newMine:FindFirstChild("EnemyStats")
	local hitbox  = newMine:FindFirstChild("Hitbox")
	local HRP = newMine:FindFirstChild("HumanoidRootPart")

	if not stats then
		warn("[Mine] Template", name, "is missing an EnemyStats child")
		newMine:Destroy()
		decrement()
		return
	end
	if not hitbox then
		warn("[Mine] Template", name, "is missing a Hitbox child")
		newMine:Destroy()
		decrement()
		return
	end

	local hipHeight = (stats:FindFirstChild("HipHeight") and stats.HipHeight.Value) or 0
	local placeCFrame 
	if stats:FindFirstChild("AdjustedMine") then
		placeCFrame	= CFrame.new(position.X, position.Y + hipHeight, position.Z) * CFrame.Angles(math.rad(90), 0, 0)
	else 
		placeCFrame	= CFrame.new(position.X, position.Y + hipHeight, position.Z) * CFrame.Angles(0, 0, 0)
	end

	if newMine.PrimaryPart then
		newMine:PivotTo(placeCFrame)
	else
		local anchorPart = newMine:FindFirstChild("HumanoidRootPart") or newMine:FindFirstChildWhichIsA("BasePart")
		if anchorPart then
			warn("[Mine] Template", name, "has no PrimaryPart set — falling back to", anchorPart:GetFullName())
			anchorPart.CFrame = placeCFrame
		else
			warn("[Mine] Template", name, "has no PrimaryPart AND no BasePart at all — cannot position it")
			newMine:Destroy()
			decrement()
			return
		end
	end

	newMine.Parent = MinesFolder

	for _, obj in ipairs(newMine:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
		end
	end

	local hrp = newMine:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.Anchored = true end

	for _, obj in ipairs(newMine:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.CollisionGroup = "Unit"
		end
	end

	local DAMAGE_RANGE  = (stats:FindFirstChild("ExplosionRange") and stats.ExplosionRange.Value) or 3
	local TRIGGER_RANGE = (stats:FindFirstChild("TriggerRange") and stats.TriggerRange.Value) or 2.5
	local damage        = (stats:FindFirstChild("Health") and stats.Health.Value) or 0
	local lifetime      = (stats:FindFirstChild("Lifetime") and stats.Lifetime.Value) or 15

	local removed = false
	local triggerConn

	local function cleanup()
		if removed then return end
		removed = true
		if triggerConn then triggerConn:Disconnect(); triggerConn = nil end
		decrement()
	end

	local function explode()
		if removed then return end
		local hbPos = hitbox.Position

		-- Owner may have been sold/destroyed since this mine was placed —
		-- re-check its liveness at explosion time, not just at spawn time.
		local ownerAlive = ownerTower and ownerTower.Parent and ownerConfig and ownerConfig.Parent
		local ownerTotalDamage = ownerAlive and ownerConfig:FindFirstChild("TotalDamage")

		for mob in pairs(MobSet) do
			local mHit   = mob:FindFirstChild("Hitbox")
			local mStats = mob:FindFirstChild("EnemyStats")
			if mHit and mStats then
				if horizontalDistance(mHit.Position, hbPos) <= DAMAGE_RANGE then
					if mStats:FindFirstChild("Invincible") then
						local shield = mHit:FindFirstChild("Shield")
						if shield then shield.Attack:Play() end
						continue
					end

					local hp = mStats:FindFirstChild("Health")
					if hp and hp.Value > 0 then
						-- Boss Buster mines only change the formula for mobs
						-- with an IsBoss flag — everything else (including
						-- bosses when this ISN'T a Boss Buster mine) uses the
						-- normal flat damage value, unchanged.
						local baseDamage = damage
						if isBossBuster and mob:FindFirstChild("IsBoss") then
							local healthStat = mStats:FindFirstChild("MaxHealth") or hp
							local mult = getBossMultiplier(healthStat.Value)
							baseDamage = damage * mult
						end

						local expDef = mStats:FindFirstChild("ExplosionDefense")
						local adjDamage = expDef
							and math_round(baseDamage / (1 + expDef.DefenseValue.Value))
							or baseDamage
						local dealt = math_min(adjDamage, hp.Value)

						hp.Value = math_max(0, hp.Value - adjDamage)

						-- Attribute damage to the owning tower ONLY if it (and its
						-- Config) still exist right now. If the tower's gone, the
						-- mine still deals damage/cash — it just isn't tallied.
						if ownerTotalDamage then
							ownerTotalDamage.Value += dealt
						end

						local killed = hp.Value <= 0 and mob:IsDescendantOf(Workspace)
						local noCash = mStats:FindFirstChild("NoCash")
						local hasShield = mStats:FindFirstChild("ShieldHealth")
							and mStats.ShieldHealth.Health.Value > 0

						if dealt > 0 and not noCash and not hasShield then
							local reward = math_max(1, math_round(dealt * 0.40))
							for _, plr in ipairs(CachedPlayers) do
								local cash = plr:FindFirstChild("Cash")
								if cash then cash.Value += reward end
							end
						end

						if killed then
							mob:Destroy()
							if Info:FindFirstChild("EnemyInGame") then
								Info.EnemyInGame.Value -= 1
							end
						end
					end
				end
			end
		end

		ExplodeMineEvent:FireAllClients(hbPos, DAMAGE_RANGE)
		cleanup()
		if newMine and newMine.Parent then newMine:Destroy() end
	end

	-- Proximity trigger: any mob within TRIGGER_RANGE (horizontal only)
	-- detonates THIS mine only. Mines never trigger each other — if a
	-- mob steps within range of several mines at once, each one
	-- independently detects it on this same Heartbeat and explodes on
	-- its own, which is the "sets off every one it steps on" behavior.
	triggerConn = RunService.Heartbeat:Connect(function()
		if removed or not newMine.Parent then
			if triggerConn then triggerConn:Disconnect(); triggerConn = nil end
			return
		end
		local hbPos = hitbox.Position
		for mob in pairs(MobSet) do
			local mHit = mob:FindFirstChild("Hitbox")
			if mHit and horizontalDistance(mHit.Position, hbPos) <= TRIGGER_RANGE and not mob.EnemyStats:FindFirstChild("Flying") then
				explode()
				return
			end
		end
	end)

	-- Lifetime expiry + visual countdown bar.
	-- Reuses the SAME 0.2s tick loop for both jobs — no extra Heartbeat/RenderStepped
	-- connection is spun up just to animate the bar. The Fill instance is looked up
	-- once here and cached, so the loop only ever does a single Size write per tick.
	local lifetimeGui = hrp:FindFirstChild("Lifetime")
	local fill = lifetimeGui and lifetimeGui:FindFirstChild("Bar")
	fill = fill and fill:FindFirstChild("Fill")
	if fill then
		fill.Size = UDim2.new(1, 0, 1, 0)
	end

	task_spawn(function()
		local elapsed = 0
		while newMine.Parent and not removed do
			task_wait(0.2)
			elapsed += 0.2 * getGameSpeed()

			if fill then
				fill.Size = UDim2.new(math_max(0, 1 - elapsed / lifetime), 0, 1, 0)
			end

			if elapsed >= lifetime then
				cleanup()
				if newMine and newMine.Parent then newMine:Destroy() end
				break
			end
		end
	end)

	newMine.Destroying:Connect(cleanup)
end

return mine
