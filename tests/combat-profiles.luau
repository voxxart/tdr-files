local Profiles = require('../Tower Defense R/ReplicatedStorage/GameModules/CombatProfiles')
assert(Profiles.Resolve('Trooper') == 'Bullet')
assert(Profiles.Resolve('Flamethrower') == 'Fire')
assert(Profiles.Resolve('Beamer') == 'Laser')
assert(Profiles.Resolve('Trooper','Energy') == 'Energy')
assert(Profiles.Resolve('Unknown') == 'None')
assert(Profiles.Resolve('Trooper','invalid') == 'Bullet')
for name,kind in pairs(Profiles.Towers) do assert(Profiles.Types[kind], name) end
print('Combat profile checks passed: defaults, overrides, unknowns, valid classifications')
