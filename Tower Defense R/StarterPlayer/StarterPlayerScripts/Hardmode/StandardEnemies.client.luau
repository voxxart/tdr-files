local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local events = ReplicatedStorage:WaitForChild("Events")
local HardEvents = events:WaitForChild("HardmodeEvents")
local ArrowEvent = HardEvents:WaitForChild("Marksman"):WaitForChild("Arrow")

local Particles = ReplicatedStorage:WaitForChild("Particle")
local ArrowTemplate = Particles:WaitForChild("Arrow")

local function gs()
	local v = workspace.Info.GameSpeed.Value
	if v <= 0 then return 1 end
	return v
end

ArrowEvent.OnClientEvent:Connect(function(enemy, tower)
	if not enemy or not enemy.Parent then return end
	if not tower or not tower.Parent then return end

	local weapon = enemy:FindFirstChild("Weapon")
	if not weapon then return end

	local handle = weapon:FindFirstChild("Handle")
	if not handle then return end

	local startAttachment = handle:FindFirstChild("Start")
	if not startAttachment then return end

	local hrp = enemy:FindFirstChild("HumanoidRootPart")

	------------------------------------------------
	-- PROJECTILE SPAWN
	------------------------------------------------
	------------------------------------------------
	-- PROJECTILE SPAWN (STUDS/SECOND VERSION)
	------------------------------------------------
	local arrow = ArrowTemplate:Clone()
	arrow.Parent = workspace
	arrow.Anchored = true
	arrow.CanCollide = false

	local startPos = startAttachment.WorldPosition
	local towerPart = tower.PrimaryPart
	local TowerTorso = tower:FindFirstChild("Torso")
	if not towerPart then return end

	-- random impact point on tower (improves variation)
	local randomOffset = Vector3.new(
		math.random(-towerPart.Size.X/3, towerPart.Size.X/3),
		math.random(-towerPart.Size.Y/3, towerPart.Size.Y/3),
		math.random(-towerPart.Size.Z/3, towerPart.Size.Z/3)
	)

	local hitPos = (towerPart.CFrame * CFrame.new(randomOffset)).Position

	-- direction vector (IMPORTANT: saved for final orientation)
	local shootDir = (hitPos - startPos).Unit

	-- face arrow correctly at spawn
	arrow.CFrame = CFrame.lookAt(startPos, startPos + shootDir)
	arrow.Position = startPos

	------------------------------------------------
	-- STUDS PER SECOND MOVEMENT (NOT TWEEN TIME)
	------------------------------------------------
	local SPEED = 140 -- studs per second (tweak for balance)
	local distance = (hitPos - startPos).Magnitude
	local travelTime = distance / SPEED

	local tween = TweenService:Create(
		arrow,
		TweenInfo.new(travelTime, Enum.EasingStyle.Linear),
		{Position = hitPos}
	)

	tween:Play()

	tween.Completed:Connect(function()
		if not arrow or not arrow.Parent then return end

		-- snap into hit position
		arrow.Position = hitPos
		arrow.Anchored = false

		------------------------------------------------
		-- KEEP ORIGINAL SHOOT DIRECTION FOREVER
		------------------------------------------------
		arrow.CFrame = CFrame.lookAt(hitPos, hitPos + shootDir)

		------------------------------------------------
		-- STICK VISUALLY INTO RANDOMIZED SURFACE
		------------------------------------------------
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = arrow
		weld.Part1 = TowerTorso
		weld.Parent = arrow

		------------------------------------------------
		-- AUTO CLEANUP AFTER 15 SECONDS
		------------------------------------------------
		Debris:AddItem(arrow, 15)
	end)

	------------------------------------------------
	-- FX OFF
	------------------------------------------------
end)


--MERHCNAT BELOw--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OrbEvent = ReplicatedStorage.Events.HardmodeEvents.Merchant.Orb
local OrbTemplate = ReplicatedStorage.Particle.EcogodCube -- Model with PrimaryPart

local FLIGHT_TIME = math.round(2.1 / workspace.Info.GameSpeed.Value)
local ARC_HEIGHT = 8 -- studs at the peak of the arc

local function getOrigin(enemy)
	local held = enemy:FindFirstChild("EcogodCube")
	if held and held.PrimaryPart then
		return held.PrimaryPart.Position
	end

	local hrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Hitbox")
	return hrp and hrp.Position
end

local function getTargetPosition(tower)
	if tower.PrimaryPart then
		return tower.PrimaryPart.Position + Vector3.new(0, 1, 0)
	end
	for _, d in ipairs(tower:GetDescendants()) do
		if d:IsA("BasePart") then
			return d.Position + Vector3.new(0, 1, 0)
		end
	end
	return nil
end

local function throwOrb(enemy, tower)
	if not enemy or not enemy.Parent then return end
	if not tower or not tower.Parent then return end

	local origin = getOrigin(enemy)
	local target = getTargetPosition(tower)
	if not origin or not target then return end

	local projectile = OrbTemplate:Clone()
	for _, d in ipairs(projectile:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end

	projectile.Parent = workspace.Visual or workspace
	projectile:SetPrimaryPartCFrame(CFrame.new(origin))

	local startTime = os.clock()
	local conn

	conn = RunService.RenderStepped:Connect(function()
		local alpha = (os.clock() - startTime) / FLIGHT_TIME
		if alpha >= 1 then
			conn:Disconnect()
			projectile.Burst:Play()
			projectile.Main.Transparency = 1
			projectile.MeshPart.Transparency = 1
			task.delay(projectile.Burst.TimeLength, function()
				projectile:Destroy()
			end)
			return
		end

		-- linear XZ interpolation, parabolic Y arc
		local flatPos = origin:Lerp(target, alpha)
		local arcOffset = math.sin(alpha * math.pi) * ARC_HEIGHT
		local pos = Vector3.new(flatPos.X, flatPos.Y + arcOffset, flatPos.Z)

		projectile:SetPrimaryPartCFrame(CFrame.new(pos))
	end)
end

OrbEvent.OnClientEvent:Connect(throwOrb)
local PlagueThrowEvent = events:WaitForChild("PlagueThrowEvent")

local PotionTemplate = ReplicatedStorage.Particle:WaitForChild("DecayPot")

---------------------------------------------------------
-- CONSTANTS  (must match server values exactly for sync)
---------------------------------------------------------
local POTION_LAND_DELAY  = 0.8   -- seconds the potion travels (mirror of server)
local ARC_HEIGHT         = 12    -- studs at the peak of the arc
local BREAK_SOUND_NAME   = "Break" -- Name of Sound inside the Potion model

---------------------------------------------------------
-- HELPERS
---------------------------------------------------------

-- Quadratic bezier position: P0 -> control point -> P1, t in [0,1]
local function bezier(p0, p1, arcHeight, t)
	local mid = p0:Lerp(p1, 0.5) + Vector3.new(0, arcHeight, 0)
	local a = p0:Lerp(mid, t)
	local b = mid:Lerp(p1, t)
	return a:Lerp(b, t)
end

-- Orient the potion model so its primary part faces the direction of travel
local function orientPotion(potionModel, prevPos, nextPos)
	local dir = (nextPos - prevPos)
	if dir.Magnitude < 0.001 then return end
	dir = dir.Unit
	local up = Vector3.new(0, 1, 0)
	if math.abs(dir:Dot(up)) > 0.99 then
		up = Vector3.new(1, 0, 0)
	end
	potionModel:SetPrimaryPartCFrame(
		CFrame.lookAt(potionModel.PrimaryPart.Position, potionModel.PrimaryPart.Position + dir, up)
	)
end

---------------------------------------------------------
-- THROW VISUAL
---------------------------------------------------------
local function playThrow(enemy, landPosition)
	-- Resolve throw origin from the enemy's Node attachment
	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local node = hrp:FindFirstChild("Node")
	if not node then return end

	local startPosition = node.WorldPosition

	-- Clone the potion model and place it at the origin
	local potion = PotionTemplate:Clone()
	if not potion.PrimaryPart then
		warn("[PlagueDoctor Client] Potion model has no PrimaryPart set.")
		potion:Destroy()
		return
	end
	potion:SetPrimaryPartCFrame(CFrame.new(startPosition))
	potion.Parent = workspace

	-- Disable the break sound during flight (play it only on landing)
	local breakSound = potion:FindFirstChildWhichIsA("Sound", true)
	if breakSound then
		breakSound.RollOffMaxDistance = 60
		breakSound.RollOffMinDistance = 5
	end

	-- Arc the potion over POTION_LAND_DELAY seconds
	local elapsed = 0
	local flightTime = POTION_LAND_DELAY
	local connection

	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed = elapsed + dt
		local t = math.clamp(elapsed / flightTime, 0, 1)

		local prevPos = bezier(startPosition, landPosition, ARC_HEIGHT, math.max(t - 0.01, 0))
		local currentPos = bezier(startPosition, landPosition, ARC_HEIGHT, t)

		potion:SetPrimaryPartCFrame(CFrame.new(currentPos))
		orientPotion(potion, prevPos, currentPos)

		if t >= 1 then
			connection:Disconnect()

			-- Snap to exact land position
			potion:SetPrimaryPartCFrame(CFrame.new(landPosition))

			-- Play break sound
			if breakSound then
				-- Detach from model so it persists after model is destroyed
				local soundClone = breakSound:Clone()
				soundClone.Parent = workspace
				soundClone:Play()
				game:GetService("Debris"):AddItem(soundClone, soundClone.TimeLength + 0.5)
			end

			-- Briefly show landing flash (any ParticleEmitters emit a burst)
			for _, desc in ipairs(potion:GetDescendants()) do
				if desc:IsA("ParticleEmitter") then
					desc:Emit(desc.Rate > 0 and math.ceil(desc.Rate * 0.1) or 10)
				end
			end

			-- Destroy the potion model after a short moment
			-- (the decay field itself is handled server-side)
			game:GetService("Debris"):AddItem(potion, 0.15)
		end
	end)
end

---------------------------------------------------------
-- EVENT LISTENER
---------------------------------------------------------
PlagueThrowEvent.OnClientEvent:Connect(function(enemy, landPosition)
	-- The server fires this exactly POTION_THROW_ANIM_DELAY seconds into
	-- the animation, so we just start flying immediately — the flight time
	-- of POTION_LAND_DELAY will match when the server spawns the decay field.
	task.spawn(playThrow, enemy, landPosition)
end)