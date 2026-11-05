local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("Events")
local NoobicusEvents = events:WaitForChild("NoobicusEvents")
local NoobicusAirstrike = NoobicusEvents:WaitForChild("AirStrike"):WaitForChild("AirStrikeClient")
local Particles = ReplicatedStorage:WaitForChild("Particle")
local EngineerEvent = ReplicatedStorage.Events:WaitForChild("NoobEngineerEvents")
local NoobEngineerBuild = EngineerEvent:WaitForChild("Build"):WaitForChild("BuildClient")

local function Explode(Target, Radius)
	local Range = Radius
	local nearestTarget = nil

	local NewExplode = ReplicatedStorage.Particle.Explosion:Clone()
	NewExplode.Parent = workspace.Visual
	NewExplode.Inner.CFrame = Target.CFrame
	NewExplode.Outer.CFrame = Target.CFrame

	local outer = TweenService:Create(
		NewExplode.Outer,
		TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, 0, true),
		{Size = Vector3.new(Radius * 2, Radius * 2, Radius * 2)}
	)
	local inner = TweenService:Create(
		NewExplode.Inner,
		TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, 0, true),
		{Size = Vector3.new(Radius, Radius, Radius)}
	)
	outer:Play()

	if game.Players.LocalPlayer.VFX.Value == "High" then
		NewExplode.Inner.Transparency = 0	
		inner:Play()
		NewExplode.Inner.Attachment.Embers:Emit(25)
		NewExplode.Inner.Attachment.Fire:Emit(25)
		NewExplode.Inner.Attachment.Smoke:Emit(25)
		NewExplode.Inner.Attachment.Streaks:Emit(25)
	else
		print("Low VFX Are Active")
	end

	NewExplode.Inner.Explosion:Play()

	for _, target in ipairs(workspace.Towers:GetChildren()) do
		local distance = (target.PrimaryPart.Position - Target.Position).Magnitude
		if distance < Range then
			nearestTarget = target
			Range = distance
			local stunned = Instance.new("NumberValue")
			stunned.Name = "Stunned"
			stunned.Value = 5
			stunned.Parent = target.Config
		end
	end

	outer.Completed:Wait()
	NewExplode.Inner.Transparency = 1
	NewExplode.Outer.Transparency = 1
	task.wait(4)
	NewExplode:Destroy()
end

NoobicusAirstrike.OnClientEvent:Connect(function(enemy, target)
	if not (enemy and target and target.PrimaryPart) then return end

	local targetPos = target.PrimaryPart.Position
	local targetCFrame = target.PrimaryPart

	-- Create airstrike field
	local field = Particles.AirstrikeField:Clone()
	field.Position = targetPos + Vector3.new(0, -1, 0)
	field.Parent = workspace.Visual

	local mesh = field:FindFirstChildOfClass("SpecialMesh")

	-- Create airstrike plane
	local plane = Particles.AirstrikePlane:Clone()
	local startPos = targetPos + Vector3.new(0, 20, -1000)
	local endPos = targetPos + Vector3.new(0, 20, 1000)
	plane.Position = startPos
	plane.Parent = workspace.Visual

	local flyTime = 6 / workspace.Info.GameSpeed.Value
	TweenService:Create(plane, TweenInfo.new(flyTime, Enum.EasingStyle.Linear), {Position = endPos}):Play()

	-- Field pulse before strike
	local startSize = mesh and mesh.Scale or field.Size
	local smallSize = startSize * 0.8
	local bigSize = startSize * 1.2
	local pulseEnd = tick() + (flyTime / 2.2)

	task.spawn(function()
		while tick() < pulseEnd and field.Parent do
			if mesh then
				TweenService:Create(mesh, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Scale = smallSize}):Play()
				task.wait(0.3)
				TweenService:Create(mesh, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Scale = bigSize}):Play()
				task.wait(0.3)
			else
				TweenService:Create(field, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = smallSize}):Play()
				task.wait(0.3)
				TweenService:Create(field, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = bigSize}):Play()
				task.wait(0.3)
			end
		end

		-- ⚡ Burst + Explosion (simultaneous)
		local maxSize = startSize * 2.5
		local minSize = startSize * 0.05
		local targetObj = mesh or field

		-- Burst up
		TweenService:Create(targetObj, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			mesh and {Scale = maxSize} or {Size = maxSize}
		):Play()

		-- Run explosion at same time
		task.spawn(function()
			Explode(targetCFrame, 8.5)
		end)
		
		-- Airstrike damage is owned by EnemyAttacks/Noobicus on the server.


		-- Shrink to invisible (continues smoothly)
		task.wait(0.35)
		TweenService:Create(targetObj, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			mesh and {Scale = minSize} or {Size = minSize}
		):Play()

		task.wait(0.25)

		-- Release the local strike visual.
		field:Destroy()
	end)

	task.wait(flyTime + 0.5)
	if plane then plane:Destroy() end
end)

local sentEnemies = {}

NoobEngineerBuild.OnClientEvent:Connect(function(enemy)
	if sentEnemies[enemy] then
		print("Denied")
		return
	end
	sentEnemies[enemy] = true

	EngineerEvent.Build.BuildServer:FireServer(enemy)

	local track = enemy.AnimationController:LoadAnimation(enemy.Animations.Build)
	track.Priority = Enum.AnimationPriority.Action
	local animSpeed = 0.5
	track:AdjustSpeed(animSpeed)
	track:Play()

	track.Stopped:Connect(function()
		sentEnemies[enemy] = nil
	end)
end)


ReplicatedStorage.Events.NoobicusEvents.Shield.ShieldClient.OnClientEvent:Connect(function(enemy)
	local Radius = enemy:FindFirstChild("Radius")
	
	Radius.Transparency = 0
	task.wait(6 / workspace.Info.GameSpeed.Value)
	Radius.Transparency = 1
end)