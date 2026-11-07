local Collection = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Behavior = require(script.Parent.Bosses.NoobJuggernaut)
local function start(enemy)
	if enemy:IsDescendantOf(workspace) then Attacks.Add(enemy, Behavior(enemy)) end
end
for _, enemy in Collection:GetTagged('NoobJuggernaut') do start(enemy) end
Collection:GetInstanceAddedSignal('NoobJuggernaut'):Connect(start)
Collection:GetInstanceRemovedSignal('NoobJuggernaut'):Connect(Attacks.Remove)
