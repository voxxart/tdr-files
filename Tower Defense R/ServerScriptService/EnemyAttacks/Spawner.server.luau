local CollectionService = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Summon = require(script.Parent.Behaviors.Summon)

local function start(enemy)
	local stats = enemy:FindFirstChild('EnemyStats')
	local cooldown = stats and stats:FindFirstChild('Cooldown')
	if not cooldown then
		if enemy:IsDescendantOf(workspace) then
			warn('Spawner requires EnemyStats.Cooldown:', enemy:GetFullName())
		end
		return
	end
	Attacks.Add(enemy, Summon.new(enemy, {
		Enemy = 'Spawned Armored Noob',
		Quantity = 3,
		HealthMultiplier = 2,
		SpeedMultiplier = 1,
		-- Keep the original short first-cast stagger, then read live cooldowns.
		InitialCooldown = function() return math.random() end,
		Cooldown = function() return math.max(0, cooldown.Value) end,
	}))
end
for _, enemy in CollectionService:GetTagged('Spawner') do start(enemy) end
CollectionService:GetInstanceAddedSignal('Spawner'):Connect(start)
CollectionService:GetInstanceRemovedSignal('Spawner'):Connect(Attacks.Remove)
