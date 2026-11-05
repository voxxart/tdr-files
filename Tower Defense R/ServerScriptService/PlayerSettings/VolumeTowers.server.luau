local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local volumeStore = DataStoreService:GetDataStore("VolumePreferences")
local remote = ReplicatedStorage.Events:WaitForChild("VolumeChange")

-- Save volume on leave
Players.PlayerRemoving:Connect(function(player)
	local volume = player:GetAttribute("VolumePercent") or 100
	pcall(function()
		volumeStore:SetAsync(player.UserId, volume)
	end)
end)

-- Load volume on join
Players.PlayerAdded:Connect(function(player)
	local success, saved = pcall(function()
		return volumeStore:GetAsync(player.UserId)
	end)
	local volume = (success and typeof(saved) == "number") and saved or 100
	player:SetAttribute("VolumePercent", volume)

	-- Send saved volume to client
	remote:FireClient(player, volume)
end)

-- Update attribute from client
remote.OnServerEvent:Connect(function(player, volumePercent)
	if typeof(volumePercent) == "number" and volumePercent >= 0 and volumePercent <= 100 then
		player:SetAttribute("VolumePercent", volumePercent)
	end
end)
