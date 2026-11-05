local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local TAG = "Inventor"
local TowersFolder = workspace:WaitForChild("Towers")
local THRESHOLD_HP = 400
local TICK_RATE = 0.2

-- =========================
-- Helpers
-- =========================
local function getHealth(model)
	local stats = model:FindFirstChild("EnemyStats")
	local hp = stats and stats:FindFirstChild("Health")
	return hp and hp.Value
end

local function hasBuffsFolder(tower)
	local config = tower:FindFirstChild("Config")
	local buffs = config and config:FindFirstChild("Buffs") or config:FindFirstChild("DamageBuffs")
	return buffs ~= nil and buffs:IsA("Folder")
end

-- =========================
-- Tower disable logic
-- =========================
local disabledTowers = {} -- [tower] = true, towers we've personally disabled

local function disableTower(tower)
	if disabledTowers[tower] then return end

	local config = tower:FindFirstChild("Config")
	if not config then return end

	local disabledValue = config:FindFirstChild("DISABLED")
	if not disabledValue then
		disabledValue = Instance.new("BoolValue")
		disabledValue.Name = "DISABLED"
		disabledValue.Parent = config
	end
	disabledValue.Value = true

	disabledTowers[tower] = true
end

local function clearDisabledTowers()
	for tower in pairs(disabledTowers) do
		if tower and tower.Parent then
			local config = tower:FindFirstChild("Config")
			local disabledValue = config and config:FindFirstChild("DISABLED")
			if disabledValue then
				disabledValue:Destroy()
			end
		end
	end
	table.clear(disabledTowers)
end

local function applyToAllTowers()
	for _, tower in ipairs(TowersFolder:GetChildren()) do
		if tower:IsA("Model") and hasBuffsFolder(tower) then
			disableTower(tower)
		end
	end
end

-- =========================
-- Caster detection
-- =========================
local function getActiveCaster()
	for _, caster in ipairs(CollectionService:GetTagged(TAG)) do
		if caster and caster.Parent and caster:IsDescendantOf(workspace) then
			local hp = getHealth(caster)
			if hp and hp > THRESHOLD_HP then
				return caster
			end
		end
	end
	return nil
end

-- =========================
-- Live Updates
-- =========================
local currentActive = false

-- if a new tower with a Buffs folder shows up mid-fight, disable it immediately
TowersFolder.ChildAdded:Connect(function(tower)
	if not currentActive then return end
	task.defer(function()
		if tower:IsA("Model") and hasBuffsFolder(tower) then
			disableTower(tower)
		end
	end)
end)

local nextTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextTick then return end
	nextTick = now + TICK_RATE

	local caster = getActiveCaster()
	local active = caster ~= nil

	if active ~= currentActive then
		currentActive = active

		if currentActive then
			applyToAllTowers()
		else
			-- caster dropped to/under the threshold (or died/despawned):
			-- remove every DISABLED bool value we handed out
			clearDisabledTowers()
		end
	end
end)
