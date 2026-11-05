local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Dialogue")
local OnEvent = DialogueFolder:WaitForChild("On")
local OffEvent = DialogueFolder:WaitForChild("Off")

local Store = DataStoreService:GetDataStore("DialogueSettings")

local DEFAULT_ENABLED = true

local function Save(userId, enabled)
	for i = 1, 6 do
		local success = pcall(function()
			Store:SetAsync("Dialogue_MODE_" .. userId, enabled)
		end)

		if success then
			return
		end

		task.wait(2)
	end

	warn("Failed to save Dialogue setting for", userId)
end

local function Load(userId)
	for i = 1, 6 do
		local success, result = pcall(function()
			return Store:GetAsync("Dialogue_MODE_" .. userId)
		end)

		if success then
			if typeof(result) == "boolean" then
				return result
			else
				return DEFAULT_ENABLED
			end
		end

		task.wait(2)
	end

	return DEFAULT_ENABLED
end

Players.PlayerAdded:Connect(function(player)

	local enabled = Load(player.UserId)

	player:SetAttribute("DialogueEnabled", enabled)

	player:WaitForChild("PlayerGui")
	task.wait(1)

	if enabled then
		OnEvent:FireClient(player, true)
	else
		OffEvent:FireClient(player, true)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local enabled = player:GetAttribute("DialogueEnabled")

	if typeof(enabled) == "boolean" then
		Save(player.UserId, enabled)
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local enabled = player:GetAttribute("DialogueEnabled")

		if typeof(enabled) == "boolean" then
			Save(player.UserId, enabled)
		end
	end
end)

OnEvent.OnServerEvent:Connect(function(player)
	player:SetAttribute("DialogueEnabled", true)
	OnEvent:FireClient(player, true)
end)

OffEvent.OnServerEvent:Connect(function(player)
	player:SetAttribute("DialogueEnabled", false)
	OffEvent:FireClient(player, true)
end)