local Tower = {}

local TOWER_MODULE = require(game.ServerScriptService.Main.TowerServer)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Particle = ReplicatedStorage.Particle:WaitForChild("Burn")
local Events = ReplicatedStorage:WaitForChild("Events")
local GameSpeedValue = workspace.Info:WaitForChild("GameSpeed")

--------------------------------------------------------
-- SAFE OWNER RESOLVER
--------------------------------------------------------
local function getOwnerPlayer(tower)
	local config = tower and tower:FindFirstChild("Config")
	if not config then return nil end

	local ownerValue = config:FindFirstChild("Owner")
	if not ownerValue then return nil end

	local ownerName = ownerValue.Value
	if typeof(ownerName) ~= "string" or ownerName == "" then return nil end

	local player = Players:FindFirstChild(ownerName)
	if not player then
		return nil
	end

	return player
end

--------------------------------------------------------
-- VISUAL DEATH EFFECTS
--------------------------------------------------------
local function applyDeathVisuals(newTower)
	for _, part in ipairs(newTower:GetDescendants()) do
		if part:IsA("BasePart") then
			part.BrickColor = BrickColor.new("Really black")
			part.Material = Enum.Material.CrackedLava
		end
	end

	local torso = newTower:FindFirstChild("Torso")
	if torso then
		local fire = Particle:Clone()
		fire.Parent = torso
	end
end

--------------------------------------------------------
-- DISABLE STATS
--------------------------------------------------------
local function disableTower(newTower)
	local config = newTower:FindFirstChild("Config")
	if not config then return end

	local range = config:FindFirstChild("Range")
	if range then
		range.Value = 0
	end

	local health = config:FindFirstChild("Health")
	if health and health:FindFirstChild("HealthValue") then
		health.HealthValue.Value = 0
	end
end

--------------------------------------------------------
-- KILL SINGLE TOWER
--------------------------------------------------------
function Tower.KillTower(newTower, ownerPlayer, canContinue)
	if canContinue and not canContinue() then return end
	if not newTower or not newTower:FindFirstChild("Config") then return end

	disableTower(newTower)
	applyDeathVisuals(newTower)

	-- resolve owner if not passed in
	local resolvedPlayer = ownerPlayer or getOwnerPlayer(newTower)

	if resolvedPlayer then
		Events.OwnerRingAlter:FireClient(resolvedPlayer, newTower)
	end

	if canContinue then
		local Match = require(game.ServerScriptService.Simulation.MatchService)
		if not Match.Wait(Match.Capture(), 2, canContinue) then return end
	else
		task.wait(2 / GameSpeedValue.Value)
	end

	if not newTower or not newTower.Parent then return end

	-- if player left, make it nil so Sell still works safely
	if resolvedPlayer and not resolvedPlayer.Parent then
		resolvedPlayer = nil
	end

	TOWER_MODULE.Sell(resolvedPlayer, newTower)
end

--------------------------------------------------------
-- KILL ALL TOWERS
--------------------------------------------------------
function Tower.KillAllTowers()
	local towerFolder = workspace:FindFirstChild("Towers")
	if not towerFolder then return end

	local toProcess = {}

	for _, newTower in ipairs(towerFolder:GetChildren()) do
		if newTower:FindFirstChild("Config") then
			disableTower(newTower)
			applyDeathVisuals(newTower)

			local ownerPlayer = getOwnerPlayer(newTower)

			if ownerPlayer then
				Events.OwnerRingAlter:FireClient(ownerPlayer, newTower)
			end

			table.insert(toProcess, {
				tower = newTower,
				owner = ownerPlayer
			})
		end
	end

	task.wait(2 / GameSpeedValue.Value)

	for _, data in ipairs(toProcess) do
		local towerModel = data.tower
		local ownerPlayer = data.owner

		if towerModel and towerModel.Parent then
			-- if player left during delay, convert to nil
			if ownerPlayer and not ownerPlayer.Parent then
				ownerPlayer = nil
			end

			TOWER_MODULE.Sell(ownerPlayer, towerModel)
		end
	end
end

return Tower
