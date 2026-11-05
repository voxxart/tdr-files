local Rep = game:GetService('ReplicatedStorage')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Sequence = require(game.ServerScriptService.Simulation.AttackSequence)
local Targeting = require(script.Parent.Parent.Targeting.NearestTower)
local Mob = require(game.ServerScriptService.Main.Mob)
local Damage = require(script.Parent.TowerDamage)
local Towers = workspace:WaitForChild('Towers')
local Marksman = {}

function Marksman.new(enemy)
	local rng = Random.new()
	local cleanup = function() end
	return {
		InitialCooldown = function() return rng:NextNumber(5, 8) end,
		Cooldown = function() return rng:NextNumber(22, 23) end,
		CooldownAfterRun = true,
		Cancel = function() cleanup() end,
		Run = function(active)
			local target = Targeting.Find(enemy, Towers, 25)
			if not target then return false end
			local generation = Match.Capture()
			local stats = enemy:FindFirstChild('EnemyStats')
			local speed = stats and stats:FindFirstChild('Speed')
			local original = stats and stats:FindFirstChild('OrigSpeed')
			local savedSpeed = speed and speed.Value
			local weapon = enemy:FindFirstChild('Weapon')
			local arrow = weapon and weapon:FindFirstChild('Arrow')
			local transparency = arrow and arrow.Transparency
			local cleaned = false
			cleanup = function()
				if cleaned then return end
				cleaned = true
				if arrow and arrow.Parent then arrow.Transparency = transparency end
				if enemy.Parent and speed and speed.Parent and speed.Value == 0 then
					speed.Value = if original and original.Parent then original.Value else savedSpeed
				end
			end
			local deathWish = workspace.Info.Modifiers['Death Wish'].Value
			local damage = math.round(target.Config.Health.MaxHealth.Value * (if deathWish then 0.5 else 0.4))
			return Sequence.Run({
				Active = active,
				ValidTarget = function() return Targeting.Valid(target, Towers) end,
				Windup = 2,
				Recovery = 2,
				Wait = function(seconds) return Match.Wait(generation, seconds, active) end,
				Cleanup = cleanup,
				Start = function()
					if speed then speed.Value = 0 end
					Mob.FacePart(enemy, target.PrimaryPart, 4 / math.max(workspace.Info.GameSpeed.Value, 0.0001))
					Rep.Events.AnimateEnemy:FireAllClients(enemy, 'Fire', target)
				end,
				Impact = function()
					local root = enemy:FindFirstChild('HumanoidRootPart')
					local sound = root and root:FindFirstChild('Attack')
					if sound and sound:IsA('Sound') then sound:Play() end
					Damage.Apply(target, damage, generation)
					Rep.Events.HardmodeEvents.Marksman.Arrow:FireAllClients(enemy, target)
					if arrow then arrow.Transparency = 1 end

				end,
			})
		end,
	}
end
return Marksman
