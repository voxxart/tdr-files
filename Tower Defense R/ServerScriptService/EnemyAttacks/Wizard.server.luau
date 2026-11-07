local Collection = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Behavior = require(script.Parent.Bosses.Wizard)
local function start(enemy)
	if enemy:IsDescendantOf(workspace) then Attacks.Add(enemy, Behavior(enemy)) end
end
for _, enemy in Collection:GetTagged('Wizard') do start(enemy) end
Collection:GetInstanceAddedSignal('Wizard'):Connect(start)
Collection:GetInstanceRemovedSignal('Wizard'):Connect(Attacks.Remove)
