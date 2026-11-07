local Collection = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Behavior = require(script.Parent.Bosses.Doombringer)
local function start(enemy)
	if enemy:IsDescendantOf(workspace) then Attacks.Add(enemy, Behavior(enemy)) end
end
for _, enemy in Collection:GetTagged('Doombringer') do start(enemy) end
Collection:GetInstanceAddedSignal('Doombringer'):Connect(start)
Collection:GetInstanceRemovedSignal('Doombringer'):Connect(Attacks.Remove)
