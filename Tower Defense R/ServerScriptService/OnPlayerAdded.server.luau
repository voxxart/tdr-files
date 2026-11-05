local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

for i, v in pairs(game.ReplicatedStorage.Towers:GetDescendants()) do
	if v:IsA("Model") then
		v:SetAttribute("Attacking", false)
	end
end

Players.PlayerAdded:Connect(function(player)

	-- Give other players a chance to load in
	task.wait(3)

	local gold = Instance.new("NumberValue")
	gold.Name = "Cash"

	if #Players:GetPlayers() == 1 then
		gold.Value = 800
	else
		gold.Value = 650
	end

	gold.Parent = player

	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = player

	local placedTowers = Instance.new("IntValue")
	placedTowers.Name = "PlacedTowers"
	placedTowers.Value = 0
	placedTowers.Parent = player

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Value = gold.Value
	cash.Parent = leaderstats

	gold.Changed:Connect(function()
		cash.Value = gold.Value
	end)

	workspace.Info.PlrValue.Value += 1

	if workspace.Info.PlrValue.Value >= 3 then
		workspace.Info.VoteSkipPlrValue.Value += 1
	end

	-- PLAYER COLLISION
	local function setupCharacter(character)

		local function setupPart(object)
			if object:IsA("BasePart") then
				object.CollisionGroup = "Player"
				object.CanQuery = false
			end
		end

		-- Existing body parts
		for _, object in ipairs(character:GetDescendants()) do
			setupPart(object)
		end

		-- Anything added afterward
		character.DescendantAdded:Connect(setupPart)

		local humanoid = character:WaitForChild("Humanoid")
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	player.CharacterAdded:Connect(setupCharacter)

	-- In case the character already exists
	if player.Character then
		setupCharacter(player.Character)
	end
end)

Players.PlayerRemoving:Connect(function()
	workspace.Info.PlrValue.Value -= 1
end)