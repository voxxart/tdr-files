local Rep = game:GetService('ReplicatedStorage')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Sequence = require(game.ServerScriptService.Simulation.AttackSequence)
local Targeting = require(script.Parent.Parent.Targeting.NearestTower)
local Mob = require(game.ServerScriptService.Main.Mob)
local Towers = workspace:WaitForChild('Towers')
local Enforcer = {}
function Enforcer.new(enemy)
	local rng = Random.new()
	local cleanup = function() end
	return {
		Cooldown = function() return rng:NextNumber(10, 14) end,
		Cancel = function() cleanup() end,
		Run = function(active)
			local target = Targeting.Find(enemy, Towers, 8, true)
			if not target or not active() then return end
			local generation = Match.Capture()
			local stats = enemy:FindFirstChild('EnemyStats')
			local speed = stats and stats:FindFirstChild('Speed')
			local orig = stats and stats:FindFirstChild('OrigSpeed')
			local saved = speed and speed.Value
			local cleaned = false
			cleanup = function()
				if cleaned then return end
				cleaned = true
				if enemy.Parent and speed and speed.Parent and speed.Value == 0 then
					speed.Value = if orig and orig.Parent then orig.Value else saved
				end
			end
			Sequence.Run({
				Active = active,
				ValidTarget = function() return Targeting.Valid(target, Towers) end,
				Wait = function(seconds) return Match.Wait(generation, seconds, active) end,
				Windup = 1, Recovery = 0.67, Cleanup = cleanup,
				Start = function()
					if speed then speed.Value = 0 end
					Mob.FacePart(enemy, target.PrimaryPart, 1.67 / math.max(workspace.Info.GameSpeed.Value, 0.0001))
					Rep.Events.AnimateEnemy:FireAllClients(enemy, 'Attack', target)
				end,
				Impact = function()
					local root = enemy:FindFirstChild('HumanoidRootPart')
					local sound = root and root:FindFirstChild('Slam')
					if sound and sound:IsA('Sound') then sound:Play() end
					local config = target.Config
					local stunned = config:FindFirstChild('Stunned')
					if not stunned then
						stunned = Instance.new('NumberValue')
						stunned.Name = 'Stunned'
						stunned.Parent = config
					end
					local duration = if workspace.Info.Modifiers['Death Wish'].Value then 13 else 10
					-- Preserve stronger concurrent stuns rather than shortening them.
					stunned.Value = math.max(stunned.Value, duration)
				end,
			})
		end,
	}
end
return Enforcer
