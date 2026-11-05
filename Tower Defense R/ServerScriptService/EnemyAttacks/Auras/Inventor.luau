local Inventor = {Tag = 'Inventor', Threshold = 400}
function Inventor.Targets()
	local targets = {}
	for _, tower in workspace.Towers:GetChildren() do
		local config = tower:FindFirstChild('Config')
		local buffs = config and (config:FindFirstChild('Buffs') or config:FindFirstChild('DamageBuffs'))
		if tower:IsA('Model') and buffs and buffs:IsA('Folder') then table.insert(targets, tower) end
	end
	return targets
end
function Inventor.Apply(_, tower)
	local config = tower:FindFirstChild('Config')
	if not config then return nil end
	local value = config:FindFirstChild('DISABLED')
	local created = not value
	if not value then value = Instance.new('BoolValue'); value.Name = 'DISABLED'; value.Parent = config end
	local previous = value.Value
	value.Value = true
	return function()
		if created then value:Destroy()
		elseif value.Parent and value.Value == true then value.Value = previous end
	end
end
return Inventor
