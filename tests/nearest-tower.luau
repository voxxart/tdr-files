local Targeting = require('../Tower Defense R/ServerScriptService/EnemyAttacks/Targeting/NearestTower')
local function node(fields)
	fields = fields or {}
	function fields:FindFirstChild(name) return self[name] end
	return fields
end
local origin = {}
local function position(x, z)
	return setmetatable({X = x, Z = z}, {__sub = function(a, _) return a end})
end
local folder = {Children = {}}
function folder:GetChildren() return self.Children end
local function tower(x, z, flag)
	local config = node({Health = node({HealthValue = {Value = 100}, MaxHealth = {Value = 100}})})
	if flag then config[flag] = {} end
	local t = node({Parent = folder, PrimaryPart = {Position = position(x, z)}, Config = config})
	function t:GetAttribute(name) return self[name] end
	return t
end
local enemy = node({Hitbox = {Position = origin}})
local cliff, ground, flying, boundary = tower(1,0,'CliffTower'), tower(3,0), tower(0,0,'Flying'), tower(8,0)
folder.Children = {flying, cliff, ground, boundary}
assert(Targeting.Find(enemy, folder, 8) == cliff)
assert(Targeting.Find(enemy, folder, 8, true) == ground)
ground.Config.Health.HealthValue.Value = 0
assert(Targeting.Find(enemy, folder, 8, true) == nil, 'Dead and boundary towers must be excluded')
cliff.Dying = true
assert(Targeting.Find(enemy, folder, 8) == nil, 'Dying towers must be excluded')
print('Targeting checks passed: nearest, flying, cliff, dead, dying, strict range')
