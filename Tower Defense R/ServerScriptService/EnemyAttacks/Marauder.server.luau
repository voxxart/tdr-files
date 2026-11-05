local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local events = ReplicatedStorage:WaitForChild("Events")
local AnimateEnemy = events:WaitForChild("AnimateEnemy")
local AnimateTowerDeath = events:WaitForChild("AnimateTowerDeath")
local TOWERDEATH_MOD = require(game.ServerScriptService.Main.TowerDeath)

local DeathWishInfo = workspace.Info.Modifiers:FindFirstChild("DeathWishInfo")
local EcoDebuff = DeathWishInfo:FindFirstChild("EcoDebuff")
local PlayerCountValue = workspace.Info:WaitForChild("PlrValue")

local TowersFolder = workspace:WaitForChild("Towers")
local GameSpeedValue = workspace.Info:WaitForChild("GameSpeed")

-- Enemy tag
local TAG = "Marauder"

-- Weak table to track per-enemy state
local State = setmetatable({}, {__mode="k"}) -- [enemy] = {rng, nextT, data}

-- Helpers
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

local function findNearestTower(enemy, range)
	local maxDist = range or 8
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

-- Schedule next attack
local function schedule(enemy, s, minCd, maxCd)
	minCd = 10
	maxCd = 11
	s.nextT = os.clock() + s.rng:NextNumber(minCd/gs(), maxCd/gs())
end

--------------------------------------------------------------------
-- BEHAVIORS
--------------------------------------------------------------------
local Behaviors = {}

Behaviors.Marauder = function(enemy, s)
	local range = enemy:GetAttribute("Range") or 8
	local minCd = enemy:GetAttribute("AttackMin") or 6
	local maxCd = enemy:GetAttribute("AttackMax") or 11

	if os.clock() < s.nextT then return end
	schedule(enemy, s, minCd, maxCd)

	local target = findNearestTower(enemy, range)
	if not target then return end

	local hv = target.Config.Health.HealthValue
	if hv.Value <= 0 then return end

	-- Face target
	local epos = enemy.Hitbox.Position
	local tpos = target.PrimaryPart.Position
	enemy.Hitbox.CFrame = CFrame.lookAt(epos, Vector3.new(tpos.X, enemy.PrimaryPart.Position.Y, tpos.Z))

	-- Fire animation
	AnimateEnemy:FireAllClients(enemy, "Attack", target)
	enemy.HumanoidRootPart.Attack:Play()
	-- Deal full health damage
	hv.Value = 0
	

	if hv.Value <= 0 then
		AnimateTowerDeath:FireAllClients(target, "TowerDeath", target)
		local ownerName = target.Config.Owner.Value
		local ownerPlayer = Players:FindFirstChild(ownerName)
		TOWERDEATH_MOD.KillTower(target, ownerPlayer)
	end
end

--------------------------------------------------------------------
-- MONEY / REWARD LOGIC
--------------------------------------------------------------------
local function setupMoneyTracking(enemy)
	local EnemyStats = enemy:WaitForChild("EnemyStats")
	local AwardMoneyAtt = enemy:WaitForChild("Head"):WaitForChild("AwardMoneyAttachment")
	local CashCounterUI = AwardMoneyAtt:WaitForChild("CashCounter")
	local TweenService = game:GetService("TweenService")
	local playerCountValue = workspace.Info:WaitForChild("PlrValue")

	local function getRewardAmount()
		local count = math.max(1, PlayerCountValue.Value)
		local Amount
		if workspace.Info.Modifiers["Death Wish"].Value == true then 
			Amount = math.round(10000 * EcoDebuff - ((workspace.Info.PlrValue.Value - 1) * 0.05))
		else
			Amount = 10000
		end
		return math.round(Amount / count)
	end

	local awarded = {false, false, false, false}
	local thresholds = {15619, 10413, 5207, 100}

	local activePopTween, activeFloatTween = nil, nil
	local tweenToken = 0

	local function playCashTween(amount)
		local label = CashCounterUI:WaitForChild("Cash")
		tweenToken += 1
		local myToken = tweenToken
		if activePopTween then activePopTween:Cancel() end
		if activeFloatTween then activeFloatTween:Cancel() end
		activePopTween, activeFloatTween = nil, nil

		CashCounterUI.Enabled = true
		label.Text = "+$" .. amount

		local originalPos = label.Position
		local originalSize = label.Size
		local originalAnchor = label.AnchorPoint

		label.AnchorPoint = Vector2.new(0.5,0.5)
		label.Position = originalPos
		label.Size = UDim2.new(
			originalSize.X.Scale * 0.8, originalSize.X.Offset * 0.8,
			originalSize.Y.Scale * 0.8, originalSize.Y.Offset * 0.8
		)

		activePopTween = TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = originalSize})
		activeFloatTween = TweenService:Create(label, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset - 18)
		})

		activePopTween:Play()
		activePopTween.Completed:Once(function(state)
			if myToken ~= tweenToken then return end
			if state == Enum.PlaybackState.Cancelled then return end
			activeFloatTween:Play()
		end)
		activeFloatTween.Completed:Once(function(state)
			if myToken ~= tweenToken then return end
			if state == Enum.PlaybackState.Cancelled then return end
			label.Position = originalPos
			label.Size = originalSize
			label.AnchorPoint = originalAnchor
			CashCounterUI.Enabled = false
		end)
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

	EnemyStats:WaitForChild("Health").Changed:Connect(function(newHealth)
		local amount = getRewardAmount()
		for i, threshold in ipairs(thresholds) do
			if (not awarded[i]) and newHealth <= threshold then
				awardAll(amount)
				playCashTween(amount)
				awarded[i] = true
			end
		end
	end)
end

--------------------------------------------------------------------
-- TRACKING / START
--------------------------------------------------------------------
local function start(enemy)
	if State[enemy] then return end
	State[enemy] = {rng = Random.new(), nextT = 0, data = nil}
	schedule(enemy, State[enemy], enemy:GetAttribute("AttackMin") or 6, enemy:GetAttribute("AttackMax") or 11)

	setupMoneyTracking(enemy)

	enemy.AncestryChanged:Connect(function(_, parent)
		if not parent then
			State[enemy] = nil
		end
	end)
end

for _, enemy in ipairs(CollectionService:GetTagged(TAG)) do
	start(enemy) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(start)
CollectionService:GetInstanceRemovedSignal(TAG, function(enemy) State[enemy] = nil end)

--------------------------------------------------------------------
-- HEARTBEAT LOOP
--------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	for enemy, s in pairs(State) do
		if not isAliveEnemy(enemy) then
			State[enemy] = nil
		else
			Behaviors.Marauder(enemy, s)
		end
	end
end)