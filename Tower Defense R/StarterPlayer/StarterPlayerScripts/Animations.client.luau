--// SUPER OPTIMIZED CLIENT ANIMATIONS (FULL SCRIPT, SAME BEHAVIOR)
--// Goals:
--// - Remove per-frame Tween creation (major lag source)
--// - Stop using BindableEvent waits for projectiles
--// - Cache templates, folders, tweens, anim tracks, marker connections
--// - Throttle / reuse state (beam/flame/scrambler)
--// - Keep ALL FUNCTIONS + same external behavior

-- Services
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")

-- Refs
local Particle = ReplicatedStorage:WaitForChild("Particle")
local events = ReplicatedStorage:WaitForChild("Events")
local animateTowerEvent = events:WaitForChild("AnimateTower")
local animateTowerDeathEvent = events:WaitForChild("AnimateTowerDeath")
local ClientSideEffects = events:FindFirstChild("ReplicateEffects")
local FrankensteinTransformEvent = events:WaitForChild("FrankensteinTransform")

-- Workspace folders (safe)
local VisualFolder = workspace:FindFirstChild("Visual") or workspace

-- Local player VFX
local LocalPlayer = Players.LocalPlayer
local VFXValue = LocalPlayer:WaitForChild("VFX", 10)

-- Info/GameSpeed cache (avoid repeated indexing)
local Info = workspace:FindFirstChild("Info")
local GameSpeedValue = Info and Info:FindFirstChild("GameSpeed")
local gameSpeed = (GameSpeedValue and GameSpeedValue.Value) or 1
if GameSpeedValue then
	GameSpeedValue:GetPropertyChangedSignal("Value"):Connect(function()
		local v = GameSpeedValue.Value
		gameSpeed = (v ~= 0 and v) or 1
	end)
end

-- Template cache
local TEMPLATE = {
	Explosion = Particle:FindFirstChild("Explosion"),
	DExplosion = Particle:FindFirstChild("DemoExplosion"),
	HeliExplosion = Particle:FindFirstChild("HeliExplosion"),
	Burn = Particle:FindFirstChild("Burn"),
	Frag = Particle:FindFirstChild("Frag"),
	Rocket = Particle:FindFirstChild("Rocket"),
	WMRocket = Particle:FindFirstChild("WMRocket"),
	SonicBoom = Particle:FindFirstChild("SonicBoom"),
	Charge = Particle:FindFirstChild("Charge"),
	Pumpkin = Particle:FindFirstChild("PumpkinBomb"),
	Bleed = Particle:FindFirstChild("Blood"),
}

-- Utility: quick VFX check
local function isHighVFX()
	return VFXValue and VFXValue.Value == "High"
end

-- Utility: safe primarypart lookup
local function getPP(m)
	return m and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart"))
end

-- Utility: create stunned value (client-sided like original)
local function applyStunToTowersAround(pos: Vector3, radius: number)
	local towersFolder = workspace:FindFirstChild("Towers")
	if not towersFolder then return end

	local r2 = radius * radius
	for _, t in ipairs(towersFolder:GetChildren()) do
		local pp = getPP(t)
		local cfg = t:FindFirstChild("Config")
		if pp and cfg then
			local d = pp.Position - pos
			if (d.X*d.X + d.Y*d.Y + d.Z*d.Z) < r2 then
				local stunned = Instance.new("NumberValue")
				stunned.Name = "Stunned"
				stunned.Value = 5
				stunned.Parent = cfg
			end
		end
	end
end

-- Arc mover (no per-frame tweens, keeps old "speed" timing)
local function arcProjectile(part: BasePart, startPos: Vector3, endPos: Vector3, flightTime: number, arcHeight: number?, spinZ: number?)
	if not (part and part.Parent) then return end
	flightTime = math.max(flightTime or 0.5, 0.05)

	-- ✅ Small "old-style" arc: scale with distance, clamp hard
	-- If arcHeight explicitly provided, still clamp it.
	local dist = (endPos - startPos).Magnitude
	local autoArc = math.clamp(dist * 0.06, 1.5, 8)  -- <= THIS is the important part
	arcHeight = math.clamp(arcHeight or autoArc, 0, 10)

	local t = 0
	local cfStart = part.CFrame
	local baseX, baseY, baseZ = cfStart:ToOrientation()

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not (part and part.Parent) then
			if conn then conn:Disconnect() end
			return
		end

		t += dt
		local a = t / flightTime
		if a >= 1 then
			part.Position = endPos
			if conn then conn:Disconnect() end
			return
		end

		local pos = startPos:Lerp(endPos, a)

		-- Small parabola bump (peaks at 0.5)
		local arc = (4 * a * (1 - a)) * arcHeight
		part.Position = pos + Vector3.new(0, arc, 0)

		if spinZ then
			part.Orientation = Vector3.new(math.deg(baseX), math.deg(baseY), math.deg(baseZ + spinZ * t))
		end
	end)
end


--------------------------------------------------------------------
-- EXPLOSIONS (optimized: no Completed:Wait, Debris instead of wait+Destroy)
--------------------------------------------------------------------
local function Explode(Target: BasePart, Radius: number)
	if not (Target and Target.Parent) then return end
	local Range = Radius

	local template = TEMPLATE.Explosion
	if not template then return end

	local NewExplode = template:Clone()
	NewExplode.Parent = VisualFolder

	-- Set CFrame once
	NewExplode.Inner.CFrame = Target.CFrame
	NewExplode.Outer.CFrame = Target.CFrame

	-- Tweens created once (not per frame)
	local outerTween = TweenService:Create(
		NewExplode.Outer,
		TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, 0, true),
		{ Size = Vector3.new(Range * 2, Range * 2, Range * 2) }
	)

	local innerTween
	if isHighVFX() then
		NewExplode.Inner.Transparency = 0
		innerTween = TweenService:Create(
			NewExplode.Inner,
			TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, 0, true),
			{ Size = Vector3.new(Range, Range, Range) }
		)

		local att = NewExplode.Inner:FindFirstChild("Attachment")
		if att then
			local emb = att:FindFirstChild("Embers")
			local fire = att:FindFirstChild("Fire")
			local smoke = att:FindFirstChild("Smoke")
			local streaks = att:FindFirstChild("Streaks")
			if emb then emb:Emit(25) end
			if fire then fire:Emit(25) end
			if smoke then smoke:Emit(25) end
			if streaks then streaks:Emit(25) end
		end
	else
		-- keep print (original behavior)
		print("Low VFX Are Active")
	end

	outerTween:Play()
	if innerTween then innerTween:Play() end

	local innerSound = NewExplode.Inner:FindFirstChild("Explosion")
	if innerSound then innerSound:Play() end

	-- Stun towers in range (client-side like original)
	applyStunToTowersAround(Target.Position, Range)

	-- Cleanup (no waits)
	Debris:AddItem(NewExplode, 4.35)
	task.delay(0.65 , function()
		if NewExplode and NewExplode.Parent then
			if NewExplode:FindFirstChild("Inner") then NewExplode.Inner.Transparency = 1 end
			if NewExplode:FindFirstChild("Outer") then NewExplode.Outer.Transparency = 1 end
		end
	end)
end

local function DemoExplode(Target: BasePart, Radius: number)
	if not (Target and Target.Parent) then return end
	local Range = Radius

	local template = TEMPLATE.DExplosion
	if not template then return end

	local NewExplode = template:Clone()
	NewExplode.Parent = VisualFolder

	-- Set CFrame once
	NewExplode.Inner.CFrame = Target.CFrame
	NewExplode.Outer.CFrame = Target.CFrame

	-- Tweens created once (not per frame)
	local outerTween = TweenService:Create(
		NewExplode.Outer,
		TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, 0, true),
		{ Size = Vector3.new(Range * 2, Range * 2, Range * 2) }
	)

	local innerTween
	if isHighVFX() then
		NewExplode.Inner.Transparency = 0
		innerTween = TweenService:Create(
			NewExplode.Inner,
			TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, 0, true),
			{ Size = Vector3.new(Range, Range, Range) }
		)

		local att = NewExplode.Inner:FindFirstChild("Attachment")
		if att then
			local emb = att:FindFirstChild("Embers")
			local fire = att:FindFirstChild("Fire")
			local smoke = att:FindFirstChild("Smoke")
			local streaks = att:FindFirstChild("Streaks")
			if emb then emb:Emit(10) end
			if fire then fire:Emit(10) end
			if smoke then smoke:Emit(10) end
			if streaks then streaks:Emit(10) end
		end
	else
		-- keep print (original behavior)
		print("Low VFX Are Active")
	end

	outerTween:Play()
	if innerTween then innerTween:Play() end

	local innerSound = NewExplode.Inner:FindFirstChild("Explosion")
	if innerSound then innerSound:Play() end

	-- Stun towers in range (client-side like original)
	applyStunToTowersAround(Target.Position, Range)

	-- Cleanup (no waits)
	Debris:AddItem(NewExplode, 4.35)
	task.delay(0.65 , function()
		if NewExplode and NewExplode.Parent then
			if NewExplode:FindFirstChild("Inner") then NewExplode.Inner.Transparency = 1 end
			if NewExplode:FindFirstChild("Outer") then NewExplode.Outer.Transparency = 1 end
		end
	end)
end

local function HeliExplode(Target: BasePart, Radius: number)
	if not (Target and Target.Parent) then return end
	local Range = Radius

	local template = TEMPLATE.HeliExplosion
	if not template then return end

	local NewExplode = template:Clone()
	NewExplode.Parent = VisualFolder

	NewExplode.Inner.CFrame = Target.CFrame
	NewExplode.Outer.CFrame = Target.CFrame

	if isHighVFX() then
		local att = NewExplode.Inner:FindFirstChild("Attachment")
		local streaks = att and att:FindFirstChild("Streaks")
		if streaks then streaks:Emit(25) end
	else
		print("Low VFX Are Active")
	end

	applyStunToTowersAround(Target.Position, Range)

	Debris:AddItem(NewExplode, 4)
end
--------------------------------------------------------------------
-- SIMPLE VISUAL EFFECTS
--------------------------------------------------------------------
local function VisualEffect(effect, target, duration)
	if effect == "Fire" then
		local burnTemplate = TEMPLATE.Burn
		if burnTemplate and target and target:FindFirstChild("Hitbox") then
			local fire = burnTemplate:Clone()
			fire.Parent = target.Hitbox
			Debris:AddItem(fire, duration)
		end
	end

	if effect == "Bleed" then
		local burnTemplate = TEMPLATE.Bleed
		if burnTemplate and target and target:FindFirstChild("Hitbox") then
			local fire = burnTemplate:Clone()
			fire.Parent = target.Hitbox
			Debris:AddItem(fire, duration)
		end
	end
end

--------------------------------------------------------------------
-- TOWER ATTACK SOUNDS
--
-- Primary tower attack sounds live directly under HumanoidRootPart and are
-- named after the tower's current level:
--
-- HumanoidRootPart
-- ├─ 0
-- ├─ 1
-- ├─ 2
-- ├─ 3
-- ├─ 4
-- ├─ 5
-- ├─ 6
-- └─ Secondary
--
-- Primary:   sound name = tostring(current tower level)
-- Secondary: sound name = "Secondary"
--------------------------------------------------------------------

local function getTowerSoundLevel(tower)
	if not tower then
		return 0
	end

	local level = tower:GetAttribute("TowerLevel")

	if typeof(level) == "number" then
		return math.max(0, math.floor(level))
	end

	local config = tower:FindFirstChild("Config")
	local levelValue = config and config:FindFirstChild("Level")

	if levelValue and levelValue:IsA("ValueBase") then
		return math.max(0, math.floor(levelValue.Value))
	end

	return 0
end

local function getTowerPrimaryAttackSound(tower)
	if not tower then
		return nil
	end

	local hrp = tower:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end

	local sound
	if tower.Config:FindFirstChild("Aviator") then
		local AviatorPlane = tower:FindFirstChild("UpgradeModels")["0"]:FindFirstChild("Plane").MainBody
		sound = AviatorPlane:FindFirstChild(
			tostring(
				getTowerSoundLevel(tower)
			)
		)
	else
		sound = hrp:FindFirstChild(
			tostring(
				getTowerSoundLevel(tower)
			)
		)
	end

	if sound and sound:IsA("Sound") then
		return sound
	end

	return nil
end

local function getTowerSecondaryAttackSound(tower)
	if not tower then
		return nil
	end

	local hrp = tower:FindFirstChild("HumanoidRootPart")
	local sound
	if tower.Config:FindFirstChild("Aviator") then
		local AviatorPlane = tower:FindFirstChild("UpgradeModels")["0"]:FindFirstChild("Plane").MainBody
		sound = AviatorPlane:FindFirstChild("Secondary")
	else
		hrp:FindFirstChild("Secondary")
	end
	if sound and sound:IsA("Sound") then
		return sound
	end

	return nil
end

local function playTowerSound(sound, resetTime)
	if not sound then
		return
	end

	sound.PlaybackSpeed = gameSpeed

	if resetTime ~= false then
		local parent = sound.Parent

		if parent
			and not parent:FindFirstChild("AdjustedSound")
		then
			sound.TimePosition = 0
		else
			sound.TimePosition = 0.05
		end
	end

	sound:Play()
end

--------------------------------------------------------------------
-- FLAMETHROWER STATE (already good; keep + minor micro-opts)
--------------------------------------------------------------------
local FlameState = setmetatable({}, { __mode = "k" })

local function visualTowerEffect(tower, effect, target)
	if effect ~= "FireFlame" then return end
	if not tower or not tower.Parent then return end

	local tool = tower:FindFirstChild("Weapon")
	local root = tower:FindFirstChild("HumanoidRootPart")
	if not tool or not root then return end

	local flameSound = getTowerPrimaryAttackSound(tower)
	local handle = tool:FindFirstChild("Handle")
	if not flameSound or not handle then return end

	local fireAttachment = handle:FindFirstChild("Fire")
	local fireEffect = fireAttachment and fireAttachment:FindFirstChild("Fire")
	if not fireEffect then return end

	local durationLocal = 0.75 / math.max(gameSpeed, 0.01)

	local state = FlameState[tower]
	if not state then
		state = { stopping = false, stopAt = 0, fireEffect = fireEffect, flameSound = flameSound }
		FlameState[tower] = state
	else
		state.fireEffect = fireEffect
		state.flameSound = flameSound
	end

	state.stopAt = os.clock() + durationLocal
	if state.stopping then return end

	state.stopping = true
	fireEffect.Enabled = true
	if not flameSound.IsPlaying then flameSound:Play() end

	task.spawn(function()
		while tower and tower.Parent and FlameState[tower] == state do
			local remaining = state.stopAt - os.clock()
			if remaining <= 0 then break end
			task.wait(remaining < 0.1 and remaining or 0.1)
		end

		if state.fireEffect then state.fireEffect.Enabled = false end
		if state.flameSound and state.flameSound.IsPlaying then state.flameSound:Stop() end

		state.stopping = false
		FlameState[tower] = nil
	end)
end


--------------------------------------------------------------------
-- PHASER / BEAMER STATE
--
-- Upgrade-safe client VFX:
-- • Beam references are never trusted forever.
-- • If an upgrade replaces Weapon / Weapon2 / Weapon3 while firing,
--   the new beam(s) are rebound to the SAME target immediately.
-- • Start particles are moved over to the new weapon visuals.
-- • Target-side Sparks are replaced with the CURRENT upgrade's template.
-- • Single -> MultiPhaser upgrades are handled without leaving both systems
--   running at the same time.
-- • The server still owns targeting/damage; this is visual continuity only.
--------------------------------------------------------------------
local PhaserState = setmetatable({}, { __mode = "k" }) -- [tower] = state

local function setPhaserParticlesEnabled(particles, enabled)
	for _, particle in ipairs(particles or {}) do
		if particle and particle.Parent then
			particle.Enabled = enabled
		end
	end
end

local function sameInstanceList(a, b)
	if a == b then
		return true
	end

	if not a or not b or #a ~= #b then
		return false
	end

	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end

	return true
end

local function addPhaserParticle(list, object)
	if object then
		list[#list + 1] = object
	end
end

local function getPhaserTargetAttachment(target)
	if not (target and target.Parent) then
		return nil, nil
	end

	local torso = target:FindFirstChild("Torso")
	if not torso then
		return nil, nil
	end

	local center = torso:FindFirstChild("Center")

	if not center then
		center = Instance.new("Attachment")
		center.Name = "Center"
		center.Parent = torso
	end

	return torso, center
end

--------------------------------------------------------------------
-- RESOLVE CURRENT BEAMER VISUALS
--------------------------------------------------------------------
local function getCurrentPhaserVisuals(tower, target)
	if not (tower and tower.Parent and target and target.Parent) then
		return nil
	end

	local config = tower:FindFirstChild("Config")
	if not config or not config:FindFirstChild("BeamerSettings") then
		return nil
	end

	local torso, targetAttachment =
		getPhaserTargetAttachment(target)

	if not (torso and targetAttachment) then
		return nil
	end

	local multiValue = config:FindFirstChild("MultiPhaser")
	local useMulti =
		multiValue
		and multiValue.Value == true

	local root = tower:FindFirstChild("HumanoidRootPart")
	local attackSound =
		root and root:FindFirstChild("Laser")

	if useMulti then
		local weapon1 = tower:FindFirstChild("Weapon")
		local weapon2 = tower:FindFirstChild("Weapon2")
		local weapon3 = tower:FindFirstChild("Weapon3")

		local firePart1 =
			weapon1 and weapon1:FindFirstChild("Handle")

		local firePart2 =
			weapon2 and weapon2:FindFirstChild("Handle4")

		local firePart3 =
			weapon3 and weapon3:FindFirstChild("Handle3")

		if not (firePart1 and firePart2 and firePart3) then
			return nil
		end

		local start1 = firePart1:FindFirstChild("Start")
		local start2 = firePart2:FindFirstChild("Start")
		local start3 = firePart3:FindFirstChild("Start")

		if not (start1 and start2 and start3) then
			return nil
		end

		local beam1 = firePart1:FindFirstChild("Laser")
		local beam2 = firePart2:FindFirstChild("Laser")
		local beam3 = firePart3:FindFirstChild("Laser")

		if not (beam1 and beam2 and beam3) then
			return nil
		end

		local particles = {}

		addPhaserParticle(particles, start1:FindFirstChild("Core"))
		addPhaserParticle(particles, start1:FindFirstChild("Glow"))
		addPhaserParticle(particles, start1:FindFirstChild("Smoke"))
		addPhaserParticle(particles, start1:FindFirstChild("Spark"))

		addPhaserParticle(particles, start2:FindFirstChild("Core"))
		addPhaserParticle(particles, start2:FindFirstChild("Glow"))
		addPhaserParticle(particles, start2:FindFirstChild("Smoke"))
		addPhaserParticle(particles, start2:FindFirstChild("Spark"))

		addPhaserParticle(particles, start3:FindFirstChild("Core"))
		addPhaserParticle(particles, start3:FindFirstChild("Glow"))
		addPhaserParticle(particles, start3:FindFirstChild("Smoke"))
		addPhaserParticle(particles, start3:FindFirstChild("Spark"))

		return {
			mode = "Multi",
			beams = { beam1, beam2, beam3 },
			starts = { start1, start2, start3 },
			particles = particles,
			sparksTemplate = firePart1:FindFirstChild("Sparks"),
			torso = torso,
			targetAttachment = targetAttachment,
			attackSound = attackSound,
		}
	end

	local weapon = tower:FindFirstChild("Weapon")
	local firePart =
		weapon and weapon:FindFirstChild("Handle")

	if not firePart then
		return nil
	end

	local start = firePart:FindFirstChild("Start")
	local beam = firePart:FindFirstChild("Laser")

	if not (start and beam) then
		return nil
	end

	local particles = {}

	addPhaserParticle(particles, start:FindFirstChild("Core"))
	addPhaserParticle(particles, start:FindFirstChild("Glow"))
	addPhaserParticle(particles, start:FindFirstChild("Particle3"))
	addPhaserParticle(particles, start:FindFirstChild("Smoke"))
	addPhaserParticle(particles, start:FindFirstChild("Spark"))

	return {
		mode = "Single",
		beams = { beam },
		starts = { start },
		particles = particles,
		sparksTemplate = firePart:FindFirstChild("Sparks"),
		torso = torso,
		targetAttachment = targetAttachment,
		attackSound = attackSound,
	}
end

local function detachPhaserVisuals(state)
	if not state then
		return
	end

	for _, beam in ipairs(state.beams or {}) do
		if beam and beam.Parent then
			beam.Attachment1 = nil
		end
	end

	setPhaserParticlesEnabled(
		state.particles,
		false
	)
end

local function replacePhaserTargetSparks(state, visual)
	if state.sparks then
		state.sparks:Destroy()
		state.sparks = nil
	end

	local template = visual.sparksTemplate
	if not template then
		return
	end

	local sparks = template:Clone()
	sparks.Parent = visual.torso
	sparks.Enabled = true
	state.sparks = sparks
end

--------------------------------------------------------------------
-- BIND / REBIND CURRENT VISUALS
--------------------------------------------------------------------
local function bindCurrentPhaserVisuals(tower, target)
	local state = PhaserState[tower]
	if not state then
		return false, false
	end

	local visual =
		getCurrentPhaserVisuals(
			tower,
			target
		)

	if not visual then
		return false, false
	end

	local targetChanged =
		state.target ~= target

	local visualsChanged =
		state.mode ~= visual.mode
		or not sameInstanceList(
			state.beams,
			visual.beams
		)
		or not sameInstanceList(
			state.starts,
			visual.starts
		)
		or state.sparksTemplate ~= visual.sparksTemplate

	if visualsChanged then
		detachPhaserVisuals(state)

		if state.attackSound
			and state.attackSound ~= visual.attackSound
		then
			state.attackSound:Stop()
			state.attackSound.TimePosition = 0
		end
	end

	state.target = target
	state.mode = visual.mode
	state.beams = visual.beams
	state.starts = visual.starts
	state.particles = visual.particles
	state.sparksTemplate = visual.sparksTemplate
	state.attackSound = visual.attackSound

	for index, beam in ipairs(visual.beams) do
		local startAttachment =
			visual.starts[index]

		if beam and beam.Parent
			and startAttachment
			and startAttachment.Parent
		then
			beam.Attachment0 = startAttachment
			beam.Attachment1 =
				visual.targetAttachment
		end
	end

	setPhaserParticlesEnabled(
		visual.particles,
		true
	)

	if targetChanged or visualsChanged then
		replacePhaserTargetSparks(
			state,
			visual
		)
	end

	if visual.attackSound then
		visual.attackSound.PlaybackSpeed = gameSpeed
		visual.attackSound.Playing = true
	end

	return true, targetChanged or visualsChanged
end

local function phaserVisualsNeedRefresh(tower, state)
	if not (tower and tower.Parent and state) then
		return false
	end

	local config = tower:FindFirstChild("Config")
	if not config then
		return false
	end

	local multiValue =
		config:FindFirstChild("MultiPhaser")

	local wantedMode =
		(
			multiValue
			and multiValue.Value == true
		)
		and "Multi"
		or "Single"

	if state.mode ~= wantedMode then
		return true
	end

	for _, beam in ipairs(state.beams or {}) do
		if not (beam and beam.Parent) then
			return true
		end
	end

	for _, start in ipairs(state.starts or {}) do
		if not (start and start.Parent) then
			return true
		end
	end

	return false
end

--------------------------------------------------------------------
-- IMMEDIATE UPGRADE REFRESH
--------------------------------------------------------------------
local function queuePhaserVisualRefresh(tower, state)
	if not (
		tower
			and state
			and PhaserState[tower] == state
		) then
		return
	end

	state.refreshSerial =
		(state.refreshSerial or 0) + 1

	local serial =
		state.refreshSerial

	task.defer(function()
		for _ = 1, 8 do
			if PhaserState[tower] ~= state
				or state.refreshSerial ~= serial
				or not state.running
				or not state.target
				or not state.target.Parent
			then
				return
			end

			local success, changed =
				bindCurrentPhaserVisuals(
					tower,
					state.target
				)

			if success and changed then
				return
			end

			task.wait(0.03)
		end
	end)
end

--------------------------------------------------------------------
-- STOP PHASER (SINGLE + MULTI)
--------------------------------------------------------------------
local function stopPhaser(tower)
	local state = PhaserState[tower]
	if not state then
		return
	end

	PhaserState[tower] = nil

	state.running = false
	state.refreshSerial =
		(state.refreshSerial or 0) + 1

	if state.levelConnection then
		state.levelConnection:Disconnect()
		state.levelConnection = nil
	end

	if state.childAddedConnection then
		state.childAddedConnection:Disconnect()
		state.childAddedConnection = nil
	end

	detachPhaserVisuals(state)

	if state.attackSound then
		state.attackSound:Stop()
		state.attackSound.TimePosition = 0
	end

	if state.sparks then
		state.sparks:Destroy()
		state.sparks = nil
	end

	state.target = nil
end

local function stopLaser(tower)
	stopPhaser(tower)
end

local function stopLasers(tower)
	stopPhaser(tower)
end

--------------------------------------------------------------------
-- START / REFRESH PHASER
--------------------------------------------------------------------
local function startOrRefreshPhaser(tower, target)
	if not (
		tower
			and tower.Parent
			and target
			and target.Parent
		) then
		return
	end

	local config = tower:FindFirstChild("Config")
	if not config
		or not config:FindFirstChild("BeamerSettings")
	then
		return
	end

	playAnimation(
		tower,
		"BeamLoop"
	)

	local state =
		PhaserState[tower]

	if not state then
		state = {
			running = false,
			target = nil,
			mode = nil,
			beams = nil,
			starts = nil,
			particles = nil,
			sparks = nil,
			sparksTemplate = nil,
			attackSound = nil,
			refreshSerial = 0,
			levelConnection = nil,
			childAddedConnection = nil,
		}

		PhaserState[tower] = state

		state.levelConnection =
			tower:GetAttributeChangedSignal(
				"TowerLevel"
			):Connect(function()
			queuePhaserVisualRefresh(
				tower,
				state
			)
		end)

		state.childAddedConnection =
			tower.ChildAdded:Connect(function(child)
				if child.Name == "Weapon"
					or child.Name == "Weapon2"
					or child.Name == "Weapon3"
				then
					queuePhaserVisualRefresh(
						tower,
						state
					)
				end
			end)
	end

	local success =
		bindCurrentPhaserVisuals(
			tower,
			target
		)

	if not success then
		return
	end

	if state.running then
		return
	end

	state.running = true

	task.spawn(function()
		while state.running
			and tower
			and tower.Parent
			and PhaserState[tower] == state
		do
			local currentTarget =
				state.target

			if not (
				currentTarget
					and currentTarget.Parent
				) then
				break
			end

			local hitbox =
				currentTarget:FindFirstChild(
					"Hitbox"
				)

			local stats =
				currentTarget:FindFirstChild(
					"EnemyStats"
				)

			local rootPart =
				tower:FindFirstChild(
					"HumanoidRootPart"
				)

			if not (
				hitbox
					and stats
					and rootPart
				) then
				break
			end

			local range =
				(
					config:FindFirstChild(
						"Range"
					)
					and config.Range.Value
				)
				or 0

			if (
				rootPart.Position
				- hitbox.Position
				).Magnitude > range then
				break
			end

			local charged =
				config:FindFirstChild(
					"Charged"
				)

			if charged
				and not charged.Value
			then
				break
			end

			if stats.Health.Value <= 0 then
				break
			end

			if phaserVisualsNeedRefresh(
				tower,
				state
				) then
				bindCurrentPhaserVisuals(
					tower,
					currentTarget
				)
			end

			task.wait(0.08)
		end

		if PhaserState[tower] == state then
			stopPhaser(tower)
		end
	end)
end

--------------------------------------------------------------------
-- COMPATIBILITY WRAPPERS
--------------------------------------------------------------------
local function PhaserLaser(tower, target)
	startOrRefreshPhaser(
		tower,
		target
	)
end

local function PhaserLasers(tower, target)
	startOrRefreshPhaser(
		tower,
		target
	)
end

--------------------------------------------------------------------
-- EVENTS
--------------------------------------------------------------------
ReplicatedStorage.Events.Beamer.Beam.OnClientEvent:Connect(function(tower, target)
	local config =
		tower
		and tower:FindFirstChild("Config")

	local multi =
		config
		and config:FindFirstChild("MultiPhaser")

	if multi and multi.Value == true then
		PhaserLasers(
			tower,
			target
		)
	else
		PhaserLaser(
			tower,
			target
		)
	end
end)

ReplicatedStorage.Events.Beamer.LostTarget.OnClientEvent:Connect(function(tower, target)
	stopPhaser(tower)

	if not (tower and tower.Parent) then
		return
	end

	StopAnimation(
		tower,
		"BeamLoop"
	)

	local beamEndTrack =
		setAnimation(
			tower,
			"BeamEnd"
		)

	if not (
		beamEndTrack
			and beamEndTrack.IsPlaying
		) then
		playAnimation(
			tower,
			"BeamEnd",
			target
		)
	end

	local root =
		tower:FindFirstChild(
			"HumanoidRootPart"
		)

	local windDown =
		root
		and root:FindFirstChild(
			"WindDown"
		)

	if windDown then
		windDown:Play()
	end

	task.delay(
		3 / math.max(gameSpeed, 0.01),
		function()
			if tower and tower.Parent then
				playAnimation(
					tower,
					"Idle"
				)
			end
		end
	)
end)

------------------------------------------------------------
-- DUEL PHASER (kept behavior, but throttled + no repeat heavy ops)
--------------------------------------------------------------------
local DuelState = setmetatable({}, { __mode = "k" })

local function DuelPhaserLaser(tower, target)
	if not (tower and tower.Parent and target and target.Parent) then return end
	local config = tower:FindFirstChild("Config")
	if not config or not config:FindFirstChild("Charged") then return end

	local w1 = tower:FindFirstChild("Weapon1")
	local w2 = tower:FindFirstChild("Weapon2")
	if not (w1 and w2 and target:FindFirstChild("Torso")) then return end

	local firePart1 = w1:FindFirstChild("Handle")
	local firePart2 = w2:FindFirstChild("Handle")
	if not (firePart1 and firePart2) then return end

	local start1 = firePart1:FindFirstChild("Start")
	local start2 = firePart2:FindFirstChild("Start")
	if not (start1 and start2) then return end

	local torso = target.Torso
	local attach2 = torso:FindFirstChild("Center")
	if not attach2 then
		attach2 = Instance.new("Attachment")
		attach2.Name = "Center"
		attach2.Parent = torso
	end

	local obeam: Beam = start1:FindFirstChild("Beam")
	local beam: Beam = start2:FindFirstChild("Beam")
	if not (obeam and beam) then return end

	local function enableStartParticles(startObj, enabled)
		for _, n in ipairs({"Particle1","Particle2","Particle3","Particle4","Particle6"}) do
			local p = startObj:FindFirstChild(n)
			if p then p.Enabled = enabled end
		end
	end

	enableStartParticles(start1, true)
	enableStartParticles(start2, true)

	beam.Attachment1 = attach2
	obeam.Attachment1 = attach2

	local root = tower:FindFirstChild("HumanoidRootPart")
	local atk = getTowerPrimaryAttackSound(tower)
	if atk then
		atk.PlaybackSpeed = gameSpeed
		atk.Playing = true
	end

	local st = DuelState[tower]
	if st then
		-- refresh target
		st.target = target
		return
	end
	st = { target = target, running = true }
	DuelState[tower] = st

	task.spawn(function()
		while tower and tower.Parent and DuelState[tower] == st do
			local t = st.target
			if not (t and t.Parent and config and config.Parent) then break end
			local hitbox = t:FindFirstChild("Hitbox")
			local stats = t:FindFirstChild("EnemyStats")
			if not (hitbox and stats) then break end

			local range = config:FindFirstChild("Range")
			if range then
				local mag = (root.Position - hitbox.Position).Magnitude
				if mag > range.Value then break end
			end

			if not config.Charged.Value or stats.Health.Value <= 0 then break end
			task.wait(0.08)
		end

		if atk then atk.Playing = false end
		beam.Attachment1 = nil
		obeam.Attachment1 = nil
		enableStartParticles(start1, false)
		enableStartParticles(start2, false)

		DuelState[tower] = nil
	end)
end

--------------------------------------------------------------------
-- ROCKET / FRAG PROJECTILES (optimized: NO Heartbeat loops, use Tween once)
--------------------------------------------------------------------
local function tweenProjectile(part: BasePart, goalPos: Vector3, timeSec: number, rot: Vector3?)
	if not (part and part.Parent) then return end
	timeSec = math.max(timeSec or 0.1, 0.05)

	if rot then
		-- rotate once (not infinite loop)
		part.Rotation = rot
	end

	local tween = TweenService:Create(part, TweenInfo.new(timeSec, Enum.EasingStyle.Linear), { Position = goalPos })
	tween:Play()
	tween.Completed:Wait()
end

local function HelicopterRockets(tower, target)
	if not (tower and tower.Parent and target and target.Parent) then return end
	playTowerSound(tower.HumanoidRootPart.Secondary)

	if tower.Config:FindFirstChild("Secondary") and tower.Config:FindFirstChild("Flying") then
		local rocketTemplate
		if tower.Config:FindFirstChild("CustomProjectile") then
			rocketTemplate = TEMPLATE[tower.Config.CustomProjectile.Value]
		else
			rocketTemplate = TEMPLATE.Rocket
		end
		if not rocketTemplate then return end

		local rocket = rocketTemplate:Clone()
		rocket.Parent = VisualFolder

		local hrp = tower:FindFirstChild("HumanoidRootPart")
		local targetPP = getPP(target)
		if not (hrp and targetPP) then
			rocket:Destroy()
			return
		end

		rocket.Position = hrp.Position

		local aimPart = Instance.new("Part")
		aimPart.Name = "AimPart"
		aimPart.Size = Vector3.one
		aimPart.Transparency = 1
		aimPart.CanCollide = false
		aimPart.Anchored = true
		aimPart.Position = targetPP.Position
		aimPart.Parent = VisualFolder

		-- smooth move aimPart (kept, but no useless tween spam)
		TweenService:Create(aimPart, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { Position = targetPP.Position }):Play()

		-- travel (kept "speed = 0.1" feel)
		local travelTime = 0.1
		tweenProjectile(rocket, aimPart.Position, travelTime)

		rocket:Destroy()
		HeliExplode(aimPart, tower.Config.Secondary.SplashRadius.Value)
		aimPart:Destroy()
	end
end

local function AviatorRockets(tower, target)
	if not (tower and tower.Parent and target and target.Parent) then return end
	local planeModel = tower:FindFirstChild("UpgradeModels")["0"]:FindFirstChild("Plane")
	local MainBody = planeModel and planeModel:FindFirstChild("RotatePart")

	playTowerSound(getTowerSecondaryAttackSound(tower))

	if tower.Config:FindFirstChild("Secondary") and tower.Config:FindFirstChild("Aviator") then
		local rocketTemplate
		if tower.Config:FindFirstChild("CustomProjectile") then
			rocketTemplate = TEMPLATE[tower.Config.CustomProjectile.Value]
		else
			rocketTemplate = TEMPLATE.Rocket
		end
		if not rocketTemplate then return end
		local rocket = rocketTemplate:Clone()
		rocket.Parent = VisualFolder

		local targetPP = getPP(target)
		if not (MainBody and targetPP) then
			rocket:Destroy()
			return
		end

		rocket.Position = MainBody.Position

		local aimPart = Instance.new("Part")
		aimPart.Name = "AimPart"
		aimPart.Size = Vector3.one
		aimPart.Transparency = 1
		aimPart.CanCollide = false
		aimPart.Anchored = true
		aimPart.Position = targetPP.Position
		aimPart.Parent = VisualFolder

		-- smooth move aimPart (kept, but no useless tween spam)
		TweenService:Create(aimPart, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { Position = targetPP.Position }):Play()

		-- travel (kept "speed = 0.1" feel)
		local travelTime = 0.1
		tweenProjectile(rocket, aimPart.Position, travelTime)

		rocket:Destroy()
		HeliExplode(aimPart, tower.Config.Secondary.SplashRadius.Value)
		aimPart:Destroy()
	end
end

local ROCKET_SPEED = 60
local MIN_TRAVEL_TIME = 0.05
local MAX_TRAVEL_TIME = 10.0

local function WMRockets(tower, target)
	if not (tower and tower.Parent and target and target.Parent) then return end

	playTowerSound(getTowerSecondaryAttackSound(tower))

	if not (tower.Config:FindFirstChild("Secondary") and tower.Config:FindFirstChild("WarMachine")) then
		return
	end

	local rocketTemplate = TEMPLATE.WMRocket
	if not rocketTemplate then return end

	local weapon3 = tower:FindFirstChild("Weapon3")
	local handle = weapon3 and weapon3:FindFirstChild("Handle")
	local targetPP = getPP(target)
	if not (handle and targetPP) then return end

	local rocket = rocketTemplate:Clone()
	rocket.Parent = VisualFolder
	rocket.Position = handle.Position

	local aimPart = Instance.new("Part")
	aimPart.Name = "AimPart"
	aimPart.Size = Vector3.one
	aimPart.Transparency = 1
	aimPart.CanCollide = false
	aimPart.Anchored = true
	aimPart.Position = targetPP.Position
	aimPart.Parent = VisualFolder
	TweenService:Create(aimPart, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { Position = targetPP.Position }):Play()

	local startPos = rocket.Position
	local endPos = aimPart.Position
	local dist = (endPos - startPos).Magnitude

	local travelTime = dist / ROCKET_SPEED
	travelTime = math.clamp(travelTime, MIN_TRAVEL_TIME, MAX_TRAVEL_TIME)

	tweenProjectile(rocket, endPos, travelTime)

	rocket:Destroy()
	HeliExplode(aimPart, tower.Config.Secondary.SplashRadius.Value)
	aimPart:Destroy()
end


--------------------------------------------------------------------
-- MINE THROW (synced visual only — server owns real placement)
--------------------------------------------------------------------
local MLevents        = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MinelayerEvents")
local PlaceMineEvent   = MLevents:WaitForChild("PlaceMine")
local ExplodeMineEvent = MLevents:WaitForChild("ExplodeMine")

--------------------------------------------------------------------
-- WEAPON MINE VISIBILITY HELPER
--------------------------------------------------------------------
local function setWeaponMineVisible(weaponModel, visible)
	if not weaponModel then return end
	local transparency = visible and 0 or 1

	for _, desc in ipairs(weaponModel:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Transparency = transparency
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = transparency
		end
	end

	-- cover the case where WeaponModel itself is a BasePart
	if weaponModel:IsA("BasePart") then
		weaponModel.Transparency = transparency
	end
end

--------------------------------------------------------------------
-- MINE THROW (synced visual only — server owns real placement)
--------------------------------------------------------------------
local function ThrowMine(tower, landPosition, travelTime)
	if not (tower and tower.Parent) then return end
	local config = tower:FindFirstChild("Config")
	if not config then return end
	local MineStats = config:FindFirstChild("MineStats")
	local selected   = MineStats and MineStats:FindFirstChild("SelectedMine")
	if not selected then return end

	local mineTemplate = ReplicatedStorage.Mines:FindFirstChild(selected.Value)
	if not mineTemplate then return end

	local originPart = getPP(tower)
	if not originPart then return end
	local startPos = originPart.Position

	playAnimation(tower, "Attack")

	local speed  = math.max(GameSpeedValue.Value, 0.01)
	local windup = 0.85 / speed

	-- Total time (windup + flight) should still match the server-driven
	-- travelTime, so the actual flung mine only flies for whatever time
	-- is left over after the throw windup, not the full travelTime.
	local fullFlightTime    = math.max(travelTime or 0.5, 0.05)
	local adjustedFlightTime = math.max(fullFlightTime - windup, 0.05)

	local WeaponModel = tower:FindFirstChild("Weapon")

	task.delay(windup, function()
		if not (tower and tower.Parent) then return end

		-- Hide the weapon's mine right as it's thrown
		if WeaponModel and WeaponModel.Parent then
			setWeaponMineVisible(WeaponModel, false)
		end

		-- Spawn + arc the visual mine now, using the reduced flight time
		local visualMine = mineTemplate:Clone()
		for _, d in ipairs(visualMine:GetDescendants()) do
			if d:IsA("BasePart") then d.CanCollide = false; d.Anchored = true end
		end
		if visualMine:IsA("BasePart") then
			visualMine.CanCollide = false
			visualMine.Anchored = true
		end
		visualMine.Parent = VisualFolder

		local arcHeight = math.clamp((landPosition - startPos).Magnitude * 0.15, 1, 6)
		local baseX = math.rad(90)
		local spinZ = math.rad(Random.new():NextNumber(-360, 360))

		local t = 0
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if not (visualMine and visualMine.Parent) then
				if conn then conn:Disconnect() end
				return
			end

			t += dt
			local a = math.clamp(t / adjustedFlightTime, 0, 1)
			local pos = startPos:Lerp(landPosition, a)
			pos += Vector3.new(0, (4 * a * (1 - a)) * arcHeight, 0)
			local cf = CFrame.new(pos) * CFrame.Angles(baseX, 0, spinZ * t)

			if visualMine.PrimaryPart then
				visualMine:PivotTo(cf)
			elseif visualMine:IsA("BasePart") then
				visualMine.CFrame = cf
			end

			if a >= 1 then
				if conn then conn:Disconnect() end
				if visualMine and visualMine.Parent then visualMine:Destroy() end

				-- Mine has landed — bring the weapon's mine back
				if WeaponModel and WeaponModel.Parent then
					setWeaponMineVisible(WeaponModel, true)
				end
			end
		end)
	end)
end

PlaceMineEvent.OnClientEvent:Connect(ThrowMine)

ExplodeMineEvent.OnClientEvent:Connect(function(position, radius)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = VisualFolder
	Explode(anchor, radius)
	Debris:AddItem(anchor, 4.5)
end)


local function arcProjectileOriented(part: BasePart, startPos: Vector3, endPos: Vector3, flightTime: number, arcHeight: number?, spinZ: number?, frontOffset: CFrame?)
	if not (part and part.Parent) then return end
	flightTime = math.max(flightTime or 0.5, 0.05)

	local dist = (endPos - startPos).Magnitude
	local autoArc = math.clamp(dist * 0.06, 1.5, 8)
	arcHeight = math.clamp(arcHeight or autoArc, 0, 10)

	-- frontOffset lets you correct for models whose "tip" isn't along
	-- the default LookVector — e.g. CFrame.Angles(0, math.pi, 0) if the
	-- rocket is built backwards. Defaults to identity (tip = LookVector).
	frontOffset = frontOffset or CFrame.new()

	local t = 0
	local EPS = 1/240  -- small step for numerical tangent

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not (part and part.Parent) then
			if conn then conn:Disconnect() end
			return
		end

		t += dt
		local a = t / flightTime
		if a >= 1 then
			part.Position = endPos
			if conn then conn:Disconnect() end
			return
		end

		-- Position at current alpha
		local pos = startPos:Lerp(endPos, a)
		local arc = (4 * a * (1 - a)) * arcHeight
		local currentPos = pos + Vector3.new(0, arc, 0)

		-- Position slightly ahead (numerical derivative for tangent direction)
		local aAhead = math.clamp(a + EPS, 0, 1)
		local posAhead = startPos:Lerp(endPos, aAhead)
		local arcAhead = (4 * aAhead * (1 - aAhead)) * arcHeight
		local aheadPos = posAhead + Vector3.new(0, arcAhead, 0)

		local tangent = aheadPos - currentPos
		if tangent.Magnitude < 1e-5 then
			-- fallback: straight-line direction if tangent degenerates (near a≈1)
			tangent = (endPos - startPos)
		end

		local lookCF = CFrame.new(currentPos, currentPos + tangent.Unit) * frontOffset

		if spinZ then
			-- apply roll spin around the rocket's own forward axis
			lookCF = lookCF * CFrame.Angles(0, 0, spinZ * t)
		end

		part.CFrame = lookCF
	end)
end

local function fireProjectile(tower, aimPos, travelTime)
	if not (tower and tower.Parent) then return end
	if not tower.Config:FindFirstChild("Splash") then return end

	local fragTemplate = TEMPLATE.Frag
	if not fragTemplate then return end

	local weapon = tower:FindFirstChild("Weapon")
	local handle = weapon and weapon:FindFirstChild("Handle")
	if not handle then return end

	local rocket = fragTemplate:Clone()
	rocket.Parent = VisualFolder
	rocket.Position = handle.Position

	local aimPart = Instance.new("Part")
	aimPart.Name = "AimPart"
	aimPart.Size = Vector3.one
	aimPart.Transparency = 1
	aimPart.CanCollide = false
	aimPart.Anchored = true
	aimPart.Position = aimPos
	aimPart.Parent = VisualFolder

	local spin = math.rad(Random.new():NextNumber(-360, 360))

	-- Same orientation-following arc as the mortar, just with a flatter arc (nil = auto)
	arcProjectileOriented(rocket, rocket.Position, aimPos, travelTime, nil, spin, CFrame.new())

	task.delay(travelTime, function()
		if rocket and rocket.Parent then rocket:Destroy() end
		if aimPart and aimPart.Parent then
			DemoExplode(aimPart, tower.Config.SplashRadius.Value)
			aimPart:Destroy()
		end
	end)
end




local function MortarfireProjectile(tower, aimPos, travelTime)
	if not (tower and tower.Parent) then return end
	if not tower.Config:FindFirstChild("Splash") then return end

	local fragTemplate = TEMPLATE.Rocket
	if not fragTemplate then return end

	local weapon = tower:FindFirstChild("Weapon")
	local handle = weapon and weapon:FindFirstChild("Handle")
	if not handle then return end

	local rocket = fragTemplate:Clone()
	rocket.Parent = VisualFolder
	rocket.Position = handle.Position

	local aimPart = Instance.new("Part")
	aimPart.Name = "AimPart"
	aimPart.Size = Vector3.one
	aimPart.Transparency = 1
	aimPart.CanCollide = false
	aimPart.Anchored = true
	aimPart.Position = aimPos
	aimPart.Parent = VisualFolder

	local spin = math.rad(Random.new():NextNumber(-360, 360))

	-- If the Rocket model's tip points backwards relative to LookVector,
	-- change this offset, e.g. CFrame.Angles(0, math.pi, 0) to flip 180°,
	-- or CFrame.Angles(-math.pi/2, 0, 0) if the tip points along the Top face.
	local frontOffset = CFrame.new()

	arcProjectileOriented(rocket, rocket.Position, aimPos, travelTime, 6, spin, frontOffset)

	task.delay(travelTime, function()
		if rocket and rocket.Parent then rocket:Destroy() end
		if aimPart and aimPart.Parent then
			Explode(aimPart, tower.Config.SplashRadius.Value)
			aimPart:Destroy()
		end
	end)
end


--------------------------------------------------------------------
-- MUZZLE FLASH (cheap: guard nil and don't double index)
--------------------------------------------------------------------
local function MuzzleFlash(tower)
	if not tower then return end
	local cfg = tower:FindFirstChild("Config")
	if not cfg then return end
	if cfg:FindFirstChild("ChargeCooldown") then return end

	local weapon = tower:FindFirstChild("Weapon")
	if not weapon then return end

	local handle = weapon:FindFirstChild("Handle")
	if not handle then return end

	local start = handle:FindFirstChild("Start")
	if not start then return end

	local barrel = handle:FindFirstChild("Barrel")

	if not barrel then
		local s = start:FindFirstChild("Spark"); if s then s:Emit(1) end
		local sm = start:FindFirstChild("Smoke"); if sm then sm:Emit(1) end
		local f = start:FindFirstChild("flash1"); if f then f:Emit(1) end
	else
		local tvfx = start:FindFirstChild("TestVFX"); if tvfx then tvfx:Emit(1) end
		local sm = barrel:FindFirstChild("Smoke"); if sm then sm:Emit(3) end
		local sm = barrel:FindFirstChild("Spark"); if sm then sm:Emit(3) end
	end
end

local function MuzzleFlashUnitTurret(unit)
	if not unit then return end
	local cfg = unit:FindFirstChild("Config")
	if not cfg then return end
	if cfg:FindFirstChild("ChargeCooldown") then return end

	local weapon = unit:FindFirstChild("Weapon")
	if not weapon then return end

	local handle = weapon:FindFirstChild("Handle")
	if not handle then return end

	local start = handle:FindFirstChild("Start")
	if not start then return end

	local barrel = handle:FindFirstChild("Barrel")

	if not barrel then
		local s = start:FindFirstChild("Spark"); if s then s:Emit(1) end
		local sm = start:FindFirstChild("Smoke"); if sm then sm:Emit(1) end
		local f = start:FindFirstChild("flash1"); if f then f:Emit(1) end
	else
		local tvfx = start:FindFirstChild("TestVFX"); if tvfx then tvfx:Emit(1) end
		local sm = barrel:FindFirstChild("Smoke"); if sm then sm:Emit(3) end
		local sm = barrel:FindFirstChild("Spark"); if sm then sm:Emit(3) end
	end
end

local function MuzzleFlashUnitCanon(unit)
	if not unit then return end
	local cfg = unit:FindFirstChild("Config")
	if not cfg then return end
	if cfg:FindFirstChild("ChargeCooldown") then return end

	local weapon = unit:FindFirstChild("Weapon2")
	if not weapon then return end

	local handle = weapon:FindFirstChild("Handle")
	if not handle then return end

	local start = handle:FindFirstChild("Start")
	if not start then return end

	local barrel = handle:FindFirstChild("Barrel")

	if not barrel then
		local s = start:FindFirstChild("Spark"); if s then s:Emit(5) end
		local sm = start:FindFirstChild("Smoke"); if sm then sm:Emit(5) end
		local f = start:FindFirstChild("flash1"); if f then f:Emit(5) end
	else
		local tvfx = start:FindFirstChild("TestVFX"); if tvfx then tvfx:Emit(1) end
		local sm = barrel:FindFirstChild("Smoke"); if sm then sm:Emit(3) end
		local sm = barrel:FindFirstChild("Spark"); if sm then sm:Emit(3) end
	end
end

local function MuzzleFlashUnitCannon(unit)
	if not unit then return end
	local cfg = unit:FindFirstChild("Config")
	if not cfg then return end
	if cfg:FindFirstChild("ChargeCooldown") then return end

	local weapon = unit:FindFirstChild("Weapon")
	if not weapon then return end

	local handle = weapon:FindFirstChild("Handle")
	if not handle then return end

	local start = handle:FindFirstChild("Start")
	if not start then return end

	local barrel = handle:FindFirstChild("Barrel")

	if not barrel then
		local s = start:FindFirstChild("Spark"); if s then s:Emit(1) end
		local sm = start:FindFirstChild("Smoke"); if sm then sm:Emit(1) end
		local f = start:FindFirstChild("flash1"); if f then f:Emit(1) end
	else
		local tvfx = start:FindFirstChild("TestVFX"); if tvfx then tvfx:Emit(1) end
		local sm = barrel:FindFirstChild("Smoke"); if sm then sm:Emit(3) end
		local sm = barrel:FindFirstChild("Spark"); if sm then sm:Emit(3) end
	end
end

local function AviatorMuzzleFlash(tower)
	if not tower then return end

	local cfg = tower:FindFirstChild("Config")
	if not cfg or cfg:FindFirstChild("ChargeCooldown") then return end

	local weapon = tower:FindFirstChild("Weapon")
	if not weapon then return end

	if tower.Config.Level.Value > 3 then
		local handle1 = weapon:FindFirstChild("Handle")
		local handle2 = weapon:FindFirstChild("Handle2")
		local handle3 = weapon:FindFirstChild("Handle3")
		local handle4 = weapon:FindFirstChild("Handle4")
		if not (handle1 and handle2 and handle3 and handle4) then return end

		local s1 = handle1:FindFirstChild("Start")
		local s2 = handle2:FindFirstChild("Start")
		local s3 = handle3:FindFirstChild("Start")
		local s4 = handle4:FindFirstChild("Start")

		local barrel1 = handle1:FindFirstChild("Barrel")
		local barrel2 = handle2:FindFirstChild("Barrel")
		local barrel3 = handle3:FindFirstChild("Barrel")
		local barrel4 = handle4:FindFirstChild("Barrel")

		-- Handle 1
		if s1 and not barrel1 then
			local a = s1:FindFirstChild("Spark"); if a then a:Emit(1) end
			local b = s1:FindFirstChild("Smoke"); if b then b:Emit(1) end
			local c = s1:FindFirstChild("flash1"); if c then c:Emit(1) end
		elseif s1 and barrel1 then
			local a = barrel1:FindFirstChild("Smoke"); if a then a:Emit(1) end
			local b = s1:FindFirstChild("TestVFX"); if b then b:Emit(1) end
			local sm = barrel1:FindFirstChild("Spark"); if sm then sm:Emit(3) end
		end

		-- Handle 2
		if s2 and not barrel2 then
			local a = s2:FindFirstChild("Spark"); if a then a:Emit(1) end
			local b = s2:FindFirstChild("Smoke"); if b then b:Emit(1) end
			local c = s2:FindFirstChild("flash1"); if c then c:Emit(1) end
		elseif s2 and barrel2 then
			local a = barrel2:FindFirstChild("Smoke"); if a then a:Emit(1) end
			local b = s2:FindFirstChild("TestVFX"); if b then b:Emit(1) end
			local sm = barrel2:FindFirstChild("Spark"); if sm then sm:Emit(3) end
		end

		if s3 and not barrel3 then
			local a = s3:FindFirstChild("Spark"); if a then a:Emit(1) end
			local b = s3:FindFirstChild("Smoke"); if b then b:Emit(1) end
			local c = s3:FindFirstChild("flash1"); if c then c:Emit(1) end
		elseif s3 and barrel3 then
			local a = barrel3:FindFirstChild("Smoke"); if a then a:Emit(1) end
			local b = s3:FindFirstChild("TestVFX"); if b then b:Emit(1) end
			local sm = barrel3:FindFirstChild("Spark"); if sm then sm:Emit(3) end
		end

		-- Handle 2
		if s4 and not barrel4 then
			local a = s4:FindFirstChild("Spark"); if a then a:Emit(1) end
			local b = s4:FindFirstChild("Smoke"); if b then b:Emit(1) end
			local c = s4:FindFirstChild("flash1"); if c then c:Emit(1) end
		elseif s4 and barrel4 then
			local a = barrel4:FindFirstChild("Smoke"); if a then a:Emit(1) end
			local b = s4:FindFirstChild("TestVFX"); if b then b:Emit(1) end
			local sm = barrel4:FindFirstChild("Spark"); if sm then sm:Emit(3) end
		end
	else
		local handle1 = weapon:FindFirstChild("Handle")
		local handle2 = weapon:FindFirstChild("Handle2")
		if not (handle1 and handle2) then return end

		local s1 = handle1:FindFirstChild("Start")
		local s2 = handle2:FindFirstChild("Start")

		local barrel1 = handle1:FindFirstChild("Barrel")
		local barrel2 = handle2:FindFirstChild("Barrel")

		-- Handle 1
		if s1 and not barrel1 then
			local a = s1:FindFirstChild("Spark"); if a then a:Emit(1) end
			local b = s1:FindFirstChild("Smoke"); if b then b:Emit(1) end
			local c = s1:FindFirstChild("flash1"); if c then c:Emit(1) end
		elseif s1 and barrel1 then
			local a = barrel1:FindFirstChild("Smoke"); if a then a:Emit(1) end
			local b = s1:FindFirstChild("TestVFX"); if b then b:Emit(1) end
			local sm = barrel1:FindFirstChild("Spark"); if sm then sm:Emit(3) end
		end

		-- Handle 2
		if s2 and not barrel2 then
			local a = s2:FindFirstChild("Spark"); if a then a:Emit(1) end
			local b = s2:FindFirstChild("Smoke"); if b then b:Emit(1) end
			local c = s2:FindFirstChild("flash1"); if c then c:Emit(1) end
		elseif s2 and barrel2 then
			local a = barrel2:FindFirstChild("Smoke"); if a then a:Emit(1) end
			local b = s2:FindFirstChild("TestVFX"); if b then b:Emit(1) end
			local sm = barrel2:FindFirstChild("Spark"); if sm then sm:Emit(3) end
		end
	end
end



local function DualMuzzleFlash(tower)
	if not tower then return end

	local cfg = tower:FindFirstChild("Config")
	if not cfg or cfg:FindFirstChild("ChargeCooldown") then return end

	local weapon = tower:FindFirstChild("Weapon")
	if not weapon then return end

	local handle1 = weapon:FindFirstChild("Handle")
	local handle2 = weapon:FindFirstChild("Handle2")
	if not (handle1 and handle2) then return end

	local s1 = handle1:FindFirstChild("Start")
	local s2 = handle2:FindFirstChild("Start")

	local barrel1 = handle1:FindFirstChild("Barrel")
	local barrel2 = handle2:FindFirstChild("Barrel")

	-- Handle 1
	if s1 and not barrel1 then
		local a = s1:FindFirstChild("Spark"); if a then a:Emit(1) end
		local b = s1:FindFirstChild("Smoke"); if b then b:Emit(1) end
		local c = s1:FindFirstChild("flash1"); if c then c:Emit(1) end
	elseif s1 and barrel1 then
		local a = barrel1:FindFirstChild("Smoke"); if a then a:Emit(1) end
		local b = s1:FindFirstChild("TestVFX"); if b then b:Emit(1) end
		local sm = barrel1:FindFirstChild("Spark"); if sm then sm:Emit(3) end
	end

	-- Handle 2
	if s2 and not barrel2 then
		local a = s2:FindFirstChild("Spark"); if a then a:Emit(1) end
		local b = s2:FindFirstChild("Smoke"); if b then b:Emit(1) end
		local c = s2:FindFirstChild("flash1"); if c then c:Emit(1) end
	elseif s2 and barrel2 then
		local a = barrel2:FindFirstChild("Smoke"); if a then a:Emit(1) end
		local b = s2:FindFirstChild("TestVFX"); if b then b:Emit(1) end
		local sm = barrel2:FindFirstChild("Spark"); if sm then sm:Emit(3) end
	end
end

local function DualWeaponMuzzleFlash(tower)
	if not tower then return end

	local cfg = tower:FindFirstChild("Config")
	if not cfg or cfg:FindFirstChild("ChargeCooldown") then return end

	local weapon = tower:FindFirstChild("Weapon")
	local weapon2 = tower:FindFirstChild("Weapon2")
	if not weapon then return end

	local handle1 = weapon:FindFirstChild("Handle")
	local handle2 = weapon2:FindFirstChild("Handle2")
	if not (handle1 and handle2) then return end

	local s1 = handle1:FindFirstChild("Start")
	local s2 = handle2:FindFirstChild("Start")

	local barrel1 = handle1:FindFirstChild("Barrel")
	local barrel2 = handle2:FindFirstChild("Barrel")

	-- Handle 1
	if s1 and not barrel1 then
		local a = s1:FindFirstChild("Spark"); if a then a:Emit(1) end
		local b = s1:FindFirstChild("Smoke"); if b then b:Emit(1) end
		local c = s1:FindFirstChild("flash1"); if c then c:Emit(1) end
	elseif s1 and barrel1 then
		local a = barrel1:FindFirstChild("Smoke"); if a then a:Emit(1) end
		local b = s1:FindFirstChild("TestVFX"); if b then b:Emit(1) end
		local sm = barrel1:FindFirstChild("Spark"); if sm then sm:Emit(3) end
	end

	-- Handle 2
	if s2 and not barrel2 then
		local a = s2:FindFirstChild("Spark"); if a then a:Emit(1) end
		local b = s2:FindFirstChild("Smoke"); if b then b:Emit(1) end
		local c = s2:FindFirstChild("flash1"); if c then c:Emit(1) end
	elseif s2 and barrel2 then
		local a = barrel2:FindFirstChild("Smoke"); if a then a:Emit(1) end
		local b = s2:FindFirstChild("TestVFX"); if b then b:Emit(1) end
		local sm = barrel2:FindFirstChild("Spark"); if sm then sm:Emit(3) end
	end
end

local function TankCannon(tower, aimPos, travelTime)
	if not (tower and tower.Parent) then return end
	if not tower.Config.SecondaryAttack:FindFirstChild("SplashRadius") then return end

	local fragTemplate = TEMPLATE.Rocket
	if not fragTemplate then return end

	local weapon = tower:FindFirstChild("Weapon2")
	local handle = weapon and weapon:FindFirstChild("Handle")
	if not handle then return end

	local rocket = fragTemplate:Clone()
	rocket.Parent = VisualFolder
	rocket.Position = handle.Start.WorldPosition

	local aimPart = Instance.new("Part")
	aimPart.Name = "AimPart"
	aimPart.Size = Vector3.one
	aimPart.Transparency = 1
	aimPart.CanCollide = false
	aimPart.Anchored = true
	aimPart.Position = aimPos
	aimPart.Parent = VisualFolder

	local spin = math.rad(Random.new():NextNumber(-360, 360))

	-- If the Rocket model's tip points backwards relative to LookVector,
	-- change this offset, e.g. CFrame.Angles(0, math.pi, 0) to flip 180°,
	-- or CFrame.Angles(-math.pi/2, 0, 0) if the tip points along the Top face.
	local frontOffset = CFrame.new()

	arcProjectileOriented(rocket, rocket.Position, aimPos, travelTime, 1.2, spin, frontOffset)

	task.delay(travelTime, function()
		if rocket and rocket.Parent then rocket:Destroy() end
		if aimPart and aimPart.Parent then
			Explode(aimPart, tower.Config.SecondaryAttack.SplashRadius.Value)
			aimPart:Destroy()
		end
	end)
end

local function DualUnitMuzzleFlash(tower)
	local w1 = tower:FindFirstChild("Weapon1")
	local w2 = tower:FindFirstChild("Weapon2")
	if not (w1 and w2) then return end
	local b1 = w1:FindFirstChild("Barrel1")
	local b2 = w2:FindFirstChild("Barrel2")
	local s1 = b1 and b1:FindFirstChild("Start")
	local s2 = b2 and b2:FindFirstChild("Start")
	if s1 then
		local a = s1:FindFirstChild("Spark"); if a then a:Emit(1) end
		local b = s1:FindFirstChild("Smoke"); if b then b:Emit(1) end
		local c = s1:FindFirstChild("flash1"); if c then c:Emit(1) end
	end
	if s2 then
		local a = s2:FindFirstChild("Spark"); if a then a:Emit(1) end
		local b = s2:FindFirstChild("Smoke"); if b then b:Emit(1) end
		local c = s2:FindFirstChild("flash1"); if c then c:Emit(1) end
	end
end

local function WMRocketMuzzleFlash(tower)
	local w1 = tower:FindFirstChild("Weapon3")
	if not w1 then return end

	local h1 = w1:FindFirstChild("Handle")
	local Attachment = h1:FindFirstChild("Start")
	if not h1 or not Attachment then return end

	local Smoke = Attachment:FindFirstChild("Smoke")
	if Smoke then Smoke:Emit(7) end
	local Spark = Attachment:FindFirstChild("Spark")
	if Spark then Spark:Emit(7) end
	local Flash = Attachment:FindFirstChild("flash1")
	if Flash then Flash:Emit(7) end
end

local function WarmachineMuzzleFlash(tower)
	local w1 = tower:FindFirstChild("Weapon1")
	local w2 = tower:FindFirstChild("Weapon2")
	if not w1 or not w2 then return end

	local h1 = w1:FindFirstChild("Handle2")
	local h2 = w2:FindFirstChild("Handle")
	if not h1 or not h2 then return end

	local start1 = h1:FindFirstChild("Start")
	local barrel1 = h1:FindFirstChild("Barrel")
	local start2 = h2:FindFirstChild("Start")
	local barrel2 = h2:FindFirstChild("Barrel")
	if not start1 or not barrel1 or not start2 or not barrel2 then return end

	local fx1 = start1:FindFirstChild("TestVFX")
	if fx1 then fx1:Emit(1) end
	local smoke1 = barrel1:FindFirstChild("Smoke")
	if smoke1 then smoke1:Emit(1) end

	local fx2 = start2:FindFirstChild("TestVFX")
	if fx2 then fx2:Emit(1) end
	local smoke2 = barrel2:FindFirstChild("Smoke")
	if smoke2 then smoke2:Emit(1) end
end

local function PhaserMuzzleFlash(tower)
	local weapon = tower:FindFirstChild("Weapon")
	local handle = weapon and weapon:FindFirstChild("Handle")
	local start = handle and handle:FindFirstChild("Start")
	if not start then return end

	for _, n in ipairs({"Spark","Core","Glow","Rays1","Rays2","Smoke"}) do
		local p = start:FindFirstChild(n)
		if p then p:Emit(1) end
	end
end

--------------------------------------------------------------------
-- SCRAMBLER LASERS MULTI (optimized: keep behavior, reduce churn)
--------------------------------------------------------------------
local ScramblerState = setmetatable({}, { __mode = "k" }) -- [tower] = state

local function ScramblerLasersMultiple(tower, targets)
	if not tower or not tower.Parent or not targets or #targets == 0 then return end

	local config = tower:FindFirstChild("Config")
	if not config then return end
	local firePart = tower:FindFirstChild("Handle")
	if not firePart then return end

	local start = firePart:FindFirstChild("Start")
	if not start then return end

	local beam1: Beam = firePart:FindFirstChild("Beam1")
	local beam2: Beam = firePart:FindFirstChild("Beam2")
	local beam3, beam4, beam5
	local big = config:FindFirstChild("BigCoil") ~= nil
	if big then
		beam3 = firePart:FindFirstChild("Beam3")
		beam4 = firePart:FindFirstChild("Beam4")
		beam5 = firePart:FindFirstChild("Beam5")
	end

	local chargeTemplate = TEMPLATE.Charge
	if not (beam1 and beam2 and chargeTemplate) then return end

	local hrp = tower:FindFirstChild("HumanoidRootPart")
	local attackAnim = getTowerPrimaryAttackSound(tower)
	if attackAnim then
		attackAnim.PlaybackSpeed = gameSpeed
		attackAnim.Playing = true
	end

	local st = ScramblerState[tower]
	if not st then
		st = { charges = setmetatable({}, { __mode = "k" }), running = false }
		ScramblerState[tower] = st
	end

	-- assign beams to centers
	local centers = {}
	for i, target in ipairs(targets) do
		local torso = target and target:FindFirstChild("Torso")
		if torso then
			local center = torso:FindFirstChild("Center")
			if not center then
				center = Instance.new("Attachment")
				center.Name = "Center"
				center.Parent = torso
			end
			centers[i] = center

			-- ensure charge exists
			if not center:FindFirstChild("Charge") then
				local chargeClone = chargeTemplate:Clone()
				chargeClone.Name = "Charge"
				chargeClone.Parent = center
				st.charges[target] = chargeClone

				task.delay(10, function()
					if chargeClone and chargeClone.Parent then chargeClone:Destroy() end
					st.charges[target] = nil
				end)
			end

			if i == 1 then
				beam1.Attachment0 = start
				beam1.Attachment1 = center
			elseif i == 2 then
				beam2.Attachment0 = start
				beam2.Attachment1 = center
			elseif i == 3 and big and beam3 then
				beam3.Attachment0 = start
				beam3.Attachment1 = center
			elseif i == 4 and big and beam4 then
				beam4.Attachment0 = start
				beam4.Attachment1 = center
			elseif i == 5 and big and beam5 then
				beam5.Attachment0 = start
				beam5.Attachment1 = center
			end
		end
	end

	if st.running then return end
	st.running = true

	task.spawn(function()
		while tower and tower.Parent and ScramblerState[tower] == st do
			local any = false
			for target, chargeClone in pairs(st.charges) do
				local hitbox = target and target:FindFirstChild("Hitbox")
				if not (target and target.Parent and chargeClone and chargeClone.Parent and hitbox and hrp) then
					st.charges[target] = nil
				else
					any = true
					if config:FindFirstChild("Range") then
						local mag = (hrp.Position - hitbox.Position).Magnitude
						if mag > config.Range.Value then
							chargeClone:Destroy()
							st.charges[target] = nil
						end
					end
				end
			end

			if not any then
				if attackAnim then attackAnim.Playing = false end
				beam1.Attachment1 = nil
				beam2.Attachment1 = nil
				if beam3 then beam3.Attachment1 = nil end
				if beam4 then beam4.Attachment1 = nil end
				if beam5 then beam5.Attachment1 = nil end
				break
			end

			task.wait(0.2)
		end

		st.running = false
		ScramblerState[tower] = nil
	end)
end



--------------------------------------------------------------------
-- ANIMATION SYSTEM
-- Supports:
--   Animations/Attack                    (legacy mobs / units)
--   Animations/<level>/Attack            (new tower format)
--
-- Design:
--   • one state table per live model
--   • one Animator lookup per model
--   • tracks loaded once per level
--   • marker connections stored + disconnected explicitly
--   • tower level changes invalidate ONLY that tower's old tracks
--   • Destroying/Ancestry cleanup releases every reference
--   • no WaitForChild in attack hot-path
--------------------------------------------------------------------

local AnimationStates = setmetatable({}, { __mode = "k" })
-- A request may arrive before Animations/<level>/<name> has replicated.
-- Keep at most ONE short-lived retry worker per model; the latest request wins.
local PendingAnimationPlay = setmetatable({}, { __mode = "k" })
local AnimationRequestSerial = setmetatable({}, { __mode = "k" })
-- Local gate handles network-order races between attributes and remotes.
local ActiveReaperTowerCasts = setmetatable({}, { __mode = "k" })
local PreloadingAnimationIds = {}

local function warmAnimationAsset(animation)
	if not (animation and animation:IsA("Animation")) then return end
	local id = animation.AnimationId
	if id == "" or PreloadingAnimationIds[id] then return end
	PreloadingAnimationIds[id] = true
	task.spawn(function()
		-- Async, so asset download never blocks firing or movement animations.
		pcall(function()
			ContentProvider:PreloadAsync({animation})
		end)
	end)
end

local function warmModelAnimations(object)
	task.delay(0.1, function()
		if not (object and object.Parent) then return end
		local folder = object:FindFirstChild("Animations")
		if not folder then return end
		for _, child in ipairs(folder:GetDescendants()) do
			warmAnimationAsset(child)
		end
	end)
end

-- Tracks whose final attack pose is intentionally held. Prevent the global
-- GameSpeed-change callback from accidentally unfreezing them.
local FrozenUnitAttackTracks = setmetatable({}, {__mode = "k"})

local SpeedOverrides = {
	["Void"] = 0.1,
	["Dark Knight"] = 0.9,
	["Marksman"] = 0.25,
	["Merchant"] = 0.8,
	["Endbringer"] = 0.5,
	["General Noobicus"] = 0.5,
	["Necromancer"] = 0.75,
	["Doombringer"] = 0.75,
	["Armored Zombie"] = 1.4,
}

local function getAnimationLevel(object)
	if not object then
		return 0
	end

	local level = object:GetAttribute("TowerLevel")
	if typeof(level) == "number" then
		return math.floor(level)
	end

	local config = object:FindFirstChild("Config")
	local levelValue = config and config:FindFirstChild("Level")

	if levelValue and levelValue:IsA("ValueBase") then
		return math.floor(levelValue.Value)
	end

	return 0
end

local function updateTrackSpeed(object, track, animName)
	if not track then
		return
	end

	if FrozenUnitAttackTracks[track] then
		track:AdjustSpeed(0)
		return
	end

	local speed = math.max(gameSpeed, 0.001)

	if animName == "Walk" or animName == "Walk2" then
		speed *= SpeedOverrides[object.Name] or 1
	elseif animName == "Summon" and (ActiveReaperTowerCasts[object]
		or object:GetAttribute("ReaperSummoning") == true) and track.Length > 0 then
		-- Fit level-specific Summon animation into exactly 2 game seconds.
		speed *= track.Length / 2
	end

	track:AdjustSpeed(speed)
end

local function disconnectConnection(connection)
	if connection and connection.Connected then
		connection:Disconnect()
	end
end

local function destroyTrack(track)
	if not track then
		return
	end

	pcall(function()
		track:Stop(0)
	end)

	pcall(function()
		track:Destroy()
	end)
end

local function clearLoadedTracks(state)
	for _, markerList in pairs(state.MarkerConnections) do
		for _, connection in ipairs(markerList) do
			disconnectConnection(connection)
		end
	end

	table.clear(state.MarkerConnections)

	for _, track in pairs(state.Tracks) do
		destroyTrack(track)
	end

	table.clear(state.Tracks)
	table.clear(state.TrackSources)
	table.clear(state.TrackIds)
end

local function cleanupAnimationState(object)
	local state = AnimationStates[object]
	if not state then
		return
	end

	AnimationStates[object] = nil
	state.Destroyed = true

	disconnectConnection(state.DestroyingConnection)
	disconnectConnection(state.AncestryConnection)
	disconnectConnection(state.LevelAttributeConnection)
	disconnectConnection(state.LevelValueConnection)

	clearLoadedTracks(state)
	table.clear(state.PausedTracks)

	state.Animator = nil
	state.Controller = nil
	state.AnimationsFolder = nil
	state.LevelFolder = nil
end

local function getAnimationContainer(state, level)
	local animationsFolder = state.AnimationsFolder
	if not animationsFolder then
		return nil, false
	end

	-- New tower format:
	-- Animations
	--   0
	--   1
	--   2
	-- etc.
	local levelFolder = animationsFolder:FindFirstChild(tostring(level))

	if levelFolder then
		return levelFolder, true
	end

	-- A tower's current level can replicate before its folder. Prefer the
	-- level-0 fallback instead of interpreting it as a legacy mob.
	local levelZero = animationsFolder:FindFirstChild("0")
	if levelZero then
		return levelZero, true
	end

	-- Legacy mobs / units:
	-- Animations
	--   Walk
	--   Attack
	-- etc.
	return animationsFolder, false
end

local function bindLevelValue(state, object)
	disconnectConnection(state.LevelValueConnection)
	state.LevelValueConnection = nil

	local config = object:FindFirstChild("Config")
	local levelValue = config and config:FindFirstChild("Level")

	if not (levelValue and levelValue:IsA("ValueBase")) then
		return
	end

	state.LevelValueConnection = levelValue:GetPropertyChangedSignal("Value"):Connect(function()
		if state.Destroyed or not object.Parent then
			return
		end

		local newLevel = getAnimationLevel(object)

		if newLevel == state.Level then
			return
		end

		state.Level = newLevel
		state.LevelFolder = nil

		clearLoadedTracks(state)

		-- Towers should immediately resume the correct Idle animation
		-- after an in-place upgrade.
		if object:IsDescendantOf(workspace:FindFirstChild("Towers") or workspace) then
			task.defer(function()
				if not state.Destroyed and object.Parent then
					if ActiveReaperTowerCasts[object] or object:GetAttribute("ReaperSummoning") == true then
						playAnimation(object, "Summon")
					else
						playAnimation(object, "Idle")
					end
				end
			end)
		end
	end)
end

local function createAnimationState(object)
	if not object or not object.Parent then
		return nil
	end

	local controller = object:FindFirstChild("AnimationController")
	local animationsFolder = object:FindFirstChild("Animations")

	if not controller or not animationsFolder then
		return nil
	end

	local animator = controller:FindFirstChildOfClass("Animator")

	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	local state = {
		Controller = controller,
		Animator = animator,
		AnimationsFolder = animationsFolder,

		Level = getAnimationLevel(object),
		LevelFolder = nil,

		Tracks = {},
		TrackSources = {},
		TrackIds = {},
		LastWarnAt = {},
		MarkerConnections = {},
		PausedTracks = {},

		DestroyingConnection = nil,
		AncestryConnection = nil,
		LevelAttributeConnection = nil,
		LevelValueConnection = nil,

		Destroyed = false,
	}

	AnimationStates[object] = state

	state.DestroyingConnection = object.Destroying:Connect(function()
		cleanupAnimationState(object)
	end)

	-- Extra safety for models that are merely unparented rather than destroyed.
	state.AncestryConnection = object.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			cleanupAnimationState(object)
		end
	end)

	state.LevelAttributeConnection =
		object:GetAttributeChangedSignal("TowerLevel"):Connect(function()
			if state.Destroyed or not object.Parent then
				return
			end

			local newLevel = getAnimationLevel(object)

			if newLevel == state.Level then
				return
			end

			state.Level = newLevel
			state.LevelFolder = nil

			clearLoadedTracks(state)

			if object:IsDescendantOf(workspace:FindFirstChild("Towers") or workspace) then
				task.defer(function()
					if not state.Destroyed and object.Parent then
						if ActiveReaperTowerCasts[object] or object:GetAttribute("ReaperSummoning") == true then
							playAnimation(object, "Summon")
						else
							playAnimation(object, "Idle")
						end
					end
				end)
			end
		end)

	bindLevelValue(state, object)

	return state
end

local function getAnimationState(object)
	local state = AnimationStates[object]

	if state and not state.Destroyed then
		-- An upgrade or replication update can replace the controller/folder.
		-- A cached AnimationTrack from the old hierarchy is not valid anymore.
		if state.Controller.Parent == object
			and state.AnimationsFolder.Parent == object
			and state.Animator.Parent == state.Controller then
			return state
		end
		cleanupAnimationState(object)
	end

	return createAnimationState(object)
end

local function getAnimationObject(state, animName)
	local level = state.Level
	local container, isLevelBased = getAnimationContainer(state, level)

	if not container then
		return nil
	end

	if isLevelBased then
		state.LevelFolder = container
	end

	local animation = container:FindFirstChild(animName)

	-- Specific-level animations take priority, then level 0, then legacy.
	-- Re-evaluated on each use, so a late-replicating higher level takes over.
	if not animation and isLevelBased and level ~= 0 then
		local levelZero = state.AnimationsFolder:FindFirstChild("0")
		if levelZero then
			animation = levelZero:FindFirstChild(animName)
		end
	end
	if not animation then
		animation = state.AnimationsFolder:FindFirstChild(animName)
	end

	return animation
end

local function connectTrackMarkers(object, state, track)
	if state.MarkerConnections[track] then
		return
	end

	local root = object:FindFirstChild("HumanoidRootPart")
	if not root then
		-- Allow marker sounds to be connected after the root replicates.
		return
	end

	local connections = {}
	state.MarkerConnections[track] = connections

	local footstepSound = root:FindFirstChild("FootSteps")
	if footstepSound then
		table.insert(
			connections,
			track:GetMarkerReachedSignal("FootStep"):Connect(function()
				if footstepSound.Parent then
					footstepSound:Play()
				end
			end)
		)
	end

	local rackSound = root:FindFirstChild("Rack")
	if rackSound then
		table.insert(
			connections,
			track:GetMarkerReachedSignal("Rack"):Connect(function()
				if rackSound.Parent then
					rackSound:Play()
				end
			end)
		)
	end
end

-- Try immediately without ever yielding inside the event handler. Missing assets
-- or folders are handled by the retry worker in playAnimation below.
function setAnimation(object, animName)
	if not object or typeof(animName) ~= "string"
		or not object:IsDescendantOf(workspace) then
		return nil
	end
	-- A dead Unit stays replicated for its death animation. Never restart
	-- a cached or delayed Walk/Attack on that same model.
	if object:GetAttribute("UnitDeathPresentation") == true
		or (object:GetAttribute("Dead") == true
			and object.Parent == workspace:FindFirstChild("Units")) then
		return nil
	end

	local state = getAnimationState(object)
	if not state then return nil end

	-- Catch a level changing even when its change signal arrived earlier/later.
	local currentLevel = getAnimationLevel(object)
	if currentLevel ~= state.Level then
		state.Level = currentLevel
		state.LevelFolder = nil
		clearLoadedTracks(state)
	end

	local key = tostring(state.Level) .. ":" .. animName
	local animationObject = getAnimationObject(state, animName)
	if not (animationObject and animationObject:IsA("Animation"))
		or animationObject.AnimationId == "" then
		return nil
	end

	warmAnimationAsset(animationObject)

	local cached = state.Tracks[key]
	if cached then
		if state.TrackSources[key] == animationObject
			and state.TrackIds[key] == animationObject.AnimationId then
			connectTrackMarkers(object, state, cached)
			return cached
		end

		-- E.g. the current-level animation appeared after we cached level 0.
		for _, connection in ipairs(state.MarkerConnections[cached] or {}) do
			disconnectConnection(connection)
		end
		state.MarkerConnections[cached] = nil
		destroyTrack(cached)
		state.Tracks[key] = nil
		state.TrackSources[key] = nil
		state.TrackIds[key] = nil
	end

	local ok, track = pcall(function()
		return state.Animator:LoadAnimation(animationObject)
	end)

	if not ok or not track then
		local now = os.clock()
		if now - (state.LastWarnAt[key] or -10) >= 2 then
			state.LastWarnAt[key] = now
			warn("[Animations] LoadAnimation failed:", object:GetFullName(),
				"level", state.Level, "animation", animName, "error", track)
		end
		return nil
	end

	track.Name = animName
	state.Tracks[key] = track
	state.TrackSources[key] = animationObject
	state.TrackIds[key] = animationObject.AnimationId

	connectTrackMarkers(object, state, track)
	updateTrackSpeed(object, track, animName)
	return track
end

local function playLoadedTrack(object, animName, track)
	updateTrackSpeed(object, track, animName)
	if track.IsPlaying then
		-- Restart one-shot attacks, but never freeze Walk/Idle/BeamLoop at
		-- frame 0 when the server repeats the same loop event.
		if not track.Looped and animName ~= "Idle" and animName ~= "Walk"
			and animName ~= "Walk2" and animName ~= "BeamLoop" then
			track.TimePosition = 0
		end
	else
		track:Play(0)
	end
	return track
end

function playAnimation(object, animName, bypassReaperCast)
	if not (object and object.Parent and typeof(animName) == "string") then
		return nil
	end
	-- Don't let delayed Attack/Idle events or in-place upgrades interrupt
	-- the Summon animation. End explicitly bypasses this lock for Idle.
	if not bypassReaperCast and animName ~= "Summon"
		and (ActiveReaperTowerCasts[object]
			or object:GetAttribute("ReaperSummoning") == true) then
		return nil
	end
	if object:GetAttribute("UnitDeathPresentation") == true
		or (object:GetAttribute("Dead") == true
			and object.Parent == workspace:FindFirstChild("Units")) then
		return nil
	end

	local serial = (AnimationRequestSerial[object] or 0) + 1
	AnimationRequestSerial[object] = serial

	local track = setAnimation(object, animName)
	if track then
		-- Any earlier missing animation must not play over this one later.
		PendingAnimationPlay[object] = nil
		return playLoadedTrack(object, animName, track)
	end

	local pending = PendingAnimationPlay[object]
	local maxWait = (animName == "Idle" or animName == "Walk"
		or animName == "Walk2" or animName == "BeamLoop") and 5 or 1.5

	if pending then
		-- Reuse the worker; don't create a task for each attack packet.
		pending.Name = animName
		pending.Serial = serial
		pending.Expires = os.clock() + maxWait
		return nil
	end

	pending = {
		Name = animName,
		Serial = serial,
		Expires = os.clock() + maxWait,
	}
	PendingAnimationPlay[object] = pending

	task.spawn(function()
		while object.Parent and PendingAnimationPlay[object] == pending
			and object:GetAttribute("UnitDeathPresentation") ~= true
			and not (object:GetAttribute("Dead") == true
				and object.Parent == workspace:FindFirstChild("Units"))
			and os.clock() < pending.Expires do
			task.wait(0.075)
			if PendingAnimationPlay[object] ~= pending or not object.Parent then
				break
			end

			local retryTrack = setAnimation(object, pending.Name)
			if retryTrack then
				if pending.Serial == AnimationRequestSerial[object] then
					playLoadedTrack(object, pending.Name, retryTrack)
				end
				PendingAnimationPlay[object] = nil
				return
			end
		end

		if PendingAnimationPlay[object] == pending then
			PendingAnimationPlay[object] = nil
		end
	end)

	return nil
end


------------------------------------------------------------
-- REAPER EXCLUSIVE ABILITY ANIMATIONS
-- The server owns the queue. This client guarantees that Walk never layers
-- under a Reaper ability and no other AnimateEnemy animation can interrupt it.
------------------------------------------------------------
local function stopAllModelAnimationTracks(object, fadeTime)
	PendingAnimationPlay[object] = nil
	AnimationRequestSerial[object] = (AnimationRequestSerial[object] or 0) + 1
	local state = AnimationStates[object]
	if not state then return end
	for _, track in pairs(state.Tracks) do
		if track and track.IsPlaying then
			track:Stop(fadeTime or 0)
		end
	end
end

local function handleReaperAbilityAnimation(action, reaper, abilityName, duration)
	if not (reaper and reaper.Parent) then return end

	if action == "Start" then
		stopAllModelAnimationTracks(reaper, 0.05)
		playAnimation(reaper, abilityName)
		if duration and duration > 0 then
			-- The ability animation may initially be missing due to replication.
			-- Sync its speed once BOTH the track and asset duration are ready.
			task.spawn(function()
				local start = os.clock()
				while reaper.Parent and os.clock() - start < 3 do
					if reaper:GetAttribute("ReaperCurrentAbility") ~= abilityName then
						return
					end
					local state = AnimationStates[reaper]
					local track = state and state.Tracks[tostring(state.Level) .. ":" .. abilityName]
					if track and track.IsPlaying and track.Length > 0 then
						local speed = math.max(0.01, track.Length / duration * math.max(gameSpeed, 0.01))
						track:AdjustSpeed(speed)
						return
					end
					task.wait(0.05)
				end
			end)
		end
	elseif action == "End" then
		stopAllModelAnimationTracks(reaper, 0.05)
		if reaper.Parent then
			playAnimation(reaper, "Walk")
		end
	end
end

-- Reaper TOWER max-summon animation. Separate from the enemy boss Reaper
-- ability event; never use the enemy Walk animation on a tower.
-- Uses the same cached, level-aware playAnimation/stop helpers as other towers.
local function handleReaperTowerSummonFX(action, model)
	if not (model and model:IsA("Model") and model.Parent) then return end
	if action == "Start" then
		ActiveReaperTowerCasts[model] = true
		stopAllModelAnimationTracks(model, 0.05)
		local track = playAnimation(model, "Summon")
		if track then track.Looped = false end

		-- Animation length may be 0 immediately after LoadAnimation. Adjust
		-- once it loads so the full motion lasts 2 game seconds.
		if not track or track.Length <= 0 then
			task.spawn(function()
				local deadline = os.clock() + 1.5
				while model.Parent and ActiveReaperTowerCasts[model] and os.clock() < deadline do
					local loaded = setAnimation(model, "Summon")
					if loaded and loaded.Length > 0 then
						loaded.Looped = false
						if not loaded.IsPlaying then playAnimation(model, "Summon") end
						updateTrackSpeed(model, loaded, "Summon")
						break
					end
					task.wait(0.05)
				end
			end)
		end
	elseif action == "End" then
		ActiveReaperTowerCasts[model] = nil
		stopAllModelAnimationTracks(model, 0.05)
		playAnimation(model, "Idle", true)
	end
end

task.spawn(function()
	local fxRemote = events:WaitForChild("ReaperSummonFX")
	fxRemote.OnClientEvent:Connect(handleReaperTowerSummonFX)
end)

-- Connect without blocking the rest of this large animation script while the
-- Reaper remotes replicate.
task.spawn(function()
	local reaperFolder = events:WaitForChild("Reaper")
	local reaperAnimationEvent = reaperFolder:WaitForChild("Animation")
	reaperAnimationEvent.OnClientEvent:Connect(handleReaperAbilityAnimation)
end)

function StopAnimation(object, animName)
	local pending = PendingAnimationPlay[object]
	if pending and pending.Name == animName then
		PendingAnimationPlay[object] = nil
		AnimationRequestSerial[object] = (AnimationRequestSerial[object] or 0) + 1
	end

	local state = AnimationStates[object]
	if not state then return end

	local key = tostring(state.Level) .. ":" .. animName
	local track = state.Tracks[key]

	if track and track.IsPlaying then
		track:Stop(0)
	end
end

local function pauseModelAnimations(model)
	local state = getAnimationState(model)
	if not state then
		return
	end

	table.clear(state.PausedTracks)

	for _, track in pairs(state.Tracks) do
		if track and track.IsPlaying then
			track:AdjustSpeed(0)
			table.insert(state.PausedTracks, track)
		end
	end
end

local function resumeModelAnimations(model)
	local state = AnimationStates[model]
	if not state then
		return
	end

	for _, track in ipairs(state.PausedTracks) do
		if track then
			updateTrackSpeed(model, track, track.Name)
		end
	end

	table.clear(state.PausedTracks)
end

ReplicatedStorage.Events.PauseAnimation.OnClientEvent:Connect(pauseModelAnimations)
ReplicatedStorage.Events.ResumeAnimation.OnClientEvent:Connect(resumeModelAnimations)

-- Update only currently loaded tracks when game speed changes.
-- One global connection; never one connection per track.
if GameSpeedValue then
	GameSpeedValue:GetPropertyChangedSignal("Value"):Connect(function()
		for object, state in pairs(AnimationStates) do
			if state.Destroyed or not object.Parent then
				cleanupAnimationState(object)
				continue
			end

			for _, track in pairs(state.Tracks) do
				if track and track.IsPlaying then
					updateTrackSpeed(object, track, track.Name)
				end
			end
		end
	end)
end

--------------------------------------------------------------------
-- AUTO PLAY ON SPAWN
--------------------------------------------------------------------
local function playSpawnAnimation(object, animationName)
	-- Warm assets in parallel so the first firing animation is less likely to
	-- spend its whole duration downloading. Loading never blocks game logic.
	warmModelAnimations(object)

	-- Play immediately if ready, otherwise the retry worker handles late
	-- replication of the controller, folder and level-specific animation.
	task.defer(function()
		if not (object and object.Parent) then return end

		-- Re-read state at playback time; Reaper or Frankenstein attributes may
		-- have replicated after ChildAdded fired.
		if object:GetAttribute("ReaperAbilityActive") == true then
			local ability = object:GetAttribute("ReaperCurrentAbility")
			if typeof(ability) == "string" and ability ~= "" then
				animationName = ability
			end
		elseif object:GetAttribute("FrankensteinTransformed") == true then
			animationName = "Walk2"
		end

		playAnimation(object, animationName)
	end)
end

local MobsFolder = workspace:WaitForChild("Mobs")
local UnitsFolder = workspace:WaitForChild("Units")
local TowersFolder = workspace:WaitForChild("Towers")

local function animateMobOnSpawn(object)
	if object:GetAttribute("ReaperAbilityActive") == true then
		local ability = object:GetAttribute("ReaperCurrentAbility")
		if typeof(ability) == "string" and ability ~= "" then
			playSpawnAnimation(object, ability)
			return
		end
	end
	playSpawnAnimation(object,
		object:GetAttribute("FrankensteinTransformed") == true and "Walk2" or "Walk")
end

MobsFolder.ChildAdded:Connect(animateMobOnSpawn)
UnitsFolder.ChildAdded:Connect(function(object)
	playSpawnAnimation(object, "Walk")
end)
TowersFolder.ChildAdded:Connect(function(object)
	playSpawnAnimation(object, "Idle")
end)

-- Existing models must also start playing (e.g. LocalScript started late).
for _, object in ipairs(MobsFolder:GetChildren()) do
	animateMobOnSpawn(object)
end
for _, object in ipairs(UnitsFolder:GetChildren()) do
	playSpawnAnimation(object, "Walk")
end
for _, object in ipairs(TowersFolder:GetChildren()) do
	playSpawnAnimation(object, "Idle")
end


events.Behemoth.RevUp.OnClientEvent:Connect(function(tower, animation)
	playAnimation(tower, animation)
	local Weapon = tower:FindFirstChild("Weapon")
	local HRP = tower:FindFirstChild("HumanoidRootPart")
	if Weapon and HRP then
		local Sound = HRP:FindFirstChild(animation)
		local Rev = Weapon.Handle:FindFirstChild("Rev")
		Rev.Spin.Enabled = true
		Sound.PlaybackSpeed = 0.8 / gameSpeed
		Sound:Play()
	end
end)

events.Behemoth.RevDown.OnClientEvent:Connect(function(tower, animation)
	local Weapon = tower:FindFirstChild("Weapon")
	local HRP = tower:FindFirstChild("HumanoidRootPart")
	if Weapon and HRP then
		local Sound = HRP:FindFirstChild(animation)
		local Rev = Weapon.Handle:FindFirstChild("Rev")
		Rev.Spin.Enabled = false
		Sound.PlaybackSpeed = 0.8 / gameSpeed
		Sound:Play()
	end
end)

events.Behemoth.Overheat.OnClientEvent:Connect(function(tower)
	local Weapon = tower:FindFirstChild("Weapon")
	local hrp = tower:FindFirstChild("HumanoidRootPart")
	if Weapon  and hrp then
		local OH = Weapon.Handle:FindFirstChild("OH")
		local Rev = Weapon.Handle:FindFirstChild("Rev")
		OH.OHSmoke.Enabled = true
		OH.Spark.Enabled = true
		Rev.Spin.Enabled = false

		local OHS = hrp:FindFirstChild("Overheat")
		OHS.PlaybackSpeed = 1 / gameSpeed
		OHS:Play()

		task.delay(3 / gameSpeed, function()
			OH.OHSmoke.Enabled = false
			OH.Spark.Enabled = false
		end)
	end
end)

------------------------------------------------------------
-- FRANKENSTEIN PHASE CHANGE
------------------------------------------------------------

local function switchFrankensteinWalk(frankenstein)
	if not frankenstein
		or not frankenstein.Parent
	then
		return
	end

	StopAnimation(
		frankenstein,
		"Walk"
	)

	local walk2 =
		playAnimation(
			frankenstein,
			"Walk2"
		)

	if not walk2 then
		warn(
			"[Animations] Frankenstein is missing Animations.Walk2:",
			frankenstein:GetFullName()
		)
	end
end

FrankensteinTransformEvent.OnClientEvent:Connect(
	function(frankenstein)
		switchFrankensteinWalk(
			frankenstein
		)
	end
)

-- Safety for a Frankenstein that was already transformed before this
-- LocalScript connected.
for _, mob in ipairs(
	workspace:WaitForChild("Mobs"):GetChildren()
	) do
	if mob:GetAttribute("FrankensteinTransformed") == true then
		task.defer(
			function()
				switchFrankensteinWalk(mob)
			end
		)
	end
end

game.ReplicatedStorage.Events.BossDeath.OnClientEvent:Connect(function(mob, animName)
	if mob and mob:GetAttribute("ReaperBossControlled") == true then
		stopAllModelAnimationTracks(mob, 0)
	end

	playAnimation(mob, "Death")
	StopAnimation(mob, "Walk")
	StopAnimation(mob, "Walk2")
end)

-- Unit animation blending:
-- NoStop: Walk -> Attack -> Walk, without freezing the animation.
-- Stop-to-attack: Walk -> Attack -> hold the LAST attack pose while
-- AttackPaused=true -> Walk only after the server releases its 1.5 game-
-- second window. A new shot restarts Attack from frame 0 immediately.
local UnitAttackBlends = setmetatable({}, {__mode = "k"})
local UNIT_ATTACK_FADE = 0.16
local UNIT_END_FRAME_MARGIN = 0.035
local UnitPauseConnections = setmetatable({}, {__mode = "k"})

local function unitHasNoStop(unit)
	local stats = unit:FindFirstChild("EnemyStats")
	local flag = stats and stats:FindFirstChild("NoStop")
	return flag and flag:IsA("BoolValue") and flag.Value == true
end

local function blendUnitWalk(unit, forceFinish)
	if not unit or not unit.Parent or unit:GetAttribute("Dead") == true then return end
	local stats = unit:FindFirstChild("EnemyStats")
	local hp = stats and stats:FindFirstChild("Health")
	if not hp or hp.Value <= 0 then return end
	if unit:GetAttribute("AttackPaused") == true and not unitHasNoStop(unit) then return end

	local blend = UnitAttackBlends[unit]
	if blend then
		local attack = blend.track
		if attack and attack.IsPlaying and not forceFinish then
			return
		end
		-- For held tracks, forceFinish ends the final-pose hold. Invalidate
		-- any old frame-monitor and Ended callback BEFORE stopping the track.
		blend.serial += 1
		blend.track = nil
		blend.frozen = false
		if attack then
			FrozenUnitAttackTracks[attack] = nil
			attack.Looped = false
			if attack.IsPlaying then attack:Stop(UNIT_ATTACK_FADE) end
		end
	end

	local walk = setAnimation(unit, "Walk")
	if walk then
		walk.Looped = true
		walk.Priority = Enum.AnimationPriority.Movement
		if not walk.IsPlaying then walk:Play(UNIT_ATTACK_FADE) end
		updateTrackSpeed(unit, walk, "Walk")
	end
end

local function blendUnitAttack(unit)
	if not unit or not unit.Parent or unit:GetAttribute("Dead") == true then return end
	local stats = unit:FindFirstChild("EnemyStats")
	local hp = stats and stats:FindFirstChild("Health")
	if not hp or hp.Value <= 0 then return end

	local noStop = unitHasNoStop(unit)
	local blend = UnitAttackBlends[unit]
	if not blend then
		blend = {serial = 0}
		UnitAttackBlends[unit] = blend
	end
	blend.serial += 1
	local serial = blend.serial

	local function perform(track)
		if UnitAttackBlends[unit] ~= blend or blend.serial ~= serial
			or not unit.Parent or unit:GetAttribute("Dead") == true then return end

		local walk = setAnimation(unit, "Walk")
		if walk and walk.IsPlaying then walk:Stop(UNIT_ATTACK_FADE) end

		-- A queued first-spawn Walk must never overlay Attack after a delay.
		PendingAnimationPlay[unit] = nil
		AnimationRequestSerial[unit] = (AnimationRequestSerial[unit] or 0) + 1

		local old = blend.track
		if old then
			FrozenUnitAttackTracks[old] = nil
			if old ~= track and old.IsPlaying then old:Stop(0.04) end
		end

		blend.track = track
		blend.frozen = false
		track.Priority = Enum.AnimationPriority.Action
		-- Keeping the stopping attack looped prevents Roblox from removing
		-- its pose before we can freeze it just BEFORE the final frame.
		-- We never actually want to repeat it; the monitor freezes it.
		track.Looped = not noStop
		FrozenUnitAttackTracks[track] = nil
		if track.IsPlaying then track:Stop(0.03) end
		track:Play(UNIT_ATTACK_FADE, 1, math.max(gameSpeed, 0.05))
		track.TimePosition = 0
		updateTrackSpeed(unit, track, "Attack")

		if noStop then
			track.Ended:Once(function()
				if UnitAttackBlends[unit] == blend and blend.serial == serial then
					blendUnitWalk(unit, true)
				end
			end)
			-- Backup for an unusually delayed Ended callback.
			task.spawn(function()
				local elapsed = 0
				while UnitAttackBlends[unit] == blend and blend.serial == serial
					and track.IsPlaying and elapsed < 12 do
					elapsed += RunService.Heartbeat:Wait()
				end
				if UnitAttackBlends[unit] == blend and blend.serial == serial then
					blendUnitWalk(unit, true)
				end
			end)
		else
			-- A stopping unit must remain in the final attack stance while
			-- paused. Poll only while the clip is reaching its final frame,
			-- then park at the last keyframe using AdjustSpeed(0).
			task.spawn(function()
				while UnitAttackBlends[unit] == blend and blend.serial == serial
					and unit.Parent and unit:GetAttribute("Dead") ~= true
					and blend.track == track and track.IsPlaying do
					local dt = RunService.Heartbeat:Wait()
					if track.Length > 0 then
						local margin = math.min(
							track.Length * 0.25,
							math.max(UNIT_END_FRAME_MARGIN,
								dt * math.max(gameSpeed, 0.05) * 1.5)
						)
						if track.TimePosition >= track.Length - margin then
							track.TimePosition = math.max(
								0, track.Length - math.min(UNIT_END_FRAME_MARGIN, track.Length * 0.1)
							)
							blend.frozen = true
							FrozenUnitAttackTracks[track] = true
							track:AdjustSpeed(0)
							return
						end
					end
				end
			end)
		end
	end

	local track = setAnimation(unit, "Attack")
	if track then
		perform(track)
	else
		-- Animation folder/asset may not have replicated yet on first fire.
		task.spawn(function()
			for _ = 1, 24 do
				task.wait(0.065)
				if UnitAttackBlends[unit] ~= blend or blend.serial ~= serial
					or not unit.Parent or unit:GetAttribute("Dead") == true then return end
				local retry = setAnimation(unit, "Attack")
				if retry then perform(retry); return end
			end
		end)
	end
end

-- AttackPaused is authoritative for stopping units. We do NOT resume Walk
-- just because the Attack clip reached the end of its duration.
local function observeUnitPause(unit)
	if UnitPauseConnections[unit] then return end
	local connections = {}
	UnitPauseConnections[unit] = connections
	connections[#connections + 1] = unit:GetAttributeChangedSignal("AttackPaused"):Connect(function()
		if unit:GetAttribute("AttackPaused") ~= true then
			task.defer(function()
				if UnitPauseConnections[unit] == connections then
					blendUnitWalk(unit, true)
				end
			end)
		end
	end)
	connections[#connections + 1] = unit:GetAttributeChangedSignal("Dead"):Connect(function()
		if unit:GetAttribute("Dead") == true then
			local blend = UnitAttackBlends[unit]
			if blend then
				blend.serial += 1
				if blend.track then
					FrozenUnitAttackTracks[blend.track] = nil
				end
			end
			UnitAttackBlends[unit] = nil
		end
	end)
end
UnitsFolder.ChildAdded:Connect(observeUnitPause)
for _, unit in ipairs(UnitsFolder:GetChildren()) do
	observeUnitPause(unit)
end
UnitsFolder.ChildRemoved:Connect(function(unit)
	local blend = UnitAttackBlends[unit]
	if blend then
		blend.serial += 1
		if blend.track then FrozenUnitAttackTracks[blend.track] = nil end
	end
	UnitAttackBlends[unit] = nil
	local connections = UnitPauseConnections[unit]
	if connections then
		for _, con in ipairs(connections) do con:Disconnect() end
	end
	UnitPauseConnections[unit] = nil
end)

events.AnimateUnit.OnClientEvent:Connect(function(unit, animName, target)
	if not unit or unit:GetAttribute("Dead") == true then return end
	if animName == "Attack" then
		blendUnitAttack(unit)
	else
		playAnimation(unit, animName)
	end

	local cfg = unit:FindFirstChild("Config")
	if not cfg then return end

	local hrp = unit:FindFirstChild("HumanoidRootPart")
	local atkSound = hrp and hrp:FindFirstChild("Attack")

	if atkSound then
		atkSound.PlaybackSpeed = gameSpeed

		if not hrp:FindFirstChild("AdjustedSound") then
			atkSound.TimePosition = 0
		else
			atkSound.TimePosition = 0.05
		end

		atkSound:Play()
	end
	MuzzleFlashUnitTurret(unit)
end)

events.AnimateUnit2.OnClientEvent:Connect(function(unit, animName, aimPos, travelTime)
	if not unit or unit:GetAttribute("Dead") == true then return end
	if animName == "Attack" then
		blendUnitAttack(unit)
	else
		playAnimation(unit, animName)
	end

	local cfg = unit:FindFirstChild("Config")
	if not cfg then return end

	local hrp = unit:FindFirstChild("HumanoidRootPart")
	local atkSound = hrp and hrp:FindFirstChild("Attack2")

	if atkSound then
		atkSound.PlaybackSpeed = gameSpeed

		if not hrp:FindFirstChild("AdjustedSound") then
			atkSound.TimePosition = 0
		else
			atkSound.TimePosition = 0.05
		end

		atkSound:Play()
	end
	TankCannon(unit, aimPos, 0.5)
	MuzzleFlashUnitCanon(unit)
end)
--------------------------------------------------------------------
-- EVENTS
--------------------------------------------------------------------
animateTowerEvent.OnClientEvent:Connect(function(tower, animName, target)
	if not tower then return end
	-- An older Attack packet can arrive right as the summon cast starts.
	-- Skip the entire attack FX, not just its AnimationTrack.
	if ActiveReaperTowerCasts[tower] or tower:GetAttribute("ReaperSummoning") == true then return end
	playAnimation(tower, animName)

	local cfg = tower:FindFirstChild("Config")
	if not cfg then return end

	local hrp = tower:FindFirstChild("HumanoidRootPart")
	local atkSound = getTowerPrimaryAttackSound(tower)

	-- mortar cliff tower
	if cfg:FindFirstChild("Splash") and cfg:FindFirstChild("CliffTower") then
		MuzzleFlash(tower)
		if atkSound then
			atkSound.PlaybackSpeed = gameSpeed
			atkSound:Play()
		end

		-- flamethrower handled via ReplicateEffects "FireFlame"
	elseif cfg:FindFirstChild("Flamethrower") then
		-- do nothing here (same as original)

	elseif tower:FindFirstChild("Weapon")
		and tower.Weapon:FindFirstChild("Handle2") then
		DualMuzzleFlash(tower)
		if atkSound then
			atkSound.PlaybackSpeed = gameSpeed
			atkSound:Play()
		end
	elseif cfg:FindFirstChild("DualWield") then
		DualWeaponMuzzleFlash(tower)
		if atkSound then
			atkSound.PlaybackSpeed = gameSpeed
			atkSound:Play()
		end

	elseif cfg:FindFirstChild("WarMachine") then
		WarmachineMuzzleFlash(tower)
		if atkSound then
			atkSound.PlaybackSpeed = gameSpeed
			atkSound:Play()
		end

	elseif cfg:FindFirstChild("Zed") then
		DualUnitMuzzleFlash(tower)

	elseif cfg:FindFirstChild("Medic") then
		-- skip (same)

	elseif tower.Config:FindFirstChild("Coil") then
		-- scrambler coils: server sends targets table
		ScramblerLasersMultiple(tower, target)

	elseif tower.Config:FindFirstChild("Scrambler") then

	elseif cfg:FindFirstChild("BeamerSettings") and target then

	elseif cfg:FindFirstChild("Charged") and cfg:FindFirstChild("DuelBeamer") and target then
		DuelPhaserLaser(tower, target)
	elseif cfg:FindFirstChild("Aviator") then
		if tower.Parent ~= workspace.Mobs then
			AviatorMuzzleFlash(tower)
		end
		playTowerSound(atkSound)
	else
		if tower.Parent ~= workspace.Mobs then
			MuzzleFlash(tower)
		end
		playTowerSound(atkSound)
	end
end)

events:WaitForChild("Helicopter"):WaitForChild("FireRockets").OnClientEvent:Connect(function(tower, target)
	HelicopterRockets(tower, target)
end)

events:WaitForChild("WarMachine"):WaitForChild("FireRockets").OnClientEvent:Connect(function(tower, target)
	WMRocketMuzzleFlash(tower)
	WMRockets(tower, target)
end)

events:WaitForChild("Aviator"):WaitForChild("FireRockets").OnClientEvent:Connect(function(tower, target)
	AviatorRockets(tower, target)
end)

events.Aviator.HandleAviatorMovement.OnClientEvent:Connect(function(tower, rotateAngle)
	if not tower then
		warn("Failed to get Aviator tower")
		return
	end

	local hrp = tower:FindFirstChild("HumanoidRootPart")
	if not hrp then
		warn("Failed to get Aviator HumanoidRootPart")
		return
	end

	local flightPos = hrp:FindFirstChild("FlightPos")
	if not flightPos then
		warn("Failed to get Aviator FlightPos")
		return
	end

	flightPos.CurrentAngle = rotateAngle
end)

events:WaitForChild("AnimateEnemy").OnClientEvent:Connect(function(tower, animName, target)
	if not tower then return end

	if tower:GetAttribute("ReaperAbilityActive") == true then
		return
	end

	playAnimation(tower, animName)

	local weapon = tower:FindFirstChild("Weapon")
	local handle = weapon and weapon:FindFirstChild("Handle")
	local start = handle and handle:FindFirstChild("Start")
	if start then
		local sm = start:FindFirstChild("Smoke"); if sm then sm:Emit(1) end
		local sp = start:FindFirstChild("Spark"); if sp then sp:Emit(1) end
		local fl = start:FindFirstChild("flash1"); if fl then fl:Emit(1) end
	end

	local hrp = tower:FindFirstChild("HumanoidRootPart")
	local atk = hrp and hrp:FindFirstChild("Attack")
	if atk then
		atk.PlaybackSpeed = gameSpeed
	end
end)

animateTowerDeathEvent.OnClientEvent:Connect(function(tower, animName, target)
	if not tower then return end
	playAnimation(tower, animName)
end)

ReplicatedStorage.Events.AnimateBoss.OnClientEvent:Connect(function(boss, animName, target)
	if not boss then return end
	playAnimation(boss, animName)
end)

ReplicatedStorage.Events.Stomp.OnClientEvent:Connect(function(position, MaxRadius)
	local template = TEMPLATE.SonicBoom
	if not template then return end

	local shockWaveInsance = template:Clone()
	shockWaveInsance.CanQuery = false
	shockWaveInsance.Orientation = Vector3.new(0, 90, 0)
	shockWaveInsance.Size = Vector3.new(0, 0, 0)
	shockWaveInsance.Position = position
	shockWaveInsance.Parent = VisualFolder

	local tweenInfo = TweenInfo.new(10, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local tween = TweenService:Create(shockWaveInsance, tweenInfo, { Size = Vector3.new(MaxRadius * 2, 10, MaxRadius * 2) })
	tween:Play()

	-- keep original timing
	task.wait(1)
	shockWaveInsance:Destroy()
end)

if ClientSideEffects then
	ClientSideEffects.OnClientEvent:Connect(function(newTower, target, effect, duration)
		if newTower == nil then return end

		if effect == "SplashProjectile" then
			-- target here is the aimPos (Vector3), duration is travelTime
			local aimPos = target
			local cfg = newTower:FindFirstChild("Config")
			if cfg and cfg:FindFirstChild("CliffTower") then
				MortarfireProjectile(newTower, aimPos, duration)
			else
				fireProjectile(newTower, aimPos, duration)
			end
			return
		end

		if target == nil or effect == nil then return end
		if effect == "Fire" then VisualEffect(effect, target, duration) end
		if effect == "FireFlame" then visualTowerEffect(newTower, effect, target) end
		if effect == "Bleed" then VisualEffect(effect, target, duration) end
	end)
end