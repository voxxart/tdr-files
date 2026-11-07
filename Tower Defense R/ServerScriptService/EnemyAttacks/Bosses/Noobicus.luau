-- Boss ability logic is isolated per entity; BossScope owns all delayed work.
local Scope = require(script.Parent.Parent.BossScope)
local Match = require(game.ServerScriptService.Simulation.MatchService)
return function(enemy)
local scope = Scope.new(enemy)
local task = scope.Task
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

	return died
end

-- Kills a single tower safely
local function killTower(tower)
	if killingInProgress[tower] then return end
	if not tower or not tower.Parent then return end

	killingInProgress[tower] = true

	ReplicatedStorage.Events.AnimateTowerDeath:FireAllClients(tower, "TowerDeath")

	local owner = resolveOwner(tower)
	scope:KillTower(tower, owner)

	-- KillTower does task.wait internally before calling Sell.
	-- If Sell fails (no owner, player left, etc.) the tower stays in workspace.
	-- Wait slightly longer than KillTower's internal delay, then force-destroy.
	local GameSpeedValue = workspace.Info:FindFirstChild("GameSpeed")
	local gs = GameSpeedValue and GameSpeedValue.Value or 1
	if gs <= 0 then gs = 1 end

	task.delay(3, function()
		if tower and tower.Parent then
			warn("[AirStrike] Tower not removed by Sell — force destroying:", tower.Name)
			scope:Destroy(tower)
		end
		killingInProgress[tower] = nil
	end)
end

-- Ability System
local function beginAbility(state, name, duration)
	if state.currentAbility then return false end
	state.currentAbility = name
	state.busyUntil = Match.Now() + duration
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
		if not ok and scope:Active() then
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
	state.nextAirStrike = Match.Now() + (COOLDOWNS.AirStrike)

	runAbility(enemy, state, "AirStrike", 5, false, function()
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
			sellLock = scope:Own(Instance.new("BoolValue"))
			sellLock.Name = "SellLock"
			sellLock.Parent = config
		end

		-- Play animation and notify clients for visuals only
		local anim = enemy.scope:Own(AnimationController:LoadAnimation(enemy.Animations.Summon))
		scope:Play(anim)

		local talk = enemy:FindFirstChild("HumanoidRootPart") and enemy.HumanoidRootPart:FindFirstChild("Talking")
		if talk then scope:Play(talk) end

		AirStrikeEvent:FireAllClients(enemy, target)

		-- Wait for the animation/visual delay before applying damage
		task.wait(3)

		-- ⚠️ Remove SellLock BEFORE damage so Sell() won't be blocked
		if sellLock and sellLock.Parent then
			scope:Destroy(sellLock)
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
	state.nextShield = Match.Now() + (COOLDOWNS.Shield)

	runAbility(enemy, state, "Shield", 6, false, function()
		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:FindFirstChild("ShieldOn") then
			scope:Play(hrp.ShieldOn)
		end

		ShieldEvent:FireAllClients(enemy)

		local stats = enemy:FindFirstChild("EnemyStats")
		if not stats then return end

		local inv = scope:Own(Instance.new("BoolValue"))
		inv.Name = "Invincible"
		inv.Parent = stats

		task.wait(6)

		if inv and inv.Parent then scope:Destroy(inv) end
	end)
end

-- 💥 Stomp
local function doStomp(enemy, state)
	state.nextStomp = Match.Now() + (COOLDOWNS.Stomp)

	runAbility(enemy, state, "Stomp", STOMP_DURATION, true, function()
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

		task.wait(STOMP_DURATION)
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
	state.nextSummon = Match.Now() + (COOLDOWNS.Summon)

	runAbility(enemy, state, "Summon", 1.5, false, function()
		local anim = enemy.scope:Own(AnimationController:LoadAnimation(enemy.Animations.Summon))
		scope:Play(anim)

		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:FindFirstChild("Death") then
			scope:Play(hrp.Death)
		end

		SummonEnemyEvent:Fire(enemy, function() return scope:Active() end)
	end)
end

-- INIT
local function initEnemy(enemy)
	if State[enemy] then return end

	local now = Match.Now()
	local gs = getGameSpeed()

	State[enemy] = {
		enemy = enemy,
		currentAbility = nil,
		busyUntil = 0,

		rewarded = false,

		nextAirStrike = now + (COOLDOWNS.AirStrike),
		nextShield    = now + (COOLDOWNS.Shield),
		nextStomp     = now + (COOLDOWNS.Stomp),
		nextSummon    = now + (COOLDOWNS.Summon),
	}
end

initEnemy(enemy)
return {
	Cooldown = function() return 0.1 end,
	InitialCooldown = function() return 0 end,
	Run = function(active)
		if not active() or not scope:Active() then return end
		scope:Sweep()
		local state = State[enemy]
		if not state then return end
		local now = Match.Now()
		tryReward(enemy, state)
		if state.currentAbility then return end
		if now >= state.nextShield then doShield(enemy, state)
		elseif now >= state.nextStomp then doStomp(enemy, state)
		elseif now >= state.nextAirStrike then doAirStrike(enemy, state)
		elseif now >= state.nextSummon then doSummon(enemy, state) end
	end,
	Cancel = function()
		scope:Cancel()
		local state = State[enemy]
		if state then
			if state.activePopTween then state.activePopTween:Cancel() end
			if state.activeFloatTween then state.activeFloatTween:Cancel() end
		end
		State[enemy] = nil
	end,
}
end
