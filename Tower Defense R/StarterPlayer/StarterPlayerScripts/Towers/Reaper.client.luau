
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local LightningBolt = require(
	ReplicatedStorage:WaitForChild("LightningBolt")
)

local WarningBillboard = ReplicatedStorage.Particle:WaitForChild("LightningWarning")

local Remote = ReplicatedStorage.Events:WaitForChild("LightningImpactFX")
local GameSpeedValue = workspace:WaitForChild("Info"):WaitForChild("GameSpeed")

--------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------

local CONFIG = {
	Height = 70,
	BuildTime = 0.15,
	HoldTime = 0.2,
	FadeTime = 0.3,

	Thickness = 0.85,
	Jaggedness = 2,
	Segments = 70,

	MainColor = Color3.fromRGB(0, 170, 255),
	ImpactColor = Color3.fromRGB(0, 170, 255),

	ImpactSize = 8,
	BranchCount = 7,

	-- Electrocution
	SurgeDuration = 0.65,
	SurgeArcCount = 5,

	-- Targeted lightning warning
	WarningDuration = 1.2,
	WarningRadius = 7,
	WarningSegments = 40,
	WarningThickness = 0.4,
	WarningGroundOffset = 0.25,
	WarningColor = Color3.fromRGB(218, 134, 122),
	WarningFillTransparency = 0.9,
}

--------------------------------------------------------
-- SHARED HELPERS
--------------------------------------------------------

local function createAttachment(position, axis)
	return {
		WorldPosition = position,
		WorldAxis = axis or Vector3.new(0, -1, 0)
	}
end

--------------------------------------------------------
-- LIGHTNING IMPACT
--------------------------------------------------------

local function createImpact(position, visualSpeed)
	visualSpeed = visualSpeed or 1
	local orb = Instance.new("Part")
	orb.Name = "LightningImpact"
	orb.Shape = Enum.PartType.Ball
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanTouch = false
	orb.CanQuery = false
	orb.Material = Enum.Material.Neon
	orb.Color = CONFIG.ImpactColor
	orb.Transparency = 0.15
	orb.Size = Vector3.new(1, 1, 1)
	orb.Position = position
	orb.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = CONFIG.ImpactColor
	light.Brightness = 8
	light.Range = 25
	light.Parent = orb

	TweenService:Create(
		orb,
		TweenInfo.new(0.45 / visualSpeed, Enum.EasingStyle.Quad),
		{
			Size = Vector3.new(
				CONFIG.ImpactSize,
				CONFIG.ImpactSize,
				CONFIG.ImpactSize
			),
			Transparency = 1
		}
	):Play()

	TweenService:Create(
		light,
		TweenInfo.new(0.45 / visualSpeed),
		{Brightness = 0}
	):Play()

	Debris:AddItem(orb, 0.5 / visualSpeed)
end

--------------------------------------------------------
-- LIGHTNING BRANCHES
--------------------------------------------------------

local function createBranches(position, visualSpeed)
	visualSpeed = visualSpeed or 1
	for i = 1, CONFIG.BranchCount do
		local angle = math.random() * math.pi * 2
		local distance = math.random(4, 11)

		local target = position + Vector3.new(
			math.cos(angle) * distance,
			math.random(0, 3),
			math.sin(angle) * distance
		)

		local a0 = createAttachment(
			position + Vector3.new(0, 0.5, 0)
		)

		local a1 = createAttachment(target)

		local branch = LightningBolt.new(a0, a1, 12)

		branch.Color = CONFIG.MainColor
		branch.Thickness = 0.28
		branch.MinRadius = 0
		branch.MaxRadius = 1.3

		branch.MinTransparency = 0
		branch.MaxTransparency = 1

		branch.PulseSpeed = 1
		branch.PulseLength = 1000000
		branch.ContractFrom = 2

		local branchLife = 0.45 / visualSpeed

		branch.OpacityProfileFunction = function(percent, t)
			return math.clamp(1 - t / branchLife, 0, 1)
		end

		task.delay(branchLife, function()
			branch:Destroy()
		end)
	end
end

--------------------------------------------------------
-- LIGHTNING SOUND
--------------------------------------------------------

local function PlayLightningSound(position, soundId, volume, speed)
	local soundPart = Instance.new("Part")
	soundPart.Name = "LightningSound"
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.CanTouch = false
	soundPart.CanQuery = false
	soundPart.Transparency = 1
	soundPart.Size = Vector3.new(1, 1, 1)
	soundPart.Position = position
	soundPart.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(soundId)
	sound.Volume = volume or 1
	sound.PlaybackSpeed = speed or 1

	sound.RollOffMode = Enum.RollOffMode.Inverse
	sound.RollOffMinDistance = 15
	sound.RollOffMaxDistance = 180

	sound.Parent = soundPart

	sound.Ended:Once(function()
		soundPart:Destroy()
	end)

	sound:Play()

	Debris:AddItem(soundPart, 15)
end

--------------------------------------------------------
-- LIGHTNING STRIKE
--------------------------------------------------------

local function LightningStrike(hitPosition, visualSpeed)
	visualSpeed = math.max(visualSpeed or 1, 0.01)
	local startPosition = hitPosition + Vector3.new(
		math.random(-7, 7),
		CONFIG.Height,
		math.random(-7, 7)
	)

	-- Original charging sound, still disabled
	-- PlayLightningSound(hitPosition, 15110260312, 0.8, 1)

	local a0 = createAttachment(startPosition)
	local a1 = createAttachment(hitPosition)

	local bolt = LightningBolt.new(
		a0,
		a1,
		CONFIG.Segments
	)

	bolt.Color = CONFIG.MainColor
	bolt.Thickness = CONFIG.Thickness

	bolt.MinRadius = 0
	bolt.MaxRadius = CONFIG.Jaggedness

	bolt.MinThicknessMultiplier = 0.65
	bolt.MaxThicknessMultiplier = 1.2

	bolt.PulseSpeed = 0.5
	bolt.PulseLength = 1000000

	bolt.MinTransparency = 0
	bolt.MaxTransparency = 1
	bolt.ContractFrom = 2

	local build = CONFIG.BuildTime / visualSpeed
	local hold = CONFIG.HoldTime / visualSpeed
	local fade = CONFIG.FadeTime / visualSpeed

	--------------------------------------------------------
	-- LIGHTNING FORMATION ANIMATION
	--------------------------------------------------------

	bolt.OpacityProfileFunction = function(percent, t)
		local progress = math.clamp(t / build, 0, 1)

		local leadingEdge = math.clamp(
			(progress - percent) / 0.035,
			0,
			1
		)

		local frontGlow = math.exp(
			-math.abs(progress - percent) * 55
		)

		local opacity = math.max(
			leadingEdge * 0.9,
			frontGlow * 0.75
		)

		if t >= build then
			local flicker =
				0.85
				+ 0.1 * math.sin(t * 65)
				+ 0.05 * math.sin(t * 127)

			opacity *= flicker
		end

		local fadeStart = build + hold

		if t > fadeStart then
			local fadeProgress = math.clamp(
				(t - fadeStart) / fade,
				0,
				1
			)

			opacity *= (1 - fadeProgress) ^ 1.5
		end

		return math.clamp(opacity, 0, 1)
	end

	--------------------------------------------------------
	-- IMPACT EFFECTS
	--------------------------------------------------------

	task.delay(build, function()
		createImpact(hitPosition, visualSpeed)
		createBranches(hitPosition, visualSpeed)

		PlayLightningSound(
			hitPosition,
			18650085493,
			0.75,
			visualSpeed
		)
	end)

	local lifetime = build + hold + fade

	task.delay(lifetime + 0.05, function()
		bolt:Destroy()
	end)
end

--------------------------------------------------------
-- ELECTROCUTION EFFECT ON R6 CHARACTERS
--------------------------------------------------------

local function ElectrocuteCharacter(character)
	if not character or not character.Parent then return end

	local limbs = {
		character:FindFirstChild("Head"),
		character:FindFirstChild("Torso"),
		character:FindFirstChild("Left Arm"),
		character:FindFirstChild("Right Arm"),
		character:FindFirstChild("Left Leg"),
		character:FindFirstChild("Right Leg")
	}

	local validLimbs = {}

	for _, limb in ipairs(limbs) do
		if limb then
			table.insert(validLimbs, limb)
		end
	end

	if #validLimbs < 2 then return end

	--------------------------------------------------------
	-- GLOWING SILHOUETTE
	--------------------------------------------------------

	local highlight = Instance.new("Highlight")
	highlight.Name = "ElectricSurge"
	highlight.FillColor = CONFIG.MainColor
	highlight.OutlineColor = Color3.fromRGB(200, 235, 255)
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = character
	highlight.Parent = character

	--------------------------------------------------------
	-- ELECTRICAL PARTICLES
	--------------------------------------------------------

	local emitters = {}

	for _, limb in ipairs(validLimbs) do
		local attachment = Instance.new("Attachment")
		attachment.Name = "ElectricSparkAttachment"
		attachment.Parent = limb

		local particles = Instance.new("ParticleEmitter")
		particles.Name = "ElectricSparks"
		particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"

		particles.Color = ColorSequence.new(
			CONFIG.MainColor,
			Color3.fromRGB(220, 245, 255)
		)

		particles.LightEmission = 1
		particles.Rate = 0
		particles.Lifetime = NumberRange.new(0.12, 0.25)
		particles.Speed = NumberRange.new(2, 6)
		particles.SpreadAngle = Vector2.new(180, 180)

		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.28),
			NumberSequenceKeypoint.new(1, 0)
		})

		particles.Parent = attachment

		table.insert(emitters, particles)

		Debris:AddItem(
			attachment,
			CONFIG.SurgeDuration + 0.5
		)
	end

	local startTime = os.clock()

	task.spawn(function()
		while os.clock() - startTime < CONFIG.SurgeDuration
			and character.Parent do

			highlight.FillTransparency = math.random(35, 85) / 100

			for _, emitter in ipairs(emitters) do
				if emitter.Parent then
					emitter:Emit(3)
				end
			end

			--------------------------------------------------------
			-- ELECTRICAL ARCS BETWEEN BODY PARTS
			--------------------------------------------------------

			for i = 1, CONFIG.SurgeArcCount do
				local partA = validLimbs[math.random(1, #validLimbs)]
				local partB = validLimbs[math.random(1, #validLimbs)]

				if partA ~= partB then
					local attachmentA = Instance.new("Attachment")
					attachmentA.Position = Vector3.new(
						math.random(-5, 5) / 10,
						math.random(-5, 5) / 10,
						math.random(-5, 5) / 10
					)
					attachmentA.Parent = partA

					local attachmentB = Instance.new("Attachment")
					attachmentB.Position = Vector3.new(
						math.random(-5, 5) / 10,
						math.random(-5, 5) / 10,
						math.random(-5, 5) / 10
					)
					attachmentB.Parent = partB

					local arc = LightningBolt.new(
						attachmentA,
						attachmentB,
						10
					)

					arc.Color = CONFIG.MainColor
					arc.Thickness = 0.16
					arc.MinRadius = 0
					arc.MaxRadius = 0.35
					arc.MinThicknessMultiplier = 0.65
					arc.MaxThicknessMultiplier = 1

					arc.PulseSpeed = 1
					arc.PulseLength = 1000000
					arc.MinTransparency = 0
					arc.MaxTransparency = 0
					arc.ContractFrom = 2

					local arcLife = 0.11

					arc.OpacityProfileFunction = function(percent, t)
						return math.clamp(1 - t / arcLife, 0, 1)
					end

					task.delay(arcLife, function()
						arc:Destroy()
						attachmentA:Destroy()
						attachmentB:Destroy()
					end)
				end
			end

			task.wait(0.09)
		end

		highlight:Destroy()
	end)
end

--------------------------------------------------------
-- LIGHTNING TARGET WARNING SYSTEM
--------------------------------------------------------

local activeWarning = nil

--------------------------------------------------------
-- REMOVE ACTIVE WARNING
--------------------------------------------------------

local function removeWarning()
	if activeWarning then
		activeWarning:Destroy()
		activeWarning = nil
	end
end

--------------------------------------------------------
-- CREATE LIGHTNING WARNING
--------------------------------------------------------

local function createStrikeWarning(position, duration, radius)
	removeWarning()

	duration = duration or CONFIG.WarningDuration
	radius = radius or CONFIG.WarningRadius

	if duration <= 0 or radius <= 0 then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "LightningTargetWarning"
	folder.Parent = workspace

	activeWarning = folder

	local center = position + Vector3.new(
		0,
		CONFIG.WarningGroundOffset,
		0
	)

	--------------------------------------------------------
	-- DANGER AREA FILL
	--------------------------------------------------------

	local fill = Instance.new("Part")
	fill.Name = "DangerArea"
	fill.Shape = Enum.PartType.Cylinder

	fill.Size = Vector3.new(
		0.12,
		radius * 2,
		radius * 2
	)

	fill.CFrame =
		CFrame.new(center)
		* CFrame.Angles(0, 0, math.rad(90))

	fill.Anchored = true
	fill.CanCollide = false
	fill.CanTouch = false
	fill.CanQuery = false

	fill.Material = Enum.Material.Neon
	fill.Color = CONFIG.WarningColor
	fill.Transparency = CONFIG.WarningFillTransparency
	fill.CastShadow = false

	fill.Parent = folder

	--------------------------------------------------------
	-- OUTER DANGER RING
	--------------------------------------------------------

	local segments = {}

	for i = 1, CONFIG.WarningSegments do
		local angle1 =
			(i - 1) / CONFIG.WarningSegments * math.pi * 2

		local angle2 =
			i / CONFIG.WarningSegments * math.pi * 2

		local point1 = center + Vector3.new(
			math.cos(angle1) * radius,
			0,
			math.sin(angle1) * radius
		)

		local point2 = center + Vector3.new(
			math.cos(angle2) * radius,
			0,
			math.sin(angle2) * radius
		)

		local midpoint = (point1 + point2) / 2
		local length = (point2 - point1).Magnitude

		local segment = Instance.new("Part")
		segment.Name = "WarningRing"

		segment.Size = Vector3.new(
			CONFIG.WarningThickness,
			0.15,
			length + 0.05
		)

		segment.CFrame = CFrame.lookAt(midpoint, point2)

		segment.Anchored = true
		segment.CanCollide = false
		segment.CanTouch = false
		segment.CanQuery = false
		segment.CastShadow = false

		segment.Material = Enum.Material.Neon
		segment.Color = CONFIG.WarningColor
		segment.Transparency = 0.1

		segment.Parent = folder
		table.insert(segments, segment)
	end

	--------------------------------------------------------
	-- CENTER MARKER
	--------------------------------------------------------

	local centerMarker = Instance.new("Part")
	centerMarker.Name = "StrikeCenter"
	centerMarker.Shape = Enum.PartType.Ball

	centerMarker.Size = Vector3.new(1.3, 0.3, 1.3)
	centerMarker.Position = center

	centerMarker.Anchored = true
	centerMarker.CanCollide = false
	centerMarker.CanTouch = false
	centerMarker.CanQuery = false
	centerMarker.CastShadow = false

	centerMarker.Material = Enum.Material.Neon
	centerMarker.Color = CONFIG.WarningColor
	centerMarker.Transparency = 0.2

	centerMarker.Parent = folder

	--------------------------------------------------------
	-- WARNING TEXT
	--------------------------------------------------------

	local billboard = WarningBillboard:Clone()

	billboard.Adornee = fill
	billboard.Parent = fill



	--------------------------------------------------------
	-- PULSING WARNING EFFECT
	--------------------------------------------------------

	local pulseDuration = 0.25

	local pulseInfo = TweenInfo.new(
		pulseDuration,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true
	)

	TweenService:Create(
		fill,
		pulseInfo,
		{
			Transparency = 0.78
		}
	):Play()

	TweenService:Create(
		centerMarker,
		pulseInfo,
		{
			Size = Vector3.new(2.5, 0.3, 2.5),
			Transparency = 0.55
		}
	):Play()

	TweenService:Create(
		label,
		pulseInfo,
		{
			TextTransparency = 0.4
		}
	):Play()

	for _, segment in ipairs(segments) do
		TweenService:Create(
			segment,
			pulseInfo,
			{
				Transparency = 0.5
			}
		):Play()
	end

	--------------------------------------------------------
	-- WARNING CLEANUP
	--------------------------------------------------------

	task.delay(duration + 0.35, function()
		if activeWarning == folder then
			removeWarning()
		elseif folder.Parent then
			folder:Destroy()
		end
	end)
end

--------------------------------------------------------
-- SERVER EVENTS
--------------------------------------------------------

Remote.OnClientEvent:Connect(function(action, data, duration, radius)

	if action == "TargetWarning" then

		-- Show the warning at the future impact position.
		createStrikeWarning(data, duration, radius)

	elseif action == "Strike" then

		-- The warning disappears when lightning begins.
		removeWarning()

		-- Play the original lightning effects.
		LightningStrike(data)

	elseif action == "Electrocute" then

		-- Play the original R6 electrocution effects.
		ElectrocuteCharacter(data)

	end

end)


-- REAPER TOWER MAX-SUMMON LIGHTNING
-- The boss lightning warning system remains completely separate.
-- Server sends only the successful cast's strike at 0.95 GAME seconds.
task.spawn(function()
	local fxRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ReaperSummonFX")
	fxRemote.OnClientEvent:Connect(function(action, towerModel)
		if action ~= "Lightning" or typeof(towerModel) ~= "Instance" then return end
		if not (towerModel:IsA("Model") and towerModel.Parent) then return end
		local root = towerModel:FindFirstChild("HumanoidRootPart")
			or towerModel.PrimaryPart
			or towerModel:FindFirstChildWhichIsA("BasePart")
		if not root then return end
		LightningStrike(root.Position, math.max(GameSpeedValue.Value, 0.01))
	end)
end)
