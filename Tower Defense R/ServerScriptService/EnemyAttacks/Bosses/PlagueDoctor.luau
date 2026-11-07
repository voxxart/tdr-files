-- Boss ability logic is isolated per entity; BossScope owns all delayed work.
local Scope = require(script.Parent.Parent.BossScope)
local Match = require(game.ServerScriptService.Simulation.MatchService)
return function(enemy)
local scope = Scope.new(enemy)
local task = scope.Task
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local events = ReplicatedStorage:WaitForChild("Events")
local AnimateEnemy = events:WaitForChild("AnimateEnemy")
local AnimateTowerDeath = events:WaitForChild("AnimateTowerDeath")
local PlagueThrowEvent = events:WaitForChild("PlagueThrowEvent")
local DecayFieldTemplate = ReplicatedStorage.Particle:FindFirstChild("DecayField")
local DeathWishInfo = workspace.Info.Modifiers:FindFirstChild("DeathWishInfo")
local EcoDebuff = DeathWishInfo:FindFirstChild("EcoDebuff").Value

local TOWERDEATH_MOD = require(game.ServerScriptService.Main.TowerDeath)
local MOB_MOD = require(game.ServerScriptService.Main.Mob)

local TowersFolder = workspace:WaitForChild("Towers")
local GameSpeedValue = workspace.Info:WaitForChild("GameSpeed")
local PlayerCountValue = workspace.Info:WaitForChild("PlrValue")

local TAG = "PlagueDoctor"
local State = setmetatable({}, { __mode = "k" })

---------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------
local POTION_THROW_ANIM_DELAY = 3
local POTION_LAND_DELAY       = 0.8
local DECAY_DAMAGE_PER_SECOND
if workspace.Info.Modifiers["Death Wish"].Value == true then 
	DECAY_DAMAGE_PER_SECOND = 40
else
	DECAY_DAMAGE_PER_SECOND = 25
end

local DECAY_FIELD_RANGE       = 3.8
local DECAY_FIELD_DURATION    = 40
local DECAY_DISSOLVE_TIME     = 1.5
local DECAY_DESTROY_DELAY     = 3
local MAX_POTIONS             = 3

local HEAL_CD    = 40
local HEAL_AMOUNT
if workspace.Info.Modifiers["Death Wish"].Value == true then 
	HEAL_AMOUNT = 1250
else
	HEAL_AMOUNT = 800
end


local POTION_MIN_CD = 15
local POTION_MAX_CD = 20

local POTION_PROP_NAMES = { "One", "Two", "Three" }

local REWARD_THRESHOLDS = { 9000, 5000, 2500}

-- Barrier tween targets
local BARRIER_MAX_SIZE        = Vector3.new(7.557, 7.557, 7.557)
local BARRIER_ACTIVATE_TIME   = 0.6
local BARRIER_DEACTIVATE_TIME = 0.8

---------------------------------------------------------
-- HELPERS
---------------------------------------------------------
local function gs()
	local v = GameSpeedValue.Value
	return v > 0 and v or 1
end

local function alive(model)
	return model and model.Parent and model:IsDescendantOf(workspace)
end

local function isAliveEnemy(enemy)
	return enemy and enemy.Parent and enemy.PrimaryPart and enemy:FindFirstChild("Hitbox")
end

local function isValidTower(tower)
	if not tower or tower.Parent ~= TowersFolder then return false end
	local cfg = tower:FindFirstChild("Config")
	local health = cfg and cfg:FindFirstChild("Health")
	return tower.PrimaryPart and cfg and health
		and health:FindFirstChild("HealthValue")
		and health:FindFirstChild("MaxHealth")
end

local function findNearestTower(enemy, range)
	range = range or 25
	local epos = enemy.Hitbox.Position
	local best, bestDist = nil, range * range
	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(tower) and not tower.Config:FindFirstChild("Flying") then
			local tpos = tower.PrimaryPart.Position
			local dx, dz = tpos.X - epos.X, tpos.Z - epos.Z
			local dist2 = dx * dx + dz * dz
			if dist2 < bestDist then
				bestDist = dist2
				best = tower
			end
		end
	end
	return best
end

local function schedule(s, cd)
	s.nextT = Match.Now() + cd
end


local function getRewardAmount()
	local count = math.max(1, PlayerCountValue.Value)
	local Amount
	if workspace.Info.Modifiers["Death Wish"].Value == true then 
		Amount = math.round(4500 * EcoDebuff - ((workspace.Info.PlrValue.Value - 1) * 0.05))
	else
		Amount = 5000
	end
	return math.round(Amount / count)
end

local function awardMoneyToPlayer(player, amount)
	local cash = player:FindFirstChild("Cash")
	if cash then cash.Value += amount end
end

local function awardAll(amount)
	for _, plr in ipairs(Players:GetPlayers()) do
		awardMoneyToPlayer(plr, amount)
	end
end

local function getBossShieldHealth(boss)
	local stats = boss:FindFirstChild("EnemyStats")
	local sh = stats and stats:FindFirstChild("ShieldHealth")
	local h = sh and sh:FindFirstChild("Health")
	return h
end

local function getBossHealth(boss)
	local stats = boss:FindFirstChild("EnemyStats")
	local h = stats and stats:FindFirstChild("Health")
	return h
end

local function getMaxShieldHealth(boss)
	local stats = boss:FindFirstChild("EnemyStats")
	local sh = stats and stats:FindFirstChild("ShieldHealth")
	local m = sh and sh:FindFirstChild("MaxHealth")
	return m and m.Value or math.huge
end

local function getMaxHealth(boss)
	local stats = boss:FindFirstChild("EnemyStats")
	local m = stats and stats:FindFirstChild("MaxHealth")
	return m and m.Value or math.huge
end

---------------------------------------------------------
-- BARRIER VISUALS
---------------------------------------------------------
local function setBarrierParticles(barrier, enabled)
	for _, desc in ipairs(barrier:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc.Enabled = enabled
		end
	end
end

local function activateBarrier(barrier)
	-- Cancel any running deactivate tween
	barrier:SetAttribute("BarrierActive", true)

	-- Start invisible and zero size, tween to full
	barrier.Transparency = 0
	barrier.Size = Vector3.new(0, 0, 0)
	setBarrierParticles(barrier, true)

	local tween = scope:Own(TweenService:Create(
		barrier,
		TweenInfo.new(BARRIER_ACTIVATE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = BARRIER_MAX_SIZE }
	))
	scope:Play(tween)
end

local function deactivateBarrier(barrier)
	barrier:SetAttribute("BarrierActive", false)
	setBarrierParticles(barrier, false)

	local tween = scope:Own(TweenService:Create(
		barrier,
		TweenInfo.new(BARRIER_DEACTIVATE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = Vector3.new(0, 0, 0), Transparency = 1 }
	))
	scope:Play(tween)
	scope:Once(tween.Completed, function()
		if barrier and barrier.Parent then
			barrier.Transparency = 1
			barrier.Size = Vector3.new(0, 0, 0)
		end
	end)
end

local function watchShield(boss)
	local shieldHP = getBossShieldHealth(boss)
	if not shieldHP then return end

	local hrp = boss:FindFirstChild("HumanoidRootPart")
	local barrier = boss and boss:FindFirstChild("Barrier")
	if not barrier then return end

	local currentTween

	local function stopTween()
		if currentTween then
			currentTween:Cancel()
			currentTween = nil
		end
	end

	local function activate()
		stopTween()

		barrier:SetAttribute("BarrierActive", true)
		barrier.Transparency = 0
		barrier.Size = Vector3.new(0, 0, 0)

		setBarrierParticles(barrier, true)

		currentTween = scope:Own(TweenService:Create(
			barrier,
			TweenInfo.new(
				BARRIER_ACTIVATE_TIME,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{
				Size = BARRIER_MAX_SIZE
			}
		))

		scope:Play(currentTween)
	end

	local function deactivate()
		stopTween()

		barrier:SetAttribute("BarrierActive", false)
		setBarrierParticles(barrier, false)

		currentTween = scope:Own(TweenService:Create(
			barrier,
			TweenInfo.new(
				BARRIER_DEACTIVATE_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{
				Size = Vector3.new(0, 0, 0),
				Transparency = 1
			}
		))

		scope:Play(currentTween)

		scope:Once(currentTween.Completed, function()
			if barrier and barrier.Parent and barrier:GetAttribute("BarrierActive") == false then
				barrier.Transparency = 1
				barrier.Size = Vector3.new(0, 0, 0)
			end
		end)
	end

	local wasZero

	-- Initial state
	if shieldHP.Value > 0 then
		activate()
		wasZero = false
	else
		deactivate()
		wasZero = true
	end

	scope:Connect(shieldHP.Changed, function(value)
		if not alive(boss) then return end

		if value <= 0 and not wasZero then
			wasZero = true
			deactivate()
		elseif value > 0 and wasZero then
			wasZero = false
			activate()
		end
	end)
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

---------------------------------------------------------
-- REWARD THRESHOLDS
---------------------------------------------------------
local function checkRewardThresholds(boss, state)
	local hpObj = getBossHealth(boss)
	if not hpObj then return end
	local hp = hpObj.Value
	local amount = getRewardAmount()

	for i, threshold in ipairs(REWARD_THRESHOLDS) do
		if not state.awarded[i] and hp <= threshold then
			state.awarded[i] = true
			awardAll(amount)
			playCashTween(boss, amount)
		end
	end
end

---------------------------------------------------------
-- TOWER DEATH
---------------------------------------------------------
local function handleTowerDeath(tower)
	if tower:GetAttribute("Dying") then return end
	tower:SetAttribute("Dying", true)
	task.spawn(function()
		if not (tower and tower.Parent) then return end
		AnimateTowerDeath:FireAllClients(tower, "TowerDeath", tower)

		local ownerPlayer
		local ownerNameValue = tower.Config:FindFirstChild("Owner")
		if ownerNameValue and ownerNameValue.Value ~= "" then
			ownerPlayer = Players:FindFirstChild(ownerNameValue.Value)
		end

		task.wait(0.5)
		if tower and tower.Parent then
			scope:KillTower(tower, ownerPlayer)
		end
	end)
end

local function applyDamageToTower(tower, damage)
	if not isValidTower(tower) then return end
	local healthFolder = tower.Config.Health
	local healthValue = healthFolder.HealthValue
	healthValue.Value = healthValue.Value - damage
	if healthValue.Value <= 0 then
		handleTowerDeath(tower)
	end
end



---------------------------------------------------------
-- DECAY FIELD
---------------------------------------------------------
local function spawnDecayField(position)
	if not DecayFieldTemplate then
		warn("[PlagueDoctor] DecayField particle template not found in ReplicatedStorage.Particle")
		return
	end

	local field = scope:Own(DecayFieldTemplate:Clone())
	field.PrimaryPart.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(-90))
	field.Parent = workspace.Visual
	field.PrimaryPart.Anchored = true

	local function getTransparencyParts()
		local parts = {}
		for _, desc in ipairs(field:GetDescendants()) do
			if desc:IsA("BasePart") or desc:IsA("Decal") then
				table.insert(parts, { instance = desc, originalTransparency = desc.Transparency })
			end
		end
		if field:IsA("BasePart") then
			table.insert(parts, { instance = field, originalTransparency = field.Transparency })
		end
		return parts
	end

	local fieldActive = true
	task.spawn(function()
		while fieldActive do
			task.wait(1)
			if not fieldActive then break end

			local fpos = field.PrimaryPart and field.PrimaryPart.Position or position
			for _, tower in ipairs(TowersFolder:GetChildren()) do
				if isValidTower(tower) then
					local tpos = tower.PrimaryPart.Position
					local dx, dz = tpos.X - fpos.X, tpos.Z - fpos.Z
					if dx * dx + dz * dz <= DECAY_FIELD_RANGE * DECAY_FIELD_RANGE then
						applyDamageToTower(tower, DECAY_DAMAGE_PER_SECOND)
					end
				end
			end
		end
	end)

	task.delay(DECAY_FIELD_DURATION, function()
		fieldActive = false

		local transparencyParts = getTransparencyParts()
		local tweenInfo = TweenInfo.new(DECAY_DISSOLVE_TIME, Enum.EasingStyle.Linear)
		for _, entry in ipairs(transparencyParts) do
			scope:Own(TweenService:Create(entry.instance, tweenInfo, { Transparency = 1 })):Play()
		end

		for _, desc in ipairs(field:GetDescendants()) do
			if desc:IsA("ParticleEmitter") then
				desc.Enabled = false
			end
		end

		task.delay(DECAY_DESTROY_DELAY, function()
			if field and field.Parent then scope:Destroy(field) end
		end)
	end)
end

---------------------------------------------------------
-- POTION THROW
---------------------------------------------------------
local function throwPotion(enemy, target, throwIndex)
	if not isAliveEnemy(enemy) or not isValidTower(target) then return end

	-- Destroy matching prop
	local propName = POTION_PROP_NAMES[throwIndex]
	if propName then
		local potionsFolder = enemy:FindFirstChild("Potions")
		local prop = potionsFolder and potionsFolder:FindFirstChild(propName)
		if prop then scope:Destroy(prop) end
	end

	local targetPos = target.PrimaryPart.Position

	local stats = enemy:FindFirstChild("EnemyStats")
	if stats and stats:FindFirstChild("Speed") then
		stats.Speed.Value = 0
	end
	MOB_MOD.FacePart(enemy, target.PrimaryPart, 4 / gs())

	AnimateEnemy:FireAllClients(enemy, "PotionThrow", target)
	task.delay(3, function()
		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		local atkSound = hrp and hrp:FindFirstChild("Attack")
		if atkSound and atkSound:IsA("Sound") then scope:Play(atkSound) end
	end)

	task.delay(POTION_THROW_ANIM_DELAY, function()
		if not isAliveEnemy(enemy) then return end

		PlagueThrowEvent:FireAllClients(enemy, targetPos)

		task.delay(POTION_LAND_DELAY, function()
			spawnDecayField(targetPos - Vector3.new(0, 1.2, 0))

			task.delay(0.2, function()
				if isAliveEnemy(enemy) then
					if stats and stats:FindFirstChild("Speed") and stats:FindFirstChild("OrigSpeed") then
						stats.Speed.Value = stats.OrigSpeed.Value
					end
				end
			end)
		end)
	end)
end
---------------------------------------------------------
-- HEAL
---------------------------------------------------------
local function doHeal(enemy)
	if not isAliveEnemy(enemy) then return end

	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	local healSound = hrp and hrp:FindFirstChild("Heal")
	if healSound and healSound:IsA("Sound") then scope:Play(healSound) end
		if not isAliveEnemy(enemy) then return end

		local shieldHPObj = getBossShieldHealth(enemy)
		if shieldHPObj then
			local maxShield = getMaxShieldHealth(enemy)
			shieldHPObj.Value = math.min(shieldHPObj.Value + HEAL_AMOUNT, maxShield)
		end
end

---------------------------------------------------------
-- BEHAVIOR
---------------------------------------------------------
local Behaviors = {}
Behaviors.PlagueDoctor = function(enemy, s)
	local now = Match.Now()

	-- Ability lock: only one ability at a time
	if s.isActing then return end

	-- Check reward thresholds every tick
	checkRewardThresholds(enemy, s)

	-- Potion throw (has its own cooldown + max count)
	if now >= s.potionNextT and s.potionsThrown < MAX_POTIONS then
		local target = findNearestTower(enemy)
		if target then
			s.isActing = true
			s.potionsThrown += 1
			local throwIndex = math.min(s.potionsThrown, #POTION_PROP_NAMES)
			s.potionNextT = now + s.rng:NextNumber(POTION_MIN_CD, POTION_MAX_CD)

			task.spawn(function()
				throwPotion(enemy, target, throwIndex)
				task.wait((POTION_THROW_ANIM_DELAY + POTION_LAND_DELAY + 0.5))
				s.isActing = false
			end)
			return
		end
	end

	-- Heal
	if now >= s.healNextT then
		s.isActing = true
		s.healNextT = now + HEAL_CD

		task.spawn(function()
			doHeal(enemy)
			task.wait(2.5)
			s.isActing = false
		end)
		return
	end
end

---------------------------------------------------------
-- START / TRACKING
---------------------------------------------------------
local function start(enemy)
	if State[enemy] then return end

	local now = Match.Now()
	State[enemy] = {
		rng            = Random.new(),
		isActing       = false,

		-- Potion
		potionsThrown  = 0,
		potionNextT    = now + 8,

		-- Heal
		healNextT      = now + 30,

		-- Rewards
		cashTweenToken = 0,
		activePopTween = nil,
		activeFloatTween = nil,
		awarded        = {},
	}

	-- Start barrier watcher
	watchShield(enemy)

end

start(enemy)
return {
	Cooldown = function() return 0.1 end,
	InitialCooldown = function() return 0 end,
	Run = function(active)
		if not active() or not scope:Active() then return end
		scope:Sweep()
		local state = State[enemy]
		if not state then return end
		Behaviors.PlagueDoctor(enemy, state)
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
