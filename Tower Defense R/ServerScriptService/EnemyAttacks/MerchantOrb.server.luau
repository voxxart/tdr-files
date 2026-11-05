local Collection = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Merchant = require(script.Parent.Behaviors.Merchant)
local function start(enemy) Attacks.Add(enemy, Merchant.new(enemy)) end
for _, enemy in Collection:GetTagged('Merchant') do start(enemy) end
Collection:GetInstanceAddedSignal('Merchant'):Connect(start)
Collection:GetInstanceRemovedSignal('Merchant'):Connect(Attacks.Remove)
