local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local TAG = "Elm"
local HEAL_AMOUNT = 200

local HEAL_INTERVAL = 4

local timer = 0

-- cached list refresh (avoids calling GetTagged every frame)
local casters = {}

local function refreshCasters()
	casters = CollectionService:GetTagged(TAG)
end

local function getStats(model)
	local stats = model:FindFirstChild("EnemyStats")
	if not stats then return end

	local hp = stats:FindFirstChild("Health")
	local maxHp = stats:FindFirstChild("MaxHealth")
	if not (hp and maxHp) then return end

	return hp, maxHp
end

RunService.Heartbeat:Connect(function(dt)
	timer += dt
	if timer < HEAL_INTERVAL then return end
	timer = 0

	refreshCasters()

	for i = 1, #casters do
		local caster = casters[i]
		if caster and caster.Parent then
			local hp, maxHp = getStats(caster)
			if hp and maxHp and hp.Value < maxHp.Value then
				local newHp = hp.Value + HEAL_AMOUNT
				hp.Value = (newHp < maxHp.Value) and newHp or maxHp.Value
			end
		end
	end
end)