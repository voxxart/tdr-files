local Collection = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Direct = require(script.Parent.Behaviors.DirectTowerAttack)
local Rewards = require(script.Parent.Behaviors.MarauderRewards)
local function start(enemy)
	if not enemy:IsDescendantOf(workspace) then return end
	local behavior = Direct.new(enemy, {
		Range = 8, RangeAttribute = true, MinCooldown = 10, MaxCooldown = 11,
		Damage = 1, DeathWishDamage = 1, Lethal = true, DeathDelay = 0,
		Animation = 'Attack', Sound = 'Attack',
	})
	local detach
	local cancel = behavior.Cancel
	behavior.Attach = function() detach = Rewards.Attach(enemy) end
	behavior.Cancel = function() cancel(); if detach then detach(); detach = nil end end
	Attacks.Add(enemy, behavior)
end
for _, enemy in Collection:GetTagged('Marauder') do start(enemy) end
Collection:GetInstanceAddedSignal('Marauder'):Connect(start)
Collection:GetInstanceRemovedSignal('Marauder'):Connect(Attacks.Remove)
