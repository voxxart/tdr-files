local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Mob = require(game.ServerScriptService.Main.Mob)

local GameSpeedValue = workspace.Info.GameSpeed

local MEUClientEvent = ReplicatedStorage.Events.MEU.Client

local TAG = "Necromancer"

local State = setmetatable({}, {__mode = "k"})

local function gs()
	local v = GameSpeedValue.Value
	return v > 0 and v or 1
end

local function isAliveEnemy(enemy)
	return enemy
		and enemy.Parent
		and enemy.PrimaryPart
		and enemy:FindFirstChild("Hitbox")
		and enemy:FindFirstChild("Alpha")
end

local function schedule(enemy, s)
	local minCd = enemy:GetAttribute("SummonMin") or 12
	local maxCd = enemy:GetAttribute("SummonMax") or 13

	s.nextT = os.clock() + s.rng:NextNumber(
		minCd / gs(),
		maxCd / gs()
	)
end

local function summonMEU(enemy)
	local map = workspace.Map:FindFirstChildOfClass("Folder")
	if not map then
		return
	end

	local path, pathLength, positions =
		Mob.GetClosestWaypointPath(
			map,
			enemy.Hitbox.CFrame
		)

	if not path then
		return
	end

	Mob.Summon(
		"Undead Squire",
		4,
		0.28,
		2,
		1,
		map,
		enemy.Alpha.Value,
		enemy.Hitbox.CFrame,
		path,
		pathLength,
		positions
	)
end

local function runMEU(enemy, s)
	if os.clock() < s.nextT then
		return
	end

	schedule(enemy, s)

	local hrp = enemy:FindFirstChild("HumanoidRootPart")

	if hrp then
		local sound = hrp:FindFirstChild("Death")

		if sound then
			sound.PlaybackSpeed = gs()
			sound:Play()
		end
	end
	
	
	ReplicatedStorage.Events.AnimateEnemy:FireAllClients(enemy, "Summon", enemy)
	MEUClientEvent:FireAllClients(enemy)

	summonMEU(enemy)
end

local function start(enemy)
	if State[enemy] then
		return
	end

	local s = {
		rng = Random.new(),
		nextT = 0,
	}

	State[enemy] = s

	schedule(enemy, s)

	enemy.AncestryChanged:Connect(function(_, parent)
		if not parent then
			State[enemy] = nil
		end
	end)
end

for _, enemy in ipairs(CollectionService:GetTagged(TAG)) do
	start(enemy)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(start)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(enemy)
	State[enemy] = nil
end)

RunService.Heartbeat:Connect(function()
	for enemy, s in pairs(State) do
		if not isAliveEnemy(enemy) then
			State[enemy] = nil
		else
			runMEU(enemy, s)
		end
	end
end)