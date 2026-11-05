local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local UiScaleFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("UiScale")

local XLRemote = UiScaleFolder:WaitForChild("ExtraLarge")
local LRemote = UiScaleFolder:WaitForChild("Large")
local DefaultRemote = UiScaleFolder:WaitForChild("Default")
local SmallRemote = UiScaleFolder:WaitForChild("Small")


local Store = DataStoreService:GetDataStore("UiScaleSetting")

local DefaultScale = "Default"

local ValidScales = {
	ExtraLarge = true,
	Large = true,
	Default = true,
	Small = true,
}


local function SaveScale(player)
	local value = player:GetAttribute("UiScale")

	if not ValidScales[value] then
		return
	end

	pcall(function()
		Store:SetAsync(
			"UI_SCALE_" .. player.UserId,
			value
		)
	end)
end


local function LoadScale(player)
	local success, result = pcall(function()
		return Store:GetAsync(
			"UI_SCALE_" .. player.UserId
		)
	end)

	if success and ValidScales[result] then
		return result
	end

	return DefaultScale
end


local function FireScaleEvent(player, scale)
	if scale == "ExtraLarge" then
		XLRemote:FireClient(player)

	elseif scale == "Large" then
		LRemote:FireClient(player)

	elseif scale == "Default" then
		DefaultRemote:FireClient(player)

	elseif scale == "Small" then
		SmallRemote:FireClient(player)
	end
end


-- Player joins
Players.PlayerAdded:Connect(function(player)

	local savedScale = LoadScale(player)

	player:SetAttribute(
		"UiScale",
		savedScale
	)

	FireScaleEvent(player, savedScale)

end)


-- Save when leaving
Players.PlayerRemoving:Connect(function(player)
	SaveScale(player)
end)


-- Handle changes
local function SetupEvent(remote, scaleName)

	remote.OnServerEvent:Connect(function(player)

		if not ValidScales[scaleName] then
			return
		end

		player:SetAttribute(
			"UiScale",
			scaleName
		)

		SaveScale(player)

		-- Sync back to client
		FireScaleEvent(player, scaleName)
	end)

end


SetupEvent(XLRemote, "ExtraLarge")
SetupEvent(LRemote, "Large")
SetupEvent(DefaultRemote, "Default")
SetupEvent(SmallRemote, "Small")