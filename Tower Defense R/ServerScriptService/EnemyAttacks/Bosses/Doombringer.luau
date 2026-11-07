-- Boss ability logic is isolated per entity; BossScope owns all delayed work.
local Scope = require(script.Parent.Parent.BossScope)
local Match = require(game.ServerScriptService.Simulation.MatchService)
return function(boss)
local scope = Scope.new(boss)
local task = scope.Task
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TOWERDEATH_MOD = require(game.ServerScriptService.Main.TowerDeath)
local MOB_MOD = require(game.ServerScriptService.Main.Mob)

local TAG = "Doombringer"

local TowersFolder = workspace:WaitForChild("Towers")
local Info = workspace:WaitForChild("Info")
local GameSpeedValue = Info:WaitForChild("GameSpeed")
local PlayerCountValue = Info:WaitForChild("PlrValue")
local DeathWishInfo = Info.Modifiers:FindFirstChild("DeathWishInfo")
local EcoDebuff = DeathWishInfo:FindFirstChild("EcoDebuff").Value

local Events = ReplicatedStorage:WaitForChild("Events")
local AnimateEnemyEvent = Events:WaitForChild("AnimateEnemy")
local AnimateBossEvent = Events:WaitForChild("AnimateBoss")
local AnimateTowerDeathEvent = Events:WaitForChild("AnimateTowerDeath")
local ShockWaveEvent = Events:WaitForChild("Stomp")
local SummonEnemyEvent = Events:WaitForChild("SummonEnemy")

local DoombringerEvents = Events:WaitForChild("DoombringerEvents")
local MinigunClientEvent = DoombringerEvents:WaitForChild("Minigun"):WaitForChild("Minigun")
local RailgunClient = DoombringerEvents:WaitForChild("Railgun"):WaitForChild("ShouldRailgun")
local Particles = ReplicatedStorage:WaitForChild("Particle")
local SlamParticleTemplate = Particles:WaitForChild("Slam")
local LightningTemplate = Particles:WaitForChild("Lightning")
local VisualFolder = workspace:WaitForChild("Visual")

local State = setmetatable({}, { __mode = "k" })

local REWARD_THRESHOLDS = {45000, 38000, 30000, 23000, 18000, 12500, 5000, 2500}
local ENRAGE_THRESHOLD = 17500
local Extra_Threshold = 250
local COOLDOWNS = {
	Minigun = 38,
	Railgun = 30,
	Slam = 15,
	Stomp = 32,
	Summon = 70,
}

local STOMP_RADIUS = 250
local STOMP_DURATION = 2

local MINIGUN_CHANNEL = 5
local DOT_DURATION = 5
local DOT_TICK = 0.5
local DOT_PERCENT = 0.05
local MINIGUN_DIRECT_PERCENT 
if workspace.Info.Modifiers["Death Wish"].Value == true then 
	MINIGUN_DIRECT_PERCENT = 0.0313
else
	MINIGUN_DIRECT_PERCENT = 0.025
end
local MINIGUN_SPLASH_RADIUS = 5
local MINIGUN_CONE_ANGLE = 20

local MANAGER_TICK = 0.1

local function getGameSpeed()
	local v = GameSpeedValue.Value
	if v <= 0 then
		return 1
	end
	return v
end

local function alive(model)
	return model and model.Parent and model:IsDescendantOf(workspace)
end

local function getBossStats(boss)
	return boss:FindFirstChild("EnemyStats")
end

local function getBossHealth(boss)
	local stats = getBossStats(boss)
	local hp = stats and stats:FindFirstChild("Health")
	return hp and hp.Value
end

local function setBossSpeed(boss, speed)
	local stats = getBossStats(boss)
	if not stats then return end
	local speedVal = stats:FindFirstChild("Speed")
	if speedVal then
		speedVal.Value = speed
	end
end

local function restoreBossSpeed(boss)
	local stats = getBossStats(boss)
	if not stats then return end
	local speedVal = stats:FindFirstChild("Speed")
	local origSpeed = stats:FindFirstChild("OrigSpeed")
	if speedVal and origSpeed then
		speedVal.Value = origSpeed.Value
	end
end

local function getRewardAmount()
	local count = math.max(1, PlayerCountValue.Value)
	local Amount
	if workspace.Info.Modifiers["Death Wish"].Value == true then 
		Amount = math.round(17500 * EcoDebuff - ((Info.PlrValue.Value - 1) * 0.05))
	else
		Amount = 17500
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

	state.activePopTween = scope:Own(TweenService:Create(label, TweenInfo.new(
		0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out
		), {
			Size = originalSize
		}))

	state.activeFloatTween = scope:Own(TweenService:Create(label, TweenInfo.new(
		0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
		), {
			Position = UDim2.new(
				originalPos.X.Scale, originalPos.X.Offset,
				originalPos.Y.Scale, originalPos.Y.Offset - 18
			)
		}))

	scope:Play(state.activePopTween)

	scope:Once(state.activePopTween.Completed, function(playbackState)
		if not alive(boss) then return end
		if myToken ~= state.cashTweenToken then return end
		if playbackState == Enum.PlaybackState.Cancelled then return end
		scope:Play(state.activeFloatTween)
	end)

	scope:Once(state.activeFloatTween.Completed, function(playbackState)
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

local function isValidTower(tower, state)
	if not (tower and tower.Parent == TowersFolder and tower:IsA("Model") and tower.PrimaryPart) then
		return false
	end

	local config = tower:FindFirstChild("Config")
	if not config or not config:FindFirstChild("Health") then return false end
	if not config.Health:FindFirstChild("HealthValue") or not config.Health:FindFirstChild("MaxHealth") then return false end

	-- check if already killed by this boss
	if state and state.killedTowers[tower] then
		return false
	end

	return true
end

local function isFlyingTower(tower)
	local flying = tower.Config:FindFirstChild("Flying")
	return flying ~= nil and ((flying:IsA("BoolValue") and flying.Value) or true)
end

local function findNearestTower(boss, maxDistance)
	local best, bestDist = nil, maxDistance or math.huge
	local hitbox = boss:FindFirstChild("Hitbox")
	if not hitbox then return nil end

	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(tower) and not isFlyingTower(tower) then
			local dist = (tower.PrimaryPart.Position - hitbox.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = tower
			end
		end
	end

	return best
end

local function findRandomTower()
	local valid = {}
	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(tower) then
			table.insert(valid, tower)
		end
	end
	if #valid == 0 then
		return nil
	end
	return valid[math.random(1, #valid)]
end

local function killTower(tower, state)
	if not isValidTower(tower, state) then return end

	-- mark tower as killed for this boss
	if state then
		state.killedTowers[tower] = true
	end

	local ownerValue = tower.Config:FindFirstChild("Owner")
	local ownerName = ownerValue and ownerValue.Value
	local ownerPlayer = ownerName and Players:FindFirstChild(ownerName)

	AnimateTowerDeathEvent:FireAllClients(tower, "TowerDeath", tower)
	scope:KillTower(tower, ownerPlayer or ownerName)
end

local function damageTowerFlat(tower, amount)
	if not isValidTower(tower) then return false end

	local health = tower.Config.Health.HealthValue
	health.Value -= amount

	if health.Value <= 0 then
		killTower(tower)
		return true
	end

	return false
end

local function damageTowerPercent(tower, percent, state)
	if not isValidTower(tower, state) then return false end

	local health = tower.Config.Health.HealthValue
	local maxHealth = tower.Config.Health.MaxHealth
	health.Value = math.round(health.Value - (maxHealth.Value * percent))

	if health.Value <= 0 then
		killTower(tower, state)
		return true
	end

	return false
end

local function startDot(state, tower)
	if not isValidTower(tower) then return end
	if state.activeDots[tower] then return end

	state.activeDots[tower] = true

	task.spawn(function()
		local ticks = math.floor(DOT_DURATION / DOT_TICK + 0.5)
		for _ = 1, ticks do
			if not alive(state.boss) then break end
			if not isValidTower(tower) then break end
			damageTowerPercent(tower, DOT_PERCENT)
			task.wait(DOT_TICK)
		end
		state.activeDots[tower] = nil
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

local function tryEnrage(boss, state)
	if state.enraged then return end

	local hp = getBossHealth(boss)
	if not hp or hp > ENRAGE_THRESHOLD then return end
	state.enraged = true

	playTrackedAnimation(boss, state, "Scream")

	local hrp = boss:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:FindFirstChild("Scream") then
		scope:Play(hrp.Scream)
	end

	local torso = boss:FindFirstChild("Torso")
	if torso then
		local specks = torso:FindFirstChild("SPECKS")
		local spikes = torso:FindFirstChild("SPIKES")
		if specks then scope:Set(specks, "Enabled", true) end
		if spikes then scope:Set(spikes, "Enabled", true) end
		task.delay(1.5, function()
			if specks then specks.Enabled = false end
			if spikes then spikes.Enabled = false end
		end)
	end

	local stats = getBossStats(boss)
	if stats then
		local speed = stats:FindFirstChild("Speed")
		local origSpeed = stats:FindFirstChild("OrigSpeed")
		if speed and origSpeed then
			origSpeed.Value = origSpeed.Value * 1.3
			speed.Value = origSpeed.Value
		end
	end

	local allTowers = {}
	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(tower) then
			table.insert(allTowers, tower)
		end
	end

	local killCount
	if workspace.Info.Modifiers["Death Wish"].Value == true then 
		killCount = math.max(1, math.floor(#allTowers * 0.33))
	else
		killCount = math.max(1, math.floor(#allTowers * 0.25))
	end
	for i = #allTowers, 2, -1 do
		local j = math.random(i)
		allTowers[i], allTowers[j] = allTowers[j], allTowers[i]
	end

	for i = 1, math.min(killCount, #allTowers) do
		local tower = allTowers[i]
		if tower and tower.PrimaryPart then
			local lightClone = scope:Own(LightningTemplate:Clone())
			lightClone.Parent = VisualFolder

			local lightningFolder = lightClone:FindFirstChild("LIGHTNING")
			local electric = lightningFolder and lightningFolder:FindFirstChild("ELECTRIC")
			if electric and electric:IsA("ParticleEmitter") then
				electric:Emit(1)
			end

			local residue = lightClone:FindFirstChild("RESIDUE")
			if residue and residue:IsA("ParticleEmitter") then
				residue:Emit(50)
			end

			if lightClone:IsA("BasePart") then
				lightClone.CFrame = CFrame.new(tower.PrimaryPart.Position + Vector3.new(0, -0.4, 0))
			end

			task.delay(2, function()
				if lightClone then
					scope:Destroy(lightClone)
				end
			end)

			if tower.Config:FindFirstChild("Range") then
				tower.Config.Range.Value = 0
			end
			tower.Config.Health.HealthValue.Value = 0

			task.delay(0.5, function()
				if isValidTower(tower) then
					killTower(tower)
				end
			end)
		end
	end
end

local function tryReward(boss, state)
	if state.rewarded then return end

	local hp = getBossHealth(boss)
	if not hp or hp > Extra_Threshold then return end

	state.rewarded = true

	local hrp = boss:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

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
local function beginAbility(state, name, duration)
	if state.currentAbility then
		return false
	end
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

local function stopAbilityTracks(state)
	if not state or not state.loadedTracks then return end
	for _, track in pairs(state.loadedTracks) do
		if track and track.IsPlaying then
			track:Stop(0.1)
		end
	end
end

local function playTrackedAnimation(boss, state, animName)
	local controller = boss:FindFirstChild("AnimationController")
	local animations = boss:FindFirstChild("Animations")
	local animObj = animations and animations:FindFirstChild(animName)
	if not controller or not animObj then
		warn("[Doombringer] Missing animation:", animName, "for", boss:GetFullName())
		return nil
	end

	state.loadedTracks = state.loadedTracks or {}

	local track = state.loadedTracks[animName]
	if not track then
		track = scope:Own(controller:LoadAnimation(animObj))
		state.loadedTracks[animName] = track
	end

	-- stop other server-side ability tracks first so they don't visually overlap
	stopAbilityTracks(state)

	scope:Play(track)
	return track
end

local function resetBossMovement(boss)
	if not alive(boss) then return end

	local stats = getBossStats(boss)
	if not stats then return end

	local speed = stats:FindFirstChild("Speed")
	local origSpeed = stats:FindFirstChild("OrigSpeed")
	if speed and origSpeed then
		speed.Value = origSpeed.Value
	end
end

local function finishAbility(boss, state, name, shouldRestoreMovement)
	if shouldRestoreMovement then
		resetBossMovement(boss)
	end
	endAbility(state, name)
end

local function runAbility(boss, state, name, duration, shouldFreezeMovement, fn)
	if not beginAbility(state, name, duration) then
		return false
	end

	task.spawn(function()
		if shouldFreezeMovement then
			setBossSpeed(boss, 0)
		end

		local ok, err = xpcall(fn, debug.traceback)

		if not ok and scope:Active() then
			warn(("[Doombringer %s Error] %s"):format(name, err))
		end

		finishAbility(boss, state, name, shouldFreezeMovement)
	end)

	return true
end

local function doSlam(boss, state)
	state.nextSlam = Match.Now() + (COOLDOWNS.Slam)

	runAbility(boss, state, "Slam", 2.4, false, function()
		local target = findNearestTower(boss, 15)
		if not target then return end

		local hitbox = boss:FindFirstChild("Hitbox")
		local hrp = boss:FindFirstChild("HumanoidRootPart")
		if not hitbox or not hrp then return end

		hitbox.CFrame = CFrame.lookAt(
			hitbox.Position,
			Vector3.new(target.PrimaryPart.Position.X, hitbox.Position.Y, target.PrimaryPart.Position.Z)
		)

		task.wait(1)
		if not alive(boss) or not isValidTower(target) then return end

		AnimateEnemyEvent:FireAllClients(boss, "Slam", target)

		local slamSound = hrp:FindFirstChild("Slam")
		if slamSound then scope:Play(slamSound) end

		local slamParticle = scope:Own(SlamParticleTemplate:Clone())
		local targetHRP = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
		local startPos = targetHRP.Position + Vector3.new(0, -targetHRP.Size.Y - 3, 0)
		local endPos = targetHRP.Position + Vector3.new(0, -targetHRP.Size.Y, 0)

		if slamParticle:IsA("BasePart") then
			slamParticle.Position = startPos
		end
		slamParticle.Parent = VisualFolder

		local tweenUp = scope:Own(TweenService:Create(
			slamParticle,
			TweenInfo.new(0.4 / getGameSpeed(), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = endPos }
		))
		local tweenDown = scope:Own(TweenService:Create(
			slamParticle,
			TweenInfo.new(0.4 / getGameSpeed(), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = startPos }
		))

		scope:Play(tweenUp)
		tweenUp.Completed:Wait()
		task.wait(0.5)
		scope:Play(tweenDown)
		tweenDown.Completed:Wait()

		scope:Destroy(slamParticle)

		if isValidTower(target) then
			killTower(target)
		end
	end)
end

local function doStomp(boss, state)
	state.nextStomp = Match.Now() + (COOLDOWNS.Stomp)

	runAbility(boss, state, "Stomp", STOMP_DURATION, true, function()
		AnimateBossEvent:FireAllClients(boss, "Stomp", "Stomp")

		local hitbox = boss:FindFirstChild("Hitbox")
		if hitbox then
			ShockWaveEvent:FireAllClients(hitbox.Position - Vector3.new(0, 0.5, 0), STOMP_RADIUS)
		end

		for _, tower in ipairs(TowersFolder:GetChildren()) do
			if isValidTower(tower) and not isFlyingTower(tower) then
				local towerHRP = tower:FindFirstChild("HumanoidRootPart") or tower.PrimaryPart
				if hitbox and towerHRP then
					local distance = (hitbox.Position - towerHRP.Position).Magnitude
					if distance < STOMP_RADIUS then
						local config = tower.Config
						local stunned = config:FindFirstChild("Stunned")
						if stunned then
							stunned.Value = 5
						elseif not config:FindFirstChild("CliffTower") then
							local newStun = Instance.new("NumberValue")
							newStun.Name = "Stunned"
							newStun.Value = 5
							newStun.Parent = config
						end

						damageTowerPercent(tower, 0.1)
					end
				end
			end
		end

		task.wait(STOMP_DURATION)
	end)
end

local function doMinigun(boss, state)
	state.nextMinigun = Match.Now() + (COOLDOWNS.Minigun)

	runAbility(boss, state, "Minigun", MINIGUN_CHANNEL, true, function()
		local target = findNearestTower(boss, 10)
		if not target then return end

		AnimateEnemyEvent:FireAllClients(boss, "MinigunSpray", target)
		MinigunClientEvent:FireAllClients(boss)

		MOB_MOD.FacePart(boss, target.PrimaryPart, 5 / getGameSpeed())

		damageTowerPercent(target, MINIGUN_DIRECT_PERCENT)
		startDot(state, target)

		local enemyOrigin = boss:FindFirstChild("HumanoidRootPart") and boss.HumanoidRootPart.Position
		local targetOrigin = target.PrimaryPart.Position
		if enemyOrigin then
			local attackDir = (targetOrigin - enemyOrigin).Unit

			for _, otherTower in ipairs(TowersFolder:GetChildren()) do
				if otherTower ~= target and isValidTower(otherTower) then
					local fromTarget = otherTower.PrimaryPart.Position - targetOrigin
					local distFromTarget = fromTarget.Magnitude
					if distFromTarget <= MINIGUN_SPLASH_RADIUS then
						local fromEnemy = otherTower.PrimaryPart.Position - enemyOrigin
						local dirFromEnemy = fromEnemy.Unit
						local dot = attackDir:Dot(dirFromEnemy)

						if dot > 0 then
							local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
							if angle <= MINIGUN_CONE_ANGLE then
								damageTowerPercent(otherTower, MINIGUN_DIRECT_PERCENT)
								startDot(state, otherTower)
							end
						end
					end
				end
			end
		end

		task.wait(MINIGUN_CHANNEL)
	end)
end

local function findPriorityFlyingTower(boss)
	local bestTower, bestScore = nil, -math.huge
	local hitbox = boss:FindFirstChild("Hitbox")
	if not hitbox then return nil end

	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(tower) and tower:FindFirstChild("Config") then
			local cfg = tower.Config
			if cfg:FindFirstChild("Flying") and cfg.Flying.Value then
				-- Score = DPS * SellValue
				local dps = cfg:FindFirstChild("DPS") and cfg.DPS.Value or 0
				local sell = cfg:FindFirstChild("SellValue") and cfg.SellValue.Value or 0
				local score = dps * sell

				if score > bestScore then
					bestScore = score
					bestTower = tower
				end
			end
		end
	end

	return bestTower
end

local function doRailgun(boss, state)
	state.nextRailgun = Match.Now() + (COOLDOWNS.Railgun)

	runAbility(boss, state, "Railgun", 2.2, true, function()
		-- 🔹 Priority: flying tower with strongest DPS*SellValue
		local target = findPriorityFlyingTower(boss)

		-- 🔹 Fallback to nearest/random tower if no flying tower
		if not target then
			target = findNearestTower(boss, 9999) or findRandomTower()
		end
		if not target then return end

		playTrackedAnimation(boss, state, "RailgunShot")

		local hrp = boss:FindFirstChild("HumanoidRootPart")
		local railgunSound = hrp and hrp:FindFirstChild("Railgun")
		if railgunSound then
			scope:Play(railgunSound)
		end
		RailgunClient:FireAllClients(boss)

		MOB_MOD.FacePart(boss, target.PrimaryPart, 1 / getGameSpeed())

		task.wait(0.8)

		if isValidTower(target) then
			killTower(target)
		end

		task.wait(0.4)
	end)
end

local function doSummon(boss, state)
	state.nextSummon = Match.Now() + (COOLDOWNS.Summon)

	runAbility(boss, state, "Summon", 1.5, false, function()
		playTrackedAnimation(boss, state, "Summon")

		local hrp = boss:FindFirstChild("HumanoidRootPart")
		local scream = hrp and hrp:FindFirstChild("Scream")
		if scream then scope:Play(scream) end

		SummonEnemyEvent:Fire(boss, function() return scope:Active() end)
		task.wait(1.5)
	end)
end

local function initBoss(boss)
	if State[boss] then return end

	local now = Match.Now()
	local gs = getGameSpeed()

	State[boss] = {
		boss = boss,
		currentAbility = nil,
		busyUntil = 0,
		loadedTracks = {},

		nextSlam = now + (COOLDOWNS.Slam),
		nextStomp = now + (COOLDOWNS.Stomp),
		nextMinigun = now + (COOLDOWNS.Minigun),
		nextRailgun = now + (COOLDOWNS.Railgun),
		nextSummon = now + (COOLDOWNS.Summon),

		enraged = false,
		rewarded = false,
		awarded = {false, false, false, false, false},

		activeDots = {},

		cashTweenToken = 0,
		activePopTween = nil,
		activeFloatTween = nil,

		killedTowers = {}, -- <<< ADD THIS
	}
end

initBoss(boss)
return {
	Cooldown = function() return 0.1 end,
	InitialCooldown = function() return 0 end,
	Run = function(active)
		if not active() or not scope:Active() then return end
		scope:Sweep()
		local state = State[boss]
		if not state then return end
		local now = Match.Now()
		checkRewardThresholds(boss, state)
		tryEnrage(boss, state)
		tryReward(boss, state)
		if state.currentAbility then return end
		if now >= state.nextRailgun then doRailgun(boss, state)
		elseif now >= state.nextSlam and findNearestTower(boss, 15) then doSlam(boss, state)
		elseif now >= state.nextMinigun and findNearestTower(boss, 10) then doMinigun(boss, state)
		elseif now >= state.nextStomp then doStomp(boss, state)
		elseif now >= state.nextSummon then doSummon(boss, state) end
	end,
	Cancel = function()
		scope:Cancel()
		local state = State[boss]
		if state then
			if state.activePopTween then state.activePopTween:Cancel() end
			if state.activeFloatTween then state.activeFloatTween:Cancel() end
		end
		State[boss] = nil
	end,
}
end
