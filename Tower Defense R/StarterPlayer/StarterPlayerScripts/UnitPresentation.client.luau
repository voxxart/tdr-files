local RepStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local owned = {}
local function explode(position, radius)
	if typeof(position) ~= "Vector3" then
		warn("[Unit] Explode called without a valid Vector3 position")
		return
	end

	radius = tonumber(radius) or 0

	if radius <= 0 then
		return
	end

	-- Create the visual independently of the unit/enemy.
	local explosionTemplate = RepStorage.Particle:FindFirstChild("Explosion")
	if not explosionTemplate then
		warn("[Unit] Missing RepStorage.Particle.Explosion")
		return
	end

	local newExplode = explosionTemplate:Clone()
	newExplode.Parent = workspace.Visual
	owned[newExplode] = true

	local inner = newExplode:FindFirstChild("Inner")
	local outer = newExplode:FindFirstChild("Outer")

	if not inner or not outer then
		warn("[Unit] Explosion is missing Inner or Outer")
		owned[newExplode] = nil; newExplode:Destroy()
		return
	end

	-- The position was already captured before the target was destroyed.
	inner.CFrame = CFrame.new(position)
	outer.CFrame = CFrame.new(position)

	local outerTween = TweenService:Create(
		outer,
		TweenInfo.new(
			0.3,
			Enum.EasingStyle.Cubic,
			Enum.EasingDirection.Out,
			0,
			true
		),
		{
			Size = Vector3.new(radius * 2, radius * 2, radius * 2)
		}
	)

	local innerTween = TweenService:Create(
		inner,
		TweenInfo.new(
			0.3,
			Enum.EasingStyle.Cubic,
			Enum.EasingDirection.Out,
			0,
			true
		),
		{
			Size = Vector3.new(radius, radius, radius)
		}
	)

	outerTween:Play()
	innerTween:Play()

	local attachment = inner:FindFirstChild("Attachment")

	if attachment then
		local embers = attachment:FindFirstChild("Embers")
		local fire = attachment:FindFirstChild("Fire")
		local smoke = attachment:FindFirstChild("Smoke")
		local streaks = attachment:FindFirstChild("Streaks")

		if embers then embers:Emit(25) end
		if fire then fire:Emit(25) end
		if smoke then smoke:Emit(25) end
		if streaks then streaks:Emit(25) end
	end

	local explosionSound = inner:FindFirstChild("Explosion")
	if explosionSound then
		explosionSound:Play()
	end

	-- Cleanup is completely independent of the unit/enemy.
	task.delay(0.6,function()
		if inner.Parent then inner.Transparency=1 end
		if outer.Parent then outer.Transparency=1 end
	end)
	task.delay(4.6,function()
		owned[newExplode]=nil
		if newExplode.Parent then newExplode:Destroy() end
	end)
end

RepStorage.Events:WaitForChild('UnitPresentation').OnClientEvent:Connect(function(kind,position,radius)
	if kind == 'Explosion' then explode(position,radius) end
end)
local function clear()
	for model in pairs(owned) do model:Destroy(); owned[model] = nil end
end
workspace.Info.GameRunning.Changed:Connect(function(running) if not running then clear() end end)
workspace.Info.Message.Changed:Connect(function(message) if message=='GAME OVER' or message=='VICTORY' then clear() end end)
