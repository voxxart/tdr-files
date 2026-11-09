local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local database = DataStoreService:GetDataStore("OfficialTDRGameData")
local events = ReplicatedStorage:WaitForChild("Events")

local exitEvent = events:WaitForChild("ExitGame")
local GetMedalStatus = ReplicatedStorage.Functions:WaitForChild("GetMedalStatus")

local data = {}
local disconnectSaves = 0
local EventWallet = require(game.ServerScriptService.EventCurrencySystem.Wallet)
EventWallet.Bind(function(player) return data[player.UserId] end)

------------------------------------------------
-- LOAD DATA
------------------------------------------------
local function LoadData(player)
	local success, playerData
	local attempt = 1

	repeat
		success, playerData = pcall(function()
			return database:GetAsync(player.UserId)
		end)

		attempt += 1
		if not success then
			task.wait(1)
		end

	until success or attempt >= 6

	if not player.Parent then return end
	if success then
		if not playerData then
			playerData = {
				Coins = 150,
				Gems = 0,
				Shards = 0,
				Level = 0,
				Wins = 0,
				PVPWins = 0,
				Exp = 0,

				EasyWins = 0,
				NormalWins = 0,
				HardWins = 0,
				InsaneWins = 0,
				Kills = 0,

				EventCurrency = 0,
				Dialogue = 1,
				UiScale = 1,
				
				Pumpkins = 0,
				HalloweenBPLevel1 = 0,
				RequiredPumpkins = 0,

				BattlePassLevel = 0,
				RequiredBattlePassExp = 0,
				RequiredExp = 0,

				SelectedTowers = {"Trooper"},
				OwnedTowers = {"Trooper"},

				SelectedMoonEventTowers = {
					"Golden Juggernaut",
					"Golden Shotgunner",
					"Marksman",
					"General",
					"DJ"
				},

				OwnedSkins = {},
				SelectedSkins = {},
				SkinsHave = {},

				UsedCodes = {},
				CollectedBattlePassRewards = {},

				OwnedQuests = {},
				ClaimableQuests = {},

				OwnedTagFlairs = {},
				EquippedFlairs = {},
				Playtime = 0,

				-- MAP DATA
				CompletedMaps = {},
				HighestWaves = {},
			}
		end

		-- Make sure older player data gets these tables
		-- without deleting or overwriting their existing data.
		if not playerData.CompletedMaps then
			playerData.CompletedMaps = {}
		end

		if not playerData.HighestWaves then
			playerData.HighestWaves = {}
		end

		data[player.UserId] = playerData
		EventWallet.Publish(player)
	else
		player:Kick("Data failed to load")
	end
end

Players.PlayerAdded:Connect(LoadData)
Players.PlayerAdded:Connect(function(player)
	-- start ticking once their data is loaded
	task.spawn(function()
		-- wait for data to be ready however you normally do it
		while player.Parent do
			task.wait(60) -- every 60 seconds = 1 minute
			if not player.Parent then break end

			local playerData = data[player.UserId]
			if playerData then
				playerData.Playtime += 1 -- 1 = 1 minute
			end
		end
	end)
end)

------------------------------------------------
-- ANTI DOUBLE REWARD LOCK
------------------------------------------------
local rewardLock = {}

------------------------------------------------
-- MAIN SAVE + REWARD FUNCTION
------------------------------------------------
local function saveData(player)
	local currencyVersion = EventWallet.Version(player)
	local playerData = data[player.UserId]
	if not playerData then return end

	------------------------------------------------
	-- HARD LOCK (prevents double reward bug)
	------------------------------------------------
	if rewardLock[player.UserId] then return end
	rewardLock[player.UserId] = true

	task.delay(5, function()
		rewardLock[player.UserId] = nil
	end)

	------------------------------------------------
	-- GAME STATE
	------------------------------------------------
	local info = workspace.Info
	local wave = info.Wave.Value
	local difficulty = info.Gamemode.Value
	local isTriumph = info.Message.Value == "VICTORY"
	local modeBonus = workspace.Info.DifficultyMultiplier
	
	------------------------------------------------
	-- MAP PROGRESS
	------------------------------------------------

	local mapName = workspace.Map:FindFirstChildOfClass("Folder").Name

	-- Make sure these tables exist
	playerData.CompletedMaps = playerData.CompletedMaps or {}
	playerData.HighestWaves = playerData.HighestWaves or {}
	
	------------------------------------------------
	-- FIRST TIME MEDAL
	------------------------------------------------

	local isFirstTimeMedal = false

	if isTriumph then

		local mapData =
			playerData.CompletedMaps[mapName]

		if not mapData then
			mapData = {}
			playerData.CompletedMaps[mapName] = mapData
		end

		-- Only Easy / Normal / Hard currently have medals
		if difficulty == "Easy"
			or difficulty == "Normal"
			or difficulty == "Hard"
		then

			if mapData[difficulty] ~= true then
				isFirstTimeMedal = true
			end

		end

	end

	------------------------------------------------
	-- HIGHEST WAVE
	------------------------------------------------
	-- This is NOT mode-specific.
	-- It only cares about the highest wave reached
	-- on this map across every mode.

	local currentHighestWave = playerData.HighestWaves[mapName] or 0

	if wave > currentHighestWave then
		playerData.HighestWaves[mapName] = wave
	end

	------------------------------------------------
	-- COMPLETED MAP
	------------------------------------------------
	-- Only mark the specific map + mode as completed
	-- when the player actually triumphs.

	------------------------------------------------
	-- COMPLETED MAP
	------------------------------------------------
	-- Only mark after determining whether this
	-- was a first-time medal.

	if isTriumph then

		if not playerData.CompletedMaps[mapName] then
			playerData.CompletedMaps[mapName] = {}
		end

		playerData.CompletedMaps[mapName][difficulty] = true

	end

	------------------------------------------------
	-- MULTIPLIER SYSTEM
	------------------------------------------------
	local Multiplier = 1

	local modifierBonus = {
		["Double HP"] = 0.06,
		["Last Life"] = 0.04,
		["Reduced Placement"] = 0.02,
		["Death Wish"] = 1,
		["More Starting Cash"] = -0.3,
		["Generous Farms"] = -0.65,
		["Extra Lives"] = -0.4,
	}

	local modsFolder = workspace.Info:WaitForChild("Modifiers")

	for modName, bonus in pairs(modifierBonus) do
		local flag = modsFolder:FindFirstChild(modName)
		if flag and flag.Value == true then
			Multiplier += bonus
		end
	end

	------------------------------------------------
	-- REWARD STORAGE
	------------------------------------------------
	local Coins, Exp, Gems = 0, 0, 0
	local Wins, ModeWin = 0, 0
	local BattlePass = 0

	------------------------------------------------
	-- EASY
	------------------------------------------------
	if difficulty == "Easy" then

		if wave <= 5 then
			Coins = math.floor(3 * wave)
			Exp = math.round(0.75 * wave)
			BattlePass = 0
		elseif wave <= 10 then
			Coins = math.floor(5 * wave)
			Exp = math.round(1.25 * wave)
			BattlePass = 25
		elseif wave <= 15 then
			Coins = math.floor(7 * wave)
			Exp = math.round(2 * wave)
			BattlePass = 55
		elseif wave <= 18 then
			Coins = math.floor(9 * wave)
			Exp = math.round(2.75 * wave)
			BattlePass = 80
		elseif wave <= 20 then
			Coins = math.floor(11 * wave)
			Exp = math.round(3.5 * wave)
			BattlePass = 95
		end


		if isTriumph then
			Coins = math.round(210 * modeBonus.Value * Multiplier)
			Exp = math.round(75 * Multiplier * modeBonus.Value)
			Gems = math.round(20 * modeBonus.Value * Multiplier)
			BattlePass = 110
			Wins = 1
			ModeWin = 1
		end



		------------------------------------------------
		-- NORMAL
		------------------------------------------------
	elseif difficulty == "Normal" then

		if wave <= 7 then
			Coins = math.floor(4 * wave)
			Exp = math.round(0.75 * wave)

		elseif wave <= 13 then
			Coins = math.floor(7 * wave)
			Exp = math.round(1.25 * wave)
			BattlePass = 60
		elseif wave <= 19 then
			Coins = math.floor(10 * wave)
			Exp = math.round(1.75 * wave)
			BattlePass = 100
		elseif wave <= 23 then
			Coins = math.floor(13 * wave)
			Exp = math.round(2.25 * wave)
			BattlePass = 125
		elseif wave <= 26 then
			Coins = math.floor(15 * wave)
			Exp = math.round(2.75 * wave)
			BattlePass = 150
		end


		if isTriumph then
			Coins = math.round(500 * modeBonus.Value * Multiplier)
			Exp = math.round(175 * Multiplier * modeBonus.Value)
			Gems = math.round(45 * modeBonus.Value * Multiplier)
			BattlePass = 175
			Wins = 1
			ModeWin = 1
		end



		------------------------------------------------
		-- HARD
		------------------------------------------------
	elseif difficulty == "Hard" then

		if wave <= 8 then
			Coins = math.floor(4 * wave)
			Exp = math.round(1 * wave)
			BattlePass = 15
		elseif wave <= 15 then
			Coins = math.floor(7 * wave)
			Exp = math.round(1.75 * wave)
			BattlePass = 60
		elseif wave <= 22 then
			Coins = math.floor(11 * wave)
			Exp = math.round(2.5 * wave)
			BattlePass = 110
		elseif wave <= 28 then
			Coins = math.floor(15 * wave)
			Exp = math.round(3.25 * wave)
			BattlePass = 140
		elseif wave <= 32 then
			Coins = math.floor(20 * wave)
			Exp = math.round(4 * wave)
			BattlePass = 170
		end


		if isTriumph then
			Coins = math.round(1050 * modeBonus.Value * Multiplier)
			Exp = math.round(295 * Multiplier * modeBonus.Value)
			Gems = math.round(80 * modeBonus.Value * Multiplier)
			BattlePass = 200
			Wins = 1
			ModeWin = 1
		end

		------------------------------------------------
		-- INSANE
		------------------------------------------------
	elseif difficulty == "Insane" then
		if wave <= 10 then
			Coins = math.floor(8 * wave * Multiplier)
			Exp = math.floor(1 * wave * Multiplier)
		elseif wave <= 26 then
			Coins = math.floor(10 * wave * Multiplier)
			Exp = math.floor(3 * wave * Multiplier)
		end

		if isTriumph then
			Coins = math.round(1450 * modeBonus.Value * Multiplier)
			Exp = math.round(7.25 * wave * 1.52 * Multiplier * modeBonus.Value)
			Gems = math.round(120 * modeBonus.Value * Multiplier)
			Wins = 1
			ModeWin = 1
		end

		------------------------------------------------
		-- CHAOS
		------------------------------------------------
	elseif difficulty == "Chaos" then
		if wave <= 10 then
			Coins = math.floor(8 * wave * Multiplier)
			Exp = math.floor(1 * wave * Multiplier)
		elseif wave <= 26 then
			Coins = math.floor(10 * wave * Multiplier)
			Exp = math.floor(3 * wave * Multiplier)
		end

		if isTriumph then
			Coins = math.round(2150 * modeBonus.Value * Multiplier)
			Exp = math.round(8.25 * wave * 1.52 * Multiplier * modeBonus.Value)
			Gems = math.round(175 * modeBonus.Value * Multiplier)
			Wins = 1
			ModeWin = 1
		end

		------------------------------------------------
		-- HARDCORE
		------------------------------------------------
	elseif difficulty == "Hardcore" then
		if wave <= 10 then
			Exp = math.floor(1 * wave * Multiplier)
		elseif wave <= 26 then
			Exp = math.floor(3 * wave * Multiplier)
		end

		if isTriumph then
			Exp = math.round(12.25 * wave * 4.52 * Multiplier * modeBonus.Value)
			Gems = math.round(3450 * modeBonus.Value * Multiplier)
			Wins = 1
			ModeWin = 1
		end
	end

	------------------------------------------------
	-- XP GAMEPASS BONUS
	------------------------------------------------
	local function ownsPass(player)
		local success, hasPass = pcall(function()
			return game:GetService("MarketplaceService"):UserOwnsGamePassAsync(player.UserId, 1169435124)
		end)
		return success and hasPass
	end

	if ownsPass(player) then
		Exp = math.round(Exp * 1.25)
	end
	
	------------------------------------------------
	-- FIRST TIME MEDAL BONUS
	------------------------------------------------

	if isFirstTimeMedal then

		Coins = math.round(Coins * 1.40)
		Exp = math.round(Exp * 1.40)
		Gems = math.round(Gems * 1.40)

	end

	------------------------------------------------
	-- APPLY DATA
	------------------------------------------------
	playerData.Coins += Coins
	playerData.Exp += Exp
	playerData.Gems += Gems
	if Multiplier >= 1 then
		playerData.Wins += Wins
		if difficulty == "Easy" then
			playerData.EasyWins += ModeWin
		elseif difficulty == "Normal" then
			playerData.NormalWins += ModeWin
		elseif difficulty == "Hard" then
			playerData.HardWins += ModeWin
		elseif difficulty == "Insane" then
			playerData.InsaneWins += ModeWin
		end

	else
		playerData.Wins += 0
		print(playerData.Wins, " Wins were not Added to Player Because Modifier is Less than 1")
	end
	playerData.Pumpkins += BattlePass
	
	local plyrKills = player:FindFirstChild("Kills")
	
	playerData.Kills += plyrKills.Value

	
	------------------------------------------------
	-- SAVE
	------------------------------------------------
	local success, err
	local attempt = 1

	repeat
		success, err = pcall(function()
			database:UpdateAsync(player.UserId, function()
				return playerData
			end)
		end)

		attempt += 1
		if not success then task.wait(1) end

	until success or attempt >= 3

	if not success then
		player:Kick("Data save failed")
	else
		EventWallet.MarkSaved(player, currencyVersion)
	end
end

GetMedalStatus.OnServerInvoke = function(player, mapName, difficulty)

	local playerData = data[player.UserId]

	if not playerData then
		return false
	end

	playerData.CompletedMaps =
		playerData.CompletedMaps or {}

	local mapData =
		playerData.CompletedMaps[mapName]

	if not mapData then
		return true
	end

	return mapData[difficulty] ~= true
end

------------------------------------------------
-- EXIT EVENT
------------------------------------------------
exitEvent.OnServerEvent:Connect(saveData)

------------------------------------------------
-- SERVER SHUTDOWN SAVE
------------------------------------------------
local function saveLoadedCurrency(player)
	local playerData = data[player.UserId]
	if not playerData or not EventWallet.Dirty(player) then return true end
	local version = EventWallet.Version(player)
	local success, err
	for attempt=1,3 do
		success, err = pcall(function()
			database:UpdateAsync(player.UserId, function() return playerData end)
		end)
		if success then EventWallet.MarkSaved(player, version); return true end
		task.wait(1)
	end
	warn("Event currency save failed:", player.UserId, err)
	return false
end

game:BindToClose(function()
	local pendingSaves = 0
	if not RunService:IsStudio() then
		for _, player in pairs(Players:GetPlayers()) do
			pendingSaves += 1
			EventWallet.Close(player)
			task.spawn(function()
				local ok, err = pcall(saveData, player)
				if not ok then warn("Shutdown reward save failed:", player.UserId, err) end
				saveLoadedCurrency(player)
				pendingSaves -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while (pendingSaves > 0 or disconnectSaves > 0) and os.clock() < deadline do task.wait(0.1) end
end)

ReplicatedStorage.Functions.GetData.OnServerInvoke = function(player) 
	return data[player.UserId]
end

------------------------------------------------
-- DATA ACCESS
------------------------------------------------
_G.DataStore = {
	GetPlayerData = function(player)
		return data[player.UserId]
	end,
	SavePlayerData = saveData
}

-- Currency pickups do not make datastore calls. Persist dirty loaded balances on
-- disconnect without running the match-reward calculation a second time.
Players.PlayerRemoving:Connect(function(player)
	EventWallet.Close(player)
	if data[player.UserId] and EventWallet.Dirty(player) then
		disconnectSaves += 1
		saveLoadedCurrency(player)
		disconnectSaves -= 1
	end
	EventWallet.Forget(player)
	data[player.UserId] = nil
	rewardLock[player.UserId] = nil
end)
