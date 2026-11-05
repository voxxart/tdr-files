local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VFXFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("VFX")
local HighEvent = VFXFolder:WaitForChild("High")
local LowEvent = VFXFolder:WaitForChild("Low")

local Store = DataStoreService:GetDataStore("VFXSetting")

local DEFAULT_HIGH = true

local function saveSetting(userId, enabled)
	local success

	for i = 1, 3 do
		success = pcall(function()
			Store:SetAsync("VFX_MODE_" .. userId, enabled)
		end)

		if success then
			return true
		end

		task.wait(2)
	end

	warn("Failed to save VFX for", userId)
	return false
end

local function loadSetting(userId)
	local success, result

	for i = 1, 3 do
		success, result = pcall(function()
			return Store:GetAsync("VFX_MODE_" .. userId)
		end)

		if success then
			break
		end

		task.wait(2)
	end

	if success and typeof(result) == "boolean" then
		return result
	end

	return DEFAULT_HIGH
end

Players.PlayerAdded:Connect(function(player)

	local enabled = loadSetting(player.UserId)

	player:SetAttribute("VFXEnabled", enabled)

	-- Wait until PlayerGui exists so the LocalScript is listening.
	player:WaitForChild("PlayerGui")

	task.wait(1)

	if enabled then
		HighEvent:FireClient(player, true)
	else
		LowEvent:FireClient(player, true)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local enabled = player:GetAttribute("VFXEnabled")

	if typeof(enabled) == "boolean" then
		saveSetting(player.UserId, enabled)
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local enabled = player:GetAttribute("VFXEnabled")

		if typeof(enabled) == "boolean" then
			saveSetting(player.UserId, enabled)
		end
	end
end)

HighEvent.OnServerEvent:Connect(function(player)
	player:SetAttribute("VFXEnabled", true)

	HighEvent:FireClient(player, true)
end)

LowEvent.OnServerEvent:Connect(function(player)
	player:SetAttribute("VFXEnabled", false)

	LowEvent:FireClient(player, true)
end)