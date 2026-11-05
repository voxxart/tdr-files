local CollectionService = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Behavior = require(script.Parent.Behaviors.DirectTowerAttack)
local definition = {Range = 25, MinCooldown = 10, MaxCooldown = 14, Damage = 0.125, DeathWishDamage = 0.20, Hold = 1, Sound = 'Attack'}
local function start(enemy) Attacks.Add(enemy, Behavior.new(enemy, definition)) end
for _, enemy in CollectionService:GetTagged('NoobSoldier') do start(enemy) end
CollectionService:GetInstanceAddedSignal('NoobSoldier'):Connect(start)
CollectionService:GetInstanceRemovedSignal('NoobSoldier'):Connect(Attacks.Remove)
