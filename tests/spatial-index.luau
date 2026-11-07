local Index = require('../Tower Defense R/ServerScriptService/Simulation/SpatialIndex')
local index = Index.new(10)
local positions = {}
for x = -30,30,3 do
	for z = -30,30,3 do
		local key = x .. '/' .. z
		positions[key] = {x,z}; index:Set(key,x,z)
	end
end
local function check(x,z,range)
	local actual, expected = {}, {}
	index:Visit(x,z,range,function(key) actual[key] = true end)
	for key,p in pairs(positions) do
		if (p[1]-x)^2+(p[2]-z)^2 <= range^2 then expected[key] = true end
	end
	for key in pairs(actual) do assert(expected[key], 'Unexpected spatial candidate') end
	for key in pairs(expected) do assert(actual[key], 'Missing spatial candidate') end
end
check(0,0,10); check(-10,-10,7); check(0,0,math.huge); check(50,50,10000)
index:Set('moving',100,100); positions.moving = {100,100}; check(100,100,0)
index:Set('moving',-1,-1); positions.moving = {-1,-1}; check(-1,-1,1)
local entry = index.Entries.moving
index:Set('moving',-2,-2); positions.moving = {-2,-2}
assert(index.Entries.moving == entry, 'In-cell movement should reuse storage')
check(-2,-2,1)
index:Remove('moving'); positions.moving = nil; check(-2,-2,10)
index:Clear(); assert(index.Count == 0 and next(index.Entries) == nil)
print('Spatial index checks passed against brute-force queries, movement, boundaries, removal')
-- Representative density: local range query should emit a small subset.
for x=0,99 do
	for z=0,49 do index:Set(x*50+z,x*8,z*8) end
end
local localCount=0
index:Visit(400,200,24,function() localCount+=1 end)
assert(index.Count==5000 and localCount>0 and localCount<100)
print('Spatial density check passed:', localCount, 'local candidates among', index.Count, 'entities (not a Studio benchmark)')
