local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Mob = require(game.ServerScriptService.Main.Mob)

local Summon = {}
function Summon.new(enemy, definition)
	local rng = Random.new()
	return {
		InitialCooldown = definition.InitialCooldown,
		Cooldown = definition.Cooldown or function()
			local minimum = enemy:GetAttribute('SummonMin') or definition.MinCooldown
			local maximum = enemy:GetAttribute('SummonMax') or definition.MaxCooldown
			return rng:NextNumber(math.max(0, minimum), math.max(minimum, maximum, 0))
		end,
		Run = function(active)
			if not active() then return end
			local map = workspace.Map:FindFirstChildOfClass('Folder')
			local hitbox = enemy:FindFirstChild('Hitbox')
			local alpha = enemy:FindFirstChild('Alpha')
			if not map or not hitbox or not alpha then
				warn('Summon skipped: missing map, Hitbox or Alpha for', enemy:GetFullName())
				return
			end
			local path, length, positions = Mob.GetClosestWaypointPath(map, hitbox.CFrame)
			if not path then
				warn('Summon skipped: no valid waypoint path for', enemy:GetFullName())
				return
			end
			if not active() then return end
			local root = enemy:FindFirstChild('HumanoidRootPart')
			local sound = definition.Sound and root and root:FindFirstChild(definition.Sound)
			if sound then
				sound.PlaybackSpeed = math.max(0, workspace.Info.GameSpeed.Value)
				sound:Play()
			end
			if definition.Animation then
				ReplicatedStorage.Events.AnimateEnemy:FireAllClients(enemy, definition.Animation, enemy)
			end
			if definition.ClientEffect then
				definition.ClientEffect:FireAllClients(enemy)
			end
			Mob.Summon(definition.Enemy, definition.Quantity, 0.28,
				definition.HealthMultiplier, definition.SpeedMultiplier, map,
				alpha.Value, hitbox.CFrame, path, length, positions, active)
		end,
	}
end
return Summon
