local Match = require(game.ServerScriptService.Simulation.MatchService)
local Burst = {}
function Burst.new(context)
	return function(model, target)
		local data = context.Towers[model]
		if not model.Parent or model:GetAttribute('ReaperSummoning') == true or not data
			or data.isBursting or not Match.IsCurrent(data.MatchGeneration) then return end
		local config = data.config
		if not config or not config.Parent then return end
		data.isBursting = true
		data.burstGen = (data.burstGen or 0) + 1
		local version = data.burstGen
		local function active()
			local health = config:FindFirstChild('Health')
			return model.Parent ~= nil and config.Parent ~= nil and context.Towers[model] == data
				and data.burstGen == version and (not health or not health:FindFirstChild('HealthValue') or health.HealthValue.Value > 0)
		end
		task.spawn(function()
			local ok, err = pcall(function()
				local count = config:FindFirstChild('MaxBurst')
				local cooldown = config:FindFirstChild('OGCooldown') or config:FindFirstChild('Cooldown')
				for i=1,(count and count.Value or 1) do
					if not active() or not Match.IsCurrent(data.MatchGeneration) then return end
					context.Tower.DoAttackLogic(model, data.player, config, if i == 1 then target else nil)
					if not Match.Wait(data.MatchGeneration, cooldown and cooldown.Value or 1, active) then return end
				end
				local delay = config:FindFirstChild('Delay')
				if delay and delay.Value > 0 then Match.Wait(data.MatchGeneration, delay.Value, active) end
			end)
			if context.Towers[model] == data and data.burstGen == version then data.isBursting = false end
			if not ok then warn('Tower burst failed:', model.Name, err) end
		end)
	end
end
return Burst
