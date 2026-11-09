local Rep = game:GetService('ReplicatedStorage')
local Collection = game:GetService('CollectionService')
local RNG = {Tag = 'RNG', Threshold = 500}
function RNG.Targets()
	local targets = {}
	for _, mob in workspace.Mobs:GetChildren() do
		if mob:IsA('Model') and not Collection:HasTag(mob, 'RNG') then table.insert(targets, mob) end
	end
	return targets
end
function RNG.Apply(caster, mob)
	local stats = mob:FindFirstChild('EnemyStats')
	local hitbox = mob:FindFirstChild('Hitbox')
	if not stats or not hitbox then return nil end
	local inv = stats:FindFirstChild('Invincible')
	local created = not inv
	if not inv then inv = Instance.new('BoolValue'); inv.Name = 'Invincible'; inv.Parent = stats end
	local previous = inv.Value
	inv.Value = true
	local shield, weld, beam
	local particles = Rep:FindFirstChild('Particle')
	local template = particles and particles:FindFirstChild('Shield')
	if template and not hitbox:FindFirstChild('Shield') then
		shield = template:Clone()
		shield.Name = 'Shield'
		if shield:IsA('BasePart') then
			local hip = stats:FindFirstChild('HipHeight')
			local size = 3.15 * (((hip and hip.Value or 2) * 4) + 0.2)
			shield.Size = Vector3.new(size, size, size)
			shield.CFrame = hitbox.CFrame
			weld = Instance.new('WeldConstraint')
			weld.Part0 = hitbox; weld.Part1 = shield; weld.Parent = shield
		end
		shield.Parent = hitbox
	end
	local core = caster:FindFirstChild('Core')
	local neon = core and core:FindFirstChild('Neon')
	local beamTemplate = neon and neon:FindFirstChild('TemplateBeam')
	local source = neon and neon:FindFirstChild('Attachment')
	local torso = mob:FindFirstChild('Torso')
	local destination = torso and torso:FindFirstChild('Center')
	local proxyDestination
	if not destination and mob:GetAttribute('LightweightEnemy') then
		proxyDestination=Instance.new('Attachment'); proxyDestination.Name='RNGProxyCenter'; proxyDestination.Parent=hitbox
		destination=proxyDestination
	end
	if beamTemplate and source and destination then
		beam = beamTemplate:Clone(); beam.Name = 'RNGAuraBeam'
		beam.Attachment0 = source; beam.Attachment1 = destination; beam.Parent = neon
	end
	return function()
		if proxyDestination then proxyDestination:Destroy() end
		if beam then beam:Destroy() end
		if weld then weld:Destroy() end
		if shield then
			local sound = shield:FindFirstChild('Break')
			if sound and sound:IsA('Sound') then sound:Play() end
			shield:Destroy()
		end
		if created then inv:Destroy()
		elseif inv.Parent and inv.Value == true then inv.Value = previous end
	end
end
return RNG
