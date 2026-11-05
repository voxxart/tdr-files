local RepStorage = game:GetService("ReplicatedStorage")
local Events = RepStorage:WaitForChild("Events")
local MEUCLient = Events.MEU.Client
local MEUServer = Events.MEU.Server

MEUCLient.OnClientEvent:Connect(function(enemy)
	local Hum = enemy.HumanoidRootPart
	local Effect = enemy.Torso:WaitForChild("Effect")
	local Effect2 = enemy.Torso:WaitForChild("Effect2")
	Hum.Summon:Play()
	if Effect and Effect2 then 
		Effect.Enabled = true
		Effect2.Enabled = true
	end
	MEUServer:FireServer(enemy)
	task.wait(1.5 / workspace.Info.GameSpeed.Value)
	if Effect and Effect2 then 
		Effect.Enabled = false
		Effect2.Enabled = false
	end
end)