for _, unit in ipairs(game.ReplicatedStorage.Units:GetChildren()) do
	if not unit:FindFirstChild("Hitbox") then
		local hrp = unit:FindFirstChild("HumanoidRootPart")
		if hrp then
			local hitBox = hrp:Clone()
			for _, child in ipairs(hitBox:GetChildren()) do
				child:Destroy()
			end
			hitBox.Name = "Hitbox"
			hitBox.CanCollide = false
			hitBox.Anchored = true
			hitBox.CanTouch = true
			hitBox.Parent = unit
		else
			warn("Unit " .. unit.Name .. " is missing a HumanoidRootPart.")
		end
	end
end
