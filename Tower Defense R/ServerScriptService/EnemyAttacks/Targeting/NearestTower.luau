local NearestTower = {}
function NearestTower.Valid(tower, folder)
	if not tower or tower.Parent ~= folder or not tower.PrimaryPart or tower:GetAttribute('Dying') then return false end
	local config = tower:FindFirstChild('Config')
	local health = config and config:FindFirstChild('Health')
	local value = health and health:FindFirstChild('HealthValue')
	return value ~= nil and value.Value > 0 and health:FindFirstChild('MaxHealth') ~= nil
end
function NearestTower.Find(enemy, folder, range, excludeCliff)
	local hitbox = enemy:FindFirstChild('Hitbox')
	if not hitbox then return nil end
	local best, distance = nil, range * range
	for _, tower in folder:GetChildren() do
		if NearestTower.Valid(tower, folder) and not tower.Config:FindFirstChild('Flying')
			and (not excludeCliff or not tower.Config:FindFirstChild('CliffTower')) then
			local delta = tower.PrimaryPart.Position - hitbox.Position
			local squared = delta.X * delta.X + delta.Z * delta.Z
			if squared < distance then best, distance = tower, squared end
		end
	end
	return best
end
return NearestTower
