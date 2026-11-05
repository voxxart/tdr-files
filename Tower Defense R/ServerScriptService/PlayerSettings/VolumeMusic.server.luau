local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local musicStore = DataStoreService:GetDataStore("MusicVolumePreferences")
local remote = ReplicatedStorage.Events:WaitForChild("VolumeChangeMusic")

-- Save on leave
Players.PlayerRemoving:Connect(function(player)
	local musicVolume = player:GetAttribute("MusicVolumePercent") or 100
	pcall(function()
		musicStore:SetAsync(player.UserId, musicVolume)
	end)
end)

-- Load on join
Players.PlayerAdded:Connect(function(player)
	local success, saved = pcall(function()
		return musicStore:GetAsync(player.UserId)
	end)
	local musicVolume = (success and typeof(saved) == "number") and saved or 100
	player:SetAttribute("MusicVolumePercent", musicVolume)

	remote:FireClient(player, musicVolume)
end)

-- Update on change
remote.OnServerEvent:Connect(function(player, volumePercent)
	if typeof(volumePercent) == "number" and volumePercent >= 0 and volumePercent <= 100 then
		player:SetAttribute("MusicVolumePercent", volumePercent)
	end
end)
