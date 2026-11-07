local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Workspace = workspace
local Players = game:GetService('Players')
local Module = {}
function Module.Start(scope, context, newTower, player)
local tower = context.Tower
local getGameSpeed = context.GetGameSpeed
local task = scope.Task
local task_spawn, task_wait, task_delay, task_defer = task.spawn, task.wait, task.delay, task.defer
local os_clock = os.clock
local math_max = math.max
local math_min = math.min
local math_round = math.round
local math_sqrt = math.sqrt
local math_random = math.random
local math_floor = math.floor
local math_clamp = math.clamp
local math_abs = math.abs
local math_rad = math.rad
local math_sin = math.sin
local math_cos = math.cos
local math_atan2 = math.atan2
local WaveValue = context.WaveValue
local getEcoDebuffMultiplier = context.getEcoDebuffMultiplier
local Comma = context.Comma
local function run(newTower, player)
	local config = newTower:FindFirstChild("Config")
	if not config then return end

	local head = newTower:FindFirstChild("Head")
	if not head then return end

	local attachment = head:FindFirstChild("FarmAttachment")
	if not attachment then return end

	local billboard = attachment:FindFirstChild("CashCounter")
	if not (billboard and billboard:IsA("BillboardGui")) then return end

	local cash = player:FindFirstChild("Cash")
	if not cash then return end

	local cashValueObj = config:FindFirstChild("Cash")
	if not cashValueObj then return end

	local alive = true
	local ancestryConn
	ancestryConn = scope:Connect(newTower.AncestryChanged, function(_, parent)
		if parent then return end
		alive = false
		if ancestryConn then ancestryConn:Disconnect() ancestryConn = nil end
	end)

	scope:OnCancel(function() billboard.Enabled = false end)

	local waveConn
	waveConn = scope:Connect(WaveValue.Changed, function()
		if not alive or not newTower.Parent then
			if waveConn then waveConn:Disconnect() waveConn = nil end
			return
		end

		local payout = math_round(cashValueObj.Value * getEcoDebuffMultiplier())

		billboard.Cash.Text = "$" ..  Comma(tostring(math.round(payout * workspace.Info.Modifiers.GenerousFarms.FarmModifierBuff.Value)))
		cash.Value += math.round(payout * workspace.Info.Modifiers.GenerousFarms.FarmModifierBuff.Value)

		local cashSound = attachment:FindFirstChild("CashSound")
		if cashSound then cashSound:Play() end

		billboard.Enabled = true

		billboard.Size = UDim2.fromScale(3.5, 0.7)
		billboard.StudsOffset = Vector3.new(0, -0.2, 0)

		billboard.Cash.TextTransparency = 1
		billboard.Cash.UIStroke.Transparency = 1

		scope:Own(TweenService:Create(
			billboard,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{
				Size = UDim2.fromScale(5, 1),
				StudsOffset = Vector3.new(0, 0.301, 0)
			}
		)):Play()

		scope:Own(TweenService:Create(
			billboard.Cash,
			TweenInfo.new(0.2),
			{
				TextTransparency = 0
			}
		)):Play()

		scope:Own(TweenService:Create(
			billboard.Cash.UIStroke,
			TweenInfo.new(0.2),
			{
				Transparency = 0
			}
		)):Play()
		-- your existing orb effect remote
		local fxFolder = ReplicatedStorage.Events:FindFirstChild("TowerEffects")
		local farmOrbs = fxFolder and fxFolder:FindFirstChild("FarmOrbs")
		if farmOrbs then
			farmOrbs:FireAllClients("Money", 0.25, 1, newTower.HumanoidRootPart.Position, player)
		end
		task.delay(0.8, function()
			if billboard and billboard.Parent and alive then
				local hideTween = scope:Own(TweenService:Create(
					billboard,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{
						Size = UDim2.fromScale(3.75, 0.75),
						StudsOffset = Vector3.new(0, -0.25, 0)
					}
				))

				scope:Own(TweenService:Create(
					billboard.Cash,
					TweenInfo.new(0.18),
					{
						TextTransparency = 1
					}
				)):Play()

				scope:Own(TweenService:Create(
					billboard.Cash.UIStroke,
					TweenInfo.new(0.18),
					{
						Transparency = 1
					}
				)):Play()

				hideTween:Play()

				scope:Once(hideTween.Completed, function()
					if billboard and billboard.Parent then
						billboard.Enabled = false
					end
				end)
			end
		end)
	end)
end

return run(newTower, player)
end
return Module
