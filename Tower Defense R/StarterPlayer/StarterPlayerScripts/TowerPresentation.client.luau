local Rep = game:GetService('ReplicatedStorage')
local Debris = game:GetService('Debris')
local effects = Rep.Events:WaitForChild('TowerPresentation')
effects.OnClientEvent:Connect(function(kind, from, to, duration)
	if kind ~= 'Laser' or typeof(from) ~= 'Vector3' or typeof(to) ~= 'Vector3' then return end
	local distance = (to-from).Magnitude
	if distance ~= distance or distance < 0.001 or distance == math.huge then return end
	local part = Instance.new('Part')
	part.Anchored = true; part.CanCollide = false; part.CanQuery = false; part.CanTouch = false
	part.CastShadow = false; part.Material = Enum.Material.Neon
	part.Size = Vector3.new(0.2,0.2,distance)
	part.CFrame = CFrame.lookAt(from,to)*CFrame.new(0,0,-distance/2)
	part.Parent = workspace
	Debris:AddItem(part, math.clamp(tonumber(duration) or 0.08, 0.01, 1))
end)
