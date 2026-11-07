local Match = require(game.ServerScriptService.Simulation.MatchService)
local Scheduler = {}
Scheduler.__index = Scheduler
function Scheduler.new(context) return setmetatable({Context = context}, Scheduler) end
local function report(model, action, err)
	warn('Tower ' .. action .. ' failed:', model.Name, err)
end
function Scheduler:Step()
	local context = self.Context
	local tower, towers = context.Tower, context.Towers
	local now, wall = Match.Now(), os.clock()
	for model, data in pairs(towers) do
		local config = data.config
		if model.Parent and config and config.Parent and data.PendingMatch then
			local generation = Match.Capture()
			if Match.IsCurrent(generation) then
				data.MatchGeneration = generation
				data.PendingMatch = false
				data.nextAttack, data.nextSecondary, data.lastAttack = 0, 0, 0
			else
				-- Keep pregame placements registered without executing combat.
				continue
			end
		end
		if not model.Parent or not config or not config.Parent or not Match.IsCurrent(data.MatchGeneration) then
			data.burstGen = (data.burstGen or 0) + 1
			context.Projectiles.Cancel(model)
			towers[model] = nil
			continue
		end
		-- Pause is authoritative; cached legacy speed helpers used 1 for zero.
		if workspace.Info.GameSpeed.Value <= 0 or model:GetAttribute('ReaperSummoning') == true then continue end
		local health = config:FindFirstChild('Health')
		if health and health:FindFirstChild('HealthValue') and health.HealthValue.Value <= 0 then
			context.Projectiles.Cancel(model); continue
		end
		local flying = config:FindFirstChild('Flying')
		if flying and wall - (data.heliLast or 0) >= (data.heliRate or 1/60) then
			data.heliLast = wall
			local ok, err = pcall(tower.Helicopter, model, data.player)
			if not ok then report(model,'movement',err) end
		end
		if config:FindFirstChild('Aviator') then tower.Aviator(model) end
		if config:FindFirstChild('Stunned') then continue end
		local stunnedUntil = config:GetAttribute('StunnedUntil')
		if stunnedUntil and wall < stunnedUntil then continue end
		if data.isPhaser then
			-- Keep its authored phase machine on its legacy wall-time contract.
			if not data.phaserBusy then
				data.phaserBusy = true
				task.spawn(function()
					local ok, err = pcall(tower.PhaserTick, model, data, wall)
					data.phaserBusy = false
					if not ok then report(model,'phaser',err) end
				end)
			end
		else
			local burstValue = config:FindFirstChild('Burst')
			local burst = burstValue and (not burstValue:IsA('BoolValue') or burstValue.Value == true)
			local cooldownObject = config:FindFirstChild('Cooldown')
			local cooldown = cooldownObject and cooldownObject.Value or 1
			local ready = if burst then now - (data.lastAttack or 0) >= cooldown else now >= (data.nextAttack or 0)
			if ready and not data.primaryBusy and not data.isBursting and now >= (data.nextIdleCheck or 0) then
				local targetMode = config:FindFirstChild('TargetMode')
				local range = config:FindFirstChild('Range')
				local target = tower.FindTarget(model, range and range.Value, targetMode and targetMode.Value or 'First')
				if target then
					data.nextIdleCheck = nil
					if burst then data.lastAttack = now; tower.Burst(model, target)
					else
						data.nextAttack = now + cooldown
						data.primaryBusy = true
						task.spawn(function()
							local ok, err = pcall(tower.DoAttackLogic, model, data.player, config, target)
							data.primaryBusy = false
							if not ok then report(model,'primary',err) end
						end)
					end
				else data.nextIdleCheck = now + 0.2 end
			end
		end
		local secondary = config:FindFirstChild('Secondary')
		if secondary and now >= (data.nextSecondary or 0) and not data.secondaryBursting then
			local delayValue = secondary:FindFirstChild('Delay')
			local countValue = secondary:FindFirstChild('MaxBurst')
			local cooldownValue = secondary:FindFirstChild('Cooldown')
			local delay = delayValue and delayValue.Value or 0
			local count = countValue and countValue.Value or 1
			local cooldown = cooldownValue and cooldownValue.Value or 1
			data.nextSecondary = now + delay + count * cooldown
			data.secondaryBursting = true
			local function active()
				return model.Parent ~= nil and config.Parent ~= nil and secondary.Parent == config and towers[model] == data
			end
			task.spawn(function()
				local ok, err = pcall(function()
					if delay > 0 and not Match.Wait(data.MatchGeneration, delay, active) then return end
					for i = 1,count do
						if not active() or not Match.IsCurrent(data.MatchGeneration) then return end
						tower.DoSecondaryAttackLogic(model, data.player, config, secondary)
						if i < count and not Match.Wait(data.MatchGeneration, cooldown, active) then return end
					end
				end)
				data.secondaryBursting = false
				if not ok then report(model,'secondary',err) end
			end)
		end
	end
end
return Scheduler
