-- StarterPlayerScripts/EnemyExplosion.client.lua
-- Enemy VFX stays client-side.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = ReplicatedStorage:WaitForChild("Events")
local EnemyExplosion = Events:WaitForChild("EnemyExplosion")

local template =
	ReplicatedStorage
	:WaitForChild("Particle")
	:WaitForChild("EnemyExplosion")

local VisualFolder =
	workspace:FindFirstChild("Visual")
	or workspace

EnemyExplosion.OnClientEvent:Connect(function(position, radius)
	local explosion = template:Clone()
	explosion.Parent = VisualFolder

	local part =
		explosion.PrimaryPart
		or explosion:FindFirstChildWhichIsA("BasePart")

	if not part then
		explosion:Destroy()
		return
	end

	explosion.PrimaryPart = part
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Position = position
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Transparency = 0

	local sound = part:FindFirstChild("Explosion")
	if sound then sound:Play() end

	local attachment = part:FindFirstChild("Attachment")

	if attachment then
		for _, name in ipairs({
			"Embers",
			"Fire",
			"Smoke",
			"Streaks",
			}) do
			local emitter = attachment:FindFirstChild(name)

			if emitter then
				emitter:Emit(25)
			end
		end
	end

	local grow = TweenService:Create(
		part,
		TweenInfo.new(0.5),
		{
			Size = Vector3.new(
				radius,
				radius,
				radius
			)
		}
	)

	local fade = TweenService:Create(
		part,
		TweenInfo.new(0.5),
		{
			Transparency = 1
		}
	)

	grow:Play()

	grow.Completed:Once(function()
		if part.Parent then
			fade:Play()
		end
	end)

	Debris:AddItem(explosion, 2)
end)
