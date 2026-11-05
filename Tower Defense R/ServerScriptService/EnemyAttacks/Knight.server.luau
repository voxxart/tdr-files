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

local TAG = "Knight"
local State = setmetatable({}, {__mode="k"}) -- weak table for enemies

---------------------------------------------------------
-- HELPERS
---------------------------------------------------------
local function gs()
	local v = GameSpeedValue.Value
	if v <= 0 then return 1 end
	return v
end

local function isAliveEnemy(enemy)
	return enemy and enemy.Parent and enemy.PrimaryPart and enemy:FindFirstChild("Hitbox")
end

local function isValidTower(tower)
	if not tower or tower.Parent ~= TowersFolder then return false end
	local cfg = tower:FindFirstChild("Config")
	local health = cfg and cfg:FindFirstChild("Health")
	return tower.PrimaryPart and cfg and health and health:FindFirstChild("HealthValue") and health:FindFirstChild("MaxHealth")
end

local function findNearestTower(enemy, range)
	range = range or 8
	local epos = enemy.Hitbox.Position
	local best, bestDist = nil, range * range

	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(tower) and tower:FindFirstChild("Config") and not tower.Config:FindFirstChild("Flying") and not tower.Config:FindFirstChild("CliffTower") then
			local tpos = tower.PrimaryPart.Position
			local dx, dz = tpos.X - epos.X, tpos.Z - epos.Z
		local dist2 = dx*dx + dz*dz
			if dist2 < bestDist then
				bestDist = dist2
				best = tower
			end
		end
	end
	return best
end

local function schedule(enemy, s, minCd, maxCd)
	s.nextT = os.clock() + s.rng:NextNumber(minCd/gs(), maxCd/gs())
end

local function attackTower(enemy, tower)
	if not isValidTower(tower) then return end

	local healthFolder = tower.Config.Health
	local healthValue = healthFolder.HealthValue
	local maxHealth = healthFolder.MaxHealth

	local damage
	if workspace.Info.Modifiers["Death Wish"].Value == true then
		damage  = math.round(maxHealth.Value * 0.30)
	else
		damage = math.round(maxHealth.Value * 0.25)
	end
	healthValue.Value = healthValue.Value - damage

	-- Rotate enemy to face tower
	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	if hrp and tower.PrimaryPart then
		local cf = CFrame.lookAt(hrp.Position, Vector3.new(tower.PrimaryPart.Position.X, hrp.Position.Y, tower.PrimaryPart.Position.Z))
		enemy.Hitbox.CFrame = cf
	end

	AnimateEnemy:FireAllClients(enemy, "Fire", tower)

	if healthValue.Value <= 0 then
		if not tower:GetAttribute("Dying") then
			tower:SetAttribute("Dying", true)
			task.spawn(function()
				if not (tower and tower.Parent) then return end
				AnimateTowerDeath:FireAllClients(tower, "TowerDeath", tower)

				local ownerPlayer
				local ownerNameValue = tower.Config:FindFirstChild("Owner")
				if ownerNameValue and ownerNameValue.Value ~= "" then
					ownerPlayer = Players:FindFirstChild(ownerNameValue.Value)
				end

				task.wait(0.5/gs())
				if tower and tower.Parent then
					TOWERDEATH_MOD.KillTower(tower, ownerPlayer)
				end
			end)
		end
	end
end

---------------------------------------------------------
-- BEHAVIOR
---------------------------------------------------------
local Behaviors = {}
Behaviors.Knight = function(enemy, s)
	if os.clock() < s.nextT then return end
	schedule(enemy, s, 3, 5)

	local target = findNearestTower(enemy)
	if target then
		attackTower(enemy, target)
	end
end

---------------------------------------------------------
-- START / TRACKING
---------------------------------------------------------
local function start(enemy)
	if State[enemy] then return end
	State[enemy] = {rng = Random.new(), nextT = 0}
	schedule(enemy, State[enemy], 3, 5)

	enemy.AncestryChanged:Connect(function(_, parent)
		if not parent then State[enemy] = nil end
	end)
end

for _, enemy in ipairs(CollectionService:GetTagged(TAG)) do
	start(enemy)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(start)
CollectionService:GetInstanceRemovedSignal(TAG, function(enemy)
	State[enemy] = nil
end)

---------------------------------------------------------
-- HEARTBEAT LOOP
---------------------------------------------------------
RunService.Heartbeat:Connect(function()
	for enemy, s in pairs(State) do
		if not isAliveEnemy(enemy) then
			State[enemy] = nil
		else
			Behaviors.Knight(enemy, s)
		end
	end
end)