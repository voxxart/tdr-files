local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local SafeTeleport = require(ServerScriptService.SafeTeleport)

local events = ReplicatedStorage:WaitForChild("Events")
local exitEvent = events:WaitForChild("ExitGame")

local function Teleport(player)
	local placeId = 87329919913993
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		["Cash"] = player.Cash.Value
	})
	SafeTeleport(placeId, {player}, options)
	print("Finished teleport")
end

exitEvent.OnServerEvent:Connect(Teleport)