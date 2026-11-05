local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Mob = require(game.ServerScriptService.Main.Mob)

local GameSpeedValue = workspace.Info:WaitForChild("GameSpeed")

local TAG = "Spawner"

local State = setmetatable({}, { __mode = "k" })

--------------------------------------------------------------------
-- UTIL
--------------------------------------------------------------------
local function gs()
	local v = GameSpeedValue.Value
	return (v > 0 and v or 1)
end

local function isAlive(enemy)
	return enemy
		and enemy.Parent
		and enemy:FindFirstChild("Hitbox")
		and enemy:FindFirstChild("EnemyStats")
		and enemy.EnemyStats:FindFirstChild("Cooldown")
end

local function schedule(enemy, s, cd)
	s.nextT = os.clock() + (cd / gs())
end

--------------------------------------------------------------------
-- SPAWN LOGIC
--------------------------------------------------------------------
local function doSpawn(enemy)
	local map = workspace.Map:FindFirstChildOfClass("Folder")
	if not map then
		return
	end

	local alphaObj = enemy:FindFirstChild("Alpha")
	if not alphaObj then
		return
	end

	local alpha = alphaObj.Value

	local hitbox = enemy:FindFirstChild("Hitbox")
	if not hitbox then
		return
	end

	local path, pathLength, positions =
		Mob.GetClosestWaypointPath(map, hitbox.CFrame)

	if not path then
		return
	end

	ReplicatedStorage.Events.SummonEnemy:Fire(enemy)
end

--------------------------------------------------------------------
-- BEHAVIOR
--------------------------------------------------------------------
local function SpawnerBehavior(enemy, s)
	local stats = enemy:FindFirstChild("EnemyStats")
	if not stats then
		return
	end

	local cooldownValue = stats:FindFirstChild("Cooldown")
	if not cooldownValue then
		return
	end

	local cooldown = cooldownValue.Value

	if os.clock() < s.nextT then
		return
	end

	schedule(enemy, s, cooldown)

	doSpawn(enemy)
end

--------------------------------------------------------------------
-- START / TRACKING
--------------------------------------------------------------------
local function start(enemy)
	if State[enemy] then
		return
	end

	State[enemy] = {
		nextT = 0,
		rng = Random.new(),
	}

	-- prevent leaks
	enemy.AncestryChanged:Connect(function(_, parent)
		if not parent then
			State[enemy] = nil
		end
	end)

	-- optional stagger so all spawners don't sync
	State[enemy].nextT = os.clock() + math.random()
end

for _, enemy in ipairs(CollectionService:GetTagged(TAG)) do
	start(enemy)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(start)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(enemy)
	State[enemy] = nil
end)

--------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	for enemy, s in pairs(State) do
		if not isAlive(enemy) then
			State[enemy] = nil
		else
			SpawnerBehavior(enemy, s)
		end
	end
end)