local Quota=require('../Tower Defense R/ServerScriptService/EventCurrencySystem/Quota')
local Config=require('../Tower Defense R/ReplicatedStorage/GameModules/EventCurrencyConfig')
assert(Config.ModeQuotas.Easy==145 and Config.ModeQuotas.Normal==315 and Config.ModeQuotas.Hard==650)
local q=Quota.new()
for mode,target in pairs(Config.ModeQuotas) do
 q:Begin(1,mode,Config)
 local total=0
 while total<target do
  local rolled=math.random(1,9)
  local reserved=q:Reserve(1,rolled)
  assert(reserved<=rolled and total+q:State(1).Reserved<=target)
  local credited=q:ClaimAmount(1,reserved); q:Collected(1,credited,reserved); total+=credited
 end
 assert(total==target and q:Available(1)==0 and q:Reserve(1,5)==0)
 assert(q:Available(2)==target,'players must have independent budgets')
 local reserved=q:Reserve(2,7); q:Release(2,reserved); assert(q:Available(2)==target,'expiry returns budget')
 assert(q:Shortfall(1)==0 and q:Shortfall(2)==target)
end
q:Begin(2,'Easy',Config); assert(q:Available(1)==145,'new match resets the quota, not the saved wallet')
q.Finished=true; assert(q:Available(1)==0)
print('Event quotas passed: exact 145/315/650 caps, random piles, independent players, reservations/expiry and restart')
