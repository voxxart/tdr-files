local Lifetime = require('../Tower Defense R/ServerScriptService/Simulation/WaveLifetime')
local orb = {EndWave = 7}
assert(Lifetime.State(orb,6,10,true) == 'Active')
assert(Lifetime.State(orb,7,11,true) == 'Linger' and orb.ReleaseAt == 14)
assert(Lifetime.State(orb,8,11,false) == 'Linger', 'Hidden visual must retain its debuff while simulation is paused')
assert(Lifetime.State(orb,8,13.9,false) == 'Linger')
assert(Lifetime.State(orb,8,14,false) == 'Expired')
assert(Lifetime.State({EndWave = 7},6,10,false) == 'Expired', 'Premature visual removal must release resources')
print('Wave lifetime checks passed: wave expiry, three-second linger, pause, external removal')
