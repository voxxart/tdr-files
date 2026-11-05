for _, mob in ipairs(game.ReplicatedStorage.Mobs:GetChildren()) do
	if not mob:FindFirstChild("Hitbox") then
		local hrp = mob:FindFirstChild("HumanoidRootPart")
		if hrp then
			local hitBox = hrp:Clone()
			for _, child in ipairs(hitBox:GetChildren()) do
				child:Destroy()
			end
			hitBox.Name = "Hitbox"
			hitBox.CanCollide = false
			hitBox.Anchored = true
			hitBox.CanTouch = true
			hitBox.Parent = mob
		else
			warn("Mob " .. mob.Name .. " is missing a HumanoidRootPart.")
		end
	end
end
