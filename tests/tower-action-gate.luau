local Gate=require('../Tower Defense R/ReplicatedStorage/GameModules/TowerActionGate')
local gate=Gate.new()
local a,b={},{}
local calls=0
local thread=coroutine.create(function()
 local ok,result=gate:Run(a,function(captured)
  assert(captured==a); calls+=1
  coroutine.yield()
  return 'done'
 end)
 assert(ok and result=='done')
end)
assert(coroutine.resume(thread))
local ok=gate:Run(a,function() error('duplicate request') end)
assert(not ok and calls==1)
local ok2,value=gate:Run(b,function() return 5 end)
assert(ok2 and value==5)
assert(coroutine.resume(thread))
local failed=gate:Run(a,function() error('remote failure') end)
assert(not failed)
local recovered=gate:Run(a,function() return true end)
assert(recovered)
print('Tower action gate passed: duplicate rejection, captured target, independent towers, failure recovery')
