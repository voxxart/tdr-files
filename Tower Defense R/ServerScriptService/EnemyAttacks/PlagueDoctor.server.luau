local Collection = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Behavior = require(script.Parent.Bosses.PlagueDoctor)
local function start(enemy)
	if enemy:IsDescendantOf(workspace) then Attacks.Add(enemy, Behavior(enemy)) end
end
for _, enemy in Collection:GetTagged('PlagueDoctor') do start(enemy) end
Collection:GetInstanceAddedSignal('PlagueDoctor'):Connect(start)
Collection:GetInstanceRemovedSignal('PlagueDoctor'):Connect(Attacks.Remove)
