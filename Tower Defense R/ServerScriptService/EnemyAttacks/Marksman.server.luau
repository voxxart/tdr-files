local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local events = ReplicatedStorage:WaitForChild("Events")
local AnimateEnemy = events:WaitForChild("AnimateEnemy")
local AnimateTowerDeath = events:WaitForChild("AnimateTowerDeath")

local TOWERDEATH_MOD = require(game.ServerScriptService.Main.TowerDeath)
local MOB_MOD = require(game.ServerScriptService.Main.Mob)

local TowersFolder = workspace:WaitForChild("Towers")
local GameSpeedValue = workspace.Info:WaitForChild("GameSpeed")

local TAG = "Marksman"
local State = setmetatable({}, {__mode = "k"})

---------------------------------------------------------
-- HELPERS
---------------------------------------------------------
local function gs()
	local v = GameSpeedValue.Value
	return v > 0 and v or 1
end

local function isAliveEnemy(enemy)
	return enemy and enemy.Parent and enemy.PrimaryPart and enemy:FindFirstChild("Hitbox")
end

local function isValidTower(tower)
	if not tower or tower.Parent ~= TowersFolder then return false end
	local cfg = tower:FindFirstChild("Config")
	local health = cfg and cfg:FindFirstChild("Health")
	return tower.PrimaryPart
		and cfg
		and health
		and health:FindFirstChild("HealthValue")
		and health:FindFirstChild("MaxHealth")
end

local function findNearestTower(enemy, range)
	range = range or 25
	local epos = enemy.Hitbox.Position
	local bestDist = range * range
	local best = nil

	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(tower) and not tower.Config:FindFirstChild("Flying") then
			local tpos = tower.PrimaryPart.Position
			local dx = tpos.X - epos.X
			local dz = tpos.Z - epos.Z
			local dist2 = dx * dx + dz * dz
			if dist2 < bestDist then
				bestDist = dist2
				best = tower
			end
		end
	end

	return best
end

local function schedule(s, minCd, maxCd)
	s.nextT = os.clock() + s.rng:NextNumber(minCd / gs(), maxCd / gs())
end

---------------------------------------------------------
-- ATTACK
---------------------------------------------------------
local function tryKillTower(tower)
	if not isValidTower(tower) then return end
	if tower:GetAttribute("Dying") then return end

	local healthValue = tower.Config.Health.HealthValue
	if healthValue.Value > 0 then return end -- only kill if actually at/below 0

	tower:SetAttribute("Dying", true)

	task.spawn(function()
		if not (tower and tower.Parent) then return end

		AnimateTowerDeath:FireAllClients(tower, "TowerDeath", tower)

		local ownerPlayer
		local ownerNameValue = tower.Config:FindFirstChild("Owner")
		if ownerNameValue and ownerNameValue.Value ~= "" then
			ownerPlayer = Players:FindFirstChild(ownerNameValue.Value)
		end

		task.wait(0.5 / gs())

		if tower and tower.Parent then
			TOWERDEATH_MOD.KillTower(tower, ownerPlayer)
		end
	end)
end

local function damageTower(enemy, tower, s)
	-- Validate both are still alive before committing
	if not isValidTower(tower) then return end
	if not isAliveEnemy(enemy) then return end

	local healthFolder = tower.Config.Health
	local healthValue = healthFolder.HealthValue
	local maxHealth = healthFolder.MaxHealth
	local damage
	if workspace.Info.Modifiers["Death Wish"].Value == true then
		damage  = math.round(maxHealth.Value * 0.5)
	else
		damage = math.round(maxHealth.Value * 0.4)
	end

	local stats = enemy:FindFirstChild("EnemyStats")
	local speedStat = stats and stats:FindFirstChild("Speed")
	local origSpeed = stats and stats:FindFirstChild("OrigSpeed")

	-- Slow enemy to 0 and face target
	if speedStat then speedStat.Value = 0 end
	if tower.PrimaryPart then
		MOB_MOD.FacePart(enemy, tower.PrimaryPart, 4 / gs())
	end

	AnimateEnemy:FireAllClients(enemy, "Fire", tower)

	local hrp = enemy:FindFirstChild("HumanoidRootPart")

	-- Arrow fires after wind-up delay
	task.delay(2 / gs(), function()
		-- Re-validate after delay; enemy or tower may have died
		if not isAliveEnemy(enemy) then
			if speedStat and origSpeed then speedStat.Value = origSpeed.Value end
			return
		end
		if not isValidTower(tower) then
			if speedStat and origSpeed then speedStat.Value = origSpeed.Value end
			return
		end

		local atkSound = hrp and hrp:FindFirstChild("Attack")
		if atkSound and atkSound:IsA("Sound") then
			atkSound:Play()
		end

		-- Apply damage THEN check for kill
		healthValue.Value = math.max(0, healthValue.Value - damage)
		ReplicatedStorage.Events.HardmodeEvents.Marksman.Arrow:FireAllClients(enemy, tower)

		local arrow = enemy:FindFirstChild("Weapon") and enemy.Weapon:FindFirstChild("Arrow")
		if arrow then arrow.Transparency = 1 end

		-- Check kill after damage is applied
		tryKillTower(tower)

		task.delay(2 / gs(), function()
			if arrow then arrow.Transparency = 0 end
			-- Restore speed after full animation
			if isAliveEnemy(enemy) and speedStat and origSpeed then
				speedStat.Value = origSpeed.Value
			end
			-- Allow next attack now that animation is fully done
			schedule(s, 22, 23)
		end)
	end)
end

---------------------------------------------------------
-- BEHAVIOR
---------------------------------------------------------
local Behaviors = {}

Behaviors.Marksman = function(enemy, s)
	if os.clock() < s.nextT then return end
	if s.attacking then return end -- prevent overlapping attacks

	local target = findNearestTower(enemy)
	if not target then return end

	s.attacking = true
	-- Schedule is now set at the END of damageTower so cooldown begins after animation
	-- Set nextT far ahead to block re-entry during the attack wind-up + animation (~6s)
	s.nextT = math.huge

	damageTower(enemy, target, s)

	-- attacking flag cleared after full animation window
	task.delay((2 + 4) / gs() + 0.1, function()
		s.attacking = false
	end)
end

---------------------------------------------------------
-- START / TRACKING
---------------------------------------------------------
local function start(enemy)
	if State[enemy] then return end
	State[enemy] = {
		rng = Random.new(),
		nextT = 0,
		attacking = false,
	}
	schedule(State[enemy], 5, 8) -- initial delay before first shot

	enemy.AncestryChanged:Connect(function(_, parent)
		if not parent then State[enemy] = nil end
	end)
end

for _, enemy in ipairs(CollectionService:GetTagged(TAG)) do
	start(enemy)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(start)

-- Fixed: was missing :Connect()
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(enemy)
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
			Behaviors.Marksman(enemy, s)
		end
	end
end)