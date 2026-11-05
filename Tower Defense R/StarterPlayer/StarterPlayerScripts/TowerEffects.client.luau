local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage.Events.TowerEffects.FarmOrbs.OnClientEvent:Connect(function(orbName, duration, amount, position, towerOwner)
	local Orbs = require(ReplicatedStorage.Orbs)
	Orbs.Play(orbName, duration, amount, position, towerOwner)
end)