local Runtime = require(game.ServerScriptService.EnemySystem.EnemyRuntime)
local Elm = {}
function Elm.new(enemy)
	return {
		Cooldown = function() return 4 end,
		Run = function(active)
			if not active() then return end
			local runtime = Runtime.Get(enemy)
			local health = runtime and runtime.HealthValue
			if health and health.Value > 0 then
				local amount = math.min(200, runtime.MaxHealth - health.Value)
				if amount > 0 then
					runtime.Health = health.Value + amount
					health.Value = runtime.Health
				end
			end
		end,
	}
end
return Elm
