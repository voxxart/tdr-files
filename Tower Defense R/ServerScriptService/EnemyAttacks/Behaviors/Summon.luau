local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Mob = require(game.ServerScriptService.Main.Mob)

local Summon = {}
function Summon.new(enemy, definition)
	local rng = Random.new()
	return {
		Cooldown = function()
			local minimum = enemy:GetAttribute('SummonMin') or definition.MinCooldown
			local maximum = enemy:GetAttribute('SummonMax') or definition.MaxCooldown
			return rng:NextNumber(math.max(0, minimum), math.max(minimum, maximum, 0))
		end,
		Run = function(active)
			if not active() then return end
			local map = workspace.Map:FindFirstChildOfClass('Folder')
			local hitbox = enemy:FindFirstChild('Hitbox')
			local alpha = enemy:FindFirstChild('Alpha')
			if not map or not hitbox or not alpha then return end
			local path, length, positions = Mob.GetClosestWaypointPath(map, hitbox.CFrame)
			if not path or not active() then return end
			local root = enemy:FindFirstChild('HumanoidRootPart')
			local sound = root and root:FindFirstChild(definition.Sound)
			if sound then
				sound.PlaybackSpeed = math.max(0, workspace.Info.GameSpeed.Value)
				sound:Play()
			end
			ReplicatedStorage.Events.AnimateEnemy:FireAllClients(enemy, definition.Animation, enemy)
			ReplicatedStorage.Events.MEU.Client:FireAllClients(enemy)
			Mob.Summon(definition.Enemy, definition.Quantity, 0.28,
				definition.HealthMultiplier, definition.SpeedMultiplier, map,
				alpha.Value, hitbox.CFrame, path, length, positions, active)
		end,
	}
end
return Summon
