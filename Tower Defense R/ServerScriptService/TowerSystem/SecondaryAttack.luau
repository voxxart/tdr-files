local Match = require(game.ServerScriptService.Simulation.MatchService)
local Rep = game:GetService('ReplicatedStorage')
local Debris = game:GetService('Debris')
local Presentation = Rep.Events:FindFirstChild('TowerPresentation')
if not Presentation then
	Presentation = Instance.new('RemoteEvent')
	Presentation.Name = 'TowerPresentation'; Presentation.Parent = Rep.Events
end
assert(Presentation:IsA('RemoteEvent'), 'TowerPresentation must be a RemoteEvent')
local Secondary = {}
function Secondary.new(context)
local tower, Towers = context.Tower, context.Towers
local isCorruptedTower, corruptionSecondaryAttack = context.IsCorrupted, context.CorruptionAttack
local events, ParticleFolder, MobSet = Rep.Events, Rep.Particle, context.MobSet
local os_clock = os.clock
return function(newTower, player, config, secondary)
	if not (newTower and newTower.Parent and secondary) then return end
	local data = Towers[newTower]
	if not data or not Match.IsCurrent(data.MatchGeneration) then return end
	local health = config:FindFirstChild('Health')
	if health and health:FindFirstChild('HealthValue') and health.HealthValue.Value <= 0 then return end
	if newTower:GetAttribute("ReaperSummoning") == true then return end
	if isCorruptedTower(newTower) then
		return corruptionSecondaryAttack(newTower, config, secondary)
	end
	local attackType = (secondary:FindFirstChild("Type") and secondary.Type.Value) or "Default"
	local range      = secondary:FindFirstChild("Range") and secondary.Range.Value
	local dmg        = secondary:FindFirstChild("Damage") and secondary.Damage.Value
	local splash     = secondary:FindFirstChild("Splash") and secondary.Splash.Value

	local stunUntil = config:GetAttribute("StunnedUntil")
	if stunUntil and os_clock() < stunUntil then return end

	-- Secondary should shoot whatever the primary is currently attacking,
	-- not go find its own target. Falls back to an independent search
	-- only if the primary has no valid target (e.g. hasn't fired yet, or
	-- its target moved out of secondary's own range).
	local schedData = Towers[newTower]
	local primaryTarget = schedData and schedData.lastPrimaryTarget
	local hrp = newTower:FindFirstChild("HumanoidRootPart")

	local function isValidSecondaryTarget(t)
		if not (t and t.Parent) then return false end
		local stats = t:FindFirstChild("EnemyStats")
		local hitbox = t:FindFirstChild("Hitbox")
		if not (stats and hitbox) then return false end
		if stats.Health.Value <= 0 then return false end
		if range and hrp and (hitbox.Position - hrp.Position).Magnitude > range then return false end
		return true
	end

	local target
	if isValidSecondaryTarget(primaryTarget) then
		target = primaryTarget
	else
		target = tower.FindTarget(newTower, range, "First")
	end
	if not target then return end

	-- Legacy stun value gate
	if config:FindFirstChild("Stunned") then return end


	local head = newTower:FindFirstChild("Head") or newTower:FindFirstChild("HumanoidRootPart")

	if attackType == "Rocket" then
		if head and ParticleFolder:FindFirstChild("Rocket") then
			local fx = ParticleFolder.Rocket:Clone(); fx.Parent = head
			local s = fx:FindFirstChildWhichIsA("Sound", true); if s then pcall(s.Play, s) end
			Debris:AddItem(fx, 2)
		end
		local hf = events:FindFirstChild("Helicopter")
		local fr = hf and hf:FindFirstChild("FireRockets")
		local AR = events.Aviator:FindFirstChild("FireRockets")
		if fr and config:FindFirstChild("Flying") then fr:FireAllClients(newTower, target)
		elseif AR and config:FindFirstChild("Aviator") then AR:FireAllClients(newTower, target)
		elseif fr and config:FindFirstChild("WarMachine") then events.WarMachine.FireRockets:FireAllClients(newTower, target) end
		if splash then tower.SecondarySplash(target, newTower)
		else
			local s = target:FindFirstChild("EnemyStats"); if s then s.Health.Value -= dmg end
		end
	elseif attackType == "Laser" then
		if head and target:FindFirstChild("Hitbox") then
			Presentation:FireAllClients('Laser', head.Position, target.Hitbox.Position, 0.08)
		end
		local s = target:FindFirstChild("EnemyStats"); if s then s.Health.Value -= dmg end
	elseif attackType == "AOE" then
		local center = newTower.PrimaryPart and newTower.PrimaryPart.Position
		if center then
			for mob in pairs(MobSet) do
				local h = mob:FindFirstChild("Hitbox"); local s = mob:FindFirstChild("EnemyStats")
				if h and s and (h.Position-center).Magnitude <= range then s.Health.Value -= dmg end
			end
		end
		if head and ParticleFolder:FindFirstChild("Explosion") then
			local fx = ParticleFolder.Explosion:Clone(); fx.Parent = head
			local s = fx:FindFirstChildWhichIsA("Sound",true); if s then pcall(s.Play,s) end
			Debris:AddItem(fx, 2)
		end
	else
		local s = target:FindFirstChild("EnemyStats"); if s then s.Health.Value -= dmg end
	end

	if config:FindFirstChild("Flying") then tower.HeliFaceTarget(newTower, target)
	elseif config:FindFirstChild("Aviator") then
	else tower.FaceTarget(newTower, target) end
end

end
return Secondary
