local Players = game:GetService('Players')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Thresholds = require(game.ServerScriptService.Simulation.ThresholdRewards)
local Rewards = {}
function Rewards.Attach(enemy)
	local generation = Match.Capture()
	local EnemyStats = enemy:FindFirstChild('EnemyStats')
	if not EnemyStats or not EnemyStats:FindFirstChild('Health') then return function() end end
	local head = enemy:FindFirstChild('Head')
	local attachment = head and head:FindFirstChild('AwardMoneyAttachment')
	local CashCounterUI = attachment and attachment:FindFirstChild('CashCounter')
	local TweenService = game:GetService('TweenService')
	local function getRewardAmount()
		local info = workspace.Info
		local count = math.max(1, info.PlrValue.Value)
		local amount = 10000
		if info.Modifiers['Death Wish'].Value then
			local folder = info.Modifiers:FindFirstChild('DeathWishInfo')
			local eco = folder and folder:FindFirstChild('EcoDebuff')
			amount = math.round(10000 * (eco and eco.Value or 1) - ((count - 1) * 0.05))
		end
		return math.round(amount / count)
	end
	local claim = Thresholds.new({15619, 10413, 5207, 100})

	local activePopTween, activeFloatTween = nil, nil
	local tweenToken = 0
	local label = CashCounterUI and CashCounterUI:FindFirstChild('Cash')
	local originalPos = label and label.Position
	local originalSize = label and label.Size
	local originalAnchor = label and label.AnchorPoint

	local function playCashTween(amount)
		local label = CashCounterUI and CashCounterUI:FindFirstChild("Cash")
		if not label then return end
		tweenToken += 1
		local myToken = tweenToken
		if activePopTween then activePopTween:Cancel() end
		if activeFloatTween then activeFloatTween:Cancel() end
		activePopTween, activeFloatTween = nil, nil

		CashCounterUI.Enabled = true
		label.Text = "+$" .. amount


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

	local connection = EnemyStats.Health.Changed:Connect(function(newHealth)
		if not Match.IsCurrent(generation) then return end
		local count = claim(newHealth)
		if count == 0 then return end
		local amount = getRewardAmount()
		awardAll(amount * count)
		playCashTween(amount * count)
	end)
	return function()
		connection:Disconnect()
		tweenToken += 1
		if activePopTween then activePopTween:Cancel() end
		if activeFloatTween then activeFloatTween:Cancel() end
		if label and label.Parent then
			label.Position = originalPos; label.Size = originalSize; label.AnchorPoint = originalAnchor
		end
		if CashCounterUI and CashCounterUI.Parent then CashCounterUI.Enabled = false end
	end

end
return Rewards
