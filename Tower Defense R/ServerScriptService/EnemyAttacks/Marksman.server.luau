local CollectionService = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Marksman = require(script.Parent.Behaviors.Marksman)
local function start(enemy)
	Attacks.Add(enemy, Marksman.new(enemy))
end
for _, enemy in CollectionService:GetTagged('Marksman') do start(enemy) end
CollectionService:GetInstanceAddedSignal('Marksman'):Connect(start)
CollectionService:GetInstanceRemovedSignal('Marksman'):Connect(Attacks.Remove)
