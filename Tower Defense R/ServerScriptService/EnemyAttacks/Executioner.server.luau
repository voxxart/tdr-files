local CollectionService = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Behavior = require(script.Parent.Behaviors.DirectTowerAttack)
local definition = {Range = 8, RangeAttribute = true, ExcludeCliff = true, MinCooldown = 6, MaxCooldown = 11, CooldownAttributes = true, Damage = 0.15, DeathWishDamage = 0.20, RoundRemaining = true, DeathDelay = 0}
local function start(enemy) Attacks.Add(enemy, Behavior.new(enemy, definition)) end
for _, enemy in CollectionService:GetTagged('Executioner') do start(enemy) end
CollectionService:GetInstanceAddedSignal('Executioner'):Connect(start)
CollectionService:GetInstanceRemovedSignal('Executioner'):Connect(Attacks.Remove)
