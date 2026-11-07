local Collection = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Behavior = require(script.Parent.Bosses.Swordmaster)
local function start(enemy)
	if enemy:IsDescendantOf(workspace) then Attacks.Add(enemy, Behavior(enemy)) end
end
for _, enemy in Collection:GetTagged('Swordmaster') do start(enemy) end
Collection:GetInstanceAddedSignal('Swordmaster'):Connect(start)
Collection:GetInstanceRemovedSignal('Swordmaster'):Connect(Attacks.Remove)
