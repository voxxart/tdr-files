-- Presentation/classification defaults. No new resistance or balance rules implied.
local Profiles = {}
Profiles.Types = {None = true, Bullet = true, Fire = true, Laser = true, Energy = true, Melee = true, Explosion = true}
Profiles.Towers = {
	Trooper = 'Bullet', Marksman = 'Bullet', Knifer = 'Melee', Reaper = 'Melee',
	['Mine Layer'] = 'Explosion', Demolitionist = 'Explosion', Shocker = 'Energy',
	Flamethrower = 'Fire', Operator = 'Bullet', ['Machine Gunner'] = 'Bullet',
	Aviator = 'Bullet', Shotgunner = 'Bullet', Sergeant = 'Bullet', Scrambler = 'Energy',
	Railgunner = 'Energy', Heavy = 'Bullet', Mortar = 'Explosion', Helicopter = 'Bullet',
	Outlaw = 'Bullet', Beamer = 'Laser', ['Golden Heavy'] = 'Bullet', ['Golden Outlaw'] = 'Bullet',
}
function Profiles.Resolve(name, explicit)
	if explicit and Profiles.Types[explicit] then return explicit end
	return Profiles.Towers[name] or 'None'
end
return Profiles
