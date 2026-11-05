local mobs = workspace.Mobs

mobs.ChildAdded:Connect(function(newMob)
	-- Check if the new child or any of its descendants has IsABoss
	local function checkForBoss(descendant)
		if descendant:IsA("BoolValue") and descendant.Name == "IsBoss" then
			game.ReplicatedStorage.Events.BossEvent:FireAllClients(newMob)
		end
	end

	-- Check if the newMob already has the IsABoss BoolValue
	for _, descendant in ipairs(newMob:GetDescendants()) do
		checkForBoss(descendant)
	end

	-- Connect the DescendantAdded event to check any new descendants
	newMob.DescendantAdded:Connect(checkForBoss)
end)
