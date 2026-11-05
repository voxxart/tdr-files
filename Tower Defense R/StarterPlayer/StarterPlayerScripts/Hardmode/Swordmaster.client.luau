-- SwordmasterClient (LocalScript — place inside StarterPlayerScripts or StarterCharacterScripts)
-- Handles all visual-only effects for the Swordmaster boss.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Info = Workspace:WaitForChild("Info")
local GameSpeedValue = Info:WaitForChild("GameSpeed")

local VisualFolder = Workspace:WaitForChild("Visual")

local Events = ReplicatedStorage:WaitForChild("Events")
local DoombringerEvents = Events:WaitForChild("SwordMaster")
local RocketStormClientEvent = DoombringerEvents:WaitForChild("Rockets")
local BlockClient = DoombringerEvents:WaitForChild("Block")
local SwordRainClient = DoombringerEvents:WaitForChild("SwordRain")
local AAOrbsClient = DoombringerEvents:WaitForChild("AntiAirOrbs")
local FireBreatheClient = DoombringerEvents:WaitForChild("FireBreathe")
local EMPClient = DoombringerEvents:WaitForChild("EMP")

local Particles = ReplicatedStorage:WaitForChild("Particle")
local SwordTemplate = Particles:WaitForChild("Sword")
local AirstrikeFieldTemplate = Particles:WaitForChild("AirstrikeField")
local BurnTemplate = Particles:WaitForChild("Burn")

-- =========================================================
-- helpers
-- =========================================================

local function getGameSpeed()
	local v = GameSpeedValue.Value
	return (v and v > 0) and v or 1
end

local function alive(inst)
	return inst and inst.Parent and inst:IsDescendantOf(Workspace)
end

--- Returns the first descendant that is a ParticleEmitter (or the object itself).
local function emitAll(obj, count)
	if obj:IsA("ParticleEmitter") then
		obj:Emit(count or 20)
		return
	end
	for _, desc in ipairs(obj:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc:Emit(count or 20)
		end
	end
end

local function setParticlesEnabled(obj, enabled)
	if obj:IsA("ParticleEmitter") then
		obj.Enabled = enabled
		return
	end
	for _, desc in ipairs(obj:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc.Enabled = enabled
		end
	end
end

local function playAnimation(boss, animName)
	local controller = boss:FindFirstChild("AnimationController")
	local animations = boss:FindFirstChild("Animations")
	local animObj = animations and animations:FindFirstChild(animName)
	if not controller or not animObj then
		warn("[SwordmasterClient] Missing animation:", animName)
		return nil
	end
	local track = controller:LoadAnimation(animObj)
	track:Play()
	return track
end

-- =========================================================
-- AA ORBS
-- Glowing cylinders that travel at a fixed speed toward
-- flying-tower targets. They "pop" after 5 seconds or on
-- arrival, whichever comes first. Players can outrun them.
-- =========================================================

local ORB_SPEED = 30         -- studs per second
local ORB_LIFETIME = 5       -- seconds before auto-pop
local ORB_RADIUS = 0.5
local ORB_LENGTH = 1.25
local ORB_COLOR = Color3.fromRGB(255, 69, 69)

local function spawnOrb(boss, targetTower)
	local attachment = boss:FindFirstChild("Torso")
		and boss.Torso:FindFirstChild("Core")
		and boss.Torso.Core:FindFirstChild("PrimGlow")
		and boss.Torso.Core.PrimGlow:FindFirstChild("Attachment")
	if not attachment then return end

	-- we track the target's HumanoidRootPart position each frame
	local targetPart = targetTower:FindFirstChild("HumanoidRootPart") or targetTower.PrimaryPart
	if not targetPart then return end

	local orb = Instance.new("Part")
	orb.Name = "AAOrb"
	orb.Size = Vector3.new(ORB_RADIUS * 2, ORB_LENGTH, ORB_RADIUS * 2)
	orb.Shape = Enum.PartType.Cylinder
	orb.Anchored = true
	orb.CanCollide = false
	orb.CastShadow = false
	orb.Material = Enum.Material.Neon
	orb.Color = ORB_COLOR
	orb.CFrame = CFrame.new(attachment.WorldPosition)
	orb.Parent = VisualFolder

	-- glow
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 4
	pointLight.Color = ORB_COLOR
	pointLight.Range = 12
	pointLight.Parent = orb

	local spawnTime = os.clock()
	local popped = false

	local function popOrb()
		if popped then return end
		popped = true
		-- quick scale-out tween
		local tween = TweenService:Create(orb, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.1, 0.1, 0.1),
			Transparency = 1
		})
		tween:Play()
		tween.Completed:Once(function()
			orb:Destroy()
		end)
	end

	-- move the orb every frame
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if popped then
			conn:Disconnect()
			return
		end

		if not alive(orb) then
			conn:Disconnect()
			return
		end

		-- auto-lifetime check
		if os.clock() - spawnTime >= ORB_LIFETIME then
			conn:Disconnect()
			popOrb()
			return
		end

		-- target may have died/moved
		if not alive(targetPart) then
			conn:Disconnect()
			popOrb()
			return
		end

		local targetPos = targetPart.Position
		local currentPos = orb.Position
		local toTarget = targetPos - currentPos
		local dist = toTarget.Magnitude

		local step = ORB_SPEED * dt * getGameSpeed()

		if dist <= step + 0.5 then
			-- arrived
			conn:Disconnect()
			popOrb()
			return
		end

		local dir = toTarget.Unit
		local newPos = currentPos + dir * step

		-- orient cylinder so its length axis points toward target
		-- Cylinders in Roblox have their length along X by default
		orb.CFrame = CFrame.new(newPos, newPos + dir)
			* CFrame.Angles(0, math.rad(90), 0)
	end)
end

AAOrbsClient.OnClientEvent:Connect(function(boss)
	if not alive(boss) then return end

	-- find all flying towers (same logic as server, client-side read)
	local TowersFolder = Workspace:FindFirstChild("Towers")
	if not TowersFolder then return end

	local flyingTargets = {}
	for _, tower in ipairs(TowersFolder:GetChildren()) do
		local cfg = tower:FindFirstChild("Config")
		local flying = cfg and cfg:FindFirstChild("Flying")
		if flying and ((flying:IsA("BoolValue") and flying.Value) or true) then
			local hrp = tower:FindFirstChild("HumanoidRootPart") or tower.PrimaryPart
			if hrp then
				flyingTargets[#flyingTargets + 1] = tower
			end
		end
	end

	-- fire up to 3 orbs, one per target (or random if fewer targets than orbs)
	local ORB_COUNT = 3
	for i = 1, ORB_COUNT do
		if #flyingTargets == 0 then break end
		local target = flyingTargets[math.random(1, #flyingTargets)]
		task.delay((i - 1) * 0.2, function()
			if alive(boss) then
				spawnOrb(boss, target)
			end
		end)
	end
end)

-- =========================================================
-- EMP
-- Plays animation, enables EMP1 + EMP2 particles in torso.
-- =========================================================

EMPClient.OnClientEvent:Connect(function(boss)
	if not alive(boss) then return end

	playAnimation(boss, "EMP")

	local torso = boss:FindFirstChild("Torso")
	if not torso then return end

	local emp1 = torso:FindFirstChild("EMP1")
	local emp2 = torso:FindFirstChild("EMP2")

	if emp1 then setParticlesEnabled(emp1, true) end
	if emp2 then setParticlesEnabled(emp2, true) end

	task.delay(1.8, function()
		if emp1 then setParticlesEnabled(emp1, false) end
		if emp2 then setParticlesEnabled(emp2, false) end
	end)
end)

-- =========================================================
-- SWORD RAIN
-- Spawns swords 30 studs above targets, tweens down, sticks,
-- then flies back up and is destroyed.
-- AirstrikeField ring expands on impact.
-- =========================================================

local SWORD_FALL_DURATION = 0.8  -- seconds to fall down
local SWORD_STICK_DURATION = 2.5 -- seconds embedded in ground
local SWORD_RISE_DURATION = 0.8  -- seconds to fly back up
local SWORD_RISE_HEIGHT = 60     -- how high it flies on exit
local FIELD_EXPAND_DURATION = 0.5

SwordRainClient.OnClientEvent:Connect(function(boss, targets)
	if not targets then return end

	local gs = getGameSpeed()
	
	boss.HumanoidRootPart.Laugh:Play()

	for i, tower in ipairs(targets) do
		task.delay((i - 1) * 0.08, function()
			if not alive(boss) then return end

			local targetPart = tower:FindFirstChild("HumanoidRootPart") or tower.PrimaryPart
			if not targetPart then return end

			local targetPos = targetPart.Position
			local spawnPos = targetPos + Vector3.new(0, 30, 0)

			----------------------------------------------------------------
			-- 🔥 TELEGRAPH PHASE (4 seconds BEFORE sword drops)
			----------------------------------------------------------------
			local warningField = AirstrikeFieldTemplate:Clone()
			warningField.Parent = VisualFolder

			local warningPart = warningField:IsA("BasePart") and warningField
				or warningField:FindFirstChildWhichIsA("BasePart")

			if warningPart then
				warningPart.Anchored = true
				warningPart.CanCollide = false
				warningPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.1, 0))
				warningPart.Size = Vector3.new(0.5, 0.2, 0.5)

				-- slowly pulse/expand during warning
				local warnTween = TweenService:Create(
					warningPart,
					TweenInfo.new(4 / gs, Enum.EasingStyle.Linear),
					{
						Size = Vector3.new(10, 0.2, 10),
						Transparency = 0.3
					}
				)
				warnTween:Play()
			end

			-- wait for telegraph window
			task.wait(4 / gs)

			if warningField then
				warningField:Destroy()
			end

			----------------------------------------------------------------
			-- ⚔️ SWORD DROP PHASE
			----------------------------------------------------------------
			local sword = SwordTemplate:Clone()
			sword.Parent = VisualFolder

			local swordPart = sword.PrimaryPart
			if not swordPart then return end

		

			local landPos = targetPos

			local lookDir = (landPos - spawnPos).Unit
			local baseCF = CFrame.lookAt(spawnPos, spawnPos + lookDir)
			local rotatedCF = baseCF * CFrame.Angles(math.rad(-90), 0, 0)

			sword:SetPrimaryPartCFrame(rotatedCF)

			local fallTween = TweenService:Create(
				swordPart,
				TweenInfo.new(SWORD_FALL_DURATION / gs, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					CFrame = CFrame.new(landPos) * CFrame.Angles(math.rad(-90), 0, 0)
				}
			)

			fallTween:Play()
			

			fallTween.Completed:Once(function()
				if not alive(sword) then return end

				-- impact ring (keep your original behavior)
				local field = AirstrikeFieldTemplate:Clone()
				field.Parent = VisualFolder

				local fieldPart = field:IsA("BasePart") and field
					or field:FindFirstChildWhichIsA("BasePart")

				if fieldPart then
					fieldPart.Anchored = true
					fieldPart.CanCollide = false
					fieldPart.CFrame = CFrame.new(landPos + Vector3.new(0, 0.1, 0))

					fieldPart.Size = Vector3.new(0.5, 0.2, 0.5)

					local expandTween = TweenService:Create(
						fieldPart,
						TweenInfo.new(FIELD_EXPAND_DURATION / gs, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{
							Size = Vector3.new(10, 0.2, 10),
							Transparency = 1
						}
					)

					expandTween:Play()
					expandTween.Completed:Once(function()
						field:Destroy()
					end)
				end

				emitAll(sword, 30)

				task.wait(SWORD_STICK_DURATION / gs)

				if not alive(sword) then return end

				local riseTween = TweenService:Create(
					swordPart,
					TweenInfo.new(SWORD_RISE_DURATION / gs, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{
						Position = landPos + Vector3.new(0, SWORD_RISE_HEIGHT, 0)
					}
				)

				riseTween:Play()
				riseTween.Completed:Once(function()
					sword:Destroy()
				end)
			end)
		end)
	end
end)
-- =========================================================
-- FIRE BREATHE
-- Enables Swordmaster.Head.Dominus.Fire.Flame.Fire particle
-- while active. Affected towers get a Burn particle in their
-- torso that persists until the server stops burning them.
-- =========================================================

-- track active burn particles per tower so we don't double-spawn
local activeBurns = {} -- [tower] = burnPart

local function applyBurnVisual(tower)
	if activeBurns[tower] then return end

	local torso = tower:FindFirstChild("Torso") or tower:FindFirstChild("HumanoidRootPart")
	if not torso then return end

	local burn = BurnTemplate:Clone()
	burn.Parent = VisualFolder

	-- attach burn visually to tower so it follows movement
	if burn:IsA("BasePart") then
		burn.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = burn
		weld.Part1 = torso
		weld.Parent = burn
		burn.CFrame = torso.CFrame
	else
		for _, d in ipairs(burn:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = d
				weld.Part1 = torso
				weld.Parent = d
				d.CFrame = torso.CFrame
			end
		end
	end

	activeBurns[tower] = burn

	-- make sure it visually “feels alive” while burning
	task.spawn(function()
		while activeBurns[tower] == burn and alive(tower) do
			-- small flicker pulse
			setParticlesEnabled(burn, true)
			task.wait(0.2)
		end
	end)

	tower.AncestryChanged:Connect(function()
		if not alive(tower) then
			removeBurnVisual(tower)
		end
	end)
end

local function removeBurnVisual(tower)
	local burn = activeBurns[tower]
	if burn then
		burn:Destroy()
		activeBurns[tower] = nil
	end
end

FireBreatheClient.OnClientEvent:Connect(function(boss, duration, primaryTarget)
	if not alive(boss) then return end

	-- flame particle
	local flameParticle = boss:FindFirstChild("Head")
		and boss.Head:FindFirstChild("Dominus")
		and boss.Head.Dominus:FindFirstChild("Fire")
		and boss.Head.Dominus.Fire:FindFirstChild("Flame")
		and boss.Head.Dominus.Fire.Flame:FindFirstChild("Fire")

	if flameParticle then
		flameParticle.Enabled = true
	end

	local gs = getGameSpeed()
	local breatheDuration = (duration or 3.5) / gs

	local BURN_RADIUS = 10
	local elapsed = 0
	local burnedThisAbility = {}

	local TowersFolder = workspace:FindFirstChild("Towers")

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt

		if elapsed >= breatheDuration then
			conn:Disconnect()

			if flameParticle and alive(boss) then
				flameParticle.Enabled = false
			end

			for tower in pairs(burnedThisAbility) do
				removeBurnVisual(tower)
			end

			return
		end

		if not alive(boss) then
			conn:Disconnect()
			if flameParticle then flameParticle.Enabled = false end
			return
		end

		if not TowersFolder then return end

		if not primaryTarget or not primaryTarget.PrimaryPart then return end

		local origin = primaryTarget.PrimaryPart.Position

		for _, tower in ipairs(TowersFolder:GetChildren()) do
			if tower.PrimaryPart then
				local dist = (tower.PrimaryPart.Position - origin).Magnitude

				if dist <= BURN_RADIUS then
					if not burnedThisAbility[tower] then
						burnedThisAbility[tower] = true
						if not burnedThisAbility[tower] then
							burnedThisAbility[tower] = true
							applyBurnVisual(tower)
						end
					end
				end
			end
		end
	end)
end)

-- =========================================================
-- ROCKET STORM
-- Rockets launch straight up, arc over, then nose-dive to
-- target. The part always faces its velocity direction.
-- =========================================================

local ROCKET_LAUNCH_HEIGHT = 80    -- studs straight up
local ROCKET_LAUNCH_SPEED = 75    -- studs/s during ascent
local ROCKET_DIVE_SPEED = 82      -- studs/s during dive
local ROCKET_SIZE = Vector3.new(0.6, 0.6, 2.5)
local ROCKET_COLOR = Color3.fromRGB(255, 100, 40)

local function fireRocket(boss, targetTower)
	local hrp = boss:FindFirstChild("HumanoidRootPart") or boss:FindFirstChild("Torso")
	if not hrp then return end

	local startPos = hrp.Position + Vector3.new(
		math.random(-4, 4), 2, math.random(-4, 4)
	)
	local apexPos = startPos + Vector3.new(
		math.random(-20, 20), ROCKET_LAUNCH_HEIGHT, math.random(-20, 20)
	)

	local targetPart = targetTower:FindFirstChild("HumanoidRootPart") or targetTower.PrimaryPart
	if not targetPart then return end

	-- Build the rocket part
	local rocket = Instance.new("Part")
	rocket.Name = "SwordmasterRocket"
	rocket.Size = ROCKET_SIZE
	rocket.Anchored = true
	rocket.CanCollide = false
	rocket.CastShadow = false
	rocket.Material = Enum.Material.Neon
	rocket.Color = ROCKET_COLOR
	rocket.CFrame = CFrame.new(startPos, startPos + Vector3.new(0, 1, 0))
	rocket.Parent = VisualFolder
	boss.HumanoidRootPart.Rockets:Play()
	-- trail
	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment") a0.Parent = rocket
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, ROCKET_SIZE.Z / 2)
	a1.Parent = rocket
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.MinLength = 0
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 80)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 10)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = rocket

	-- smoke/fire particles
	local sparks = Instance.new("ParticleEmitter")
	sparks.Parent = rocket
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 80)),
	})
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Lifetime = NumberRange.new(0.15, 0.4)
	sparks.Rate = 60
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	sparks.Speed = NumberRange.new(1, 4)
	sparks.SpreadAngle = Vector2.new(30, 30)
	sparks.Rotation = NumberRange.new(0, 360)

	local gs = getGameSpeed()
	local destroyed = false

	local function destroyRocket()
		if destroyed then return end
		destroyed = true
		sparks.Enabled = false
		trail.Enabled = false
		local ExplosionSound = Instance.new("Sound")
		ExplosionSound.Parent = rocket
		ExplosionSound.SoundId = "rbxassetid://262562442"
		ExplosionSound:Play()
		local flash = Instance.new("Part")
		flash.Anchored = true
		flash.CanCollide = false
		flash.Size = Vector3.new(4, 4, 4)
		flash.Shape = Enum.PartType.Ball
		flash.Material = Enum.Material.Neon
		flash.Color = Color3.fromRGB(255, 200, 80)
		flash.CFrame = rocket.CFrame
		flash.Parent = VisualFolder
		local flashTween = TweenService:Create(flash,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(10, 10, 10), Transparency = 1 }
		)
		flashTween:Play()
		flashTween.Completed:Once(function() flash:Destroy() end)
		rocket:Destroy()
	end

	task.spawn(function()
		-- PHASE 1: straight up to apex
		local phase1Dist = (apexPos - startPos).Magnitude
		local phase1Time = phase1Dist / (ROCKET_LAUNCH_SPEED * gs)
		local elapsed = 0

		while elapsed < phase1Time do
			local dt = task.wait()
			if destroyed then return end
			elapsed += dt * gs
			local t = math.clamp(elapsed / phase1Time, 0, 1)
			local pos = startPos:Lerp(apexPos, t)
			local vel = (apexPos - startPos).Unit
			rocket.CFrame = CFrame.new(pos, pos + vel)
		end
		rocket.CFrame = CFrame.new(apexPos, apexPos + (apexPos - startPos).Unit)

		if destroyed then return end

		-- brief pause at apex so the arc feels physical
		task.wait(0.05)

		-- PHASE 2: nose-dive toward target
		local targetPos = targetPart.Position

		-- recalculate in case tower moved slightly
		local phase2Dist = (targetPos - apexPos).Magnitude
		local phase2Time = phase2Dist / (ROCKET_DIVE_SPEED * gs)
		elapsed = 0

		while elapsed < phase2Time do
			local dt = task.wait()
			if destroyed then return end
			elapsed += dt * gs
			local t = math.clamp(elapsed / phase2Time, 0, 1)
			-- use the live target position each frame so it tracks
			local liveTarget = alive(targetPart) and targetPart.Position or targetPos
			local pos = apexPos:Lerp(liveTarget, t)
			local vel = (liveTarget - apexPos).Unit
			rocket.CFrame = CFrame.new(pos, pos + vel)
		end

		destroyRocket()
	end)
end

RocketStormClientEvent.OnClientEvent:Connect(function(boss, targets)
	if not alive(boss) or not targets then return end

	for i, tower in ipairs(targets) do
		task.delay((i - 1) * 0.3, function()
			if alive(boss) and tower and tower.Parent then
				fireRocket(boss, tower)
			end
		end)
	end
end)

-- =========================================================
-- BLOCK  (simple visual acknowledgement — shield glow)
-- Server handles invulnerability; we just add a client glow.
-- =========================================================

BlockClient.OnClientEvent:Connect(function(boss)
	if not alive(boss) then return end

	playAnimation(boss, "Block")

	local torso = boss:FindFirstChild("Torso")
	if not torso then return end

	local shield = Instance.new("SelectionBox")
	shield.Name = "BlockShield"
	shield.Adornee = torso
	shield.Color3 = Color3.fromRGB(255, 0, 0)
	shield.LineThickness = 0.06
	shield.SurfaceTransparency = 0.6
	shield.SurfaceColor3 = Color3.fromRGB(255, 0, 0)
	shield.Parent = torso

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 0, 0)
	light.Brightness = 6
	light.Range = 20
	light.Parent = torso

	-- fade out after 5 seconds (matches server BLOCK_DURATION)
	task.delay(5, function()
		if alive(shield) then
			local fadeTween = TweenService:Create(shield,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ SurfaceTransparency = 1 }
			)
			fadeTween:Play()
			fadeTween.Completed:Once(function()
				shield:Destroy()
				light:Destroy()
			end)
		end
	end)
end)