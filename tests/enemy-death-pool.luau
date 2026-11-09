local Pool=require('../Tower Defense R/ReplicatedStorage/GameModules/EnemyDeathPool')
local created,destroyed,resets=0,0,0
local adapter={Create=function(key) created+=1; return {Name=key} end,Begin=function(entry,args,time) entry.Start=time end,
 Update=function(entry,speed,time) entry.LastTime=time end,Reset=function() resets+=1 end,Destroy=function() destroyed+=1 end}
local pool=Pool.new(adapter,4,2)
assert(pool:Emit('A',{Duration=2}) and pool:Emit('A',{Duration=2}))
assert(not pool:Emit('A',{}))
pool:Step(1,0); assert(pool.Time==0 and #pool.Active==2,'pause must freeze expiry')
assert(pool:Emit('A',{Duration=2}) and pool:Emit('A',{Duration=2}))
pool:Step(0.1,1); assert(not pool:Emit('A',{}) and created==4)
pool:Step(2,1); assert(#pool.Active==0 and #pool.Free.A==4)
assert(pool:Emit('A',{}) and created==4,'same template should reuse its rig')
pool:Clear(); pool:Step(0,1)
assert(pool:Emit('B',{}) and created==5 and destroyed==1 and pool.Created==4,'new template evicts idle resources within the global cap')
for frame=1,100 do
 pool:Step(0.1,1)
 for _=1,100 do pool:Emit('B',{Duration=0.2}) end
 assert(pool.Created<=4 and #pool.Active<=4)
end
pool:Clear(); pool:Destroy(); assert(pool.Created==0 and next(pool.Free)==nil and created==destroyed)
print('Enemy death pool passed: burst/resource caps, pause, reuse, cross-template eviction, 10000 attempts, match cleanup')
