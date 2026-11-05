local CollectionService = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Summon = require(script.Parent.Behaviors.Summon)

local definition = {
	MinCooldown = 8,
	MaxCooldown = 9,
	Enemy = 'Summoned Armored Zombie',
	Quantity = 3,
	HealthMultiplier = 1.18,
	SpeedMultiplier = 1,
	Sound = 'Summon',
	ClientEffect = game:GetService('ReplicatedStorage').Events.MEU.Client,
}
local function start(enemy)
	Attacks.Add(enemy, Summon.new(enemy, definition))
end
for _, enemy in CollectionService:GetTagged('MEU') do start(enemy) end
CollectionService:GetInstanceAddedSignal('MEU'):Connect(start)
CollectionService:GetInstanceRemovedSignal('MEU'):Connect(Attacks.Remove)
