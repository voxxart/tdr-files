local Rep = game:GetService('ReplicatedStorage')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Amount = require(game.ServerScriptService.Simulation.DamageAmount)
local Targeting = require(script.Parent.Parent.Targeting.NearestTower)
local Damage = require(script.Parent.TowerDamage)
local Mob = require(game.ServerScriptService.Main.Mob)
local Towers = workspace:WaitForChild('Towers')
local Attack = {}
function Attack.new(enemy, definition)
	local rng = Random.new()
	local cleanup = function() end
	return {
		InitialCooldown = if definition.InitialMin then function() return rng:NextNumber(definition.InitialMin, definition.InitialMax) end else nil,
		Cooldown = function()
			local minimum = if definition.CooldownAttributes then enemy:GetAttribute('AttackMin') or definition.MinCooldown else definition.MinCooldown
			local maximum = if definition.CooldownAttributes then enemy:GetAttribute('AttackMax') or definition.MaxCooldown else definition.MaxCooldown
			return rng:NextNumber(math.max(0, minimum), math.max(0, minimum, maximum))
		end,
		Cancel = function() cleanup() end,
		Run = function(active)
			local target = Targeting.Find(enemy, Towers, (if definition.RangeAttribute then enemy:GetAttribute('Range') else nil) or definition.Range, definition.ExcludeCliff)
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
				if definition.Hold and enemy.Parent and speed and speed.Parent and speed.Value == 0 then
					speed.Value = if orig and orig.Parent then orig.Value else saved
				end
			end
			local ok, err = pcall(function()
				local fraction = if workspace.Info.Modifiers['Death Wish'].Value then definition.DeathWishDamage else definition.Damage
				local health = target.Config.Health
				local amount = Amount.Percent(health.HealthValue.Value, health.MaxHealth.Value, fraction, definition.RoundRemaining)
				Damage.Apply(target, if definition.Lethal then health.HealthValue.Value else amount, generation, definition.DeathDelay)
				if definition.Hold then
					if speed then speed.Value = 0 end
					Mob.FacePart(enemy, target.PrimaryPart, definition.Hold / math.max(workspace.Info.GameSpeed.Value, 0.0001))
				else
					local root = enemy:FindFirstChild('HumanoidRootPart')
					if root then
						local position = target.PrimaryPart.Position
						enemy.Hitbox.CFrame = CFrame.lookAt(root.Position, Vector3.new(position.X, root.Position.Y, position.Z))
					end
				end
				Rep.Events.AnimateEnemy:FireAllClients(enemy, definition.Animation or 'Fire', target)
				if definition.SoundDelay and not Match.Wait(generation, definition.SoundDelay, active) then return end
				if definition.Sound and active() then
					local root = enemy:FindFirstChild('HumanoidRootPart')
					local sound = root and root:FindFirstChild(definition.Sound)
					if sound and sound:IsA('Sound') then sound:Play() end
				end
				if definition.Hold then Match.Wait(generation, math.max(0, definition.Hold - (definition.SoundDelay or 0)), active) end
			end)
			cleanup()
			if not ok then error(err, 0) end
		end,
	}
end
return Attack
