local CollectionService = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Summon = require(script.Parent.Behaviors.Summon)

local definition = {
	MinCooldown = 12,
	MaxCooldown = 13,
	Enemy = 'Undead Squire',
	Quantity = 4,
	HealthMultiplier = 2,
	SpeedMultiplier = 1,
	Sound = 'Death',
	Animation = 'Summon',
	ClientEffect = game:GetService('ReplicatedStorage').Events.MEU.Client,
}
local function start(enemy)
	Attacks.Add(enemy, Summon.new(enemy, definition))
end
for _, enemy in CollectionService:GetTagged('Necromancer') do start(enemy) end
CollectionService:GetInstanceAddedSignal('Necromancer'):Connect(start)
CollectionService:GetInstanceRemovedSignal('Necromancer'):Connect(Attacks.Remove)
