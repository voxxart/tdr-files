-- Boss ability logic is isolated per entity; BossScope owns all delayed work.
local Scope = require(script.Parent.Parent.BossScope)
local Match = require(game.ServerScriptService.Simulation.MatchService)
return function(enemy)
local scope = Scope.new(enemy)
local task = scope.Task
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local events = ReplicatedStorage:WaitForChild("Events")
local AnimateEnemy = events:WaitForChild("AnimateEnemy")
local AnimateTowerDeath = events:WaitForChild("AnimateTowerDeath")
local JuggernautEvents = events:WaitForChild("JuggernautEvents")
local TweenService = game:GetService("TweenService")
local TOWERDEATH_MOD = require(game.ServerScriptService.Main.TowerDeath)
local MOB_MOD = require(game.ServerScriptService.Main.Mob)
local DeathWishInfo = workspace.Info.Modifiers:FindFirstChild("DeathWishInfo")
local EcoDebuff = DeathWishInfo:FindFirstChild("EcoDebuff").Value

local TowersFolder = workspace:WaitForChild("Towers")
local GameSpeedValue = workspace.Info:WaitForChild("GameSpeed")
local PlayerCountValue = workspace.Info:WaitForChild("PlrValue")

local TAG = "NoobJuggernaut"
local State = setmetatable({}, {__mode="k"}) -- [enemy] = {rng, nextT, data}

local REWARD_THRESHOLDS = {10000, 7500, 5000, 2500}

--------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------
local function gs()
	local v = GameSpeedValue.Value
	if v <= 0 then return 1 end
	return v
end

local function isAliveEnemy(enemy)
	return enemy and enemy.Parent and enemy.PrimaryPart and enemy:FindFirstChild("Hitbox")
end

local function isValidTower(tower)
	return tower
		and tower.Parent == TowersFolder
		and tower:IsA("Model")
		and tower.PrimaryPart
		and tower:FindFirstChild("Config")
		and tower.Config:FindFirstChild("Health")
		and tower.Config.Health:FindFirstChild("HealthValue")
		and tower.Config.Health:FindFirstChild("MaxHealth")
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

local function getRewardAmount()
	local count = math.max(1, PlayerCountValue.Value)
	local Amount
	if workspace.Info.Modifiers["Death Wish"].Value == true then 
		Amount = math.round(17500 * EcoDebuff - ((workspace.Info.PlrValue.Value - 1) * 0.05))
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

local function findNearestTower(enemy, range)
	local maxDist = range or 10
	local maxSq = maxDist * maxDist
	local epos = enemy.Hitbox.Position

	local best, bestSq = nil, maxSq
	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(tower) and not tower.Config:FindFirstChild("Flying") then
			local tpos = tower.PrimaryPart.Position
			local dx = tpos.X - epos.X
			local dz = tpos.Z - epos.Z
			local d2 = dx*dx + dz*dz
			if d2 < bestSq then
				bestSq = d2
				best = tower
			end
		end
	end
	return best
end

local function schedule(enemy, s, minCd, maxCd)
	minCd = minCd or 14
	maxCd = maxCd or 22
	s.nextT = Match.Now() + s.rng:NextNumber(minCd, maxCd)
end

local function damageTower(tower, percent)
	if not isValidTower(tower) then return end
	local hv = tower.Config.Health.HealthValue
	local maxH = tower.Config.Health.MaxHealth
	hv.Value = math.round(hv.Value - maxH.Value * percent)

	if hv.Value <= 0 then
		local ownerName = tower.Config.Owner.Value
		local ownerPlayer = Players:FindFirstChild(ownerName)
		AnimateTowerDeath:FireAllClients(tower, "TowerDeath", tower)
		scope:KillTower(tower, ownerPlayer)
	end
end

local function applyDOT(tower)
	local duration = 5
	local tickInterval = 0.5
	local ticks = duration / tickInterval
	task.spawn(function()
		for _ = 1, ticks do
			if not tower or not tower.Parent then return end
			damageTower(tower, 0.05)
			task.wait(tickInterval)
		end
	end)
end

--------------------------------------------------------------------
-- BEHAVIOR
--------------------------------------------------------------------
local Behaviors = {}

Behaviors.NoobJuggernaut = function(enemy, s)
	local minCd = 14
	local maxCd = 22
	if Match.Now() < s.nextT then return end
	schedule(enemy, s, minCd, maxCd)

	local target = findNearestTower(enemy)
	if not target then return end

	-- stop movement
	enemy.EnemyStats.Speed.Value = 0

	-- animate attack
	AnimateEnemy:FireAllClients(enemy, "Fire", target)
	JuggernautEvents.Minigun.MinigunClient:FireAllClients(enemy)

	-- rotate mob visually
	MOB_MOD.FacePart(enemy, target.PrimaryPart, 5/gs())

	-- main tower damage
	damageTower(target, 0.025)
	applyDOT(target)

	-- splash damage (front-only)
	local enemyOrigin = enemy.HumanoidRootPart.Position
	local targetOrigin = target.PrimaryPart.Position
	local attackDir = (targetOrigin - enemyOrigin).Unit
	local splashRadius = 5
	local coneAngle = 20

	for _, otherTower in ipairs(TowersFolder:GetChildren()) do
		if otherTower ~= target and isValidTower(otherTower) then
			local fromTarget = otherTower.PrimaryPart.Position - targetOrigin
			if fromTarget.Magnitude > splashRadius then continue end

			local fromEnemy = otherTower.PrimaryPart.Position - enemyOrigin
			local dirFromEnemy = fromEnemy.Unit
			local dot = attackDir:Dot(dirFromEnemy)
			if dot <= 0 then continue end

			local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
			if angle <= coneAngle then
				damageTower(otherTower, 0.025)
				applyDOT(otherTower)
			end
		end
	end

	-- restore speed after short delay
	task.spawn(function()
		task.wait(5)
		if enemy and enemy.Parent then
			enemy.EnemyStats.Speed.Value = enemy.EnemyStats.OrigSpeed.Value
		end
	end)
end

--------------------------------------------------------------------
-- START / TRACKING
--------------------------------------------------------------------
local function start(enemy)
	if State[enemy] then
		return
	end

	State[enemy] = {
		rng = Random.new(),
		nextT = 0,

		awarded = {},

		cashTweenToken = 0,
		activePopTween = nil,
		activeFloatTween = nil,
	}

	schedule(enemy, State[enemy], 14, 22)

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
		checkRewardThresholds(enemy, state)
		Behaviors.NoobJuggernaut(enemy, state)
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
