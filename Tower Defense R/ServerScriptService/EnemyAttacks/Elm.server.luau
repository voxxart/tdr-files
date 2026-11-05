local Collection = game:GetService('CollectionService')
local Attacks = require(script.Parent.AttackService)
local Elm = require(script.Parent.Behaviors.Elm)
local function start(enemy) Attacks.Add(enemy, Elm.new(enemy)) end
for _, enemy in Collection:GetTagged('Elm') do start(enemy) end
Collection:GetInstanceAddedSignal('Elm'):Connect(start)
Collection:GetInstanceRemovedSignal('Elm'):Connect(Attacks.Remove)
