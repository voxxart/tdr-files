local RunService = game:GetService('RunService')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Scheduler = require(game.ServerScriptService.Simulation.AttackScheduler)
local Runtime = require(game.ServerScriptService.EnemySystem.EnemyRuntime)

local function alive(enemy)
	local runtime = Runtime.Get(enemy)
	return runtime ~= nil and not runtime.Dead and not runtime.Cleaned
		and runtime.Health > 0 and runtime.Model.Parent ~= nil
		and runtime.HealthValue.Value > 0
end

local scheduler = Scheduler.new({
	Now = Match.Now,
	IsCurrent = Match.IsCurrent,
	Alive = alive,
	Dispatch = task.spawn,
	Report = function(err) warn('Enemy attack failed:', err) end,
})

-- All migrated attacks share this single connection.
RunService.Heartbeat:Connect(function() scheduler:Step() end)
local AttackService = {}
function AttackService.Add(enemy, behavior)
	local runtime = Runtime.Get(enemy)
	if runtime then scheduler:Add(enemy, runtime.MatchGeneration, behavior) end
end
function AttackService.Remove(enemy)
	scheduler:Remove(enemy)
end
return AttackService
