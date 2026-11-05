-- StarterPlayerScripts/EnemyDeath.client.lua
--
-- Optional death presentation. Gameplay death remains immediate/server-side.
--
-- Per-enemy setup:
--
-- ReplicatedStorage
-- └ Mobs
--   └ Noob
--     └ DeathEffects                     (Folder) OPTIONAL
--       ├ Animations                     (Folder) OPTIONAL
--       │ ├ Death1                       (Animation)
--       │ └ Death2                       (Animation)
--       ├ Sounds                         (Folder) OPTIONAL
--       │ ├ Death1                       (Sound)
--       │ └ Death2                       (Sound)
--       └ Particles                      (Folder) OPTIONAL
--         ├ Smoke                        (ParticleEmitter)
--         └ Sparks                       (ParticleEmitter)
--
-- DeathEffects attributes:
--   Duration   number, default 2.0 seconds
--
-- ParticleEmitter attributes:
--   EmitCount  integer, default 20
--
-- Multiple animations/sounds are treated as variants. The same enemy ID is
-- used as the random seed so every client picks the same variant.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Events = ReplicatedStorage:WaitForChild("Events")
local EnemyDeath = Events:WaitForChild("EnemyDeath")
local Mobs = ReplicatedStorage:WaitForChild("Mobs")

local Info = Workspace:WaitForChild("Info")
local GameSpeedValue = Info:FindFirstChild("GameSpeed")

local VisualFolder =
	Workspace:FindFirstChild("Visual")
	or Workspace

local function getGameSpeed()
	if not GameSpeedValue then
		return 1
	end

	return math.max(GameSpeedValue.Value, 0.05)
end

local function collectDescendantsOfClass(root, className)
	local found = {}

	if not root then
		return found
	end

	for _, object in ipairs(root:GetDescendants()) do
		if object:IsA(className) then
			found[#found + 1] = object
		end
	end

	return found
end

local function makeEffectAnchor(cframe)
	local part = Instance.new("Part")
	part.Name = "EnemyDeathFX"
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = cframe
	part.Parent = VisualFolder

	return part
end

local function playSoundVariant(deathEffects, parent, random)
	local soundsFolder =
		deathEffects:FindFirstChild("Sounds")

	if not soundsFolder then
		return
	end

	local sounds =
		collectDescendantsOfClass(
			soundsFolder,
			"Sound"
		)

	if #sounds == 0 then
		return
	end

	local sound =
		sounds[
	random:NextInteger(1, #sounds)
	]:Clone()

	sound.Looped = false
	sound.PlaybackSpeed *= getGameSpeed()
	sound.Parent = parent
	sound:Play()
end

local function emitParticles(deathEffects, parent)
	local particlesFolder =
		deathEffects:FindFirstChild("Particles")

	if not particlesFolder then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "DeathParticles"
	attachment.Parent = parent

	-- Direct ParticleEmitter templates are cloned into one root attachment.
	for _, object in ipairs(particlesFolder:GetDescendants()) do
		if object:IsA("ParticleEmitter") then
			local emitter = object:Clone()
			local count =
				object:GetAttribute("EmitCount")
				or 20

			emitter.Enabled = false
			emitter.Parent = attachment
			emitter:Emit(
				math.max(
					0,
					math.floor(count)
				)
			)
		end
	end
end

local function prepareCorpse(template, cframe)
	local success, corpse =
		pcall(function()
			return template:Clone()
		end)

	if not success or not corpse then
		return nil, nil
	end

	corpse.Name = template.Name .. "_DeathVisual"

	-- Strip gameplay-only descendants.
	for _, name in ipairs({
		"EnemyStats",
		"Effects",
		"Alpha",
		"Hitbox",
		}) do
		local object = corpse:FindFirstChild(name)

		if object then
			object:Destroy()
		end
	end

	local root =
		corpse.PrimaryPart
		or corpse:FindFirstChild("HumanoidRootPart")
		or corpse:FindFirstChildWhichIsA("BasePart")

	if not root then
		corpse:Destroy()
		return nil, nil
	end

	corpse.PrimaryPart = root

	for _, object in ipairs(corpse:GetDescendants()) do
		if object:IsA("BasePart") then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			object.Massless = true

		elseif object:IsA("BillboardGui")
			or object:IsA("SurfaceGui")
		then
			-- Health bars / gameplay UI should not survive death.
			object.Enabled = false
		end
	end

	-- Preserve the template's rig/weld setup. Only the root is forcibly
	-- anchored so Motor6D animation can still pose the visual.
	root.Anchored = true

	corpse:PivotTo(cframe)
	corpse.Parent = VisualFolder

	return corpse, root
end

local function playAnimationVariant(
	deathEffects,
	corpse,
	random
)
	local animationsFolder =
		deathEffects:FindFirstChild("Animations")

	if not animationsFolder then
		return nil
	end

	local animations =
		collectDescendantsOfClass(
			animationsFolder,
			"Animation"
		)

	if #animations == 0 then
		return nil
	end

	local controller =
		corpse:FindFirstChild(
			"AnimationController",
			true
		)

	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = corpse
	end

	local animator =
		controller:FindFirstChildOfClass(
			"Animator"
		)

	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	local animation =
		animations[
	random:NextInteger(
		1,
		#animations
	)
	]

	local track
	local success =
		pcall(function()
			track =
			animator:LoadAnimation(
				animation
			)
		end)

	if not success or not track then
		return nil
	end

	track.Looped = false
	track.Priority =
		Enum.AnimationPriority.Action4

	track:Play(0)
	track:AdjustSpeed(getGameSpeed())

	return track
end

EnemyDeath.OnClientEvent:Connect(
	function(enemyName, deathCFrame, enemyId)
		if typeof(enemyName) ~= "string"
			or typeof(deathCFrame) ~= "CFrame"
		then
			return
		end

		local template =
			Mobs:FindFirstChild(enemyName)

		if not template then
			return
		end

		local deathEffects =
			template:FindFirstChild(
				"DeathEffects"
			)

		if not deathEffects then
			return
		end

		local random =
			Random.new(
				tonumber(enemyId) or 0
			)

		local duration =
			tonumber(
				deathEffects:GetAttribute(
					"Duration"
				)
			)
			or 2

		local gameSpeed =
			getGameSpeed()

		local realDuration =
			math.max(
				0.05,
				duration / gameSpeed
			)

		local animationsFolder =
			deathEffects:FindFirstChild(
				"Animations"
			)

		local hasAnimation =
			animationsFolder
			and animationsFolder:FindFirstChildWhichIsA(
				"Animation",
				true
			) ~= nil

		local corpse
		local effectParent

		if hasAnimation then
			corpse, effectParent =
				prepareCorpse(
					template,
					deathCFrame
				)
		end

		if not effectParent then
			effectParent =
				makeEffectAnchor(
					deathCFrame
				)
		end

		if corpse then
			playAnimationVariant(
				deathEffects,
				corpse,
				random
			)
		end

		playSoundVariant(
			deathEffects,
			effectParent,
			random
		)

		emitParticles(
			deathEffects,
			effectParent
		)

		if corpse then
			Debris:AddItem(
				corpse,
				realDuration
			)
		else
			Debris:AddItem(
				effectParent,
				realDuration
			)
		end
	end
)
