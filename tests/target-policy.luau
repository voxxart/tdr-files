local Policy = require('../Tower Defense R/ServerScriptService/Simulation/TargetPolicy')
local function record(distance,alpha,health,flying,aggro)
	return {Distance=distance, Alpha=alpha, Health=health, Flying=flying or false, Aggro=aggro or false}
end
local a,b = record(10,0.8,100),record(20,0.2,200)
assert(Policy.Better(a,b,'Near',false))
assert(Policy.Better(a,b,'First',false))
assert(Policy.Better(b,a,'Last',false))
assert(Policy.Better(b,a,'Strong',false))
assert(Policy.Better(a,b,'Weak',false))
assert(Policy.Better(record(100,0,1,true),a,'Near',true))
assert(Policy.Better(record(100,0,1,false,true),a,'Near',false))
assert(not Policy.Better(b,a,'Near',false))
print('Target policy checks passed: five modes, flying priority, aggro priority')
