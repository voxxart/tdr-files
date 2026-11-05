local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TAG = "RNG"
local mobsFolder = workspace:WaitForChild("Mobs")
local THRESHOLD_HP = 500
local TICK_RATE = 0.2

local shieldTemplate =
	ReplicatedStorage:FindFirstChild("Particle")
	and ReplicatedStorage.Particle:FindFirstChild("Shield")

if not shieldTemplate then
	warn("Shield particle not found in ReplicatedStorage.Particle.Shield")
end

-- =========================
-- Helpers
-- =========================
local function isCaster(model)
	return CollectionService:HasTag(model, TAG)
end

local function getHealth(model)
	local stats = model:FindFirstChild("EnemyStats")
	local hp = stats and stats:FindFirstChild("Health")
	return hp and hp.Value
end

local function getHipHeight(stats)
	local hipObj = stats and stats:FindFirstChild("HipHeight")
	if hipObj and hipObj:IsA("NumberValue") then
		return hipObj.Value
	end
	return 2
end

local function ensureInvincible(stats)
	if not stats then return end
	local inv = stats:FindFirstChild("Invincible")
	if not inv then
		inv = Instance.new("BoolValue")
		inv.Name = "Invincible"
		inv.Parent = stats
	end
	inv.Value = true
end

local function removeInvincible(stats)
	if not stats then return end
	local inv = stats:FindFirstChild("Invincible")
	if inv then inv:Destroy() end
end

local function ensureShield(mob)
	if not shieldTemplate then return end

	local stats = mob:FindFirstChild("EnemyStats")
	local hitbox = mob:FindFirstChild("Hitbox")
	if not stats or not hitbox then return end

	if hitbox:FindFirstChild("Shield") then return end

	local shield = shieldTemplate:Clone()
	shield.Name = "Shield"

	local hipHeight = getHipHeight(stats)
	local scaleFactor = 3.15 * ((hipHeight * 4) + 0.2)

	if shield:IsA("BasePart") then
		shield.Size = Vector3.new(scaleFactor, scaleFactor, scaleFactor)
		shield.CFrame = hitbox.CFrame
	end

	shield.Parent = hitbox

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hitbox
	weld.Part1 = shield
	weld.Parent = hitbox
end

local function removeShield(mob)
	local hitbox = mob:FindFirstChild("Hitbox")
	if not hitbox then return end

	local shield = hitbox:FindFirstChild("Shield")
	if shield then
		local breakSound = shield:FindFirstChild("Break")
		if breakSound and breakSound:IsA("Sound") then
			breakSound:Play()
		end
		shield:Destroy()
	end
end

-- =========================
-- Beam Logic
-- =========================
local beamConnections = {} -- track beams per mob so we can clean up

local function removeBeams(mob)
	if beamConnections[mob] then
		for _, beam in ipairs(beamConnections[mob]) do
			if beam and beam.Parent then
				beam:Destroy()
			end
		end
		beamConnections[mob] = nil
	end
end

local function ensureBeams(caster, mob)
	-- Don't beam casters to themselves or re-create if already present
	if mob == caster then return end
	if beamConnections[mob] then return end

	local core = caster:FindFirstChild("Core")
	local neon = core and core:FindFirstChild("Neon")
	local template = neon and neon:FindFirstChild("TemplateBeam")
	local neonAttachment = neon and neon:FindFirstChild("Attachment")

	if not template or not neonAttachment then return end

	local torso = mob:FindFirstChild("Torso")
	local centerAttachment = torso and torso:FindFirstChild("Center")

	if not centerAttachment then return end

	beamConnections[mob] = beamConnections[mob] or {}

	local beamCount = #beamConnections[mob] + 1
	local beam = template:Clone()
	beam.Name = "Beam" .. beamCount
	beam.Attachment0 = neonAttachment
	beam.Attachment1 = centerAttachment
	beam.Parent = neon

	table.insert(beamConnections[mob], beam)

	-- Auto-clean if mob is removed
	mob.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeBeams(mob)
		end
	end)
end

-- =========================
-- Aura Logic
-- =========================
local function setAuraOnMob(mob, enabled, caster)
	if not mob or mob.Parent ~= mobsFolder or not mob:IsA("Model") then return end

	local stats = mob:FindFirstChild("EnemyStats")
	if isCaster(mob) then
		removeShield(mob)
		removeInvincible(stats)
		return
	end

	if enabled and caster then
		ensureInvincible(stats)
		ensureShield(mob)
		ensureBeams(caster, mob)
	else
		removeShield(mob)
		removeInvincible(stats)
		removeBeams(mob)
	end
end

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

local function applyAura(active, caster)
	for _, mob in ipairs(mobsFolder:GetChildren()) do
		setAuraOnMob(mob, active, caster)
	end
end

-- =========================
-- Live Updates
-- =========================
local currentActive = false
local currentCaster = nil

mobsFolder.ChildAdded:Connect(function(mob)
	task.defer(function()
		setAuraOnMob(mob, currentActive, currentCaster)
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
		currentCaster = caster
		applyAura(currentActive, currentCaster)
	end
end)

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(caster)
	task.defer(function()
		setAuraOnMob(caster, false, nil)
	end)
end)