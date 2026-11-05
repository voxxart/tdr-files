local CollectionService = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Enforcer = require(script.Parent.Behaviors.Enforcer)
local function start(enemy) Attacks.Add(enemy, Enforcer.new(enemy)) end
for _, enemy in CollectionService:GetTagged('Enforcer') do start(enemy) end
CollectionService:GetInstanceAddedSignal('Enforcer'):Connect(start)
CollectionService:GetInstanceRemovedSignal('Enforcer'):Connect(Attacks.Remove)
