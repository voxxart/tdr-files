local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local events = ReplicatedStorage:WaitForChild("Events")
local AnimateEnemy = events:WaitForChild("AnimateEnemy")
local AnimateTowerDeath = events:WaitForChild("AnimateTowerDeath")

local TOWERDEATH_MOD = require(game.ServerScriptService.Main.TowerDeath)
local SpawnModule = require(game.ServerScriptService.Main.Mob)

local TowersFolder = workspace:WaitForChild("Towers")
local GameSpeedValue = workspace.Info:WaitForChild("GameSpeed")

local TAG = "BreadBearer"
local State = setmetatable({}, {__mode = "k"})

---------------------------------------------------------
-- HELPERS
---------------------------------------------------------
local function gs()
	local v = GameSpeedValue.Value
	return v > 0 and v or 1
end

local function isAliveEnemy(enemy)
	return enemy and enemy.Parent and enemy.PrimaryPart and enemy:FindFirstChild("Hitbox")
end

local function schedule(s, minCd, maxCd)
	s.nextT = os.clock() + s.rng:NextNumber(minCd / gs(), maxCd / gs())
end

---------------------------------------------------------
-- ABILITY
---------------------------------------------------------
local BREAD_NAMES = {"Bread1", "Bread2"}

local function initBreadModels(enemy)
	local BreadModels = enemy:FindFirstChild("BreadModels")
	if not BreadModels then return end
	for _, name in ipairs(BREAD_NAMES) do
		local union = BreadModels:FindFirstChild(name)
		if union and union:IsA("BasePart") then
			union.Transparency = 0
		end
	end
end

local function dropBread(enemy, s)
	if s.abilityCount >= 2 then return end
	s.abilityCount += 1

	local breadName = BREAD_NAMES[s.abilityCount]

	-- Reveal the union by setting transparency to 0
	local BreadModels = enemy:FindFirstChild("BreadModels")
	if BreadModels then
		local union = BreadModels:FindFirstChild(breadName)
		if union and union:IsA("BasePart") then
			union.Transparency = 1
		end
	end

	local map = workspace.Map:FindFirstChildOfClass("Folder")
	if not map then return end

	local alphaObj = enemy:FindFirstChild("Alpha")
	if not alphaObj then return end

	local hitbox = enemy:FindFirstChild("Hitbox")
	if not hitbox then return end

	local path, pathLength, positions = SpawnModule.GetClosestWaypointPath(map, hitbox.CFrame)
	if not path then return end

	SpawnModule.Summon(
		breadName,
		1,
		0.28,
		2.5,
		1,
		map,
		alphaObj.Value,
		hitbox.CFrame,
		path,
		pathLength,
		positions
	)
end

---------------------------------------------------------
-- BEHAVIOR
---------------------------------------------------------
local Behaviors = {}

Behaviors.BreadBearer = function(enemy, s)
	if os.clock() < s.nextT then return end
	if s.abilityCount >= 2 then return end

	schedule(s, 3, 5)
	dropBread(enemy, s)
end

---------------------------------------------------------
-- START / TRACKING
---------------------------------------------------------
local function start(enemy)
	if State[enemy] then return end

	State[enemy] = {
		rng = Random.new(),
		nextT = 0,
		abilityCount = 0,
	}

	initBreadModels(enemy) -- hide both unions immediately on spawn
	schedule(State[enemy], 5, 8)

	enemy.AncestryChanged:Connect(function(_, parent)
		if not parent then State[enemy] = nil end
	end)
end

for _, enemy in ipairs(CollectionService:GetTagged(TAG)) do
	start(enemy)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(start)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(enemy)
	State[enemy] = nil
end)

---------------------------------------------------------
-- HEARTBEAT LOOP
---------------------------------------------------------
RunService.Heartbeat:Connect(function()
	for enemy, s in pairs(State) do
		if not isAliveEnemy(enemy) then
			State[enemy] = nil
		else
			Behaviors.BreadBearer(enemy, s)
		end
	end
end)