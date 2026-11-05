local Mob = require(game.ServerScriptService.Main.Mob)
local BreadDrops = {}
function BreadDrops.new(enemy)
	local rng = Random.new()
	local count = 0
	local names = {'Bread1', 'Bread2'}
	local models = enemy:FindFirstChild('BreadModels')
	if models then
		for _, name in names do
			local part = models:FindFirstChild(name)
			if part and part:IsA('BasePart') then part.Transparency = 0 end
		end
	end
	return {
		InitialCooldown = function() return rng:NextNumber(5, 8) end,
		Cooldown = function() return rng:NextNumber(3, 5) end,
		Finished = function() return count >= 2 end,
		Run = function(active)
			if not active() or count >= 2 then return end
			local map = workspace.Map:FindFirstChildOfClass('Folder')
			local hitbox = enemy:FindFirstChild('Hitbox')
			local alpha = enemy:FindFirstChild('Alpha')
			if not map or not hitbox or not alpha then return end
			local path, length, positions = Mob.GetClosestWaypointPath(map, hitbox.CFrame)
			if not path or not active() then return end
			count += 1
			local name = names[count]
			local part = models and models:FindFirstChild(name)
			if part and part:IsA('BasePart') then part.Transparency = 1 end
			Mob.Summon(name, 1, 0.28, 2.5, 1, map, alpha.Value,
				hitbox.CFrame, path, length, positions, active)
		end,
	}
end
return BreadDrops
