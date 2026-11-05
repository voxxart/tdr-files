local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AirStrikeServer = ReplicatedStorage.Events.NoobicusEvents.AirStrike.AirStrikeServer
local TOWERDEATH_MOD = require(game.ServerScriptService.Main.TowerDeath)
local Players = game:GetService("Players")
local GameSpeedValue = workspace:WaitForChild("Info"):WaitForChild("GameSpeed")

local killingInProgress = {}

local function getGameSpeed()
	local v = GameSpeedValue.Value
	return v > 0 and v or 1
end

local function safeDamageTower(tower, damagePercent)
	local config = tower:FindFirstChild("Config")
	if not config then return false end
	local health = config:FindFirstChild("Health")
	if not health then return false end
	local healthValue = health:FindFirstChild("HealthValue")
	local maxHealth = health:FindFirstChild("MaxHealth")
	if not healthValue or not maxHealth then return false end

	local damage = maxHealth.Value * damagePercent
	healthValue.Value = math.max(0, healthValue.Value - damage)
	return healthValue.Value <= 0
end

local function resolveOwner(tower)
	local config = tower:FindFirstChild("Config")
	if not config then return nil end
	local ownerValue = config:FindFirstChild("Owner")
	if not ownerValue then return nil end
	return Players:FindFirstChild(ownerValue.Value)
end

-- Kills tower and guarantees removal even if Sell fails
local function killTower(tower)
	if killingInProgress[tower] then return end
	if not tower or not tower.Parent then return end

	killingInProgress[tower] = true

	ReplicatedStorage.Events.AnimateTowerDeath:FireAllClients(tower, "TowerDeath")

	local owner = resolveOwner(tower)

	-- KillTower yields internally (task.wait before Sell), so run it in its own thread
	task.spawn(function()
		TOWERDEATH_MOD.KillTower(tower, owner)

		-- After KillTower finishes (including its internal wait + Sell),
		-- if the tower is STILL in workspace then Sell failed silently — force remove it
		task.delay(3 / getGameSpeed(), function()
			if tower and tower.Parent then
				warn("[AirStrike] Sell failed to remove tower, force destroying:", tower.Name)
				tower:Destroy()
			end
			killingInProgress[tower] = nil
		end)
	end)
end

AirStrikeServer.OnServerEvent:Connect(function(player, enemy, target)
	-- Validate
	if not target or not target.Parent then
		warn("[AirStrike] Target nil or destroyed")
		return
	end
	if not target:FindFirstChild("Config") then
		warn("[AirStrike] Target missing Config")
		return
	end
	if not target.Config:FindFirstChild("Health") then
		warn("[AirStrike] Target missing Health")
		return
	end
	if not target.Config.Health:FindFirstChild("HealthValue") then
		warn("[AirStrike] Target missing HealthValue")
		return
	end
	if not target.PrimaryPart then
		warn("[AirStrike] Target missing PrimaryPart")
		return
	end
	if killingInProgress[target] then
		warn("[AirStrike] Target already dying")
		return
	end

	local primaryPos = target.PrimaryPart.Position
	local isFlying = target.Config:FindFirstChild("Flying") ~= nil
	local primaryPct = isFlying and 0.77 or 0.90
	local splashPct = 0.30
	local splashFlyingPct = 0.08
	local splashRadius = 5

	local towersToKill = {}

	-- Damage primary
	if safeDamageTower(target, primaryPct) then
		table.insert(towersToKill, target)
	end

	-- Splash damage
	local towerFolder = workspace:FindFirstChild("Towers")
	if towerFolder then
		for _, other in ipairs(towerFolder:GetChildren()) do
			if  other ~= target
				and other.Parent
				and not killingInProgress[other]
				and other:FindFirstChild("Config")
				and other.Config:FindFirstChild("Health")
				and other.Config.Health:FindFirstChild("HealthValue")
				and other.PrimaryPart
			then
				local dist = (other.PrimaryPart.Position - primaryPos).Magnitude
				if dist <= splashRadius then
					local pct = other.Config:FindFirstChild("Flying") and splashFlyingPct or splashPct
					if safeDamageTower(other, pct) then
						table.insert(towersToKill, other)
					end
				end
			end
		end
	end

	-- Kill all dead towers
	for _, tower in ipairs(towersToKill) do
		killTower(tower)
	end
end)
