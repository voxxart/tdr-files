--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

--// Modules
local TOWERDEATH_MOD = require(game.ServerScriptService.Main.TowerDeath)
local MOB_MOD = require(game.ServerScriptService.Main.Mob)

--// Tag
local TAG = "Honorary"

--// Workspace refs
local TowersFolder = workspace:WaitForChild("Towers")
local Info = workspace:WaitForChild("Info")
local GameSpeedValue = Info:WaitForChild("GameSpeed")
local PlayerCountValue = Info:WaitForChild("PlrValue")
local VisualFolder = workspace:WaitForChild("Visual")
local DeathWishInfo = Info.Modifiers:FindFirstChild("DeathWishInfo")
local EcoDebuff = DeathWishInfo:FindFirstChild("EcoDebuff").Value

--// Events
local Events = ReplicatedStorage:WaitForChild("Events")
local AnimateEnemyEvent = Events:WaitForChild("AnimateEnemy")
local AnimateBossEvent = Events:WaitForChild("AnimateBoss")
local AnimateTowerDeathEvent = Events:WaitForChild("AnimateTowerDeath")
local ShockWaveEvent = Events:WaitForChild("Stomp")
local SummonEnemyEvent = Events:WaitForChild("SummonEnemy")

--// Particles
local Particles = ReplicatedStorage:WaitForChild("Particle")
local SlamParticleTemplate = Particles:WaitForChild("Slam")

--// State
local State = setmetatable({}, { __mode = "k" })

--// Constants
local REWARD_THRESHOLDS = {38500, 27500, 18000, 10000, 1000}

local COOLDOWNS = {
	Slam = 20,
	Stomp = 32,
	Summon = 50,
}

local STOMP_RADIUS = 250
local STOMP_RADIUS_SQ = STOMP_RADIUS * STOMP_RADIUS
local STOMP_DURATION = 1.3

local SLAM_AOE_RADIUS = 5
local SLAM_MAX_TOWERS
if workspace.Info.Modifiers["Death Wish"].Value == true then 
	SLAM_MAX_TOWERS = 5
else
	SLAM_MAX_TOWERS = 3
end

local MANAGER_TICK = 1

------------------------------------------------------------
-- Tower cache system (optimized)
------------------------------------------------------------

local TowerSet = {}
local TowerList = {}
local TowerCache = setmetatable({}, { __mode = "k" })

local function buildTowerCache(tower)
	local config = tower:FindFirstChild("Config")
	if not config then return nil end

	local health = config:FindFirstChild("Health")
	local healthValue = health and health:FindFirstChild("HealthValue")
	local maxHealth = health and health:FindFirstChild("MaxHealth")
	if not healthValue or not maxHealth then return nil end

	local cache = {
		config = config,
		healthValue = healthValue,
		maxHealth = maxHealth,
		flyingValue = config:FindFirstChild("Flying"),
		ownerValue = config:FindFirstChild("Owner"),
		hrp = tower:FindFirstChild("HumanoidRootPart") or tower.PrimaryPart,
		stunnedValue = config:FindFirstChild("Stunned"),
		hasCliffTower = config:FindFirstChild("CliffTower") ~= nil,
	}

	TowerCache[tower] = cache
	return cache
end

local function getTowerCache(tower)
	return TowerCache[tower] or buildTowerCache(tower)
end

local function addTowerToCache(tower)
	if not tower or not tower:IsA("Model") then return end
	if TowerSet[tower] then return end

	TowerList[#TowerList + 1] = tower
	TowerSet[tower] = #TowerList
	buildTowerCache(tower)
end

local function removeTowerFromCache(tower)
	local idx = TowerSet[tower]
	if not idx then return end

	local last = TowerList[#TowerList]
	TowerList[idx] = last
	TowerSet[last] = idx

	TowerList[#TowerList] = nil
	TowerSet[tower] = nil
	TowerCache[tower] = nil
end

for _, t in ipairs(TowersFolder:GetChildren()) do
	addTowerToCache(t)
end

TowersFolder.ChildAdded:Connect(function(t)
	task.wait(0.2)
	addTowerToCache(t)
end)

TowersFolder.ChildRemoved:Connect(function(t)
	task.wait(0.2)
	removeTowerFromCache(t)
end)

------------------------------------------------------------
-- Utilities
------------------------------------------------------------

local function alive(m)
	return m and m.Parent and m:IsDescendantOf(workspace)
end

local function getGameSpeed()
	local v = GameSpeedValue.Value
	return (v > 0 and v) or 1
end

local function distSq(a, b)
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return dx*dx + dy*dy + dz*dz
end

local function isValidTower(tower, state)
	if not tower or tower.Parent ~= TowersFolder or not tower.PrimaryPart then
		return false
	end
	if state and state.killedTowers[tower] then
		return false
	end
	return getTowerCache(tower) ~= nil
end

local function isFlyingTower(tower)
	local cache = getTowerCache(tower)
	local f = cache and cache.flyingValue
	return f and f.Value == true
end

------------------------------------------------------------
-- Tower queries
------------------------------------------------------------

local function findNearestTower(boss, maxDist)
	local hitbox = boss:FindFirstChild("Hitbox")
	if not hitbox then return nil end

	local best, bestD = nil, (maxDist and maxDist*maxDist) or math.huge
	local pos = hitbox.Position

	for _, t in ipairs(TowerList) do
		if isValidTower(t) and not isFlyingTower(t) then
			local d = distSq(t.PrimaryPart.Position, pos)
			if d < bestD then
				bestD = d
				best = t
			end
		end
	end

	return best
end

local function findTowersNear(pos, radius, maxCount, state)
	local res = {}
	local r2 = radius*radius

	for _, t in ipairs(TowerList) do
		if isValidTower(t, state) then
			if distSq(t.PrimaryPart.Position, pos) <= r2 then
				res[#res+1] = t
				if #res >= maxCount then break end
			end
		end
	end

	return res
end

------------------------------------------------------------
-- Damage / kill
------------------------------------------------------------

local function killTower(tower, state)
	if not isValidTower(tower, state) then return end
	state.killedTowers[tower] = true

	local cache = TowerCache[tower]
	local owner = cache and cache.ownerValue and cache.ownerValue.Value
	local plr = owner and Players:FindFirstChild(owner)

	AnimateTowerDeathEvent:FireAllClients(tower, "TowerDeath", tower)
	task.defer(TOWERDEATH_MOD.KillTower, tower, plr or owner)
end

local function damageTowerPercent(tower, pct, state)
	if not isValidTower(tower, state) then return end

	local c = TowerCache[tower]
	local hp = c.healthValue
	local max = c.maxHealth

	hp.Value = math.max(0, hp.Value - (max.Value * pct))

	if hp.Value <= 0 then
		killTower(tower, state)
	end
end

local function getBossStats(boss)
	return boss:FindFirstChild("EnemyStats")
end

local function getBossHealth(boss)
	local stats = getBossStats(boss)
	local hp = stats and stats:FindFirstChild("Health")
	return hp and hp.Value
end

local function getRewardAmount()
	local count = math.max(1, PlayerCountValue.Value)
	local Amount
	if workspace.Info.Modifiers["Death Wish"].Value == true then 
		Amount = math.round(30000 * EcoDebuff - ((Info.PlrValue.Value - 1) * 0.05))
	else
		Amount = 30000
	end
	return math.round(Amount / count)
end

local function awardMoneyToPlayer(player, amount)
	local cash = player:FindFirstChild("Cash")
	if cash then
		cash.Value += amount
	end
end

local function awardAll(amount)
	for _, plr in ipairs(Players:GetPlayers()) do
		awardMoneyToPlayer(plr, amount)
	end
end

local function playCashTween(boss, amount)
	local head = boss:FindFirstChild("Head")
	local awardAtt = head and head:FindFirstChild("AwardMoneyAttachment")
	local cashCounterUI = awardAtt and awardAtt:FindFirstChild("CashCounter")
	local label = cashCounterUI and cashCounterUI:FindFirstChild("Cash")
	if not label or not cashCounterUI then return end

	local state = State[boss]
	if not state then return end

	state.cashTweenToken += 1
	local myToken = state.cashTweenToken

	if state.activePopTween then state.activePopTween:Cancel() end
	if state.activeFloatTween then state.activeFloatTween:Cancel() end
	state.activePopTween = nil
	state.activeFloatTween = nil

	cashCounterUI.Enabled = true
	label.Text = "+$" .. amount

	local originalPos = label.Position
	local originalSize = label.Size
	local originalAnchor = label.AnchorPoint

	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = originalPos
	label.Size = UDim2.new(
		originalSize.X.Scale * 0.8, originalSize.X.Offset * 0.8,
		originalSize.Y.Scale * 0.8, originalSize.Y.Offset * 0.8
	)

	state.activePopTween = TweenService:Create(label, TweenInfo.new(
		0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out
		), {
			Size = originalSize
		})

	state.activeFloatTween = TweenService:Create(label, TweenInfo.new(
		0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
		), {
			Position = UDim2.new(
				originalPos.X.Scale, originalPos.X.Offset,
				originalPos.Y.Scale, originalPos.Y.Offset - 18
			)
		})

	state.activePopTween:Play()

	state.activePopTween.Completed:Once(function(playbackState)
		if not alive(boss) then return end
		if myToken ~= state.cashTweenToken then return end
		if playbackState == Enum.PlaybackState.Cancelled then return end
		state.activeFloatTween:Play()
	end)

	state.activeFloatTween.Completed:Once(function(playbackState)
		task.wait(1.2)
		if not alive(boss) then return end
		if myToken ~= state.cashTweenToken then return end
		if playbackState == Enum.PlaybackState.Cancelled then return end

		label.Position = originalPos
		label.Size = originalSize
		label.AnchorPoint = originalAnchor
		cashCounterUI.Enabled = false
	end)
end

local function checkRewardThresholds(boss, state)
	local hp = getBossHealth(boss)
	if not hp then return end

	local amount = getRewardAmount()
	for i, threshold in ipairs(REWARD_THRESHOLDS) do
		if not state.awarded[i] and hp <= threshold then
			state.awarded[i] = true
			awardAll(amount)
			playCashTween(boss, amount)
		end
	end
end
------------------------------------------------------------
-- Boss state
------------------------------------------------------------

local function initBoss(boss)
	if State[boss] then return end

	local now = os.clock()
	local gs = getGameSpeed()

	local stats = boss:WaitForChild("EnemyStats")

	local state = {
		boss = boss,
		stats = stats,
		hitbox = boss:WaitForChild("Hitbox"),
		hrp = boss:WaitForChild("HumanoidRootPart"),

		speed = stats.Speed,
		origSpeed = stats.OrigSpeed,

		currentAbility = nil,
		killedTowers = {},
		awarded = {false, false, false, false, false},
		cashTweenToken = 0,
		activePopTween = nil,
		activeFloatTween = nil,

		nextSlam = now + COOLDOWNS.Slam/gs,
		nextStomp = now + COOLDOWNS.Stomp/gs,
		nextSummon = now + COOLDOWNS.Summon/gs,
	}

	State[boss] = state

	task.spawn(function()
		bossLoop(boss, state)
	end)
end

------------------------------------------------------------
-- Boss loop (DEFINED BEFORE USE — FIXED)
------------------------------------------------------------

function bossLoop(boss, state)
	while alive(boss) do
		local now = os.clock()
		
		checkRewardThresholds(boss, state)

		if not state.currentAbility then
			if now >= state.nextSlam and findNearestTower(boss, 15) then
				doSlam(boss, state)
			elseif now >= state.nextStomp then
				doStomp(boss, state)
			elseif now >= state.nextSummon then
				doSummon(boss, state)
			end
		end

		task.wait(MANAGER_TICK)
	end

	State[boss] = nil
end

------------------------------------------------------------
-- Abilities (simplified but safe structure)
------------------------------------------------------------

function doSlam(boss, state)
	local gs = getGameSpeed()
	state.nextSlam = os.clock() + (COOLDOWNS.Slam / gs)

	state.currentAbility = "Slam"

	-- freeze only during windup
	state.speed.Value = 0

	local target = findNearestTower(boss, 15)
	if not target or not target.PrimaryPart then
		state.speed.Value = state.origSpeed.Value
		state.currentAbility = nil
		return
	end

	MOB_MOD.FacePart(boss, target.PrimaryPart, 2 / gs)

	AnimateEnemyEvent:FireAllClients(boss, "Slash", target)

	-- windup
	task.wait(0.9 / gs)

	-- impact happens HERE
	if isValidTower(target, state) then
		local victims = findTowersNear(
			target.PrimaryPart.Position,
			SLAM_AOE_RADIUS,
			SLAM_MAX_TOWERS,
			state
		)

		local hrp = boss:FindFirstChild("HumanoidRootPart")
		local atkSound = hrp and hrp:FindFirstChild("Slash")
		if atkSound and atkSound:IsA("Sound") then
			atkSound:Play()
		end

		for _, t in ipairs(victims) do
			damageTowerPercent(t, 1, state)
		end
	end

	-- 🔥 CRITICAL CHANGE:
	-- unlock movement immediately after impact (NOT after waits or visuals)
	state.speed.Value = state.origSpeed.Value
	state.currentAbility = nil

	-- optional: visual linger ONLY
	task.delay(0.6 / gs, function()
		-- purely cosmetic delay, no gameplay lock
	end)
end

function doStomp(boss, state)
	local gs = getGameSpeed()
	state.nextStomp = os.clock() + COOLDOWNS.Stomp/gs

	state.currentAbility = "Stomp"

	local hitbox = boss:FindFirstChild("Hitbox")
	if not hitbox then return end
	AnimateBossEvent:FireAllClients(boss, "Stomp", "Stomp")
	
	ShockWaveEvent:FireAllClients(hitbox.Position, STOMP_RADIUS)

	for _, t in ipairs(TowerList) do
		if isValidTower(t, state) and not isFlyingTower(t) then
			local c = getTowerCache(t)
			local hrp = c.hrp
			if hrp and distSq(hrp.Position, hitbox.Position) <= STOMP_RADIUS_SQ then
				damageTowerPercent(t, 0.1, state)
				local config = t.Config
				local stunned = config:FindFirstChild("Stunned")
				if stunned then
					stunned.Value = 4
				elseif not config:FindFirstChild("CliffTower") then
					local newStun = Instance.new("NumberValue")
					newStun.Name = "Stunned"
					newStun.Value = 4
					newStun.Parent = config
				end
			end
		end
	end

	state.currentAbility = nil
end

function doSummon(boss, state)
	local gs = getGameSpeed()
	state.nextSummon = os.clock() + COOLDOWNS.Summon/gs

	state.currentAbility = "Summon"
	AnimateEnemyEvent:FireAllClients(boss, "Summon", nil)
	SummonEnemyEvent:Fire(boss)
	local hrp = boss:FindFirstChild("HumanoidRootPart")
	local atkSound = hrp and hrp:FindFirstChild("Summon")
	if atkSound and atkSound:IsA("Sound") then atkSound:Play() end

	task.wait(1.5/gs)

	state.currentAbility = nil
end

------------------------------------------------------------
-- Setup
------------------------------------------------------------

for _, b in ipairs(CollectionService:GetTagged(TAG)) do
	initBoss(b)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(initBoss)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(b)
	State[b] = nil
end)