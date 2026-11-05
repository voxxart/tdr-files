local Players = game:GetService("Players")

local mob = require(script.Mob)
local tower = require(script.TowerServer)
local mines = require(script.Mine)
local round = require(script.Round)

local minPlayers = 1
local readyToStart = true

Players.PlayerAdded:Connect(function(player)
	local currentPlayers = #Players:GetPlayers()
	
	if currentPlayers >= minPlayers and readyToStart then
		readyToStart = false
		round.StartGame()
		readyToStart = true
	else
		workspace.Info.Message.Value = "Waiting for " .. (minPlayers - currentPlayers) .. " more player(s)"
	end
end)