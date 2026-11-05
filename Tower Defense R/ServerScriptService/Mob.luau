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

function mob.SetEffects(model)
	return model
end

-- Legacy entry points are intentionally no-ops:
-- compatibility Effect values are captured by EnemyService.
function mob.Burning() end
function mob.Bleeding() end
function mob.Stunned() end

return mob
