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
local VisualFolder = workspace:WaitForChild("Visual")
local MobsFolder = workspace:WaitForChild("Mobs")

local TAG = "Merchant"
local State = setmetatable({}, {__mode="k"}) -- [enemy] = {rng, nextT}

local ECO_DEBUFF_RADIUS = 5 -- studs
local ECO_DEBUFF_WAVES = 2 -- how many waves the orb persists for

local CASH_DEBUFF_INTERVAL = 15 -- seconds between global cash-debuff ticks
local CASH_DEBUFF_LOSS = 1000

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

local function isEligibleForDebuff(tower)
	return isValidTower(tower)
		and not tower.Config:FindFirstChild("Flying")
		and tower.Config:FindFirstChild("Farm")
		and not tower.Config:FindFirstChild("EcoDebuff")
end

local function findNearestTower(enemy, range)
	range = range or 100
	local epos = enemy.Hitbox.Position
	local best, bestDist = nil, range * range

	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isEligibleForDebuff(tower) then
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

---------------------------------------------------------
-- ECO DEBUFF APPLY / REMOVE
---------------------------------------------------------
local function applyEcoDebuff(tower)
	if tower.Config:FindFirstChild("EcoDebuff") then return end

	local config = tower:FindFirstChild("Config")
	local Cash = config and config:FindFirstChild("Cash")

	if not Cash then
		warn("[EcoDebuff] No Drops.CashPerEco found on tower:", tower:GetFullName())
		return
	end

	local EcoDebuff = Instance.new("BoolValue")
	EcoDebuff.Name = "EcoDebuff"
	EcoDebuff.Parent = tower.Config
	EcoDebuff.Value = true

	local OriginalCash = config:FindFirstChild("OriginalCash")
	if not OriginalCash then
		OriginalCash = Cash:Clone()
		OriginalCash.Name = "OriginalCash"
		OriginalCash.Parent = config
	end

	local newValue = math.round(OriginalCash.Value * 0.5)
	Cash.Value = newValue
end

local function removeEcoDebuff(tower)
	if not isValidTower(tower) then return end

	local EcoDebuff = tower.Config:FindFirstChild("EcoDebuff")
	if EcoDebuff then EcoDebuff:Destroy() end

	local OriginalCash = tower.Config:FindFirstChild("OriginalCash")
	local Cash = tower.Config:FindFirstChild("Cash")
	if OriginalCash and Cash then
		Cash.Value = OriginalCash.Value
		OriginalCash:Destroy()
	end
end

---------------------------------------------------------
-- ECO DEBUFF ORB (area effect)
---------------------------------------------------------
local function spawnEcoDebuffOrb(position)
	local DebuffRadius = ReplicatedStorage.Particle.EcoDebuff:Clone()
	DebuffRadius.Parent = VisualFolder
	DebuffRadius.Position = position - Vector3.new(0, 1.18, 0)
	DebuffRadius.Anchored = true

	local endWave = workspace.Info.Wave.Value + ECO_DEBUFF_WAVES
	DebuffRadius.DebuffWave.Value = endWave
	DebuffRadius.Immune.Disappears.Text = "Despawns: Wave " .. endWave

	local affectedTowers = {}

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not DebuffRadius.Parent then
			conn:Disconnect()
			return
		end

		-- expire the orb once the target wave is reached
		if workspace.Info.Wave.Value >= endWave then
			conn:Disconnect()

			-- linger debuff on affected towers a bit longer, then remove
			task.spawn(function()
				task.wait(3 / gs())
				for tower in pairs(affectedTowers) do
					removeEcoDebuff(tower)
				end
			end)

			DebuffRadius:Destroy()
			return
		end

		-- continuously scan and debuff any valid tower within range
		local origin = DebuffRadius.Position
		for _, tower in ipairs(TowersFolder:GetChildren()) do
			if isEligibleForDebuff(tower) then
				local tpos = tower.PrimaryPart.Position
				local dx, dz = tpos.X - origin.X, tpos.Z - origin.Z
				if (dx*dx + dz*dz) <= (ECO_DEBUFF_RADIUS * ECO_DEBUFF_RADIUS) then
					applyEcoDebuff(tower)
					affectedTowers[tower] = true
				end
			end
		end
	end)
end

---------------------------------------------------------
-- TOWER DAMAGE / ATTACK
---------------------------------------------------------
local function damageTower(enemy, tower)
	if not isValidTower(tower) then return end

	if enemy:GetAttribute("UsedAbility") then return end
	if enemy:GetAttribute("OrbUsed") then return end
	enemy:SetAttribute("UsedAbility", true)
	enemy:SetAttribute("OrbUsed", true)

	local healthFolder = tower.Config.Health
	local healthValue = healthFolder.HealthValue
	local maxHealth = healthFolder.MaxHealth

	-- stop and rotate enemy visually
	local stats = enemy:FindFirstChild("EnemyStats")
	if stats and stats:FindFirstChild("Speed") then stats.Speed.Value = 0 end
	if tower.PrimaryPart then MOB_MOD.FacePart(enemy, tower.PrimaryPart, 3.5/gs()) end

	AnimateEnemy:FireAllClients(enemy, "Throw", tower)
	local hrp = enemy:FindFirstChild("HumanoidRootPart")


	task.delay(1 / gs(), function()
		local atkSound = hrp and hrp:FindFirstChild("Attack")
		if atkSound and atkSound:IsA("Sound") then atkSound:Play() end
		ReplicatedStorage.Events.HardmodeEvents.Merchant.Orb:FireAllClients(enemy, tower)
	end)

	task.delay(3 / gs(), function()
		if not (tower and tower.Parent and tower.PrimaryPart) then return end

		spawnEcoDebuffOrb(tower.PrimaryPart.Position)

		if enemy:FindFirstChild("EcogodCube") then
			enemy.EcogodCube.Main.Transparency = 1
			enemy.EcogodCube.MeshPart.Transparency = 1
		end
	end)

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
	-- attack cooldown
	task.wait(3.5/gs())
	-- restore speed
	if stats and stats:FindFirstChild("Speed") and stats:FindFirstChild("OrigSpeed") then
		stats.Speed.Value = stats.OrigSpeed.Value
	end

	-- release ability lock
	enemy:SetAttribute("UsedAbility", false)
end

---------------------------------------------------------
-- BEHAVIOR
---------------------------------------------------------
local Behaviors = {}
Behaviors.Merchant = function(enemy, s)
	if enemy:GetAttribute("UsedAbility") then return end
	if enemy:GetAttribute("OrbUsed") then return end
	if os.clock() < s.nextT then return end
	schedule(enemy, s, 8, 9)

	local target = findNearestTower(enemy)
	if target then
		damageTower(enemy, target)
	end
end

---------------------------------------------------------
-- START / TRACKING
---------------------------------------------------------
local function start(enemy)
	if State[enemy] then return end
	State[enemy] = {rng = Random.new(), nextT = 0}
	schedule(enemy, State[enemy], 10, 14)

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
			Behaviors.Merchant(enemy, s)
		end
	end
end)

---------------------------------------------------------
-- GLOBAL CASH DEBUFF (merged from second script)
---------------------------------------------------------
local function GetDebuffData()
	local total = 0
	local validEnemies = {}
	for _, mob in ipairs(MobsFolder:GetChildren()) do
		if not mob:GetAttribute("UsedAbility") then
			local enemyStats = mob:FindFirstChild("EnemyStats")
			local debuff = enemyStats and enemyStats:FindFirstChild("DebuffPercent")
			if debuff and debuff.Value > 0 then
				total += debuff.Value
				table.insert(validEnemies, mob)
			end
		end
	end
	return total, validEnemies
end

local function DeductMoney()
	local totalDebuff, enemies = GetDebuffData()
	if totalDebuff <= 0 then return end

	-- pick enemy safely
	local enemyToAnimate = enemies[1]
	if enemyToAnimate then
		-- claim ability lock so the Merchant AI won't fire on this enemy mid-CoinFlip
		enemyToAnimate:SetAttribute("UsedAbility", true)

		local stats = enemyToAnimate:FindFirstChild("EnemyStats")
		local speed = stats and stats:FindFirstChild("Speed")
		local orig = stats and stats:FindFirstChild("OrigSpeed")
		if speed then speed.Value = 0 end

		task.delay(4 / gs(), function()
			if speed and orig then
				speed.Value = orig.Value
			end
			if enemyToAnimate and enemyToAnimate.Parent then
				enemyToAnimate:SetAttribute("UsedAbility", false)
			end
		end)

		-- FIRE ANIMATION ONCE (IMPORTANT FIX)
		AnimateEnemy:FireAllClients(enemyToAnimate, "CoinFlip", nil)
	end

	-- apply money loss
	for _, player in ipairs(Players:GetPlayers()) do
		local cash = player:FindFirstChild("Cash")
		if cash then
			events.MoneyDebuff:FireClient(player)
			cash.Value -= CASH_DEBUFF_LOSS
		end
	end
end

task.spawn(function()
	local nextTick = os.clock() + CASH_DEBUFF_INTERVAL
	while true do
		local now = os.clock()
		if now >= nextTick then
			nextTick += CASH_DEBUFF_INTERVAL
			DeductMoney()
		end
		task.wait(0.1)
	end
end)
