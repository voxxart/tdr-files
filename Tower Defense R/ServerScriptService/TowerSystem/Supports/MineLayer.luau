local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Workspace = workspace
local Players = game:GetService('Players')
local Module = {}
function Module.Start(scope, context, newTower, player)
local tower = context.Tower
local getGameSpeed = context.GetGameSpeed
local task = scope.Task
local task_spawn, task_wait, task_delay, task_defer = task.spawn, task.wait, task.delay, task.defer
local os_clock = os.clock
local math_max = math.max
local math_min = math.min
local math_round = math.round
local math_sqrt = math.sqrt
local math_random = math.random
local math_floor = math.floor
local math_clamp = math.clamp
local math_abs = math.abs
local math_rad = math.rad
local math_sin = math.sin
local math_cos = math.cos
local math_atan2 = math.atan2
local PlaceMineEvent = context.PlaceMineEvent
local MineMod = context.MineMod
local function run(newTower)
	local config = newTower:FindFirstChild("Config")
	if not config then warn("[MineLayer] No Config on", newTower:GetFullName()) return end

	local MineStats = config:FindFirstChild("MineStats")
	if not MineStats then warn("[MineLayer] No MineStats folder on", newTower:GetFullName()) return end

	scope:OnCancel(function()
		local current = MineStats:FindFirstChild('CurrentMines')
		if current then current.Value = 0 end
		local bb = MineStats:FindFirstChild('BossBusterMines')
		local bbCurrent = bb and bb:FindFirstChild('CurrentMines')
		if bbCurrent then bbCurrent.Value = 0 end
	end)
	local CurrentMines  = MineStats:FindFirstChild("CurrentMines")
	local MaxMines      = MineStats:FindFirstChild("MaxMines")
	local SelectedMine  = MineStats:FindFirstChild("SelectedMine")
	local MaxTravelTime = MineStats:FindFirstChild("TravelTime")

	local Range    = config:FindFirstChild("Range")    or MineStats:FindFirstChild("Range")
	local Cooldown = config:FindFirstChild("Cooldown") or MineStats:FindFirstChild("Cooldown")

	if not CurrentMines then warn("[MineLayer] Missing MineStats.CurrentMines") return end
	if not MaxMines     then warn("[MineLayer] Missing MineStats.MaxMines") return end
	if not SelectedMine then warn("[MineLayer] Missing MineStats.SelectedMine") return end
	if not Range        then warn("[MineLayer] Missing Range (checked Config and MineStats)") return end
	if not Cooldown     then warn("[MineLayer] Missing Cooldown (checked Config and MineStats)") return end

	-- Optional Boss Buster mine sub-config. Same field layout as MineStats
	-- itself (CurrentMines/MaxMines/SelectedMine, optional TravelTime).
	-- Only kicks in once the normal mine quota is fully placed.
	local BossBusterFolder = MineStats:FindFirstChild("BossBusterMines")
	local BBCurrentMines, BBMaxMines, BBSelectedMine, BBMaxTravelTime
	if BossBusterFolder then
		BBCurrentMines  = BossBusterFolder:FindFirstChild("CurrentMines")
		BBMaxMines      = BossBusterFolder:FindFirstChild("MaxMines")
		BBSelectedMine  = BossBusterFolder:FindFirstChild("SelectedMine")
		BBMaxTravelTime = BossBusterFolder:FindFirstChild("TravelTime")

		if not (BBCurrentMines and BBMaxMines and BBSelectedMine) then
			warn("[MineLayer] BossBusterMines folder found but missing CurrentMines/MaxMines/SelectedMine — disabling Boss Buster mines for", newTower:GetFullName())
			BossBusterFolder = nil
		end
	end

	local hrp = newTower:FindFirstChild("HumanoidRootPart")
	if not hrp then warn("[MineLayer] No HumanoidRootPart") return end

	local mapFolder = Workspace:FindFirstChild("Map")
	local map = mapFolder and mapFolder:FindFirstChildOfClass("Folder")
	if not map then warn("[MineLayer] No Map folder found") return end
	local pathFolder = map:FindFirstChild("Path")
	if not pathFolder then warn("[MineLayer] No Path folder found under Map") return end

	-- Cache the actual path PARTS (not just their center positions) so we
	-- can sample points across each part's real footprint, not just its center.
	local pathParts = {}
	for _, wp in ipairs(pathFolder:GetChildren()) do
		if wp:IsA("BasePart") then
			table.insert(pathParts, wp)
		end
	end
	if #pathParts == 0 then warn("[MineLayer] Path folder has no BaseParts") return end

	local alive = true
	local ancestryConn
	ancestryConn = scope:Connect(newTower.AncestryChanged, function(_, parent)
		if parent then return end
		alive = false
		if ancestryConn then ancestryConn:Disconnect(); ancestryConn = nil end
	end)

	local function waitCooldown(seconds)
		local elapsed = 0
		while elapsed < seconds do
			elapsed += task_wait(0.1)
			if not (alive and newTower.Parent and config.Parent) then return false end
		end
		return true
	end

	-- Returns a uniformly-random world point on the given part's top face.
	local function randomPointOnPart(part)
		local size = part.Size
		local localX = (math_random() - 0.5) * size.X
		local localZ = (math_random() - 0.5) * size.Z
		return (part.CFrame * CFrame.new(localX, size.Y / 2, localZ)).Position
	end

	local SAMPLES_PER_PART = 5 -- points tested per part per cycle

	task_spawn(function()
		while alive and newTower.Parent and config.Parent do
			if not waitCooldown(math_max(Cooldown.Value, 0.05)) then break end

			-- Decide what (if anything) to place this cycle:
			--  1. Normal mines take priority until they hit MaxMines.
			--  2. Once normal mines are maxed, start topping off Boss Buster
			--     mines (if the folder exists and isn't maxed itself).
			--  3. If both are maxed (or no Boss Buster folder), skip this cycle.
			local placeBossBuster = false
			if CurrentMines.Value >= MaxMines.Value then
				if BossBusterFolder and BBCurrentMines.Value < BBMaxMines.Value then
					placeBossBuster = true
				else
					continue
				end
			end

			local towerPos = hrp.Position
			local rangeVal = Range.Value
			local rangeSq  = rangeVal * rangeVal

			-- Sample several random points across each part's real surface
			-- (not just its center) so towers near a part's edge/end still
			-- see it as in-range, not just towers near its middle.
			local candidates = {}
			for _, part in ipairs(pathParts) do
				for i = 1, SAMPLES_PER_PART do
					local p = randomPointOnPart(part)
					local dx, dz = p.X - towerPos.X, p.Z - towerPos.Z
					if dx*dx + dz*dz <= rangeSq then
						candidates[#candidates+1] = p
					end
				end
			end
			if #candidates == 0 then continue end

			local landPos = candidates[math_random(1, #candidates)]

			-- Small, uniform circular scatter so mines don't stack exactly
			-- on top of each other, without biasing toward one direction.
			local scatterRadius = 0.1
			local angle  = math_random() * math.pi * 2
			local radius = math.sqrt(math_random()) * scatterRadius
			landPos = landPos + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

			local dist = (landPos - towerPos).Magnitude
			local maxDist = rangeVal > 0 and rangeVal or 1

			tower.FacePositionInstant(newTower, landPos)

			if placeBossBuster then
				BBCurrentMines.Value += 1
				local maxTT = (BBMaxTravelTime and BBMaxTravelTime.Value)
					or (MaxTravelTime and MaxTravelTime.Value) or 1
				local travelTime = math_max((dist / maxDist) * maxTT, 0.1)

				PlaceMineEvent:FireAllClients(newTower, landPos, travelTime / getGameSpeed())

				task_delay(travelTime, function()
					if not (config and config.Parent) then return end
					MineMod.Spawn(BBSelectedMine.Value, landPos, newTower, config, BBCurrentMines, true)
				end)
			else
				CurrentMines.Value += 1
				local maxTT = (MaxTravelTime and MaxTravelTime.Value) or 1
				local travelTime = math_max((dist / maxDist) * maxTT, 0.1)

				PlaceMineEvent:FireAllClients(newTower, landPos, travelTime / getGameSpeed())

				task_delay(travelTime, function()
					if not (config and config.Parent) then return end
					MineMod.Spawn(SelectedMine.Value, landPos, newTower, config, CurrentMines, false)
				end)
			end
		end
	end)
end

return run(newTower, player)
end
return Module
