local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local TOWERDEATH_MOD = require(game.ServerScriptService.Main.TowerDeath)
local MOB_MOD = require(game.ServerScriptService.Main.Mob)

local TAG = "Swordmaster"

local TowersFolder = workspace:WaitForChild("Towers")
local Info = workspace:WaitForChild("Info")
local GameSpeedValue = Info:WaitForChild("GameSpeed")
local PlayerCountValue = Info:WaitForChild("PlrValue")
local DeathWishInfo = Info.Modifiers:FindFirstChild("DeathWishInfo")
local EcoDebuff = DeathWishInfo:FindFirstChild("EcoDebuff").Value


local Events = ReplicatedStorage:WaitForChild("Events")
local AnimateEnemyEvent = Events:WaitForChild("AnimateEnemy")
local AnimateTowerDeathEvent = Events:WaitForChild("AnimateTowerDeath")
local SummonEnemyEvent = Events:WaitForChild("SummonEnemy")

local DoombringerEvents = Events:WaitForChild("SwordMaster")
local RocketStormClientEvent = DoombringerEvents:WaitForChild("Rockets")
local BlockClient = DoombringerEvents:WaitForChild("Block")
local SwordRainClient = DoombringerEvents:WaitForChild("SwordRain")
local AAOrbsClient = DoombringerEvents:WaitForChild("AntiAirOrbs")
local FireBreatheClient = DoombringerEvents:WaitForChild("FireBreathe")
local EMPClient = DoombringerEvents:WaitForChild("EMP")

local Particles = ReplicatedStorage:WaitForChild("Particle")
local LightningTemplate = Particles:WaitForChild("Lightning")
local VisualFolder = workspace:WaitForChild("Visual")

-- =========================================================
-- TUNING — edit these freely
-- =========================================================

local REWARD_THRESHOLDS = { 200000, 160000, 125000, 92500, 60000, 38500, 20000 }
local ENRAGE_THRESHOLD  = 50000
local Extra_Threshold   = 250

local COOLDOWNS = {
	RocketStorm = 65,
	Slam        = 22,
	AAOrbs      = 27,
	SwordRain   = 80,
	Summon      = 100,
	FireBreathe = 30,
	EMP         = 35,
	Block       = 70,
}

-- Animation playback speeds (1 = normal). Multiplied by game speed automatically.
local ANIM_SPEEDS = {
	Slam        = 1.2,
	AAOrbs      = 1.0,
	SwordRain   = 1.0,
	Summon      = 1.0,
	FireBreathe = 1.0,
	EMP         = 1.7,
	Block       = 1.0,
	RocketStorm = 1.0,
	Scream      = 1.0,
}

-- Rocket Storm
local ROCKET_COUN
if workspace.Info.Modifiers["Death Wish"].Value == true then 
	ROCKET_COUNT = 6
else
	ROCKET_COUNT = 4
end
local ROCKET_LAUNCH_STAGGER = 0.25  -- seconds between each rocket launch
local ROCKET_TRAVEL_TIME   = 4      -- seconds from launch to impact (per rocket)
local ROCKET_PRIMARY_DMG
if workspace.Info.Modifiers["Death Wish"].Value == true then 
	ROCKET_PRIMARY_DMG = 1150
else
	ROCKET_PRIMARY_DMG = 800
end

local ROCKET_SPLASH_DMG 
if workspace.Info.Modifiers["Death Wish"].Value == true then 
	ROCKET_SPLASH_DMG = 650
else
	ROCKET_SPLASH_DMG = 400
end
local ROCKET_SPLASH_RADIUS = 4

-- Slam
local SLAM_STUN_RADIUS   = 5
local SLAM_STUN_DURATION = 3

-- AA Orbs
local AAORB_COUNT        = 3
local AAORB_DMG          = 1000
local AAORB_LAUNCH_STAGGER = 0.2   -- seconds between each orb launch (matches client)
local AAORB_MAX_LIFETIME = 5       -- seconds before orb pops (matches client)
local ORB_SPEED_STUDS    = 60      -- studs/s — must match client ORB_SPEED

-- Sword Rain
local SWORDRAIN_COUNT 
if workspace.Info.Modifiers["Death Wish"].Value == true then 
	SWORDRAIN_COUNT = 3
else
	SWORDRAIN_COUNT = 2
end
local SWORDRAIN_KILL_RADIUS = 3
local SWORDRAIN_FALL_TIME  = 1.4   -- seconds — matches client tween duration

-- Fire Breathe
local FIREBREATHE_DPS 
if workspace.Info.Modifiers["Death Wish"].Value == true then 
	FIREBREATHE_DPS = 225
else
	FIREBREATHE_DPS = 175
end
local FIREBREATHE_RANGE      = 15
local FIREBREATHE_HALF_ANGLE = 50
local FIREBREATHE_TICK       = 0.25
local FIREBREATHE_DURATION   = 3.5

-- EMP
local EMP_RADIUS        = 200
local EMP_STUN_DURATION = 6
local EMP_DAMAGE_DELAY  = 2    -- seconds after animation starts before damage fires

-- Block
local BLOCK_DURATION = 5

local MANAGER_TICK = 0.1

-- =========================================================
-- State
-- =========================================================

local State = setmetatable({}, { __mode = "k" })

-- =========================================================
-- Helpers
-- =========================================================

local function getGameSpeed()
	local v = GameSpeedValue.Value
	return (v and v > 0) and v or 1
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
	local s = stats:FindFirstChild("Speed")
	if s then s.Value = speed end
end

local function resetBossMovement(boss)
	if not alive(boss) then return end
	local stats = getBossStats(boss)
	if not stats then return end
	local speed = stats:FindFirstChild("Speed")
	local orig  = stats:FindFirstChild("OrigSpeed")
	if speed and orig then speed.Value = orig.Value end
end

local function getRewardAmount()
	local count = math.max(1, PlayerCountValue.Value)
	local Amount
	if workspace.Info.Modifiers["Death Wish"].Value == true then 
		Amount = math.round(40000 * EcoDebuff - ((Info.PlrValue.Value - 1) * 0.05))
	else
		Amount = 40000
	end
	return math.round(Amount / count)
end

local function awardAll(amount)
	for _, plr in ipairs(Players:GetPlayers()) do
		local cash = plr:FindFirstChild("Cash")
		if cash then cash.Value += amount end
	end
end

local function playCashTween(boss, amount)
	local head          = boss:FindFirstChild("Head")
	local awardAtt      = head and head:FindFirstChild("AwardMoneyAttachment")
	local cashCounterUI = awardAtt and awardAtt:FindFirstChild("CashCounter")
	local label         = cashCounterUI and cashCounterUI:FindFirstChild("Cash")
	if not label or not cashCounterUI then return end

	local state = State[boss]
	if not state then return end

	state.cashTweenToken += 1
	local myToken = state.cashTweenToken

	if state.activePopTween   then state.activePopTween:Cancel()   end
	if state.activeFloatTween then state.activeFloatTween:Cancel() end
	state.activePopTween   = nil
	state.activeFloatTween = nil

	cashCounterUI.Enabled = true
	label.Text = "+$" .. amount

	local origPos    = label.Position
	local origSize   = label.Size
	local origAnchor = label.AnchorPoint

	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position    = origPos
	label.Size = UDim2.new(
		origSize.X.Scale * 0.8, origSize.X.Offset * 0.8,
		origSize.Y.Scale * 0.8, origSize.Y.Offset * 0.8
	)

	state.activePopTween = TweenService:Create(label,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = origSize })

	state.activeFloatTween = TweenService:Create(label,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(
			origPos.X.Scale, origPos.X.Offset,
			origPos.Y.Scale, origPos.Y.Offset - 18) })

	state.activePopTween:Play()

	state.activePopTween.Completed:Once(function(ps)
		if not alive(boss) then return end
		if myToken ~= state.cashTweenToken then return end
		if ps == Enum.PlaybackState.Cancelled then return end
		state.activeFloatTween:Play()
	end)

	state.activeFloatTween.Completed:Once(function(ps)
		task.wait(1.2)
		if not alive(boss) then return end
		if myToken ~= state.cashTweenToken then return end
		if ps == Enum.PlaybackState.Cancelled then return end
		label.Position    = origPos
		label.Size        = origSize
		label.AnchorPoint = origAnchor
		cashCounterUI.Enabled = false
	end)
end

-- ---- Tower helpers ----

local function isValidTower(tower, state)
	if not (tower and tower.Parent == TowersFolder
		and tower:IsA("Model") and tower.PrimaryPart) then
		return false
	end
	local cfg = tower:FindFirstChild("Config")
	if not cfg then return false end
	local h = cfg:FindFirstChild("Health")
	if not h or not h:FindFirstChild("HealthValue") or not h:FindFirstChild("MaxHealth") then
		return false
	end
	if state and state.killedTowers[tower] then return false end
	return true
end

local function isFlyingTower(tower)
	local cfg    = tower:FindFirstChild("Config")
	local flying = cfg and cfg:FindFirstChild("Flying")
	if not flying then return false end
	if flying:IsA("BoolValue") then return flying.Value end
	return true
end

local function collectValidTowers(state, groundedOnly)
	local list = {}
	for _, t in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(t, state) then
			if not groundedOnly or not isFlyingTower(t) then
				list[#list + 1] = t
			end
		end
	end
	return list
end

local function findNearestTower(boss, maxDist, state)
	local hitbox = boss:FindFirstChild("Hitbox")
	if not hitbox then return nil end
	local best, bestD = nil, maxDist or math.huge
	for _, t in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(t, state) and not isFlyingTower(t) then
			local d = (t.PrimaryPart.Position - hitbox.Position).Magnitude
			if d < bestD then bestD = d; best = t end
		end
	end
	return best
end

local function killTower(tower, state)
	if not isValidTower(tower, state) then return end
	if state then state.killedTowers[tower] = true end
	local ownerVal  = tower.Config:FindFirstChild("Owner")
	local ownerName = ownerVal and ownerVal.Value
	local ownerPlr  = ownerName and Players:FindFirstChild(ownerName)
	AnimateTowerDeathEvent:FireAllClients(tower, "TowerDeath", tower)
	task.defer(TOWERDEATH_MOD.KillTower, tower, ownerPlr or ownerName)
	state.killedTowers[tower] = true

	task.delay(2, function()
		if state then
			state.killedTowers[tower] = nil
		end
	end)
end

-- Marks all victims dead first (so no double-kills), then fires deaths together.
local function batchKill(victims, state)
	local validVictims = {}

	for _, tower in ipairs(victims) do
		if isValidTower(tower, state) then
			state.killedTowers[tower] = true
			validVictims[#validVictims + 1] = tower
		end
	end

	task.defer(function()
		for _, tower in ipairs(validVictims) do
			if tower and tower.Parent then
				local ownerVal = tower.Config:FindFirstChild("Owner")
				local ownerName = ownerVal and ownerVal.Value
				local ownerPlr = ownerName and Players:FindFirstChild(ownerName)

				AnimateTowerDeathEvent:FireAllClients(
					tower,
					"TowerDeath",
					tower
				)

				TOWERDEATH_MOD.KillTower(
					tower,
					ownerPlr or ownerName
				)
			end
		end
	end)
end

local function damageTowerFlat(tower, amount, state)
	if not isValidTower(tower, state) then
		return false
	end

	local hp = tower.Config.Health.HealthValue

	hp.Value -= amount

	if hp.Value <= 0 then
		batchKill({tower}, state)
		return true
	end

	return false
end

local function stunTower(tower, duration)
	local cfg = tower:FindFirstChild("Config")
	if not cfg then return end
	
	if workspace.Info.Modifiers["Death Wish"].Value == true then 
		duration = math.round(duration * 1.25)
	else
		duration = duration
	end
	
	local s = cfg:FindFirstChild("Stunned")
	if s then
		s.Value = math.max(s.Value, duration)
	else
		local ns = Instance.new("NumberValue")
		ns.Name   = "Stunned"
		ns.Value  = duration
		ns.Parent = cfg
	end
end

local function unifiedBatchDamage(victims, amount, state)
	if #victims == 0 then
		return
	end

	local killList = {}

	-- Apply all damage in the same frame
	for _, tower in ipairs(victims) do
		if isValidTower(tower, state) then
			local hp = tower.Config.Health.HealthValue

			hp.Value -= amount

			if hp.Value <= 0 then
				killList[#killList + 1] = tower
			end
		end
	end

	-- Kill all dead towers together
	if #killList > 0 then
		batchKill(killList, state)
	end
end

-- ---- Reward helpers ----

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

local function tryReward(boss, state)
	if state.rewarded then return end
	local hp = getBossHealth(boss)
	if not hp or hp > Extra_Threshold then return end
	state.rewarded = true
	local hitbox = boss:FindFirstChild("Hitbox")
	if not hitbox then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		ReplicatedStorage.Events.BPCurrency:FireClient(
			plr, "ReleaseBPCurrency", 0.3, hitbox.Position, plr)
	end
end

-- =========================================================
-- Ability scaffolding
-- =========================================================

local function isBusy(state)
	return state.currentAbility ~= nil
end

local function beginAbility(state, name, duration)
	if isBusy(state) then return false end
	state.currentAbility = name
	state.busyUntil      = os.clock() + duration
	return true
end

local function endAbility(state, name)
	if state.currentAbility == name then
		state.currentAbility = nil
		state.busyUntil      = 0
	end
end

local function stopAllTracks(state)
	if not state.loadedTracks then return end
	for _, track in pairs(state.loadedTracks) do
		if track and track.IsPlaying then
			track:Stop(0.15)
		end
	end
end

local function playAnim(boss, state, animName, speedOverride)
	local controller = boss:FindFirstChild("AnimationController")
	local animations = boss:FindFirstChild("Animations")
	local animObj    = animations and animations:FindFirstChild(animName)
	if not controller or not animObj then
		warn("[Swordmaster] Missing animation:", animName)
		return nil
	end

	state.loadedTracks = state.loadedTracks or {}

	local track = state.loadedTracks[animName]
	if not track then
		track = controller:LoadAnimation(animObj)
		state.loadedTracks[animName] = track
	end

	stopAllTracks(state)

	local speed = (speedOverride or ANIM_SPEEDS[animName] or 1) * getGameSpeed()
	track:Play()
	track:AdjustSpeed(speed)
	return track
end

local function finishAbility(boss, state, name, restoreMovement)
	if restoreMovement then resetBossMovement(boss) end
	endAbility(state, name)
end

local function runAbility(boss, state, name, duration, freezeMovement, fn)
	if not beginAbility(state, name, duration) then return false end

	task.spawn(function()
		if freezeMovement then setBossSpeed(boss, 0) end

		local ok, err = xpcall(fn, debug.traceback)
		if not ok then
			warn(("[Swordmaster:%s] %s"):format(name, err))
		end

		finishAbility(boss, state, name, freezeMovement)
	end)

	return true
end

-- =========================================================
-- Abilities
-- =========================================================

-- ---- Slam ----
local function doSlam(boss, state)
	local gs = getGameSpeed()
	state.nextSlam = os.clock() + COOLDOWNS.Slam / gs

	runAbility(boss, state, "Slam", 2.5 / gs, false, function()
		local target = findNearestTower(boss, 15, state)
		if not target then return end

		local hrp = boss:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local stats    = getBossStats(boss)
		local origSpeed = stats and stats:FindFirstChild("OrigSpeed")
		local speedVal  = stats and stats:FindFirstChild("Speed")
		if speedVal then speedVal.Value = 0 end

		if target.PrimaryPart then
			MOB_MOD.FacePart(boss, target.PrimaryPart, 2.5)
		end

		playAnim(boss, state, "Slam")
		AnimateEnemyEvent:FireAllClients(boss, "Slam", target)

		task.wait(1 / gs)
		if not alive(boss) then return end

		local slamSound = hrp:FindFirstChild("Slam")
		if slamSound then slamSound:Play() end

		local origin = target.PrimaryPart and target.PrimaryPart.Position

		-- Stun nearby towers first (doesn't kill them)
		if origin then
			for _, other in ipairs(TowersFolder:GetChildren()) do
				if other ~= target and isValidTower(other, state) and other.PrimaryPart then
					if (other.PrimaryPart.Position - origin).Magnitude <= SLAM_STUN_RADIUS then
						stunTower(other, SLAM_STUN_DURATION)
					end
				end
			end
		end

		-- Kill primary target
		if isValidTower(target, state) then
			killTower(target, state)
		end

		if speedVal and origSpeed then speedVal.Value = origSpeed.Value end

		task.wait(0.5 / gs)
	end)
end

-- ---- Rocket Storm ----
--[[
	Each rocket is an independent task.delay that:
	  1. Plays the launch sound
	  2. Waits ROCKET_TRAVEL_TIME (per-rocket timer, not shared)
	  3. Resolves its own primary kill + splash damage at impact

	The ability lock covers the last rocket's full travel time plus a small buffer.
	This way rocket 6 still deals damage even though it launched last.

	Shared killedTowers table on `state` prevents any tower being killed twice
	across rockets (e.g. rocket 1 kills tower A, rocket 2 targets same tower → skip).
]]
local function doRocketStorm(boss, state)
	local gs = getGameSpeed()
	state.nextRocketStorm = os.clock() + COOLDOWNS.RocketStorm / gs

	-- Total lock = all stagger delays + travel time of the last rocket + buffer
	local totalStagger = ROCKET_LAUNCH_STAGGER * (ROCKET_COUNT - 1)
	local lockDuration = (totalStagger + ROCKET_TRAVEL_TIME + 0.5) / gs

	runAbility(boss, state, "RocketStorm", lockDuration, false, function()
		local pool = collectValidTowers(state, false)
		if #pool == 0 then return end

		-- Assign targets up-front so all rockets have a destination immediately.
		-- Targets can repeat if there are fewer towers than rockets.
		local targets = {}
		for i = 1, ROCKET_COUNT do
			targets[i] = pool[math.random(1, #pool)]
		end

		playAnim(boss, state, "RocketStorm")
		-- Tell client to animate all 6 rockets at once with their targets
		RocketStormClientEvent:FireAllClients(boss, targets)
		AnimateEnemyEvent:FireAllClients(boss, "RocketStorm", targets)

		-- Fire each rocket as an independent timed task.
		-- They run concurrently so rocket 2 doesn't wait for rocket 1 to land.
		local hrp = boss:FindFirstChild("HumanoidRootPart")

		for i, target in ipairs(targets) do
			local launchDelay = (ROCKET_LAUNCH_STAGGER * (i - 1)) / gs

			task.delay(launchDelay, function()
				if not alive(boss) then return end

				-- Launch sound
				if hrp then
					local snd = hrp:FindFirstChild("Rocket")
					if snd then snd:Play() end
				end

				-- Wait for this rocket to travel to its target
				task.wait(ROCKET_TRAVEL_TIME / gs)

				if not alive(boss) then return end

				-- Primary kill — check validity at moment of impact
				if not isValidTower(target, state) then return end

				-- Snapshot origin before killing primary (so splash can use its last position)
				local impactPos = target.PrimaryPart and target.PrimaryPart.Position
				task.defer(function()
					damageTowerFlat(target,ROCKET_PRIMARY_DMG,state)
				end)

				-- Splash damage to nearby towers (flat, doesn't kill on its own unless HP <= 0)
				if impactPos then
					local splashVictims = {}
					for _, other in ipairs(TowersFolder:GetChildren()) do
						if isValidTower(other, state) and other.PrimaryPart then
							if (other.PrimaryPart.Position - impactPos).Magnitude <= ROCKET_SPLASH_RADIUS then
								splashVictims[#splashVictims + 1] = other
							end
						end
					end
					-- Batch-mark splash victims dead before applying damage
					-- so simultaneous rockets don't double-damage
					unifiedBatchDamage(splashVictims, ROCKET_SPLASH_DMG, state)
				end
			end)
		end

		-- Hold ability slot until the last rocket has landed
		task.wait((totalStagger + ROCKET_TRAVEL_TIME + 0.3) / gs)
	end)
end

-- ---- AA Orbs ----
--[[
	Each orb is fully independent:
	  • Its own launch delay (stagger)
	  • Its own travel time based on distance to its specific target at launch moment
	  • Its own arrival check — re-validates that the tower didn't outrun the orb
	  • Damage fires only for that orb; other orbs are unaffected

	The ability slot is held until the last possible orb can resolve
	(last stagger + max lifetime), but each orb damages independently.
]]
local function doAAOrbs(boss, state)
	local gs = getGameSpeed()
	state.nextAAOrbs = os.clock() + COOLDOWNS.AAOrbs / gs

	-- Ability lock = last stagger offset + max orb lifetime + buffer
	local lastStagger  = AAORB_LAUNCH_STAGGER * (AAORB_COUNT - 1)
	local lockDuration = (lastStagger + AAORB_MAX_LIFETIME + 0.3) / gs

	runAbility(boss, state, "AAOrbs", lockDuration, false, function()
		-- Build flying pool once
		local flyingPool = {}
		for _, t in ipairs(TowersFolder:GetChildren()) do
			if isValidTower(t, state) and isFlyingTower(t) then
				flyingPool[#flyingPool + 1] = t
			end
		end
		if #flyingPool == 0 then
			return
		end

		playAnim(boss, state, "AAOrbs")
		AAOrbsClient:FireAllClients(boss)

		-- Source position for travel time calculation
		local attachment = boss:FindFirstChild("Torso")
			and boss.Torso:FindFirstChild("Core")
			and boss.Torso.Core:FindFirstChild("PrimGlow")
			and boss.Torso.Core.PrimGlow:FindFirstChild("Attachment")
		local sourcePos = attachment and attachment.WorldPosition
			or (boss:FindFirstChild("Torso") and boss.Torso.Position)
			or boss:GetPivot().Position

		for i = 1, math.min(AAORB_COUNT, #flyingPool) do
			-- Each orb picks its own independent target
			local target     = flyingPool[math.random(1, #flyingPool)]
			local targetPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
			local launchDelay = (AAORB_LAUNCH_STAGGER * (i - 1)) / gs

			-- Compute this orb's travel time from source to target RIGHT NOW
			-- (position at launch moment — client does the same)
			local travelTime
			if targetPart then
				local dist = (targetPart.Position - sourcePos).Magnitude
				travelTime = math.min(dist / ORB_SPEED_STUDS, AAORB_MAX_LIFETIME)
			else
				travelTime = AAORB_MAX_LIFETIME
			end

			-- Each orb runs in its own task — fully independent of the others
			task.delay(launchDelay, function()
				-- Wait for this orb to travel
				task.wait(travelTime)

				if not alive(boss) then return end
				if not isValidTower(target, state) then return end

				-- Re-check if tower moved far enough to outrun the orb
				local nowPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
				if not nowPart then return end
				-- Max distance orb could have covered = speed * total elapsed time
				local elapsed  = launchDelay + travelTime
				local maxReach = ORB_SPEED_STUDS * gs * elapsed + 2  -- +2 stud tolerance
				local newDist = (nowPart.Position - sourcePos).Magnitude
				if newDist <= ORB_SPEED_STUDS * elapsed + 2 then
					damageTowerFlat(target, AAORB_DMG, state)
				end
				-- If tower outran it, no damage (client orb already popped)
			end)
		end

		-- Hold ability slot until the very last orb could possibly resolve
		task.wait((lastStagger + AAORB_MAX_LIFETIME + 0.2) / gs)
	end)
end

-- ---- Sword Rain ----
local function doSwordRain(boss, state)
	local gs = getGameSpeed()
	state.nextSwordRain = os.clock() + COOLDOWNS.SwordRain / gs

	local totalLock = (SWORDRAIN_FALL_TIME + 1.0) / gs
	runAbility(boss, state, "SwordRain", totalLock, false, function()
		local pool = collectValidTowers(state, false)
		if #pool == 0 then return end

		local targets = {}
		local used    = {}
		for _ = 1, #pool * 2 do
			if #targets >= math.min(SWORDRAIN_COUNT, #pool) then break end
			local c = pool[math.random(1, #pool)]
			if not used[c] then used[c] = true; targets[#targets + 1] = c end
		end

		playAnim(boss, state, "SwordRain")
		SwordRainClient:FireAllClients(boss, targets)
		AnimateEnemyEvent:FireAllClients(boss, "SwordRain", targets)

		task.wait(SWORDRAIN_FALL_TIME / gs)

		-- Collect all victims across every impact zone before any kills fire
		local victimSet = {}
		for _, primary in ipairs(targets) do
			if isValidTower(primary, state) and primary.PrimaryPart then
				local origin = primary.PrimaryPart.Position
				for _, tower in ipairs(TowersFolder:GetChildren()) do
					if isValidTower(tower, state) and tower.PrimaryPart and not victimSet[tower] then
						if (tower.PrimaryPart.Position - origin).Magnitude <= SWORDRAIN_KILL_RADIUS then
							victimSet[tower] = true
						end
					end
				end
			end
		end

		local victims = {}
		for t in pairs(victimSet) do victims[#victims + 1] = t end
		batchKill(victims, state)

		task.wait(0.4 / gs)
	end)
end

-- ---- Summon ----
local function doSummon(boss, state)
	local gs = getGameSpeed()
	state.nextSummon = os.clock() + COOLDOWNS.Summon / gs

	runAbility(boss, state, "Summon", 1.5 / gs, false, function()
		playAnim(boss, state, "Summon")
		
		local hrp    = boss:FindFirstChild("HumanoidRootPart")
		local summon = hrp and hrp:FindFirstChild("Summon")
		if summon then summon:Play() end

		SummonEnemyEvent:Fire(boss)
		task.wait(1.5 / gs)
	end)
end

-- ---- Fire Breathe ----
local function doFireBreathe(boss, state)
	local gs = getGameSpeed()
	state.nextFireBreathe = os.clock() + COOLDOWNS.FireBreathe / gs

	local totalDuration = FIREBREATHE_DURATION / gs

	runAbility(boss, state, "FireBreathe", totalDuration + 0.3, false, function()
		local primaryTarget = findNearestTower(boss, FIREBREATHE_RANGE, state)

		if primaryTarget and primaryTarget.PrimaryPart then
			MOB_MOD.FacePart(boss, primaryTarget.PrimaryPart, 3.5)
		end

		setBossSpeed(boss, 0)

		playAnim(boss, state, "FireBreathe")
		FireBreatheClient:FireAllClients(boss, FIREBREATHE_DURATION)
		local hrp    = boss:FindFirstChild("HumanoidRootPart")
		local summon = hrp and hrp:FindFirstChild("Breathe")
		if summon then summon:Play() end
		
		task.delay(totalDuration, function()
			summon:Stop()
		end)

		local head = boss:FindFirstChild("Hitbox")
			or boss:FindFirstChild("HumanoidRootPart")

		local ticks = math.floor(FIREBREATHE_DURATION / FIREBREATHE_TICK + 0.5)
		local dmgPerTick = FIREBREATHE_DPS * FIREBREATHE_TICK

		for _ = 1, ticks do
			if not alive(boss) then break end

			local primaryTarget = findNearestTower(boss, FIREBREATHE_RANGE, state)
			if primaryTarget and primaryTarget.PrimaryPart then
				local origin = primaryTarget.PrimaryPart.Position

				-- COLLECT ALL VICTIMS THIS TICK (TRUE BATCH)
				local victims = {}

				-- main target
				if isValidTower(primaryTarget, state) then
					table.insert(victims, primaryTarget)
				end

				-- splash targets
				for _, tower in ipairs(TowersFolder:GetChildren()) do
					if tower ~= primaryTarget
						and isValidTower(tower, state)
						and tower.PrimaryPart then

						if (tower.PrimaryPart.Position - origin).Magnitude <= 5 then
							table.insert(victims, tower)
						end
					end
				end

				if #victims > 0 then
					unifiedBatchDamage(victims, dmgPerTick, state)
				end
			end

			task.wait(FIREBREATHE_TICK / gs)
		end

		resetBossMovement(boss)
		task.wait(0.2 / gs)
	end)
end
-- ---- EMP ----
-- ---- EMP ----
local function doEMP(boss, state)
	local gs = getGameSpeed()
	state.nextEMP = os.clock() + COOLDOWNS.EMP / gs

	runAbility(boss, state, "EMP", 4 / gs, false, function()

		task.delay(EMP_DAMAGE_DELAY / gs, function()
			if not alive(boss) then return end

			EMPClient:FireAllClients(boss)
			local hrp    = boss:FindFirstChild("HumanoidRootPart")
			local scream = hrp and hrp:FindFirstChild("Scream")
			if scream then scream:Play() end

			-- Stun and damage EVERY tower
			local victims = {}

			for _, tower in ipairs(TowersFolder:GetChildren()) do
				if isValidTower(tower, state) then
					stunTower(tower, EMP_STUN_DURATION)
					table.insert(victims, tower)
				end
			end

			unifiedBatchDamage(victims, 150, state)
		end)

		task.wait(3.5 / gs)
	end)
end

-- ---- Block ----
local function doBlock(boss, state)
	local gs = getGameSpeed()
	state.nextBlock = os.clock() + COOLDOWNS.Block / gs

	runAbility(boss, state, "Block", (BLOCK_DURATION + 0.5) / gs, false, function()
		playAnim(boss, state, "Block")
		BlockClient:FireAllClients(boss)

		local stats = getBossStats(boss)
		if not stats then return end

		local invuln = stats:FindFirstChild("Invincible")
		if not invuln then
			invuln        = Instance.new("BoolValue")
			invuln.Name   = "Invincible"
			invuln.Parent = stats
		end
		invuln.Value = true
		
		local shieldObj = stats:FindFirstChild("ShieldHealth")
		local shield = shieldObj and (shieldObj:FindFirstChild("Health") or shieldObj)

		if shield and shield:IsA("ValueBase") then
			task.spawn(function()
				local start = os.clock()

				while os.clock() - start < BLOCK_DURATION do
					if not alive(boss) then break end
					if not stats:FindFirstChild("Invincible") then break end

					shield.Value += 400 -- healing per tick while blocking
					task.wait(0.25 / gs)
				end
			end)
		end

		task.wait(BLOCK_DURATION / gs)

		invuln:Destroy()
	end)
end

-- =========================================================
-- Enrage sequence (EMP → AAOrbs → SwordRain → Summon, no overlap)
-- =========================================================

local function tryEnrage(boss, state)
	if state.enraged then return end
	local hp = getBossHealth(boss)
	if not hp or hp > ENRAGE_THRESHOLD then return end

	state.enraged          = true
	state.inEnrageSequence = true

	task.spawn(function()
		local stats     = getBossStats(boss)
		local speed     = stats and stats:FindFirstChild("Speed")
		local origSpeed = stats and stats:FindFirstChild("OrigSpeed")
		if speed and origSpeed then
			origSpeed.Value = origSpeed.Value * 1.3
			speed.Value     = origSpeed.Value
		end

		local torso = boss:FindFirstChild("Torso")
		if torso then
			local specks = torso:FindFirstChild("SPECKS")
			local spikes = torso:FindFirstChild("SPIKES")
			if specks then specks.Enabled = true end
			if spikes then spikes.Enabled = true end
			task.delay(1.5, function()
				if alive(boss) then
					if specks then specks.Enabled = false end
					if spikes then spikes.Enabled = false end
				end
			end)
		end

		local function waitFree()
			while isBusy(state) do
				task.wait(MANAGER_TICK)
				if not alive(boss) then return false end
			end
			return true
		end

		if not alive(boss) then state.inEnrageSequence = false; return end
		if not waitFree()  then state.inEnrageSequence = false; return end

		local sequence = { doEMP, doAAOrbs, doSwordRain, doSummon }
		for _, abilityFn in ipairs(sequence) do
			if not alive(boss) then break end
			abilityFn(boss, state)
			if not waitFree() then break end
		end

		state.inEnrageSequence = false
	end)
end

-- =========================================================
-- Boss lifecycle
-- =========================================================

local function initBoss(boss)
	if State[boss] then return end

	local now = os.clock()
	local gs  = getGameSpeed()

	State[boss] = {
		boss           = boss,
		currentAbility = nil,
		busyUntil      = 0,
		loadedTracks   = {},

		nextRocketStorm = now + COOLDOWNS.RocketStorm / gs,
		nextSlam        = now + COOLDOWNS.Slam / gs,
		nextAAOrbs      = now + COOLDOWNS.AAOrbs / gs,
		nextSwordRain   = now + COOLDOWNS.SwordRain / gs,
		nextSummon      = now + COOLDOWNS.Summon / gs,
		nextFireBreathe = now + COOLDOWNS.FireBreathe / gs,
		nextEMP         = now + COOLDOWNS.EMP / gs,
		nextBlock       = now + COOLDOWNS.Block / gs,

		enraged          = false,
		inEnrageSequence = false,
		rewarded         = false,
		awarded          = { false, false, false, false, false, false, false },

		cashTweenToken   = 0,
		activePopTween   = nil,
		activeFloatTween = nil,

		killedTowers = {},
	}
end

for _, boss in ipairs(CollectionService:GetTagged(TAG)) do
	initBoss(boss)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(initBoss)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(boss)
	State[boss] = nil
end)

-- =========================================================
-- Main loop
-- =========================================================

task.spawn(function()
	while true do
		local now = os.clock()

		for boss, state in pairs(State) do
			if not alive(boss) then
				State[boss] = nil
				continue
			end

			checkRewardThresholds(boss, state)
			tryReward(boss, state)

			if not state.enraged then
				tryEnrage(boss, state)
			end

			if state.inEnrageSequence then continue end
			if isBusy(state) then continue end

			if state.nextSlam <= now and findNearestTower(boss, 15, state) then
				doSlam(boss, state)

			elseif state.nextRocketStorm <= now then
				doRocketStorm(boss, state)

			elseif state.nextAAOrbs <= now then
				doAAOrbs(boss, state)

			elseif state.nextFireBreathe <= now and findNearestTower(boss, FIREBREATHE_RANGE, state) then
				doFireBreathe(boss, state)

			elseif state.nextEMP <= now then
				doEMP(boss, state)

			elseif state.nextSwordRain <= now then
				doSwordRain(boss, state)

			elseif state.nextBlock <= now then
				doBlock(boss, state)

			elseif state.nextSummon <= now then
				doSummon(boss, state)
			end
		end

		task.wait(MANAGER_TICK)
	end
end)
