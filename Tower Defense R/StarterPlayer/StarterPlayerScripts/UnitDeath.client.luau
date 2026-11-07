-- StarterPlayerScripts/UnitDeath.client.lua
-- Use ONLY ONE copy of this LocalScript.
-- Death animates the ORIGINAL server model while its gameplay is already dead.
-- The server keeps the rig in workspace.Units until DeathEffects.Duration expires;
-- reparenting the rig during Animator playback can interrupt its tracks.
-- Remote + UnitDeathPresentation attribute listeners handle replication order.
--
-- Unit/DeathEffects (Folder)
--   Attributes: Duration = 4 (optional, game-seconds)
--   Animations (Folder)
--      Death (Animation)   <-- required for death animation
--   Sounds (Folder; optional)
--   Particles (Folder; optional)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Workspace = game:GetService("Workspace")

local Events = ReplicatedStorage:WaitForChild("Events")
local UnitDeath = Events:WaitForChild("UnitDeath")
local Units = Workspace:WaitForChild("Units")
local UnitTemplates = ReplicatedStorage:WaitForChild("Units")
local GameSpeed = Workspace:WaitForChild("Info"):WaitForChild("GameSpeed")
local Definitions = require(ReplicatedStorage.GameModules.UnitDefinitions)

local function speed()
	return math.max(GameSpeed.Value, 0)
end

-- Proactively preload optional Death animation assets on existing/future units.
local warmed = {}
local function warmTemplate(template)
	task.spawn(function()
		local effects = template:FindFirstChild("DeathEffects")
		local animations = effects and effects:FindFirstChild("Animations")
		local profile=(Definitions.Units[template.Name] or {}).Death or {}
		local animation = animations and animations:FindFirstChild(profile.Animation or 'Death')
		if animation and animation:IsA("Animation") and animation.AnimationId ~= ""
			and not warmed[animation.AnimationId] then
			warmed[animation.AnimationId] = true
			local ok, err = pcall(ContentProvider.PreloadAsync, ContentProvider, {animation})
			if not ok then warn("[UnitDeath] preload failed:", template.Name, err) end
		end
	end)
end
for _, template in ipairs(UnitTemplates:GetChildren()) do warmTemplate(template) end
UnitTemplates.ChildAdded:Connect(warmTemplate)

local deathTracks = {}
GameSpeed.Changed:Connect(function()
	for model,track in pairs(deathTracks) do
		if model.Parent then track:AdjustSpeed(speed()) else deathTracks[model]=nil; track:Destroy() end
	end
end)
Units.ChildRemoved:Connect(function(model)
	local track=deathTracks[model]
	deathTracks[model]=nil
	if track then track:Stop(0); track:Destroy() end
end)
local processed = setmetatable({}, {__mode = "k"})
local watched = setmetatable({}, {__mode = "k"})

local function rootController(model)
	-- Exactly match the tower/enemy/unit animation script: its animator lives
	-- under the TOP-LEVEL AnimationController. A recursive lookup can grab an
	-- unrelated controller inside a weapon and leave the rig in bind pose.
	local controller = model:FindFirstChild("AnimationController")
	if controller and not controller:IsA("AnimationController") then controller = nil end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local host = controller or humanoid
	if not host then
		host = Instance.new("AnimationController")
		host.Name = "AnimationController"
		host.Parent = model
	end
	local animator = host:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = host
	end
	return animator
end

local function emitAndPlay(effects, root)
	if not root then return end

	local sounds = effects:FindFirstChild("Sounds")
	if sounds then
		for _, original in ipairs(sounds:GetDescendants()) do
			if original:IsA("Sound") then
				local sound = original:Clone()
				sound.Looped = false
				sound.PlaybackSpeed *= speed()
				sound.Parent = root
				sound:Play()
			end
		end
	end

	local particles = effects:FindFirstChild("Particles")
	if particles and root:IsA("BasePart") then
		local attachment = Instance.new("Attachment")
		attachment.Name = "UnitDeathParticles"
		attachment.Parent = root
		for _, original in ipairs(particles:GetDescendants()) do
			if original:IsA("ParticleEmitter") then
				local emitter = original:Clone()
				emitter.Enabled = false
				emitter.Parent = attachment
				emitter:Emit(math.max(0, math.floor(tonumber(original:GetAttribute("EmitCount")) or 20)))
			end
		end
	end
end

local function startDeath(model, deathCFrame)
	if not (model and model:IsA("Model") and model.Parent) or processed[model] then return end
	processed[model] = true

	-- Immediate visual stop; server already disabled gameplay and all damage.
	-- Do not set a client-only flag that can race the server's attributes.
	task.spawn(function()
		local effects = model:FindFirstChild("DeathEffects")
		if not effects then effects = model:WaitForChild("DeathEffects", 0.75) end
		if not (effects and model.Parent) then
			warn("[UnitDeath] No DeathEffects folder for", model.Name)
			return
		end

		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChildWhichIsA("BasePart", true)
		if deathCFrame and typeof(deathCFrame) == "CFrame" and model.PrimaryPart then
			model:PivotTo(deathCFrame)
		end

		-- Walk and Attack MUST stop on the SAME animator as Death. Stop all
		-- other animators as well in case the rig was built with extras.
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("Animator") then
				for _, oldTrack in ipairs(descendant:GetPlayingAnimationTracks()) do
					oldTrack:Stop(0)
				end
			end
		end

		emitAndPlay(effects, root)

		local animFolder = effects:FindFirstChild("Animations")
			or effects:WaitForChild("Animations", 0.75)
		local animationName = model:GetAttribute('UnitDeathAnimation') or 'Death'
		local animation = animFolder and (animFolder:FindFirstChild(animationName)
			or animFolder:WaitForChild(animationName, 0.75))

		if not (animation and animation:IsA("Animation")) then
			warn("[UnitDeath] Missing DeathEffects.Animations.Death (Animation) for", model.Name)
			return
		end
		if animation.AnimationId == "" then
			warn("[UnitDeath] Blank Death AnimationId for", model.Name)
			return
		end
		if not model.Parent then return end

		local animator = rootController(model)
		local track, errorMessage
		for attempt = 1, 3 do
			local success, result = pcall(animator.LoadAnimation, animator, animation)
			if success and result then
				track = result
				break
			end
			errorMessage = result
			if attempt < 3 then task.wait(0.1) end
		end
		if not track then
			warn("[UnitDeath] LoadAnimation failed for", model.Name, animation.AnimationId, errorMessage)
			return
		end

		deathTracks[model]=track
		track.Name = "UnitDeath_Death"
		track.Looped = false
		track.Priority = Enum.AnimationPriority.Action4
		track:Play(0.05, 1, speed())
		-- Sometimes Roblox reports a track before its underlying asset has
		-- been downloaded. Warm the asset without blocking the first Play.
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, {animation})
		end)

		task.delay(1, function()
			if not model.Parent then return end
			if track.Length <= 0 then
				warn("[UnitDeath] Animation asset has not loaded or is invalid:",
					model.Name, animation.AnimationId,
					"Check animation permissions, rig joints, and Output errors")
			end
		end)
	end)
end

-- Observe the server's state as well as the RemoteEvent. The attribute is a
-- durable signal even if an event reaches the client before its Instance.
local function watchUnit(model)
	if not model:IsA("Model") or watched[model] then return end
	watched[model] = true

	local connection
	local function tryDeath()
		if model.Parent and model:GetAttribute("UnitDeathPresentation") == true then
			startDeath(model)
		end
	end
	connection = model:GetAttributeChangedSignal("UnitDeathPresentation"):Connect(tryDeath)
	model.Destroying:Once(function()
		if connection then connection:Disconnect() end
		watched[model] = nil
	end)
	tryDeath()
end

Units.ChildAdded:Connect(watchUnit)
for _, model in ipairs(Units:GetChildren()) do watchUnit(model) end

-- Event carries an accurate death position from the server-side hitbox.
UnitDeath.OnClientEvent:Connect(function(model, deathCFrame)
	if model then
		startDeath(model, deathCFrame)
	end
end)
