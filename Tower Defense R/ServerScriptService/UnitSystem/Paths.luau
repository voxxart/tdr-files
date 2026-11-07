local Rep = game:GetService('ReplicatedStorage')
local Bezier = require(Rep.Modules.BezierPath)
local Definitions = require(Rep.GameModules.UnitDefinitions)
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Paths = {}
local cache, generation = {}, nil
local function build(folder)
	local waypoints = folder:GetChildren()
	table.sort(waypoints,function(a,b) return (tonumber(a.Name) or math.huge) < (tonumber(b.Name) or math.huge) end)
	local positions = {}
	for _, part in waypoints do if part:IsA('BasePart') then table.insert(positions,part.Position) end end
	if #positions < 2 then return nil end
	local curve = Bezier.new(positions,1.2)
	local count = math.max(2, Definitions.Settings.PathSamples or 512)
	local samples = table.create(count+1)
	for i=0,count do samples[i+1] = curve:CalculateUniformCFrame(i/count) end
	return {Id=tostring(Match.Capture())..':'..folder:GetFullName(),Positions=positions,Length=math.max(curve:GetPathLength(),0.001),Samples=samples,Count=count}
end
function Paths.Select(map)
	local current = Match.Capture()
	if generation ~= current then table.clear(cache); generation = current end
	local list = cache[map]
	if not list then
		list = {}
		for i=1,4 do
			local folder = map:FindFirstChild(if i==1 then 'UnitWaypoints' else 'UnitWaypoints'..i)
			local path = folder and build(folder)
			if path then table.insert(list,path) end
		end
		cache[map] = list
	end
	if #list == 0 then return nil end
	return list[math.random(1,#list)]
end
function Paths.Sample(path, alpha)
	if not path.Samples then return path:CalculateUniformCFrame(alpha) end
	local scaled = math.clamp(alpha,0,1)*path.Count
	local index = math.min(math.floor(scaled)+1,path.Count)
	return path.Samples[index]:Lerp(path.Samples[index+1],scaled-(index-1))
end
return Paths
