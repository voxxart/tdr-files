local ServerStorage = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")
local RepStorage = game:GetService("ReplicatedStorage")
local BezierPath = require(RepStorage.Modules.BezierPath)
local RunService = game:GetService("RunService")

local mob = {}

function mob.Move(newMob, map)
	local Positions = {}
	
	for i=1, #map.Waypoints:GetChildren() do
		local waypoint = map.Waypoints[i]
		local AdjustedPosition = waypoint.Position
		table.insert(Positions, AdjustedPosition)
	end
	
	local path = BezierPath.new(Positions, 6)
	local PathLength = path:GetPathLength()
	local speed
	local T = 0
	local lastUpdatedTime = tick()
	local mobUpdates = {}
	local updateInterval = 0.001
	
	while T < 1 do
		speed	= newMob.EnemyStats.Speed.Value
		
		local currentTime = tick()
		local CFramePos = path:CalculateUniformCFrame(T)
		local Height = newMob.EnemyStats.HipHeight.Value + (newMob.PrimaryPart.Size.Y / 2)
		table.insert(mobUpdates, {newMob, CFramePos})
		
		if currentTime - lastUpdatedTime >= updateInterval then
			newMob.Alpha.Value = T
			
			for _, update in ipairs(mobUpdates) do
				local currentMob = update[1]
				local CFramePos = update[2]
				
				currentMob.PrimaryPart.CFrame = CFramePos + Vector3.new(0, Height, 0)
			end
			
			mobUpdates = {}
			lastUpdatedTime = currentTime
		end
		T=T + (speed * RunService.Heartbeat:Wait()) / PathLength
		if T > 1 then T = 1 end
		
		newMob.EnemyStats.Health.Changed:Connect(function()
			if newMob.EnemyStats.Health.Value <= 0 then
				T = 1
			end
		end)
	end
	
	if newMob.EnemyStats.Health.Value and newMob.EnemyStats.Health.Value >= 0 then
		map.Base.EnemyStats.Health.Value -= (15)
	end
end

function mob.Spawn(name, quantity, cooldown, healthMultiplier, speedMultiplier, map)
	local mobExists = ServerStorage.Mobs:FindFirstChild(name)
	
	if mobExists then
		for i=1, quantity do
			task.wait(cooldown)
		local newMob = mobExists:Clone()
		newMob.EnemyStats.MaxHealth.Value *= healthMultiplier
		newMob.EnemyStats.Health.Value *= healthMultiplier
		newMob.EnemyStats.Speed.Value *= speedMultiplier
		local height = newMob.EnemyStats.HipHeight.Value + (newMob.PrimaryPart.Size.Y / 1.75)
		
		newMob.HumanoidRootPart.CFrame = map.Waypoints["1"].CFrame + Vector3.new(0,height,0)
		newMob.Parent = workspace.Mobs
		newMob.HumanoidRootPart.Anchored = true
		
		local alpha = Instance.new("NumberValue")
		alpha.Name = "Alpha"
		alpha.Parent = newMob
		
		for i, object in ipairs(newMob:GetDescendants()) do
			if object:IsA("BasePart") then
				PhysicsService:SetPartCollisionGroup(object, "Mob")
			end
		end
		
		
		game.ReplicatedStorage.Events.ReplicateMob:FireAllClients(newMob, map)
		
		coroutine.wrap(mob.Move)(newMob, map)
		end
	else
		warn("no mob ", name)
	end
end

return mob
