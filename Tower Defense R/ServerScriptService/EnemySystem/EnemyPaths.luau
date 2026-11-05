-- ServerScriptService/EnemySystem/EnemyPaths.lua
-- Every map path is built + sampled once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BezierPath = require(ReplicatedStorage.Modules:WaitForChild("BezierPath"))
local EnemyData = require(ReplicatedStorage.GameModules:WaitForChild("EnemyData"))

local EnemyPaths = {}

local Cache = setmetatable({}, { __mode = "k" })
local SAMPLE_COUNT = EnemyData.Settings.PathSampleCount or 512

local function sortedWaypoints(folder)
	local children = folder:GetChildren()

	table.sort(children, function(a, b)
		return (tonumber(a.Name) or math.huge) < (tonumber(b.Name) or math.huge)
	end)

	return children
end

local function build(folder, id)
	local positions = {}

	for _, waypoint in ipairs(sortedWaypoints(folder)) do
		if waypoint:IsA("BasePart") then
			positions[#positions + 1] = waypoint.Position
		end
	end

	if #positions < 2 then
		return nil
	end

	local curve = BezierPath.new(
		positions,
		EnemyData.Settings.PathCurveResolution or 1.2
	)

	local samples = table.create(SAMPLE_COUNT + 1)

	for i = 0, SAMPLE_COUNT do
		samples[i + 1] = curve:CalculateUniformCFrame(i / SAMPLE_COUNT)
	end

	return {
		Id = id,
		Name = folder.Name,
		Positions = positions,
		Length = curve:GetPathLength(),
		Samples = samples,
		SampleCount = SAMPLE_COUNT,
		StartPosition = positions[1],
	}
end

function EnemyPaths.GetMapPaths(map)
	local cached = Cache[map]
	if cached then
		return cached
	end

	local list = {}
	local byId = {}

	for i = 1, 4 do
		local folderName = (i == 1) and "Waypoints" or ("Waypoints" .. i)
		local folder = map:FindFirstChild(folderName)

		if folder then
			local data = build(folder, i)

			if data then
				list[#list + 1] = data
				byId[i] = data
			end
		end
	end

	cached = {
		List = list,
		ById = byId,
	}

	Cache[map] = cached
	return cached
end

function EnemyPaths.GetRandomPath(map)
	local paths = EnemyPaths.GetMapPaths(map).List

	if #paths == 0 then
		return nil
	end

	return paths[math.random(1, #paths)]
end

function EnemyPaths.GetById(map, id)
	return EnemyPaths.GetMapPaths(map).ById[id]
end

-- Returns the path that is physically closest to the supplied world position.
--
-- If alphaHint is supplied, every lane is compared at that SAME progress.
-- This is the ideal summon lookup for dual/multi-lane maps because a summoner
-- at alpha 0.60 will compare against alpha 0.60 on every lane instead of
-- comparing against each lane's starting waypoint.
--
-- If alphaHint is omitted, sampled path points are searched instead. That is
-- still much more accurate than comparing only the first waypoint.
function EnemyPaths.GetClosestPath(map, position, alphaHint)
	local best
	local bestDistSq
	local bestAlpha = 0

	local paths = EnemyPaths.GetMapPaths(map).List

	if typeof(alphaHint) == "number" then
		local alpha = math.clamp(alphaHint, 0, 1)

		for _, data in ipairs(paths) do
			local scaled = alpha * data.SampleCount
			local index = math.clamp(
				math.floor(scaled + 0.5) + 1,
				1,
				#data.Samples
			)

			local samplePos = data.Samples[index].Position
			local delta = samplePos - position
			local distSq =
				delta.X * delta.X
				+ delta.Y * delta.Y
				+ delta.Z * delta.Z

			if not bestDistSq or distSq < bestDistSq then
				bestDistSq = distSq
				best = data
				bestAlpha = alpha
			end
		end

		return best, bestAlpha
	end

	-- Coarse sampled search followed by a small local refinement.
	-- This is only used when a caller does not know the host's alpha.
	for _, data in ipairs(paths) do
		local samples = data.Samples
		local count = data.SampleCount
		local stride = math.max(1, math.floor(count / 128))
		local localBestIndex
		local localBestDistSq

		for sampleIndex = 1, #samples, stride do
			local delta = samples[sampleIndex].Position - position
			local distSq =
				delta.X * delta.X
				+ delta.Y * delta.Y
				+ delta.Z * delta.Z

			if not localBestDistSq or distSq < localBestDistSq then
				localBestDistSq = distSq
				localBestIndex = sampleIndex
			end
		end

		if localBestIndex then
			local first =
				math.max(
					1,
					localBestIndex - stride
				)

			local last =
				math.min(
					#samples,
					localBestIndex + stride
				)

			for sampleIndex = first, last do
				local delta = samples[sampleIndex].Position - position
				local distSq =
					delta.X * delta.X
					+ delta.Y * delta.Y
					+ delta.Z * delta.Z

				if distSq < localBestDistSq then
					localBestDistSq = distSq
					localBestIndex = sampleIndex
				end
			end

			if not bestDistSq or localBestDistSq < bestDistSq then
				bestDistSq = localBestDistSq
				best = data
				bestAlpha =
					(localBestIndex - 1)
					/ data.SampleCount
			end
		end
	end

	return best, bestAlpha
end

-- Returns the progress value on ONE specific cached path that is physically
-- closest to a world position. This is intentionally used for summoning so a
-- stale compatibility Alpha can never throw a summoned enemy back to waypoint 1.
-- 513 samples at the default setting, once per summon hoard, is negligible.
function EnemyPaths.GetClosestAlphaOnPath(pathData, position)
	if not pathData
		or not pathData.Samples
		or #pathData.Samples == 0
	then
		return 0
	end

	local bestIndex = 1
	local bestDistSq = math.huge

	for index, sample in ipairs(pathData.Samples) do
		local delta = sample.Position - position
		local distSq =
			delta.X * delta.X
			+ delta.Y * delta.Y
			+ delta.Z * delta.Z

		if distSq < bestDistSq then
			bestDistSq = distSq
			bestIndex = index
		end
	end

	return math.clamp(
		(bestIndex - 1) / pathData.SampleCount,
		0,
		1
	)
end

function EnemyPaths.SampleCFrame(pathData, alpha)
	alpha = math.clamp(alpha, 0, 1)

	local scaled = alpha * pathData.SampleCount
	local lower = math.floor(scaled)
	local upper = math.min(lower + 1, pathData.SampleCount)
	local blend = scaled - lower

	local a = pathData.Samples[lower + 1]

	if upper == lower then
		return a
	end

	return a:Lerp(pathData.Samples[upper + 1], blend)
end

function EnemyPaths.Clear(map)
	Cache[map] = nil
end

return EnemyPaths
