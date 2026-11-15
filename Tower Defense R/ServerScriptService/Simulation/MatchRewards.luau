-- Reward eligibility is captured once per match, never evaluated at payout time.
local Schedule=require(game.ReplicatedStorage.GameModules.EXPWeekend)
local info=workspace:WaitForChild('Info')
local Rewards={}
local capturedGeneration
local active=false
function Rewards.Begin(generation,timestamp)
 if capturedGeneration==generation then return end
 capturedGeneration=generation
 local started=timestamp or DateTime.now().UnixTimestamp
 active=Schedule.IsActive(started)
 info:SetAttribute('EXPWeekendStartedAt',started)
 info:SetAttribute('EXPWeekendActive',active)
end
function Rewards.ApplyXP(amount) return Schedule.ApplyXP(amount,active) end
return Rewards
