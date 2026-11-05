local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local FXEvent = ReplicatedStorage.Events.Shocker:WaitForChild("LightningBolt")

local camera = Workspace.CurrentCamera

local function getJitteredPoint(a, b, alpha, strength)
	local pos = a:Lerp(b, alpha)

	local offset = Vector3.new(
		math.random(-100,100)/100 * strength,
		math.random(-100,100)/100 * strength,
		math.random(-100,100)/100 * strength
	)

	return pos + offset
end

------------------------------------------------
-- CREATE ONE BEAM SEGMENT
------------------------------------------------
local function createBeam(startPos, endPos, lifetime)
	local function newPart(pos)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Transparency = 1
		p.Size = Vector3.zero
		p.CFrame = CFrame.new(pos)
		p.Parent = workspace.Terrain
		return p
	end

	local p0 = newPart(startPos)
	local p1 = newPart(endPos)

	local a0 = Instance.new("Attachment", p0)
	local a1 = Instance.new("Attachment", p1)

	------------------------------------------------
	-- CORE BEAM (bright center)
	------------------------------------------------
	local core = Instance.new("Beam")
	core.Attachment0 = a0
	core.Attachment1 = a1
	core.Width0 = 0.12
	core.Width1 = 0.12
	core.LightEmission = 0.8
	core.LightInfluence = 0.8
	core.Brightness = 22
	core.FaceCamera = true
	core.Color = ColorSequence.new(Color3.fromRGB(120, 220, 255))
	core.Transparency = NumberSequence.new(0)
	core.TextureSpeed = 2
	core.TextureLength = 1
	core.Parent = p0

	------------------------------------------------
	-- GLOW BEAM (fatter aura)
	------------------------------------------------
	local glow = Instance.new("Beam")
	glow.Attachment0 = a0
	glow.Attachment1 = a1
	glow.Width0 = 0.27
	glow.Width1 = 0.27
	core.LightEmission = 0.8
	core.LightInfluence = 0.8
	core.Brightness = 22
	glow.FaceCamera = true
	glow.Color = ColorSequence.new(Color3.fromRGB(0, 85, 255))
	glow.Transparency = NumberSequence.new(0.6)
	glow.Parent = p0

	------------------------------------------------
	-- cleanup
	------------------------------------------------
	game:GetService("Debris"):AddItem(p0, lifetime)
	game:GetService("Debris"):AddItem(p1, lifetime)
end

------------------------------------------------
-- GET SAFE POSITION
------------------------------------------------
local function getHitPos(model)
	if not model then return nil end

	local hit = model:FindFirstChild("Hitbox")
	if not hit or not hit:IsA("BasePart") then return nil end
	if not hit.Parent then return nil end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then return nil end

	return hit.Position
end

------------------------------------------------
-- PLAY CHAIN FX
------------------------------------------------
local function playChain(towerModel, chain)
	if not towerModel or not chain or #chain == 0 then return end

	local weapon = towerModel:FindFirstChild("Weapon")
	local handle = weapon and weapon:FindFirstChild("Handle")
	local startAttachment = handle and handle:FindFirstChild("Lightning")
	if not startAttachment then return end

	local startPos = startAttachment.WorldPosition

	local MAX_CHAIN = 5
	local SEGMENTS = 3 -- more = smoother lightning
	local lifetime = 0.12

	local prevPos = startPos

	for i = 1, math.min(#chain, MAX_CHAIN) do
		local endPos = getHitPos(chain[i])
		if not endPos then break end

		------------------------------------------------
		-- BUILD LIGHTNING PATH (CURVED CHAIN)
		------------------------------------------------
		local points = { prevPos }

		for s = 1, SEGMENTS - 1 do
			local alpha = s / SEGMENTS
			table.insert(points, getJitteredPoint(prevPos, endPos, alpha, 0.15))
		end

		table.insert(points, endPos)

		------------------------------------------------
		-- DRAW SEGMENTS
		------------------------------------------------
		for p = 1, #points - 1 do
			local jitter = Vector3.new(
				math.random(-8,8)/100,
				math.random(-8,8)/100,
				math.random(-8,8)/100
			)

			createBeam(points[p] + jitter, points[p+1] + jitter, lifetime * 1.1)
		end

		------------------------------------------------
		-- UPDATE CHAIN STEP
		------------------------------------------------
		prevPos = endPos
	end
end

------------------------------------------------
-- EVENT
------------------------------------------------
FXEvent.OnClientEvent:Connect(function(towerModel, hitTargets)
	playChain(towerModel, hitTargets)
end)