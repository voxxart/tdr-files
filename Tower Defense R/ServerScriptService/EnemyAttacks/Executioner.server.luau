local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local events = ReplicatedStorage:WaitForChild("Events")
local AnimateEnemy = events:WaitForChild("AnimateEnemy")
local AnimateTowerDeath = events:WaitForChild("AnimateTowerDeath")

local TOWERDEATH_MOD = require(game.ServerScriptService.Main.TowerDeath)

local TowersFolder = workspace:WaitForChild("Towers")
local GameSpeedValue = workspace.Info:WaitForChild("GameSpeed")

-- Track all enemies you want simulated by the manager
local TAG = "Executioner"

-- Per-enemy state (weak so GC cleans if model goes away)
local State = setmetatable({}, {__mode="k"}) -- [enemy] = {rng=Random, nextT=number, data=table}

local function gs()
	local v = GameSpeedValue.Value
	if v <= 0 then return 1 end
	return v
end

local function isAliveEnemy(enemy)
	return enemy and enemy.Parent and enemy.PrimaryPart and enemy:FindFirstChild("Hitbox")
end

local function isValidTower(tower)
	return tower
		and tower.Parent == TowersFolder
		and tower:IsA("Model")
		and tower.PrimaryPart
		and tower:FindFirstChild("Config")
		and tower.Config:FindFirstChild("Health")
		and tower.Config.Health:FindFirstChild("HealthValue")
		and tower.Config.Health:FindFirstChild("MaxHealth")
end

local function findNearestTower(enemy, range)
	local maxDist = range or 8
	local maxSq = maxDist * maxDist
	local epos = enemy.Hitbox.Position

	local best, bestSq = nil, maxSq
	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(tower) and not tower.Config:FindFirstChild("Flying") and not tower.Config:FindFirstChild("CliffTower") then
			local tpos = tower.PrimaryPart.Position
			local dx = tpos.X - epos.X
			local dz = tpos.Z - epos.Z
			local d2 = dx*dx + dz*dz
			if d2 < bestSq then
				bestSq = d2
				best = tower
			end
		end
	end
	return best
end

-- Helper: schedule next attack time for this enemy
local function schedule(enemy, s, minCd, maxCd)
	minCd = minCd or 6
	maxCd = maxCd or 11
	local g = gs()
	s.nextT = os.clock() + s.rng:NextNumber(minCd/g, maxCd/g)
end

--------------------------------------------------------------------
-- ATTACK BEHAVIORS (ONE function per enemy type)
--------------------------------------------------------------------
local Behaviors = {}

-- Your current enemy logic as a behavior:
Behaviors.TowerKiller = function(enemy, s)
	local range = enemy:GetAttribute("Range") or 8
	local minCd = enemy:GetAttribute("AttackMin") or 6
	local maxCd = enemy:GetAttribute("AttackMax") or 11

	-- only attack when cooldown ready
	if os.clock() < s.nextT then return end
	schedule(enemy, s, minCd, maxCd)

	local target = findNearestTower(enemy, range)
	if not target then return end

	local hv = target.Config.Health.HealthValue
	if hv.Value <= 0 then return end

	-- face target
	local epos = enemy.Hitbox.Position
	local tpos = target.PrimaryPart.Position
	enemy.Hitbox.CFrame = CFrame.lookAt(epos, Vector3.new(tpos.X, enemy.PrimaryPart.Position.Y, tpos.Z))

	AnimateEnemy:FireAllClients(enemy, "Fire", target)

	-- damage
	local maxH = target.Config.Health.MaxHealth.Value
	local newHealth
	if workspace.Info.Modifiers["Death Wish"].Value == true then 
		newHealth = math.round(hv.Value - maxH * 0.2)
	else
		newHealth = math.round(hv.Value - maxH * 0.15)
	end
	hv.Value = newHealth

	-- IMPORTANT: kill tower immediately (no waits that can be canceled by enemy dying)
	if newHealth <= 0 then
		AnimateTowerDeath:FireAllClients(target, "TowerDeath", target)
		local ownerName = target.Config.Owner.Value
		local ownerPlayer = Players:FindFirstChild(ownerName)
		TOWERDEATH_MOD.KillTower(target, ownerPlayer)
	end
end

-- Example: a different enemy type (burst attack)
Behaviors.BurstShooter = function(enemy, s)
	-- you can store custom state in s.data
	local data = s.data
	if not data then
		data = {shotsLeft = 0}
		s.data = data
	end

	local minCd = enemy:GetAttribute("AttackMin") or 4
	local maxCd = enemy:GetAttribute("AttackMax") or 7
	local burstCount = enemy:GetAttribute("BurstCount") or 3
	local burstGap = enemy:GetAttribute("BurstGap") or 0.12

	local now = os.clock()
	if data.shotsLeft > 0 then
		if now >= (data.nextShotT or 0) then
			data.shotsLeft -= 1
			data.nextShotT = now + burstGap / gs()

			local target = findNearestTower(enemy, enemy:GetAttribute("Range") or 10)
			if target then
				AnimateEnemy:FireAllClients(enemy, "Fire", target)
				-- apply your burst damage here...
			end
		end
		return
	end

	-- start a new burst when main cooldown is ready
	if now < s.nextT then return end
	schedule(enemy, s, minCd, maxCd)
	data.shotsLeft = burstCount
	data.nextShotT = now
end

--------------------------------------------------------------------
-- TRACKING
--------------------------------------------------------------------
local function start(enemy)
	if State[enemy] then return end
	State[enemy] = {rng = Random.new(), nextT = 0, data = nil}
	-- seed nextT so they don't all attack on the same frame
	schedule(enemy, State[enemy], enemy:GetAttribute("AttackMin") or 6, enemy:GetAttribute("AttackMax") or 11)

	enemy.AncestryChanged:Connect(function(_, parent)
		if not parent then
			State[enemy] = nil
		end
	end)
end

for _, enemy in ipairs(CollectionService:GetTagged(TAG)) do
	start(enemy)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(start)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(enemy) State[enemy] = nil end)

--------------------------------------------------------------------
-- ONE LOOP TOTAL
--------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	for enemy, s in pairs(State) do
		if not isAliveEnemy(enemy) then
			State[enemy] = nil
		else
			Behaviors.TowerKiller(enemy, s)
		end
	end
end)
