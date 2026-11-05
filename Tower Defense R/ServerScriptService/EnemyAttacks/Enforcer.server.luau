local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local events = ReplicatedStorage:WaitForChild("Events")
local AnimateEnemy = events:WaitForChild("AnimateEnemy")

local MOB_MOD = require(game.ServerScriptService.Main.Mob)

local TowersFolder = workspace:WaitForChild("Towers")
local GameSpeedValue = workspace.Info:WaitForChild("GameSpeed")

local TAG = "Enforcer"
local State = setmetatable({}, { __mode = "k" })

local STUN_DURATION
if workspace.Info.Modifiers["Death Wish"].Value == true then 
	STUN_DURATION = 13
else
	STUN_DURATION = 10
end

---------------------------------------------------------
-- CACHED REFERENCES (BIG WIN)
---------------------------------------------------------

local clock = os.clock
local random = Random.new
local ipairs = ipairs

local function gs()
	local v = GameSpeedValue.Value
	return (v > 0 and v) or 1
end

---------------------------------------------------------
-- TOWER CACHE (CRITICAL OPTIMIZATION)
---------------------------------------------------------

local Towers = {}
local TowerIndex = {}

local function addTower(tower)
	if TowerIndex[tower] then return end
	TowerIndex[tower] = true
	Towers[#Towers + 1] = tower
end

local function removeTower(tower)
	if not TowerIndex[tower] then return end
	TowerIndex[tower] = nil

	for i = #Towers, 1, -1 do
		if Towers[i] == tower then
			Towers[i] = Towers[#Towers]
			Towers[#Towers] = nil
			break
		end
	end
end

for _, t in ipairs(TowersFolder:GetChildren()) do
	addTower(t)
end

TowersFolder.ChildAdded:Connect(addTower)
TowersFolder.ChildRemoved:Connect(removeTower)

---------------------------------------------------------
-- HELPERS (REDUCED LOOKUPS)
---------------------------------------------------------

local function isAliveEnemy(enemy)
	return enemy and enemy.Parent and enemy.PrimaryPart and enemy:FindFirstChild("Hitbox")
end

local function isValidTower(tower)
	local cfg = tower:FindFirstChild("Config")
	if not cfg or not tower.PrimaryPart then return false end

	local health = cfg:FindFirstChild("Health")
	if not health then return false end

	return health:FindFirstChild("HealthValue") and health:FindFirstChild("MaxHealth")
end

---------------------------------------------------------
-- OPTIMIZED NEAREST SEARCH
---------------------------------------------------------

local function findNearestTower(enemy, range)
	range = range or 8

	local hitbox = enemy.Hitbox
	if not hitbox then return nil end

	local epos = hitbox.Position
	local best, bestDist = nil, range * range

	for i = 1, #Towers do
		local tower = Towers[i]

		if tower and tower.Parent == TowersFolder then
			local cfg = tower:FindFirstChild("Config")

			if cfg
				and not cfg:FindFirstChild("Flying")
				and not cfg:FindFirstChild("CliffTower")
				and tower.PrimaryPart then

				local tpos = tower.PrimaryPart.Position
				local dx = tpos.X - epos.X
				local dz = tpos.Z - epos.Z
				local dist2 = dx * dx + dz * dz

				if dist2 < bestDist then
					bestDist = dist2
					best = tower
				end
			end
		end
	end

	return best
end

---------------------------------------------------------
-- SCHEDULING (NO EXTRA DIVISION CALLS)
---------------------------------------------------------

local function schedule(enemy, s, minCd, maxCd, speed)
	s.nextT = clock() + s.rng:NextNumber(minCd / speed, maxCd / speed)
end

---------------------------------------------------------
-- STUN (REDUCED LOOKUPS + LOCAL CACHES)
---------------------------------------------------------

local function stunTower(enemy, tower)
	if not isValidTower(tower) then return end

	local stats = enemy:FindFirstChild("EnemyStats")
	local speedVal, origSpeed

	if stats then
		speedVal = stats:FindFirstChild("Speed")
		origSpeed = stats:FindFirstChild("OrigSpeed")

		if speedVal then
			speedVal.Value = 0
		end
	end

	local speed = gs()

	if tower.PrimaryPart then
		MOB_MOD.FacePart(enemy, tower.PrimaryPart, 1.67 / speed)
	end

	AnimateEnemy:FireAllClients(enemy, "Attack", tower)

	task.delay(1 / speed, function()
		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		local slam = hrp and hrp:FindFirstChild("Slam")

		if slam and slam:IsA("Sound") then
			slam:Play()
		end

		local config = tower.Config
		if not config then return end

		local stunned = config:FindFirstChild("Stunned")

		if stunned then
			stunned.Value = STUN_DURATION
		elseif not config:FindFirstChild("CliffTower") then
			local newStun = Instance.new("NumberValue")
			newStun.Name = "Stunned"
			newStun.Value = STUN_DURATION
			newStun.Parent = config
		end
	end)

	task.wait(1.67 / speed)

	if speedVal and origSpeed then
		speedVal.Value = origSpeed.Value
	end
end

---------------------------------------------------------
-- BEHAVIOR
---------------------------------------------------------

local Behaviors = {}

Behaviors.NoobSoldier = function(enemy, s, now)
	if now < s.nextT then return end

	local speed = gs()
	schedule(enemy, s, 10, 14, speed)

	local target = findNearestTower(enemy)
	if target then
		stunTower(enemy, target)
	end
end

---------------------------------------------------------
-- START
---------------------------------------------------------

local function start(enemy)
	if State[enemy] then return end

	State[enemy] = {
		rng = random(),
		nextT = 0
	}

	schedule(enemy, State[enemy], 10, 14, gs())

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

---------------------------------------------------------
-- HEARTBEAT (1 CLOCK CALL PER FRAME)
---------------------------------------------------------

RunService.Heartbeat:Connect(function()
	local now = clock()

	for enemy, s in pairs(State) do
		if not isAliveEnemy(enemy) then
			State[enemy] = nil
		else
			Behaviors.NoobSoldier(enemy, s, now)
		end
	end
end)