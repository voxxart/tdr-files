local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local events = ReplicatedStorage:WaitForChild("Events")
local AnimateEnemy = events:WaitForChild("AnimateEnemy")

local TowersFolder = workspace:WaitForChild("Towers")
local GameSpeedValue = workspace.Info:WaitForChild("GameSpeed")
local MOB_MOD = require(game.ServerScriptService.Main.Mob)

local TAG = "Wizard"
local MAX_CHAIN = 3
local CHAIN_RADIUS = 4
local State = setmetatable({}, {__mode = "k"})

---------------------------------------------------------
-- HELPERS
---------------------------------------------------------
local function gs()
	local v = GameSpeedValue.Value
	if v <= 0 then return 1 end
	return v
end

local function isAliveEnemy(enemy)
	return enemy and enemy.Parent and enemy.PrimaryPart and enemy:FindFirstChild("Hitbox")
end

local function isValidTower(tower)
	if not tower or tower.Parent ~= TowersFolder then return false end
	local cfg = tower:FindFirstChild("Config")
	local health = cfg and cfg:FindFirstChild("Health")
	return tower.PrimaryPart and cfg and health
		and health:FindFirstChild("HealthValue")
		and health:FindFirstChild("MaxHealth")
end

local function schedule(enemy, s, minCd, maxCd)
	s.nextT = os.clock() + s.rng:NextNumber(minCd / gs(), maxCd / gs())
end

local function findNearestTower(enemy, range)
	range = range or 25
	local epos = enemy.Hitbox.Position
	local best, bestDist = nil, range * range

	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(tower) and not tower.Config:FindFirstChild("Flying") then
			local tpos = tower.PrimaryPart.Position
			local dx, dz = tpos.X - epos.X, tpos.Z - epos.Z
			local dist2 = dx * dx + dz * dz
			if dist2 < bestDist then
				bestDist = dist2
				best = tower
			end
		end
	end
	return best
end

local function findChainTarget(fromPos, alreadyHit)
	local best, bestDist = nil, CHAIN_RADIUS * CHAIN_RADIUS

	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if isValidTower(tower) and not tower.Config:FindFirstChild("Flying") and not alreadyHit[tower] then
			local tpos = tower.PrimaryPart.Position
			local dx, dz = tpos.X - fromPos.X, tpos.Z - fromPos.Z
			local dist2 = dx * dx + dz * dz
			if dist2 < bestDist then
				bestDist = dist2
				best = tower
			end
		end
	end
	return best
end

---------------------------------------------------------
-- ATTACHMENT HELPERS
---------------------------------------------------------

-- Gets or creates a temporary center attachment on a part
local function getOrMakeTempAttachment(part)
	local att = part:FindFirstChild("_TempBeamAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "_TempBeamAtt"
		att.Position = Vector3.zero
		att.Parent = part
	end
	return att
end

-- Gets the wand tip attachment on the enemy
local function getWandAttachment(enemy)
	local weapon = enemy:FindFirstChild("Weapon")
	local wand = weapon and weapon:FindFirstChild("Wand")
	local wandInner = wand and wand:FindFirstChild("Wand")
	local att = wandInner and wandInner:FindFirstChild("Start")
	return att
end

-- Gets the torso attachment on a tower, or makes a temp one
local function getTowerAttachment(tower)
	-- Search all parts under the tower for a "Torso" attachment
	for _, desc in ipairs(tower:GetDescendants()) do
		if desc:IsA("Attachment") and desc.Name == "Torso" then
			return desc
		end
	end
	-- Fallback: attach to the PrimaryPart center
	return getOrMakeTempAttachment(tower.PrimaryPart)
end

---------------------------------------------------------
-- BEAM
---------------------------------------------------------
local BEAM_LIFETIME = 0.45 -- seconds the beam is visible

local function fireBeam(fromAttachment, toAttachment)
	local beam = Instance.new("Beam")
	beam.Attachment0 = fromAttachment
	beam.Attachment1 = toAttachment
	beam.Width0 = 0.15
	beam.Width1 = 0.08
	beam.Segments = 6
	beam.CurveSize0 = 0
	beam.CurveSize1 = 0
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.TextureSpeed = 2
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	-- Parent to fromAttachment's instance so it lives in the world
	beam.Parent = fromAttachment.Parent

	task.delay(BEAM_LIFETIME, function()
		if beam and beam.Parent then beam:Destroy() end
	end)
end

---------------------------------------------------------
-- STUN
---------------------------------------------------------
local function stunTower(tower)
	if not isValidTower(tower) then return end
	local cfg = tower.Config
	
	local ST
	if workspace.Info.Modifiers["Death Wish"].Value == true then
		ST  = 5
	else
		ST = 5
	end

	local stunValue = cfg:FindFirstChild("Stunned")
	if not stunValue then
		stunValue = Instance.new("NumberValue")
		stunValue.Name = "Stunned"
		stunValue.Value = ST
		stunValue.Parent = cfg
	else
		stunValue.Value = ST
	end
end

---------------------------------------------------------
-- CHAIN STUN BEHAVIOR
---------------------------------------------------------
local function doChainStun(enemy)
	local primaryTarget = findNearestTower(enemy)
	if not primaryTarget then return end
	
	local Speed = enemy.EnemyStats:FindFirstChild("Speed")
	local OrigSpeed = enemy.EnemyStats:FindFirstChild("OrigSpeed")

	local chain = { primaryTarget }
	local alreadyHit = { [primaryTarget] = true }

	while #chain < MAX_CHAIN do
		local lastTower = chain[#chain]
		local nextTarget = findChainTarget(lastTower.PrimaryPart.Position, alreadyHit)
		if not nextTarget then break end
		table.insert(chain, nextTarget)
		alreadyHit[nextTarget] = true
	end

	if primaryTarget.PrimaryPart then
		MOB_MOD.FacePart(enemy, primaryTarget.PrimaryPart, 2.5 / gs())
		Speed.Value = 0
	end
	
	task.delay(2.5 / gs(), function()
		Speed.Value = OrigSpeed.Value
	end)

	AnimateEnemy:FireAllClients(enemy, "Fire", chain[1])

	task.delay(1.07 / gs(), function()
		if not isAliveEnemy(enemy) then return end

		local wandAtt = getWandAttachment(enemy)

		for i, tower in ipairs(chain) do
			if not isValidTower(tower) then continue end

			stunTower(tower)

			local toAtt = getTowerAttachment(tower)

			if i == 1 then
				-- Beam from wand tip to first tower (or fallback)
				if wandAtt then
					fireBeam(wandAtt, toAtt)
				else
					-- No wand found: beam from enemy PrimaryPart center
					local fallback = getOrMakeTempAttachment(enemy.PrimaryPart)
					fireBeam(fallback, toAtt)
				end
			else
				-- Chain beam: from previous tower to this tower
				local prevAtt = getTowerAttachment(chain[i - 1])
				fireBeam(prevAtt, toAtt)
			end

			AnimateEnemy:FireAllClients(chain[i > 1 and i - 1 or 1], "Fire", tower)
		end

		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		local atkSound = hrp and hrp:FindFirstChild("Attack")
		if atkSound and atkSound:IsA("Sound") then atkSound:Play() end
	end)
end

---------------------------------------------------------
-- BEHAVIOR
---------------------------------------------------------
local Behaviors = {}
Behaviors.Wizard = function(enemy, s)
	if os.clock() < s.nextT then return end
	schedule(enemy, s, 12, 17)

	doChainStun(enemy)
end

---------------------------------------------------------
-- START / TRACKING
---------------------------------------------------------
local function start(enemy)
	if State[enemy] then return end
	State[enemy] = { rng = Random.new(), nextT = 0 }
	schedule(enemy, State[enemy], 12, 17)

	enemy.AncestryChanged:Connect(function(_, parent)
		if not parent then State[enemy] = nil end
	end)
end

for _, enemy in ipairs(CollectionService:GetTagged(TAG)) do
	start(enemy)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(start)
CollectionService:GetInstanceRemovedSignal(TAG, function(enemy)
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
			Behaviors.Wizard(enemy, s)
		end
	end
end)