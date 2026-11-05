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
local AttackService = {}
local pending = {}
function AttackService.Add(enemy, behavior)
	local runtime = Runtime.Get(enemy)
	if not enemy:IsDescendantOf(workspace) then return end
	if not runtime then
		-- Tag signals can arrive before a custom spawner finishes registration.
		pending[enemy] = {Behavior = behavior, Deadline = os.clock() + 2}
		return
	end
	if not Match.IsCurrent(runtime.MatchGeneration) then
		warn('Enemy attack not registered: inactive or missing MatchGeneration for', enemy:GetFullName(),
			'Check that EnemyService and Main.Round are both updated.')
		return
	end
	scheduler:Add(enemy, runtime.MatchGeneration, behavior)
end
function AttackService.Remove(enemy)
	pending[enemy] = nil
	scheduler:Remove(enemy)
end
RunService.Heartbeat:Connect(function()
	for enemy, request in pairs(pending) do
		if not enemy:IsDescendantOf(workspace) then
			pending[enemy] = nil
		elseif Runtime.Get(enemy) then
			pending[enemy] = nil
			AttackService.Add(enemy, request.Behavior)
		elseif os.clock() >= request.Deadline then
			pending[enemy] = nil
			warn('Enemy attack not registered: no EnemyRuntime for', enemy:GetFullName(),
				'Confirm this enemy was spawned by the updated EnemyService.')
		end
	end
	scheduler:Step()
end)
return AttackService
