local CollectionService = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Behavior = require(script.Parent.Behaviors.DirectTowerAttack)
local definition = {Range = 8, ExcludeCliff = true, MinCooldown = 3, MaxCooldown = 5, Damage = 0.25, DeathWishDamage = 0.30}
local function start(enemy) Attacks.Add(enemy, Behavior.new(enemy, definition)) end
for _, enemy in CollectionService:GetTagged('Knight') do start(enemy) end
CollectionService:GetInstanceAddedSignal('Knight'):Connect(start)
CollectionService:GetInstanceRemovedSignal('Knight'):Connect(Attacks.Remove)
