local CollectionService = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local BreadDrops = require(script.Parent.Behaviors.BreadDrops)
local function start(enemy)
	if enemy:IsDescendantOf(workspace) then Attacks.Add(enemy, BreadDrops.new(enemy)) end
end
for _, enemy in CollectionService:GetTagged('BreadBearer') do start(enemy) end
CollectionService:GetInstanceAddedSignal('BreadBearer'):Connect(start)
CollectionService:GetInstanceRemovedSignal('BreadBearer'):Connect(Attacks.Remove)
