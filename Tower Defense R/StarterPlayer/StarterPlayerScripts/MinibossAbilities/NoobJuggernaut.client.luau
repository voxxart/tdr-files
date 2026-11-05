local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local events = ReplicatedStorage:WaitForChild("Events")
local JugEvents = events:WaitForChild("JuggernautEvents")
local MinigunSpray = JugEvents:WaitForChild("Minigun"):WaitForChild("MinigunClient")
local Particles = ReplicatedStorage:WaitForChild("Particle")

MinigunSpray.OnClientEvent:Connect(function(enemy)
	if not enemy or not enemy.Parent then return end

	local Weapon = enemy:FindFirstChild("Weapon")
	if not Weapon or not Weapon:FindFirstChild("Handle") then return end
	Weapon = Weapon.Handle

	local HRP = enemy:FindFirstChild("HumanoidRootPart")
	if not HRP then return end

	local AttackSound = HRP:FindFirstChild("Attack")
	local SpinSound = HRP:FindFirstChild("Spin")

	local StartFolder = Weapon:FindFirstChild("Start")
	if not StartFolder then return end

	local Smoke = StartFolder:FindFirstChild("Smoke")
	local Spark = StartFolder:FindFirstChild("Spark")
	local Flash = StartFolder:FindFirstChild("flash1")

	-- ENABLE effects
	if Smoke then Smoke.Enabled = true end
	if Spark then Spark.Enabled = true end
	if Flash then Flash.Enabled = true end

	-- Play spin sound for 1 second, then play attack sound
	if SpinSound then
		SpinSound:Play()
		task.delay(1/ workspace.Info.GameSpeed.Value, function()
			if AttackSound then
				AttackSound:Play()
			end
		end)
	else
		if AttackSound then
			AttackSound:Play()
		end
	end

		task.delay(5/ workspace.Info.GameSpeed.Value, function()
		if Smoke then Smoke.Enabled = false end
		if Spark then Spark.Enabled = false end
		if Flash then Flash.Enabled = false end
		end)

		if SpinSound and SpinSound.IsPlaying then SpinSound:Stop() end
		if AttackSound and AttackSound.IsPlaying then AttackSound:Stop() end
end)
