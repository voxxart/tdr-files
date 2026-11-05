local CollectionService = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Behavior = require(script.Parent.Behaviors.DirectTowerAttack)
local definition = {Range = 5, ExcludeCliff = true, InitialMin = 5, InitialMax = 6, MinCooldown = 10, MaxCooldown = 14, Damage = 0.4, DeathWishDamage = 0.5, Hold = 0.75, Sound = 'Attack', SoundDelay = 0.5, Animation = 'AttackTower'}
local function start(enemy) Attacks.Add(enemy, Behavior.new(enemy, definition)) end
for _, enemy in CollectionService:GetTagged('Assassin') do start(enemy) end
CollectionService:GetInstanceAddedSignal('Assassin'):Connect(start)
CollectionService:GetInstanceRemovedSignal('Assassin'):Connect(Attacks.Remove)
