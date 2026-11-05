local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local TOWERDEATH_MOD = require(game.ServerScriptService.Main.TowerDeath)

local TAG = "Noobicus"

local TowersFolder = workspace:WaitForChild("Towers")
local Info = workspace:WaitForChild("Info")
local GameSpeedValue = Info:WaitForChild("GameSpeed")

local Events = ReplicatedStorage:WaitForChild("Events")

-- Noobicus Events
local NoobEvents = Events:WaitForChild("NoobicusEvents")
local AirStrikeEvent = NoobEvents:WaitForChild("AirStrike"):WaitForChild("AirStrikeClient")
local ShieldEvent = NoobEvents:WaitForChild("Shield"):WaitForChild("ShieldClient")

local AnimateBoss = Events:WaitForChild("AnimateBoss")
local ShockWaveEvent = Events:WaitForChild("Stomp")
local SummonEnemyEvent = Events:WaitForChild("SummonEnemy")

local State = setmetatable({}, { __mode = "k" })

-- Tracks towers currently being killed to prevent double-processing
local killingInProgress = {}

-- CONFIG
local COOLDOWNS = {
	AirStrike = 20,
	Shield = 45,
	Stomp = 35,
	Summon = 25,
}

local STOMP_RADIUS = 250
local STOMP_DURATION = 2
local AIRSTRIKE_SPLASH_RADIUS = 5
local MANAGER_TICK = 0.1
local Extra_Threshold = 250

-- Helpers
local function getGameSpeed()
	local v = GameSpeedValue.Value
	return v > 0 and v or 1
end

local function getBossStats(boss)
	return boss:FindFirstChild("EnemyStats")
end

local function getBossHealth(boss)
	local stats = getBossStats(boss)
	local hp = stats and stats:FindFirstChild("Health")
	return hp and hp.Value
end

local function alive(model)
	return model and model.Parent and model:IsDescendantOf(workspace)
end

local function getRandomTower()
	local towers = TowersFolder:GetChildren()
	if #towers == 0 then return nil end
	return towers[math.random(1, #towers)]
end

local function resolveOwner(tower)
	local config = tower:FindFirstChild("Config")
	if not config then return nil end
	local ownerValue = config:FindFirstChild("Owner")
	if not ownerValue then return nil end
	return Players:FindFirstChild(ownerValue.Value)
end

-- Applies damage to a tower, returns true if it died
local function damageTower(tower, percent)
	local config = tower:FindFirstChild("Config")
	if not config then
		warn("[AirStrike] damageTower: no Config on", tower)
		return false
	end
	local health = config:FindFirstChild("Health")
	if not health then
		warn("[AirStrike] damageTower: no Health folder on", tower)
		return false
	end
	local healthValue = health:FindFirstChild("HealthValue")
	if not healthValue then
		warn("[AirStrike] damageTower: no HealthValue on", tower, "| Health children:", health:GetChildren())
		return false
	end
	local maxHealth = health:FindFirstChild("MaxHealth")
	if not maxHealth then
		warn("[AirStrike] damageTower: no MaxHealth on", tower, "| Health children:", health:GetChildren())
		return false
	end

	local damage = maxHealth.Value * percent
	local before = healthValue.Value
	healthValue.Value = math.max(0, healthValue.Value - damage)
	local died = healthValue.Value <= 0
	print(string.format("[AirStrike] Damaged %s | Before: %.0f | Damage: %.0f | After: %.0f | Died: %s",
		tower.Name, before, damage, healthValue.Value, tostring(died)))
	return died
end

-- Kills a single tower safely
local function killTower(tower)
	if killingInProgress[tower] then return end
	if not tower or not tower.Parent then return end

	killingInProgress[tower] = true

	ReplicatedStorage.Events.AnimateTowerDeath:FireAllClients(tower, "TowerDeath")

	local owner = resolveOwner(tower)
	TOWERDEATH_MOD.KillTower(tower, owner)

	-- KillTower does task.wait internally before calling Sell.
	-- If Sell fails (no owner, player left, etc.) the tower stays in workspace.
	-- Wait slightly longer than KillTower's internal delay, then force-destroy.
	local GameSpeedValue = workspace.Info:FindFirstChild("GameSpeed")
	local gs = GameSpeedValue and GameSpeedValue.Value or 1
	if gs <= 0 then gs = 1 end

	task.delay(3 / gs, function()
		if tower and tower.Parent then
			warn("[AirStrike] Tower not removed by Sell — force destroying:", tower.Name)
			tower:Destroy()
		end
		killingInProgress[tower] = nil
	end)
end

-- Ability System
local function beginAbility(state, name, duration)
	if state.currentAbility then return false end
	state.currentAbility = name
	state.busyUntil = os.clock() + duration
	return true
end

local function endAbility(state, name)
	if state.currentAbility == name then
		state.currentAbility = nil
		state.busyUntil = 0
	end
end

local function runAbility(enemy, state, name, duration, freeze, fn)
	if not beginAbility(state, name, duration) then return false end

	task.spawn(function()
		local stats = enemy:FindFirstChild("EnemyStats")

		if freeze and stats and stats:FindFirstChild("Speed") then
			stats.Speed.Value = 0
		end

		local ok, err = xpcall(fn, debug.traceback)
		if not ok then
			warn("[GenNoob " .. name .. " Error]:", err)
		end

		if freeze and stats and stats:FindFirstChild("OrigSpeed") then
			stats.Speed.Value = stats.OrigSpeed.Value
		end

		endAbility(state, name)
	end)

	return true
end

-- ABILITIES

-- ✈️ AirStrike — damage handled SERVER-SIDE, client only does visuals
local function doAirStrike(enemy, state)
	state.nextAirStrike = os.clock() + (COOLDOWNS.AirStrike / getGameSpeed())

	runAbility(enemy, state, "AirStrike", 5 / getGameSpeed(), false, function()
		local target = getRandomTower()
		if not target then warn("[AirStrike] No towers to target") return end
		if not target.PrimaryPart then warn("[AirStrike] Target missing PrimaryPart") return end
		if killingInProgress[target] then warn("[AirStrike] Target already dying") return end

		-- SellLock stops the player manually selling during the animation.
		-- We keep a reference so we can destroy it BEFORE damage is applied,
		-- because Sell() checks for SellLock and silently returns if it exists.
		local config = target:FindFirstChild("Config")
		local sellLock = nil
		if config then
			sellLock = Instance.new("BoolValue")
			sellLock.Name = "SellLock"
			sellLock.Parent = config
		end

		-- Play animation and notify clients for visuals only
		local anim = enemy.AnimationController:LoadAnimation(enemy.Animations.Summon)
		anim:Play()

		local talk = enemy:FindFirstChild("HumanoidRootPart") and enemy.HumanoidRootPart:FindFirstChild("Talking")
		if talk then talk:Play() end

		AirStrikeEvent:FireAllClients(enemy, target)

		-- Wait for the animation/visual delay before applying damage
		task.wait(3 / getGameSpeed())

		-- ⚠️ Remove SellLock BEFORE damage so Sell() won't be blocked
		if sellLock and sellLock.Parent then
			sellLock:Destroy()
			sellLock = nil
		end

		-- Re-validate target still exists after wait
		if not target or not target.Parent then
			warn("[AirStrike] Target gone after wait")
			return
		end

		local primaryPos = target.PrimaryPart and target.PrimaryPart.Position
		if not primaryPos then
			warn("[AirStrike] Target lost PrimaryPart after wait")
			return
		end

		local towersToKill = {}

		-- Damage primary target
		local isFlying = config and config:FindFirstChild("Flying") ~= nil
		local primaryPct = isFlying and 0.77 or 0.90
		if damageTower(target, primaryPct) then
			table.insert(towersToKill, target)
		end

		-- Splash damage to nearby towers
		for _, otherTower in ipairs(TowersFolder:GetChildren()) do
			if  otherTower ~= target
				and otherTower.Parent
				and not killingInProgress[otherTower]
				and otherTower:FindFirstChild("Config")
				and otherTower.Config:FindFirstChild("Health")
				and otherTower.Config.Health:FindFirstChild("HealthValue")
				and otherTower.PrimaryPart
			then
				local dist = (otherTower.PrimaryPart.Position - primaryPos).Magnitude
				if dist <= AIRSTRIKE_SPLASH_RADIUS then
					local otherFlying = otherTower.Config:FindFirstChild("Flying") ~= nil
					local splashPct = otherFlying and 0.08 or 0.30
					if damageTower(otherTower, splashPct) then
						table.insert(towersToKill, otherTower)
					end
				end
			end
		end

		-- Kill all towers that died
		for _, tower in ipairs(towersToKill) do
			killTower(tower)
		end
	end)
end

-- 🛡 Shield
local function doShield(enemy, state)
	state.nextShield = os.clock() + (COOLDOWNS.Shield / getGameSpeed())

	runAbility(enemy, state, "Shield", 6 / getGameSpeed(), false, function()
		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:FindFirstChild("ShieldOn") then
			hrp.ShieldOn:Play()
		end

		ShieldEvent:FireAllClients(enemy)

		local stats = enemy:FindFirstChild("EnemyStats")
		if not stats then return end

		local inv = Instance.new("BoolValue")
		inv.Name = "Invincible"
		inv.Parent = stats

		task.wait(6 / getGameSpeed())

		if inv and inv.Parent then inv:Destroy() end
	end)
end

-- 💥 Stomp
local function doStomp(enemy, state)
	state.nextStomp = os.clock() + (COOLDOWNS.Stomp / getGameSpeed())

	runAbility(enemy, state, "Stomp", STOMP_DURATION / getGameSpeed(), true, function()
		AnimateBoss:FireAllClients(enemy, "Stomp", "Stomp")

		local hitbox = enemy:FindFirstChild("Hitbox")
		if not hitbox then return end

		ShockWaveEvent:FireAllClients(hitbox.Position, STOMP_RADIUS)

		local towersToKill = {}

		for _, tower in ipairs(TowersFolder:GetChildren()) do
			local config = tower:FindFirstChild("Config")
			local hrp = tower:FindFirstChild("HumanoidRootPart") or tower.PrimaryPart

			if config and hrp and not (config:FindFirstChild("Flying") and config.Flying.Value) then
				local dist = (hitbox.Position - hrp.Position).Magnitude
				if dist < STOMP_RADIUS then
					local died = damageTower(tower, 0.10)
					-- Stun regardless of death
					local stun = config:FindFirstChild("Stunned")
					if stun then
						stun.Value = 3
					else
						local new = Instance.new("NumberValue")
						new.Name = "Stunned"
						new.Value = 3
						new.Parent = config
					end
					if died then
						table.insert(towersToKill, tower)
					end
				end
			end
		end

		for _, tower in ipairs(towersToKill) do
			killTower(tower)
		end

		task.wait(STOMP_DURATION / getGameSpeed())
	end)
end

local function tryReward(boss, state)
	if state.rewarded then return end

	local hp = getBossHealth(boss)
	if not hp or hp > Extra_Threshold then return end

	state.rewarded = true

	for _, plr in ipairs(Players:GetPlayers()) do
		ReplicatedStorage.Events.BPCurrency:FireClient(
			plr,
			"ReleaseBPCurrency",
			0.3,
			8,
			boss.Hitbox.Position,
			plr
		)
	end
end

-- 👹 Summon
local function doSummon(enemy, state)
	state.nextSummon = os.clock() + (COOLDOWNS.Summon / getGameSpeed())

	runAbility(enemy, state, "Summon", 1.5 / getGameSpeed(), false, function()
		local anim = enemy.AnimationController:LoadAnimation(enemy.Animations.Summon)
		anim:Play()

		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:FindFirstChild("Death") then
			hrp.Death:Play()
		end

		SummonEnemyEvent:Fire(enemy)
	end)
end

-- INIT
local function initEnemy(enemy)
	if State[enemy] then return end

	local now = os.clock()
	local gs = getGameSpeed()

	State[enemy] = {
		enemy = enemy,
		currentAbility = nil,
		busyUntil = 0,

		rewarded = false,

		nextAirStrike = now + (COOLDOWNS.AirStrike / gs),
		nextShield    = now + (COOLDOWNS.Shield / gs),
		nextStomp     = now + (COOLDOWNS.Stomp / gs),
		nextSummon    = now + (COOLDOWNS.Summon / gs),
	}
end

for _, enemy in ipairs(CollectionService:GetTagged(TAG)) do
	initEnemy(enemy)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(initEnemy)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(enemy)
	State[enemy] = nil
end)

-- MAIN LOOP
task.spawn(function()
	while true do
		local now = os.clock()

		for enemy, state in pairs(State) do
			if not alive(enemy) then
				State[enemy] = nil
			else
				tryReward(enemy, state)

				if state.currentAbility and now < state.busyUntil then
					continue
				end

				if state.currentAbility then
					continue
				end

				if now >= state.nextShield then
					doShield(enemy, state)
				elseif now >= state.nextStomp then
					doStomp(enemy, state)
				elseif now >= state.nextAirStrike then
					doAirStrike(enemy, state)
				elseif now >= state.nextSummon then
					doSummon(enemy, state)
				end
			end
		end

		task.wait(MANAGER_TICK)
	end
end)
