-- ReplicatedStorage.Modules.Orbs
local Orbs = {}

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- Folder to store orb objects
local Storage = Instance.new("Folder")
Storage.Name = "OrbsClient"
Storage.Parent = workspace

-- Reuse a single Random object
local rng = Random.new()

-- Table to track all active orbs
local activeOrbs = {}

-- Single Heartbeat loop for all orbs
RunService.Heartbeat:Connect(function(delta)
	for i = #activeOrbs, 1, -1 do
		local orbData = activeOrbs[i]
		local t = math.clamp(orbData.t + delta / orbData.duration, 0, 1)
		orbData.t = t

		local p0, p2, p1 = orbData.p0, orbData.p2, orbData.p1
		local newPos = (1 - t)^2 * p0 + 2 * (1 - t) * t * p1 + t^2 * p2
		orbData.orb.Position = newPos

		if t >= 1 then
			-- Remove from table
			table.remove(activeOrbs, i)

			-- Tween fade out
			local tween = TweenService:Create(orbData.orb, TweenInfo.new(0.4), {Transparency = 1})
			tween:Play()
			tween.Completed:Once(function()
				orbData.orb:Destroy()
			end)
		end
	end
end)

-- Play function
function Orbs.Play(orbName, duration: number, amount: number, position: Vector3, targetPlayer: Player)
	-- Only render for the local player's target
	if targetPlayer ~= Player then return end
	local Character = targetPlayer.Character
	if not Character then return end

	local OrbObject = ReplicatedStorage.Particle.Orb:FindFirstChild(orbName)
	if not OrbObject then return end

	local HRP = Character:FindFirstChild("HumanoidRootPart")
	if not HRP then return end

	for i = 1, amount do
		local Clone = OrbObject:Clone()
		Clone.Position = position
		Clone.Anchored = true
		Clone.CanCollide = false
		Clone.Parent = Storage

		local RandomX = rng:NextInteger(-3, 20)
		local RandomY = rng:NextInteger(-3, 10)

		-- Calculate midpoint + random offset
		local midpoint = (position + HRP.Position) / 2
		local p1 = midpoint + Vector3.new(RandomX, RandomY, 0)

		-- Add to active orbs table
		table.insert(activeOrbs, {
			orb = Clone,
			p0 = position,
			p1 = p1,
			p2 = HRP.Position,
			t = 0,
			duration = duration
		})
	end
end

return Orbs