local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

--// CONFIG
local DEV_USER_IDS = {
	3106176024, -- Vox
}

local QA_USER_IDS = {
	911591943, -- icey
	1936502819, -- fennex
	3645963867, -- Community Manager
}

local VIP_GAMEPASS_ID = 1169435124

--// CHECK FUNCTIONS
local function isDev(player)
	return table.find(DEV_USER_IDS, player.UserId) ~= nil
end

local function isQA(player)
	return table.find(QA_USER_IDS, player.UserId) ~= nil
end

local function isVIP(player)
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
	end)

	return success and owns
end

--// CHAT HOOK
TextChatService.OnIncomingMessage = function(message)
	if not message.TextSource then
		return
	end

	local player = Players:GetPlayerByUserId(message.TextSource.UserId)
	if not player then
		return
	end

	local props = Instance.new("TextChatMessageProperties")

	local tag = ""
	local tagColor = ""

	-- PRIORITY ORDER (important!)
	if isDev(player) then
		tag = "[LEAD DEV]"
		tagColor = "rgb(236, 96, 255)"

	elseif isQA(player) then
		tag = "[QA]"
		tagColor = "rgb(255, 89, 89)"

	elseif isVIP(player) then
		tag = "[VIP]"
		tagColor = "rgb(255, 215, 0)"
	end

	if tag ~= "" then
		props.PrefixText =
			'<font color="' .. tagColor .. '">' .. tag .. '</font> ' ..
			'<font color="rgb(200, 200, 200)">' .. player.DisplayName .. '</font>' .. ":"
	end

	return props
end