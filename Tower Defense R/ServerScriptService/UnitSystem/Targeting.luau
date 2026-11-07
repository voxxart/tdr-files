local Spatial = require(game.ServerScriptService.TowerSystem.Targeting)
local EnemyRuntime = require(game.ServerScriptService.EnemySystem.EnemyRuntime)
local Policy = require(game.ServerScriptService.Simulation.TargetPolicy)
local Targeting = {}
function Targeting.Find(model, origin, range)
	local ownerValue = model:FindFirstChild('OwnerTower')
	local owner = ownerValue and ownerValue.Value
	local ownerConfig = owner and owner:FindFirstChild('Config')
	local targetMode = ownerConfig and ownerConfig:FindFirstChild('TargetMode')
	local mode = targetMode and targetMode.Value or 'First'
	local best, target
	local candidate = {}
	Spatial.Visit(origin,range,function(mob)
		local stats = mob:FindFirstChild('EnemyStats')
		local hitbox = mob:FindFirstChild('Hitbox')
		local hp = stats and stats:FindFirstChild('Health')
		if not hitbox or not hp or hp.Value <= 0 then return end
		local flying = stats:FindFirstChild('Flying')
		if flying and flying.Value then return end
		local aggro = stats:FindFirstChild('Aggro') ~= nil
		local maxHp = stats:FindFirstChild('MaxHealth')
		if not aggro and ownerConfig and ownerConfig:FindFirstChild('BeamerSettings') and maxHp and maxHp.Value < 500 then return end
		local runtime = EnemyRuntime.Get(mob)
		local alpha = mob:FindFirstChild('Alpha')
		local p = hitbox.Position-origin
		candidate.Aggro = aggro; candidate.Flying = false; candidate.Health = hp.Value
		candidate.Alpha = if runtime then runtime.Alpha else (alpha and alpha.Value or 0)
		candidate.Distance = p.X*p.X+p.Z*p.Z
		if Policy.Better(candidate,best,mode,false) then
			best = best or {}; for key,value in pairs(candidate) do best[key] = value end
			target = mob
		end
	end)
	return target
end
return Targeting
