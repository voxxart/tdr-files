local Amount = require('../Tower Defense R/ServerScriptService/Simulation/DamageAmount')
assert(Amount.Percent(100, 100, 0.4, false) == 40)
assert(Amount.Percent(100, 100, 0.5, false) == 50)
-- Executioner rounds remaining health, unlike the other attacks. At half
-- boundaries these differ; preserve the existing balance calculation.
assert(Amount.Percent(100, 10, 0.15, true) == 1)
assert(Amount.Percent(100, 10, 0.15, false) == 2)
assert(Amount.Percent(50.25, 101, 0.2, true) == 20.25)
print('Damage calculation checks passed: percentages and legacy remaining-health rounding')
