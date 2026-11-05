local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

ReplicatedStorage.Events.OwnerRingAlter.OnClientEvent:Connect(function(newTower)
	local Box = newTower:FindFirstChild("Box")
	if Box and Box:FindFirstChild("Box") then
		Box.Box.BrickColor = BrickColor.new("Persimmon")
	else
		warn("No Box Found in tower:", newTower.Name)
	end
end)