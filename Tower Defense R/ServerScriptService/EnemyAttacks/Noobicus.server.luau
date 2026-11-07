local Collection = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Behavior = require(script.Parent.Bosses.Noobicus)
local function start(enemy)
	if enemy:IsDescendantOf(workspace) then Attacks.Add(enemy, Behavior(enemy)) end
end
for _, enemy in Collection:GetTagged('Noobicus') do start(enemy) end
Collection:GetInstanceAddedSignal('Noobicus'):Connect(start)
Collection:GetInstanceRemovedSignal('Noobicus'):Connect(Attacks.Remove)
