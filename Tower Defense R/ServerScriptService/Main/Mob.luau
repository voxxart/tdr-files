-- ServerScriptService/Main/Mob.lua
-- Drop-in compatibility wrapper.

local EnemyService = require(
	game.ServerScriptService.EnemySystem:WaitForChild("EnemyService")
)

local mob = {}

function mob.Spawn(...)
	return EnemyService.Spawn(...)
end

function mob.ArrowSpawn(...)
	return EnemyService.ArrowSpawn(...)
end

function mob.Summon(...)
	return EnemyService.Summon(...)
end

function mob.GetClosestWaypointPath(...)
	return EnemyService.GetClosestWaypointPath(...)
end

function mob.FacePart(...)
	return EnemyService.FacePart(...)
end

function mob.Explode(...)
	return EnemyService.Explode(...)
end

return mob
