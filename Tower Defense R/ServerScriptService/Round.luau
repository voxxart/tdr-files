local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local events = ReplicatedStorage:WaitForChild("Events")
local mob = require(script.Parent.Mob)
local unit = require(script.Parent.Unit)
local info = workspace.Info

local GM = 1

local voteSkip = ReplicatedStorage.Functions:WaitForChild("VoteSkip")
local setTimeText = ReplicatedStorage.Events:WaitForChild("SetTextTime")

local SpeedupFunction = ReplicatedStorage.Functions:WaitForChild("SpeedUp1")
local SpeedupFunction2 = ReplicatedStorage.Functions:WaitForChild("SpeedUp2")
local CooldownSpeedUP = ReplicatedStorage.Events:WaitForChild("SpeedupCooldown")

local voteSkipValue = workspace.Info.VoteSkipValue
local m = workspace.Info.Min
local s = workspace.Info.Sec
local st = workspace.Info.SkipTime

local round = {}
local votes = {}
local ModifierVotes = {}


function round.StartGame()
	if info.GameRunning.Value == true then return end
	local waves = nil
	local map = round.LoadMap()
	local mode
	if map then
		mode = round.LoadMode()
	end

	if mode == "Easy" then
		waves = 20
	elseif mode == "Normal" then
		waves = 26
	elseif mode == "Hard" then
		waves = 32
	end
	info.GameRunning.Value = true


	for i = 12, 0, -1 do
		if i < 10 then
			info.Timer.Value = "00:0" .. i
		else
			info.Timer.Value = "00:" .. i
		end
		wait(1 / workspace.Info.GameSpeed.Value)
		info.Message.Value = ""
		game.StarterGui.GameGui.Sounds.Countdown:Play() mob.ArrowSpawn("Arrow", 4, 0.05, 1, 1, map)
	end

	for wave=1, waves do
		info.Wave.Value = wave
		info.Message.Value = ""

		if mode == "Easy" then
			round.GetEasy(wave, map)
		end
		if mode == "Normal" then
			round.GetNormal(wave, map)
		end
		if mode == "Hard" then
			round.GetHard(wave, map)
		end

		repeat
			task.wait(1 / workspace.Info.GameSpeed.Value)
		until #workspace.Mobs:GetChildren() == 0 or not info.GameRunning.Value or (m.Value <= 0 and s.Value <= 0)

		if info.GameRunning.Value and wave == waves then
			info.Message.Value = "VICTORY"

			local BadgeService = game:GetService("BadgeService")
			local Players = game:GetService("Players")

			local EasybadgeId = 1433436900060994
			local NormalbadgeId = 4109630051863460
			local HardbadgeId = 4414807599567797
			local InsanebadgeId = 574027632887462

			-- Map completion badges (Normal+)
			local MapBadges = {
				["Coast Line"] = 3021881430547702,
				["Deadend Valley"] = 2175231252609243,
				["Oasis"]  = 1397671917538574
			}

			local function AwardBadgeToPlayers(badgeId, message)
				for _, plr in ipairs(Players:GetPlayers()) do
					local success, hasBadge = pcall(function()
						return BadgeService:UserHasBadgeAsync(plr.UserId, badgeId)
					end)

					if success and not hasBadge then
						pcall(function()
							print(message .. " - " .. plr.Name)
							BadgeService:AwardBadge(plr.UserId, badgeId)
						end)
					end
				end
			end

			-- Gamemode badges
			if workspace.Info.Gamemode.Value == "Easy" then
				AwardBadgeToPlayers(EasybadgeId, "Awarding Badge For Beating Easy Mode!")

			elseif workspace.Info.Gamemode.Value == "Normal" then
				AwardBadgeToPlayers(NormalbadgeId, "Awarding Badge For Beating Normal Mode!")

			elseif workspace.Info.Gamemode.Value == "Hard" then
				AwardBadgeToPlayers(HardbadgeId, "Awarding Badge For Beating Hard Mode!")

			elseif workspace.Info.Gamemode.Value == "Insane" then
				AwardBadgeToPlayers(InsanebadgeId, "Awarding Badge For Beating Insane Mode!")
			end


			-- Map badges (Normal or harder only)
			local mapFolder = workspace.Map:FindFirstChildOfClass("Folder")
			local mapName = mapFolder and mapFolder.Name

			if mapName 
				and MapBadges[mapName]
				and (
					workspace.Info.Gamemode.Value == "Normal"
						or workspace.Info.Gamemode.Value == "Hard"
						or workspace.Info.Gamemode.Value == "Insane"
				)
			then
				AwardBadgeToPlayers(
					MapBadges[mapName],
					"Awarding Badge For Beating " .. mapName .. " On " .. workspace.Info.Gamemode.Value .. "!"
				)
			end
		elseif info.GameRunning.Value then
			local reward = 0
			local gamemodeValue = workspace.Info.Gamemode.Value
			local modeFolder = ServerStorage.Modes:FindFirstChild(gamemodeValue)

			if modeFolder then
				local deathWish = info.Modifiers["Death Wish"].Value
				local noWaveReward = info.Modifiers.NoWaveReward.Value
				local players = #Players:GetPlayers()

				if not deathWish and not noWaveReward then
					local playerMultiplier = math.max(0.5, 1 - 0.1 * players)

					reward = math.round(
						(modeFolder.WaveReward.Value +
							(wave - 1) * modeFolder.RewardMultiplier.Value)
							* playerMultiplier
					)
				elseif deathWish and not noWaveReward then
					local playerMultiplier = math.max(0.5, 1 - 0.1 * players)

					reward = math.round(
						(modeFolder.WaveReward.Value +
							(wave - 1) * modeFolder.RewardMultiplier.Value)
							* playerMultiplier
					)
					
					reward = math.round(reward / 2)
				end
			end

			for _, player in ipairs(Players:GetPlayers()) do
				local cash = player:FindFirstChild("Cash")

				if cash and cash:IsA("NumberValue") then
					cash.Value += reward
				end
			end
			
			
			events.SkipWaveHide:FireAllClients()
			if reward > 0 then
				info.Message.Value = "Wave Reward: $" .. reward
				task.wait(2 / workspace.Info.GameSpeed.Value)
			else
				info.Message.Value = ""
			end
			

			local instant = workspace.Info:FindFirstChild("ForceNextWaveInstant")
			if instant and instant.Value == true then
				instant.Value = false -- consume it (only skips once)
			else
				for i = 5, 1, -1 do
					if i < 10 then
						info.Timer.Value = "00:0" .. i
					else
						info.Timer.Value = "00:" .. i
					end
					wait(1 / workspace.Info.GameSpeed.Value)
					info.Message.Value = ""
					-- (you should play countdown sound via remote, but leaving your logic as-is)
					game.StarterGui.GameGui.Sounds.Countdown:Play()
					mob.ArrowSpawn("Arrow", 4, 0.05, 1, 1, map)
				end
			end
		else
			break
		end
	end
end

function round.LoadMap()
	local votedMap = round.ToggleVoting()
	local mapFolder = ServerStorage.Maps:FindFirstChild(votedMap)
	if not mapFolder then
		mapFolder = ServerStorage.Maps.Grassland
	end

	local newMap = mapFolder:Clone()
	newMap.Parent = workspace.Map

	-- Enemy multiplier based on map
	if newMap.Name == "Outskirts" then
		workspace.Info.EnemyMultiplier.Value = 1.5
	elseif newMap.Name == "Deadend Valley" then
		workspace.Info.EnemyMultiplier.Value = 1.8
	elseif newMap.Name == "Winter Valley" then
		workspace.Info.EnemyMultiplier.Value = 4
	elseif newMap.Name == "Baseplate" then
		workspace.Info.EnemyMultiplier.Value = 1.5
	else
		workspace.Info.EnemyMultiplier.Value = 1
	end

	if newMap.Difficulty.Value == "Hard" then
		GM = 1.5
	end

	-- Difficulty multiplier based on map StringValue
	if newMap:FindFirstChild("Difficulty") then
		local diff = newMap.Difficulty.Value
		if diff == "Very Easy" then
			workspace.Info.DifficultyMultiplier.Value = 0.75
			workspace.Info.DifficultyMultiplierPercent.Value = -25
		elseif diff == "Easy" then
			workspace.Info.DifficultyMultiplier.Value = 0.9
			workspace.Info.DifficultyMultiplierPercent.Value = -10
		elseif diff == "Normal" then
			workspace.Info.DifficultyMultiplier.Value = 1
			workspace.Info.DifficultyMultiplierPercent.Value = 0
		elseif diff == "Hard" then
			workspace.Info.DifficultyMultiplier.Value = 1.1
			workspace.Info.DifficultyMultiplierPercent.Value = 10
		elseif diff == "Insane" then
			for i, player in ipairs(Players:GetPlayers()) do
				local cash = player:FindFirstChild("Cash")
				if cash and cash:IsA("NumberValue") then
					cash.Value = cash.Value + 100
				else
					warn("Player " .. player.Name .. " does not have a valid Cash property.")
				end
			end
			workspace.Info.DifficultyMultiplier.Value = 1.2
			workspace.Info.DifficultyMultiplierPercent.Value = 20
		elseif diff == "Nightmare" then
			for i, player in ipairs(Players:GetPlayers()) do
				local cash = player:FindFirstChild("Cash")
				if cash and cash:IsA("NumberValue") then
					cash.Value = cash.Value + 350
				else
					warn("Player " .. player.Name .. " does not have a valid Cash property.")
				end
			end
			workspace.Info.DifficultyMultiplier.Value = 1.35
			workspace.Info.DifficultyMultiplierPercent.Value = 35
		end
	end

	-- Clean up voting lobby
	if workspace:FindFirstChild("VotingLobby") then
		workspace.VotingLobby:Destroy()
	end

	-- Set map ambience
	local Ambience = newMap:FindFirstChild("Ambience") and newMap.Ambience:FindFirstChild("Ambience")
	if Ambience then
		Ambience.Parent = workspace.Ambience
	end

	-- Optional: track base health if needed (should probably track each mob separately)
	if newMap.Base:FindFirstChild("EnemyStats") and newMap.Base.EnemyStats:FindFirstChild("Health") then
		newMap.Base.EnemyStats.Health.Changed:Connect(function(health)
			if health <= 0 then
				info.GameRunning.Value = false
				info.Message.Value = "GAME OVER"
			end
		end)
	end

	return newMap
end



function round.LoadMode()
	local votedMode = round.ToggleVotingMode()
	local modeValue = ServerStorage.Modes:FindFirstChild(votedMode)
	if not modeValue then
		modeValue = ServerStorage.Maps.Easy
	end

	return modeValue.Name
end

function round.ToggleVoting()
	local maps = ServerStorage.Maps:GetChildren()
	local modifiers = ServerStorage.Modifiers:GetChildren()

	votes = {}
	for _, map in ipairs(maps) do
		votes[map.Name] = {}
	end

	ModifierVotes = {}
	for _, modifier in ipairs(modifiers) do
		ModifierVotes[modifier.Name] = {}
	end

	-- Both open at once, sharing one timer
	info.Voting.Value = true
	info.ModifierVoting.Value = true

	for i = 20, 1, -1 do
		if i < 10 then
			info.Timer.Value = "00:0" .. i
		else
			info.Timer.Value = "00:" .. i
		end
		task.wait(1 / workspace.Info.GameSpeed.Value)
		info.Message.Value = ""
	end

	-- Tally map winner
	local winVote = nil
	local winScore = 0
	for name, mapVotes in pairs(votes) do
		if #mapVotes > winScore then
			winScore = #mapVotes
			winVote = name
		end
	end
	if not winVote then
		winVote = maps[math.random(#maps)].Name
	end

	local winModifier = "None"
	local winModScore = 0

	for name, modVotes in pairs(ModifierVotes) do
		if #modVotes > winModScore then
			winModScore = #modVotes
			winModifier = name
		end
	end

	-- Apply the chosen modifier
	for _, value in ipairs(info.Modifiers:GetChildren()) do
		if value:IsA("BoolValue") then
			value.Value = false
		end
	end

	if winModifier ~= "None" then
		local chosen = info.Modifiers:FindFirstChild(winModifier)
		if chosen then
			chosen.Value = true
		end
	end

	info.Voting.Value = false
	info.ModifierVoting.Value = false

	return winVote
end

function round.ToggleVotingMode()
	local modes = ServerStorage.Modes:GetChildren()
	votes = {}
	for i, mode in ipairs(modes) do
		votes[mode.Name] = {}
	end

	info.GamemodeVoting.Value = true

	for i = 15, 0, -1 do
		if i < 10 then
			info.Timer.Value = "00:0" .. i
		else
			info.Timer.Value = "00:" .. i
		end
		task.wait(1 / workspace.Info.GameSpeed.Value)
		info.Message.Value = ""
	end

	local winVote = nil
	local winScore = 0
	for name, mode in pairs(votes) do
		if #mode > winScore then
			winScore = #mode
			winVote = name
			info.Gamemode.Value = name
		end
	end

	if not winVote then
		local n = math.random(#modes)
		winVote = modes[n].Name
		info.Gamemode.Value = winVote
	end

	info.GamemodeVoting.Value = false

	return winVote
end

function round.ToggleVotingModifier()
	local modifiers = ServerStorage.Modifiers:GetChildren()

	ModifierVotes = {}
	for _, modifier in ipairs(modifiers) do
		votes[modifier.Name] = {}
	end

	info.ModifierVoting.Value = true

	-- Allow players to vote
	for i = 15, 0, -1 do
		task.wait(1 / workspace.Info.GameSpeed.Value)
	end

	-- Find winning modifier
	local winVote
	local winScore = -1

	for name, playerVotes in pairs(votes) do
		if #playerVotes > winScore then
			winScore = #playerVotes
			winVote = name
		end
	end

	if not winVote then
		winVote = modifiers[math.random(#modifiers)].Name
	end

	-- Disable every modifier first
	for _, value in ipairs(info.Modifiers:GetChildren()) do
		if value:IsA("BoolValue") then
			value.Value = false
		end
	end

	-- Enable chosen modifier
	local chosen = info.Modifiers:FindFirstChild(winVote)
	if chosen then
		chosen.Value = true
	end

	info.ModifierVoting.Value = false

	return winVote
end


function round.ProcessVote(player, vote)

	for name, mapVotes in pairs(votes) do
		local oldVote = table.find(mapVotes, player.UserId)
		if oldVote then
			table.remove(mapVotes, oldVote)
			break
		end
	end
	table.insert(votes[vote], player.UserId)

	events:WaitForChild("UpdateVoteCount"):FireAllClients(votes)
end
events:WaitForChild("VoteForMap").OnServerEvent:Connect(round.ProcessVote)

function round.ProcessModeVote(player, vote)

	for name, mapVotes in pairs(votes) do
		local oldVote = table.find(mapVotes, player.UserId)
		if oldVote then
			table.remove(mapVotes, oldVote)
			break
		end
	end
	table.insert(votes[vote], player.UserId)

	events:WaitForChild("UpdateModeVoteCount"):FireAllClients(votes)
end
events:WaitForChild("VoteForMode").OnServerEvent:Connect(round.ProcessModeVote)

function round.ProcessModifierVote(player, vote)
	for name, modVotes in pairs(ModifierVotes) do
		local oldVote = table.find(modVotes, player.UserId)
		if oldVote then
			table.remove(modVotes, oldVote)
			break
		end
	end
	table.insert(ModifierVotes[vote], player.UserId)

	events:WaitForChild("UpdateModifierVoteCount"):FireAllClients(ModifierVotes)
end
events:WaitForChild("VoteForModifier").OnServerEvent:Connect(round.ProcessModifierVote)

function round.Skip()
	voteSkipValue.Value += 1
	if workspace.Info.PlrValue.Value > 1 then
		if voteSkipValue.Value == (workspace.Info.PlrValue.Value - 1) then
			ReplicatedStorage.Events.SkipButton:FireAllClients(true,true)
			voteSkipValue.Value = 0
			m.Value = 0
			s.Value = 0
		end
	elseif workspace.Info.PlrValue.Value == 1 then
		if voteSkipValue.Value == workspace.Info.PlrValue.Value then
			ReplicatedStorage.Events.SkipButton:FireAllClients(true,true)
			voteSkipValue.Value = 0
			m.Value = 0
			s.Value = 0
		end
	end
end
voteSkip.OnServerInvoke = round.Skip

function round.TimescaleVote()
	info.TimescaleVote.Value += 1
	if workspace.Info.PlrValue.Value > 0 then
		if info.TimescaleVote.Value == (workspace.Info.PlrValue.Value) then
			ReplicatedStorage.Events.TimescaleVoteWin:FireAllClients(true, true)
			info.TimescaleVote.Value = 0
		end
end
ReplicatedStorage.Functions.TimescaleVote.OnServerInvoke = round.TimescaleVote

function round.TimescaleVoteNo()
		info.TimescaleVoteNo.Value += 1
		if workspace.Info.PlrValue.Value > 0 then
			if info.TimescaleVoteNo.Value == (workspace.Info.PlrValue.Value) then
				ReplicatedStorage.Events.TimescaleVoteWin:FireAllClients(false, false)
				info.TimescaleVoteNo.Value = 0
			end
		end
end
end
ReplicatedStorage.Functions.TimescaleVoteNo.OnServerInvoke = round.TimescaleVoteNo

function round.SpeedUp()
	local gameSpeed = workspace:FindFirstChild("Info") and workspace.Info:FindFirstChild("GameSpeed")
	if gameSpeed and gameSpeed.Value == 1.5 then
		gameSpeed.Value = 1
		print("Speeding up game. New value:", gameSpeed.Value)
		CooldownSpeedUP:FireAllClients()
	else
		warn("SpeedUp failed: GameSpeed not found or already 2")
	end
end

function round.SpeedUp2()
	local gameSpeed = workspace:FindFirstChild("Info") and workspace.Info:FindFirstChild("GameSpeed")
	if gameSpeed and gameSpeed.Value == 1 then
		gameSpeed.Value = 1.5
		print("Slowing game down. New value:", gameSpeed.Value)
		CooldownSpeedUP:FireAllClients()
	else
		warn("SpeedUp2 failed: GameSpeed not found or already 1")
	end
end

SpeedupFunction.OnServerInvoke = round.SpeedUp
SpeedupFunction2.OnServerInvoke = round.SpeedUp2


function round.GetEasy(wave, map)
	if wave == 1 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Noob", 7, 0.28, 1, 1, map)
	elseif wave == 2 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Noob", 11, 0.28, 1, 1, map)
	elseif wave == 3 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Noob", 11, 0.28, 1, 1, map)
		mob.Spawn("Energetic Noob", 4, 0.28, 1.5, 1, map)
	elseif wave == 4 then m.Value = 1 ; s.Value = 10 ; st.Value = 055 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Energetic Noob", 12, 0.28, 1.1, 1, map)
		mob.Spawn("Noob", 10, 0.28, 1, 1, map)
	elseif wave == 5 then m.Value = 1 ; s.Value = 10 ; st.Value = 055 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Noob", 14, 0.28, 1, 1, map)
		mob.Spawn("Energetic Noob", 8, 0.28, 2, 1, map)
	elseif wave == 6 then m.Value = 1 ; s.Value = 25 ; st.Value = 0110 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Armored Noob", 3, 0.28, 1, 1, map)
		mob.Spawn("Noob", 9, 0.28, 1, 1, map)
		mob.Spawn("Energetic Noob", 14, 0.28, 1.5, 1, map)
		mob.Spawn("Armored Noob", 11, 0.28, 1.1, 1, map)
	elseif wave == 7 then m.Value = 1 ; s.Value = 25 ; st.Value = 0110 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Armored Noob", 25, 0.28, 1, 1, map)
		mob.Spawn("Noob", 12, 0.28, 1, 1, map)
	elseif wave == 8 then m.Value = 3 ; s.Value = 0 ; st.Value = 0240; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Armored Noob", 11, 0.28, 1, 1, map)
		mob.Spawn("Noob Soldier", 1, 1.25, 1.05, 1, map)
	elseif wave == 9 then m.Value = 1 ; s.Value = 25 ; st.Value = 0110 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Energetic Noob", 10, 0.28, 1, 1.69, map)
		mob.Spawn("Noob", 12, 0.28, 1, 1, map)
		mob.Spawn("Armored Noob", 20, 0.28, 1, 1, map)
	elseif wave == 10 then m.Value = 1 ; s.Value = 25 ; st.Value = 0110 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Aviator Noob", 5, 0.28, 1, 1, map)
		mob.Spawn("Energetic Noob", 8, 0.28, 1, 2, map)
		mob.Spawn("Armored Noob", 13, 0.28, 3.5, 0.8, map)
	elseif wave == 11 then m.Value = 1 ; s.Value = 25 ; st.Value = 0110 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Noob Soldier", 1, 1.25, 2, 0.8, map)
		mob.Spawn("Aviator Noob", 8, 0.28, 2, 0.65, map)
		mob.Spawn("Armored Noob", 11, 0.28, 1.25, 1, map)
		mob.Spawn("Noob Soldier", 1, 1.25, 1, 1, map)
	elseif wave == 12 then m.Value = 1 ; s.Value = 25 ; st.Value = 0110 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Aviator Noob", 1, 0.28, 10, 0.65, map)
		mob.Spawn("Noob Soldier", 3, 0.5, 1, 1, map)
		mob.Spawn("Shadow Noob", 25, 0.28, 1, 1, map)
		mob.Spawn("Armored Noob", 20, 0.28, 1, 1, map)
	elseif wave == 13 then m.Value = 3 ; s.Value = 0 ; st.Value = 0245 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Shadow Noob", 14, 0.28, 2.5, 1, map)
		mob.Spawn("Noob Soldier", 1, 1.25, 2, 1.25, map)
		mob.Spawn("Noob Doctor", 1, 0.28, 1, 1, map)
	elseif wave == 14 then m.Value = 2 ; s.Value = 25 ; st.Value = 0255 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Aviator Noob", 5, 0.28, 1, 0.65, map)
		mob.Spawn("Noob Soldier", 1, 0.5, 2.75, 1, map)
		mob.Spawn("Shadow Noob", 20, 0.28, 1.15, 1, map)
		mob.Spawn("Noob Doctor", 1, 0.28, 0.5, 1.5, map)
	elseif wave == 15 then m.Value = 2 ; s.Value = 25 ; st.Value = 0255 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Noob Engineer", 1, 0.28, 2, 1, map)
		mob.Spawn("Armored Noob", 18, 0.5, 1.5, 1, map)
		mob.Spawn("Aviator Noob", 7, 0.35, 1, 0.8, map)
		mob.Spawn("Shadow Noob", 12, 0.28, 2.5, 1, map)
		mob.Spawn("Noob Engineer", 1, 0.28, 2.25, 1, map)
	elseif wave == 16 then m.Value = 2 ; s.Value = 25 ; st.Value = 0255 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Noob Soldier", 3, 0.5, 1.85, 1, map)
		mob.Spawn("Aviator Noob", 15, 0.35, 1, 0.8, map)
		mob.Spawn("Noob Engineer", 1, 0.28, 1.75, 1, map)
		mob.Spawn("Noob Doctor", 1, 0.28, 0.5, 1.5, map)
	elseif wave == 17 then m.Value = 5 ; s.Value = 05 ; st.Value = 0435 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Noob Gaurdian", 1, 0.5, 1.2, 1, map)
		mob.Spawn("Noob Soldier", 4, 0.28, 0.35, 1.5, map)
		mob.Spawn("Shadow Noob", 30, 0.28, 1, 1, map)
	elseif wave == 18 then m.Value = 5 ; s.Value = 05 ; st.Value = 0435 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Noob Gaurdian", 1, 0.5, 1, 1, map)
		mob.Spawn("Noob Doctor", 1, 0.28, 0.5, 1, map)
		mob.Spawn("Noob Gaurdian", 1, 0.5, 0.5, 1.25, map)
		mob.Spawn("Noob Engineer", 1, 0.28, 2, 1, map)
	elseif wave == 19 then m.Value = 10 ; s.Value = 00 ; st.Value = 0850 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Noob Juggernaut", 1, 0.28, 0.67, 1, map)
	elseif wave == 20 then m.Value = 99 ; s.Value = 60 ; st.Value = 0850 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		ReplicatedStorage.Events.FinalWave:FireAllClients(Color3.new(1, 0.333333, 0))
		mob.Spawn("Noob Doctor", 1, 0.28, 0.8, 1, map)
		mob.Spawn("Noob Gaurdian", 1, 0.5, 0.67, 1.15, map)
		mob.Spawn("General Noobicus", 1, 5, 1, 1, map)
	end
end

function round.GetNormal(wave, map)
	if wave == 1 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Zombie", 8,0.28 ,1 ,1 , map)
	elseif wave == 2 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Zombie", 13,0.28 ,1 ,1 , map)
	elseif wave == 3 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Speedy", 5,0.28 ,1 ,1 , map)
		mob.Spawn("Zombie", 11,0.28 ,1 ,1 , map)
		mob.Spawn("Speedy", 3,0.28 ,1 ,1 , map)
	elseif wave == 4 then m.Value = 2 ; s.Value = 0 ; st.Value = 0145 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Zombie", 9,0.28 ,1.45 ,1 , map)
		mob.Spawn("Speedy", 7,0.22 ,1.25 ,0.8 , map)
		mob.Spawn("Zombie", 6,0.28 ,1.25,1 , map)
		mob.Spawn("Speedy", 2,0.22 ,1.65 ,1 , map)
	elseif wave == 5 then m.Value = 2 ; s.Value = 5 ; st.Value = 0145 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Armored Zombie", 11,0.28 ,2.2 ,1 , map)
		mob.Spawn("Speedy", 7,0.22 ,1.67 ,1.25 , map)
		mob.Spawn("Zombie", 5,0.28 ,1,2 , map)
		mob.Spawn("Armored Zombie", 3,0.28 ,1.25 ,1 , map)
	elseif wave == 6 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Armored Zombie", 25,0.28 ,2 ,1 , map)
		mob.Spawn("Speedy", 5,0.28 ,1 ,1.5 , map)
	elseif wave == 7 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Zombie", 7,0.28 ,1,1 , map)
		mob.Spawn("Armored Zombie", 4,0.28 ,1.25 ,1 , map)
		mob.Spawn("Executioner", 1,0.28 ,2.02 ,1 , map)
	elseif wave == 8 then m.Value = 1 ; s.Value = 15 ; st.Value = 055 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Armored Zombie", 8,0.25 ,2 ,1 , map)
		mob.Spawn("Zombie", 20,0.20 ,1,1 , map)
		mob.Spawn("Armored Zombie", 12,0.25 ,5,1 , map)
		mob.Spawn("Speedy", 5,0.18,1,1 , map)
	elseif wave == 9 then m.Value = 1 ; s.Value = 15 ; st.Value = 055 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Executioner", 1,2 ,1.45 ,1 , map)
		mob.Spawn("Spy", 17,0.25 ,1.2 ,1 , map)
		mob.Spawn("Executioner", 1,2 ,1.8,1 , map)
	elseif wave == 10 then m.Value = 1 ; s.Value = 15 ; st.Value = 055 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Executioner", 1,1 ,1.3 ,1 , map)
		mob.Spawn("Spy", 15,0.25 ,1 ,1 , map)
		mob.Spawn("Armored Zombie", 30,0.25 ,2 ,1 , map)
		mob.Spawn("Executioner", 1,2 ,1.7 ,1 , map)	
	elseif wave == 11 then m.Value = 1 ; s.Value = 20 ; st.Value = 059 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Spy", 25,0.25 ,1.15 ,1 , map)
	elseif wave == 12 then m.Value = 1 ; s.Value = 20 ; st.Value = 059 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Executioner", 1,0.25 ,0.95 ,2.1 , map)
		mob.Spawn("Pilot", 7,0.25 ,0.8 ,0.8 , map)
	elseif wave == 13 then m.Value = 1 ; s.Value = 10 ; st.Value = 059 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Spy", 15,0.25 ,2 ,1.25 , map)
		mob.Spawn("Pilot", 5,0.25 ,0.8 ,0.8 , map)
		mob.Spawn("Spy", 8,0.25 ,1 ,1.75 , map)
	elseif wave == 14 then m.Value = 2 ; s.Value = 0 ; st.Value = 0145 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Pilot", 9,0.35 ,1.5 ,0.5, map)
	elseif wave == 15 then m.Value = 3 ; s.Value = 0 ; st.Value = 0245 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Executioner", 1,0.25 ,1.25 ,1 , map)
		mob.Spawn("MEU", 1,1 ,1.05 ,1 , map)
		mob.Spawn("Pilot", 4,0.25 ,2 ,0.8, map)
		mob.Spawn("Spy", 5,0.25 ,0.5 ,1 , map)
	elseif wave == 16 then m.Value = 2 ; s.Value = 0 ; st.Value = 0145 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Executioner", 5,1 ,0.8 ,1 , map)
		mob.Spawn("MEU", 1,1 ,1.1 ,1 , map)
	elseif wave == 17 then m.Value = 2 ; s.Value = 0 ; st.Value = 0145 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("MEU", 1,3 ,2 ,1 , map)
		mob.Spawn("MEU", 1,3 ,0.5 ,1 , map)
	elseif wave == 18 then m.Value = 3 ; s.Value = 0 ; st.Value = 0230 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Polycephaly", 5,1 ,1.25 ,1 , map)
		mob.Spawn("Executioner", 1,1 ,1.6 ,1 , map)
		mob.Spawn("Pilot", 4,1 ,1 ,0.8 , map)
		mob.Spawn("MEU", 1,3 ,1 ,1 , map)
	elseif wave == 19 then m.Value = 3 ; s.Value = 0 ; st.Value = 0230 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Polycephaly", 10,1 ,1 ,1 , map)
	elseif wave == 20 then m.Value = 3 ; s.Value = 0 ; st.Value = 0200 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Brute", 1,1 ,1.125 ,1 , map)
		mob.Spawn("Polycephaly", 3,1 ,2 ,1.35 , map)
		mob.Spawn("MEU", 1,1.45 ,0.8 ,1 , map)
	elseif wave == 21 then m.Value = 3 ; s.Value = 0 ; st.Value = 0200 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Brute", 1,1 ,1.3 ,1 , map)
		mob.Spawn("Infected Medic", 1,1 ,0.5 ,1 , map)
		mob.Spawn("Pilot", 4,0.25 ,1 ,0.8 , map)
		mob.Spawn("Spy", 13,0.25 ,1 ,1.5 , map)
	elseif wave == 22 then m.Value = 3 ; s.Value = 0 ; st.Value = 0200 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Brute", 5,3 ,0.9 ,0.75 , map)
	elseif wave == 23 then m.Value = 3 ; s.Value = 0 ; st.Value = 0200 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("MEU", 3,1 ,0.75 ,1 , map)
		mob.Spawn("Polycephaly", 4,1 ,1 ,1 , map)
		mob.Spawn("Brute", 1,1 ,1 ,1 , map)
		mob.Spawn("Infected Medic", 1,1 ,1.25 ,1 , map)
		mob.Spawn("Pilot", 1,1 ,5 ,0.7 , map)
		mob.Spawn("Executioner", 2,1 ,1 ,0.5 , map)
		mob.Spawn("Brute", 1,1 ,0.28 ,1 , map)
	elseif wave == 24 then m.Value = 10 ; s.Value = 0 ; st.Value = 0800 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Executioner", 7,1 ,1 ,0.5 , map)
		mob.Spawn("Brute", 3,2.25 ,0.75 ,0.75 , map)
		mob.Spawn("Infected Medic", 2,3 ,0.5 ,1 , map)
		mob.Spawn("Pilot", 10,0.3,1.1 ,0.6 , map)
		mob.Spawn("Polycephaly", 3,1 ,2 ,0.75, map)
		mob.Spawn("Marauder", 1,1 ,0.7 ,1.1, map)
		mob.Spawn("Resurrected Noob Gaurdian", 1,2.25 ,0.5 ,0.325, map)
	elseif wave == 25 then m.Value = 5 ; s.Value = 0 ; st.Value = 0440 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Brute", 4,2 ,1 ,1 , map)
		mob.Spawn("Endbringer", 1,2.25 ,1 ,1 , map)
		mob.Spawn("Infected Medic", 8,1 ,0.8 ,1 , map)
		mob.Spawn("Endbringer", 1,2.25 ,1.5 ,1.15 , map)
		mob.Spawn("Pilot", 22,0.3,1 ,0.95 , map)
		mob.Spawn("Polycephaly", 15,0.35 ,2 ,1, map)
	elseif wave == 26 then m.Value = 99 ; s.Value = 59 ; st.Value = 0440 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		ReplicatedStorage.Events.FinalWave:FireAllClients(Color3.new(1, 0, 0))
		mob.Spawn("Endbringer", 1,1 ,1 ,1 , map)
		mob.Spawn("Polycephaly", 4,0.35 ,3.5 ,1, map)
		mob.Spawn("Endbringer", 1,1 ,1 ,1 , map)
		mob.Spawn("Polycephaly", 7,0.35 ,1 ,1, map)
		mob.Spawn("Pilot", 15,0.3,1 ,0.95 , map)
		mob.Spawn("Infected Medic", 3,1 ,1.2 ,1 , map)
		mob.Spawn("Doombringer", 1,1 ,1 * GM ,1 , map)
	end
end

function round.GetHard(wave, map)
	if wave == 1 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Peasant", 12,0.28 ,1 ,1 , map)
	elseif wave == 2 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Peasant", 15,0.28 ,1 ,1 , map)
	elseif wave == 3 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Peasant", 5,0.28 ,1 ,1 , map)
		mob.Spawn("Worker", 1,0.28 ,2,0.8 , map)
		mob.Spawn("Peasant", 15,0.28 ,1 ,1 , map)
		mob.Spawn("Worker", 1,0.28 ,2.5,0.8 , map)
	elseif wave == 4 then m.Value = 1 ; s.Value = 0 ; st.Value = 045 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Worker", 2,0.35 ,2,0.8 , map)
		mob.Spawn("Peasant", 14,0.28 ,1 ,1 , map)
		mob.Spawn("Worker", 5,0.35 ,2,0.8 , map)
	elseif wave == 5 then m.Value = 2 ; s.Value = 0 ; st.Value = 0140 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Worker", 20,0.35 ,1.8,0.8 , map)
	elseif wave == 6 then m.Value = 2 ; s.Value = 0 ; st.Value = 0140 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Worker", 4,0.35 ,1.8,0.8 , map)
		mob.Spawn("Peasant", 23,0.28 ,1 ,1 , map)
		mob.Spawn("Knight", 1,0.35 ,1.15,1 , map)
		mob.Spawn("Worker", 6,0.5 ,2,0.8 , map)
	elseif wave == 7 then m.Value = 2 ; s.Value = 0 ; st.Value = 0140 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Knight", 1,0.35 ,1.5,1 , map)
		mob.Spawn("Peasant", 10,0.28 ,1 ,1 , map)
		mob.Spawn("Worker", 7,0.35 ,2,0.8 , map)
		mob.Spawn("Peasant", 14,0.28 ,1 ,1 , map)
		mob.Spawn("Knight", 1,1.5 ,2,1 , map)
	elseif wave == 8 then m.Value = 2 ; s.Value = 0 ; st.Value = 0140 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Knight", 3,0.35 ,1,1 , map)
		mob.Spawn("Worker", 12,0.35 ,1.8,0.8 , map)
		mob.Spawn("Knight", 1,0.35 ,1,1 , map)
		mob.Spawn("Peasant", 10 ,0.28 ,1.5 ,1 , map)
		mob.Spawn("Worker", 6,0.35 ,1.8,0.8 , map)
	elseif wave == 9 then m.Value = 2 ; s.Value = 0 ; st.Value = 0140 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Peasant", 18,0.28 ,1 ,1 , map)
		mob.Spawn("Worker", 9,0.28 ,2,0.8 , map)
		mob.Spawn("Bread Bearer", 1,0.35 ,2,0.8 , map)
		mob.Spawn("Peasant", 14,0.28 ,1 ,1 , map)
		mob.Spawn("Worker", 10,0.28 ,2,1 , map)
	elseif wave == 10 then m.Value = 3 ; s.Value = 0 ; st.Value = 0230 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Worker", 3,0.28 ,1.4,1 , map)
		mob.Spawn("Marksman", 1,0.28 ,1.12 ,1.1 , map)
		mob.Spawn("Peasant", 10,0.28 ,1 ,1 , map)
		mob.Spawn("Bread Bearer", 1,3 ,1,0.8 , map)
		mob.Spawn("Worker", 12,0.28 ,2,1 , map)
	elseif wave == 11 then m.Value = 2 ; s.Value = 0 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Worker", 4,0.28 ,2,1 , map)
		mob.Spawn("Bread Bearer", 1,0.35 ,2,0.8 , map)
		mob.Spawn("Bronze", 5,0.35 ,1,1 , map)
		mob.Spawn("Knight", 2, 0.6 ,1,1 , map)
	elseif wave == 12 then m.Value = 1 ; s.Value = 50 ; st.Value = 0112 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Peasant", 10,0.2 ,2 ,1 , map)
		mob.Spawn("Bronze", 2,0.35 ,1,1 , map)
		mob.Spawn("Knight", 3, 0.6 ,1,1 , map)
		mob.Spawn("Bread Bearer", 1,1.5 ,1,0.8 , map)
		mob.Spawn("Bronze", 1,0.35 ,1.5,1 , map)
		mob.Spawn("Knight", 1, 0.3 ,2,1 , map)
	elseif wave == 13 then m.Value = 2 ; s.Value = 0 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Marksman", 1,0.28 ,1 ,0.8 , map)
		mob.Spawn("Bronze", 4,0.35 ,1,1 , map)
		mob.Spawn("Wraith", 10,0.28 ,1,1 , map)
		mob.Spawn("Bronze", 2,0.35 ,1.5,1 , map)
		mob.Spawn("Bread Bearer", 1,1.5 ,3,0.8 , map)
		mob.Spawn("Marksman", 1,0.28 ,0.5 ,1.75 , map)
	elseif wave == 14 then m.Value = 2 ; s.Value = 0 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Wraith", 45,0.28 ,1,1.25 , map)
	elseif wave == 15 then m.Value = 2 ; s.Value = 0 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Worker", 15,0.28 ,1.5,1 , map)
		mob.Spawn("Marksman", 1,0.28 ,0.75 ,1 , map)
		mob.Spawn("Glider", 2,3 ,1.6 ,1 , map)
		mob.Spawn("Bread Bearer", 1,1.5 ,1,0.8 , map)
		mob.Spawn("Wraith", 8,0.28 ,1,1 , map)
	elseif wave == 16 then m.Value = 2 ; s.Value = 0 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Bronze", 12,0.35 ,1,1 , map)
		mob.Spawn("Glider", 1,3 ,2 ,1 , map)
		mob.Spawn("Wraith", 12,0.28 ,2,1 , map)
		mob.Spawn("Bread Bearer", 1,1.5 ,1,0.8 , map)
		mob.Spawn("Knight", 5, 0.3 ,2,1 , map)
		mob.Spawn("Bread Bearer", 1,1.5 ,1,0.8 , map)
		mob.Spawn("Bronze", 4,0.35 ,3,1 , map)
	elseif wave == 17 then m.Value = 5 ; s.Value = 0 ; st.Value = 0425 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Bronze", 14,0.25 ,1,1 , map)
		mob.Spawn("Glider", 1,2.25 ,3 ,0.8 , map)
		mob.Spawn("Marksman", 1,0.28 ,1.5,1 , map)
		mob.Spawn("Merchant", 1,0.28 ,1,1 , map)
		mob.Spawn("Bread Bearer", 1,1.5 ,1,0.8 , map)
	elseif wave == 18 then m.Value = 2 ; s.Value = 0 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Marksman", 2,3 ,0.8 ,1 , map)
		mob.Spawn("Glider", 3,2.25 ,0.75 ,1.2 , map)
		mob.Spawn("Bronze", 3,0.35 ,1,1 , map)
		mob.Spawn("Wraith", 4,0.28 ,1,1 , map)
		mob.Spawn("Bronze", 7,0.35 ,1,1 , map)
		mob.Spawn("Marksman", 1,3 ,2 ,1 , map)
		mob.Spawn("Worker", 20,0.2 ,1,1.25 , map)
		mob.Spawn("Merchant", 1,0.28 ,0.75,1 , map)
	elseif wave == 19 then m.Value = 2 ; s.Value = 0 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Merchant", 1,0.28 ,0.75,1 , map)
		mob.Spawn("Bread Bearer", 1,1.5 ,5,0.8 , map)
		mob.Spawn("Bronze", 3,0.35 ,1,1 , map)
		mob.Spawn("Glider", 10,2.25 ,1 ,1.1 , map)
		mob.Spawn("Bread Bearer", 1,1.5 ,1,0.8 , map)
		mob.Spawn("Wizard", 2, 5 ,2.5,1 , map)
		mob.Spawn("Worker", 45,0.1 ,2,2 , map)
	elseif wave == 20 then m.Value = 6 ; s.Value = 9 ; st.Value = 0001 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		info.Modifiers.NoWaveReward.Value = true
		mob.Spawn("Marksman", 4,3 ,0.8 ,1 , map)
		mob.Spawn("Glider", 5,0.6 ,0.5 ,2 , map)
		mob.Spawn("Bronze", 15,0.35 ,1,1 , map)
		mob.Spawn("Bread Bearer", 1,1.5 ,5,0.8 , map)
		mob.Spawn("Wraith", 20,0.28 ,2,1 , map)
		mob.Spawn("Plague Doctor", 1,4 ,1,0.95 , map)
		mob.Spawn("Plagued", 15,2 ,1,1 , map)
	elseif wave == 21 then m.Value = 2 ; s.Value = 30 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Plagued", 3,0.5 ,1.5,1 , map)
		mob.Spawn("Wizard", 1, 1 ,3,1 , map)
		mob.Spawn("Bronze", 20,0.25 ,1,1.25 , map)
		mob.Spawn("Dark Knight", 1,0.35 ,0.75,1 , map)
		mob.Spawn("Wizard", 1, 1 ,3,1 , map)
		mob.Spawn("Glider", 3,4.5 ,1.5,1 , map)
		mob.Spawn("Wraith", 50,0.15 ,2,2 , map)
	elseif wave == 22 then m.Value = 2 ; s.Value = 30 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Merchant", 1,0.28 ,1.125,1 , map)
		mob.Spawn("Wizard", 1, 1 ,5,1 , map)
		mob.Spawn("Plagued", 2,1 ,1,3 , map)
		mob.Spawn("Necromancer", 1,0.5 ,1,1 , map)
		mob.Spawn("Glider", 5,4.5 ,2.5,1 , map)
		mob.Spawn("Merchant", 1,0.28 ,1.125,1 , map)
		mob.Spawn("Necromancer", 1,0.5 ,1,1 , map)
	elseif wave == 23 then m.Value = 4 ; s.Value = 30 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Dark Knight", 5,1.2 ,0.45,0.95 , map)
		mob.Spawn("Marksman", 3,4.5 ,1.75,1 , map)
		mob.Spawn("Wraith", 15,0.28 ,5,1 , map)
		mob.Spawn("Dark Knight", 5,1.2 ,0.5,0.85 , map)
		mob.Spawn("Bronze", 2,0.5 ,4,1 , map)
		mob.Spawn("Necromancer", 2,0.8 ,1.85,1 , map)
		mob.Spawn("Marksman", 5,4.5 ,1,1 , map)
		mob.Spawn("Dark Knight", 1,1.2 ,1.3, 0.85 , map)
	elseif wave == 24 then m.Value = 2 ; s.Value = 30 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Inventor", 1,1.2 ,0.5,1 , map)
		mob.Spawn("Dark Knight", 2,1 ,0.8,1 , map)
		mob.Spawn("Necromancer", 1,0.8 ,1.5,1 , map)
		mob.Spawn("Wizard", 3,0.75 ,1,1 , map)
		mob.Spawn("Plagued", 13,0.5 ,1,1.25 , map)
		mob.Spawn("Merchant", 1,0.5 ,1,2 , map)
		mob.Spawn("Glider", 10,0.5 ,1,2.5 , map)
		mob.Spawn("Dark Knight", 3,1.2 ,1,0.8 , map)
		mob.Spawn("Dark Knight", 1,1.2 ,1.4,0.8 , map)
	elseif wave == 25 then m.Value = 2 ; s.Value = 30 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Bronze", 10,0.25 ,8,1 , map)
		mob.Spawn("Dark Knight", 1,1 ,2.75,1 , map)
		mob.Spawn("Merchant", 3,0.5 ,1,2 , map)
		mob.Spawn("Wizard", 5, 0.65 ,1,1 , map)
		mob.Spawn("Marksman", 3,2.2 ,1.45,1.45 , map)
		mob.Spawn("Dark Knight", 2,1.5 ,0.5,1 , map)
		mob.Spawn("Inventor", 1,1.2 ,1,1 , map)
	elseif wave == 26 then m.Value = 2 ; s.Value = 30 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Assassin", 18,0.3 ,1.25,1 , map)
	elseif wave == 27 then m.Value = 2 ; s.Value = 30 ; st.Value = 0130 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Assassin", 3,0.3 ,2,1 , map)
		mob.Spawn("Enforcer", 1,0.3 ,1,1 , map)
		mob.Spawn("Dark Knight", 2,1 ,1,1 , map)
		mob.Spawn("Necromancer", 3,0.8 ,2,1 , map)
		mob.Spawn("Marksman", 5,4.5 ,2.75,1 , map)
		mob.Spawn("Inventor", 1,1 ,2,1, map)
		mob.Spawn("Plagued", 10,0.5 ,1,1.25 , map)
		mob.Spawn("Assassin", 2,0.3 ,3,1 , map)
	elseif wave == 28 then m.Value = 6 ; s.Value = 9 ; st.Value = 0001 ; events.SetTextTime:FireAllClients(m.Value,s.Value)	
		mob.Spawn("Inventor", 1,1.2 ,1.2,1 , map)
		mob.Spawn("Assassin", 10,0.3 ,1,1 , map)
		mob.Spawn("Necromancer", 5,0.8 ,1.2,1 , map)
		mob.Spawn("Merchant", 5,0.5 ,1.5,1.2 , map)
		mob.Spawn("Wizard", 10, 0.65 ,0.8,1 , map)
		mob.Spawn("Honorary", 1,0.5 ,1,1 , map)
		mob.Spawn("Dark Knight", 4, 0.65 ,0.4,1.5 , map)
		mob.Spawn("Marksman", 4, 0.5 ,1.5,2 , map)
	elseif wave == 29 then m.Value = 4 ; s.Value = 30 ; st.Value = 0330 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Whispering Elm", 1,0.25 ,1,1 , map)
		mob.Spawn("Assassin", 15,0.3 ,1,1.25 , map)
		mob.Spawn("Enforcer", 2,1.35 ,1,1 , map)
		mob.Spawn("Wizard", 10, 0.5 ,1,1 , map)
		mob.Spawn("Inventor", 1,1.2 ,1,1 , map)
		mob.Spawn("Whispering Elm", 3,1.25 ,1,1.15 , map)
	elseif wave == 30 then m.Value = 4 ; s.Value = 30 ; st.Value = 0330 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Whispering Elm", 10,1.5 ,0.7,1 , map)
		mob.Spawn("Inventor", 1,0.3 ,1,1 , map)
		mob.Spawn("Volent", 4,1 ,1,1 , map)
		mob.Spawn("Assassin", 25,0.25 ,0.40,2 , map)
	elseif wave == 31 then m.Value = 4 ; s.Value = 30 ; st.Value = 0330 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		mob.Spawn("Volent", 1,0.25 ,1,1 , map)
		mob.Spawn("Necromancer", 3,1 ,4,1 , map)
		mob.Spawn("Enforcer", 1,1 ,1,1 , map)
		mob.Spawn("Inventor", 1,1.2 ,0.5,2 , map)
		mob.Spawn("Volent", 6,1 ,0.5,1 , map)
		mob.Spawn("Whispering Elm", 5,1.5 ,1.25,1 , map)
		mob.Spawn("Dark Knight", 9, 0.65 ,1,1 , map)
		mob.Spawn("Whispering Elm", 1,1.5 ,1,1 , map)
		mob.Spawn("Volent", 1,1 ,0.9,0.9 , map)
		mob.Spawn("Enforcer", 1,1.2 ,1,1 , map)
		mob.Spawn("Marksman", 15,1.5 ,2,1 , map)
	elseif wave == 32 then m.Value = 99 ; s.Value = 59 ; st.Value = 0001 ; events.SetTextTime:FireAllClients(m.Value,s.Value)
		ReplicatedStorage.Events.FinalWave:FireAllClients(Color3.new(1, 0, 0))
		mob.Spawn("Whispering Elm", 4,1 ,0.4,1.5 , map)
		mob.Spawn("Assassin", 13,0.25 ,1,1 , map)
		mob.Spawn("Enforcer", 1,1 ,0.5,1 , map)
		mob.Spawn("Wizard", 14, 0.5 ,1.5,1 , map)
		mob.Spawn("Merchant", 6,1 ,2,1 , map)
		mob.Spawn("Inventor", 1,1.2 ,1,1 , map)
		mob.Spawn("Whispering Elm", 2,1.5 ,0.65,1 , map)
		mob.Spawn("Swordmaster", 1,1 ,1,1 , map)
		mob.Spawn("Volent", 4,1 ,0.45,1.25 , map)
		mob.Spawn("Enforcer", 1,1 ,0.5,1 , map)
		mob.Spawn("Volent", 1,0.1 ,1,1 , map)
		mob.Spawn("Dark Knight", 20,1 ,0.45,1.25 , map)
	end
end

function round.GetInsane(wave, map)
end

function round.GetChaos(wave, map)
end

function round.GetHardcore(wave, map)
end



return round
