local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local modules = ReplicatedStorage:WaitForChild("GameModules")
-- Some places retain the shared lightning package at ReplicatedStorage's root.
local LightningBolt = require(ReplicatedStorage:FindFirstChild("LightningBolt") or modules:WaitForChild("LightningBolt"))
local Policy = require(modules:WaitForChild("VFXPolicy"))
local FXEvent = ReplicatedStorage.Events.Shocker:WaitForChild("LightningBolt")

local LIFETIME = 0.16
local FADE_TIME = 0.04
local MAX_PARTS = 768
local COLOR = Color3.fromRGB(65, 180, 255)
local active = {}
local usedParts = 0
local clock = os.clock

local function opacity(_, elapsed)
	return math.clamp((LIFETIME - elapsed) / FADE_TIME, 0, 1)
end

local function getHitPos(model)
	if typeof(model) ~= "Instance" or not model.Parent then return nil end
	local hit = model:FindFirstChild("Hitbox")
	if not hit or not hit:IsA("BasePart") then return nil end
	return hit.Position
end

local function validPosition(position)
	return position.X == position.X and position.Y == position.Y and position.Z == position.Z
		and math.abs(position.X) < 100000 and math.abs(position.Y) < 100000 and math.abs(position.Z) < 100000
end

local function createBolt(startPos, endPos, low)
	if not validPosition(startPos) or not validPosition(endPos) then return end
	local distance = (endPos - startPos).Magnitude
	if distance < 0.01 or distance > 512 then return end
	local count = math.clamp(math.ceil(distance / 2), 5, if low then 8 else 12)
	if usedParts + count > MAX_PARTS then return end
	-- Snapshot endpoints need no Parts or Attachments. The module accepts these tables.
	local axis = (endPos - startPos).Unit
	local bolt = LightningBolt.new(
		{WorldPosition = startPos, WorldAxis = axis},
		{WorldPosition = endPos, WorldAxis = axis}, count)
	bolt.Jagged = true
	bolt.Static = true
	bolt.StaticLifetime = LIFETIME
	bolt.Color = COLOR
	bolt.ColorOffsetSpeed = 0
	bolt.AnimationSpeed = 0
	bolt.Frequency = 1
	bolt.MinRadius = 0
	bolt.MaxRadius = math.min(1.1, distance * 0.16)
	bolt.Thickness = 0.095
	bolt.MinThicknessMultiplier = 0.65
	bolt.MaxThicknessMultiplier = 1
	bolt.ContractFrom = 2
	bolt.OpacityProfileFunction = opacity
	usedParts += count
	table.insert(active, {Bolt = bolt, Parts = count, Expires = clock() + LIFETIME})
end

local eventConnection = FXEvent.OnClientEvent:Connect(function(towerModel, chain)
	if typeof(towerModel) ~= "Instance" or not towerModel.Parent or type(chain) ~= "table" then return end
	local weapon = towerModel:FindFirstChild("Weapon")
	local handle = weapon and weapon:FindFirstChild("Handle")
	local origin = handle and handle:FindFirstChild("Lightning")
	if not origin or not origin:IsA("Attachment") then return end
	local previous = origin.WorldPosition
	local low = Policy.Quality() == "Low"
	for _, target in ipairs(chain) do
		local position = getHitPos(target)
		if not position then break end
		createBolt(previous, position, low)
		previous = position
	end
end)

-- One cleanup loop for every shot; Destroy returns geometry to the shared cache.
local heartbeat = RunService.Heartbeat:Connect(function()
	local now = clock()
	for i = #active, 1, -1 do
		local record = active[i]
		if now >= record.Expires then
			record.Bolt:Destroy()
			usedParts -= record.Parts
			active[i] = active[#active]
			active[#active] = nil
		end
	end
end)
script.Destroying:Connect(function()
	eventConnection:Disconnect()
	heartbeat:Disconnect()
	for _, record in active do record.Bolt:Destroy() end
	table.clear(active)
	usedParts = 0
end)
