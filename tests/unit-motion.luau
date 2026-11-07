local Motion = require('../Tower Defense R/ServerScriptService/Simulation/UnitMotion')
local alpha=0
for _=1,10 do alpha=Motion.Advance(alpha,10,0.1,100,false) end
assert(math.abs(alpha-0.1)<0.00001)
alpha=Motion.Advance(alpha,10,10,100,true)
assert(math.abs(alpha-0.1)<0.00001, 'Attack hold must freeze movement')
alpha=Motion.Advance(alpha,10,2,100,false)
assert(math.abs(alpha-0.3)<0.00001)
assert(Motion.Advance(0.9,100,1,100,false)==1)
assert(Motion.Advance(0,1,1,0,false)==1, 'Degenerate lengths must remain finite')
print('Unit movement checks passed: distance, hold, variable steps, path completion')
