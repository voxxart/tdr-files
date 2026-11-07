-- Planar grid; very large/unbounded queries fall back to occupied cells.
local Index = {}
Index.__index = Index
function Index.new(size)
	assert(size > 0)
	return setmetatable({Size = size, Cells = {}, Entries = {}, Count = 0}, Index)
end
function Index:Clear()
	table.clear(self.Cells); table.clear(self.Entries); self.Count = 0
end
function Index:Set(key, x, z)
	local cx, cz = math.floor(x / self.Size), math.floor(z / self.Size)
	local id = cx .. ':' .. cz
	local existing = self.Entries[key]
	if existing and existing.Cell == id then existing.X, existing.Z = x, z; return end
	self:Remove(key)
	local bucket = self.Cells[id]
	if not bucket then bucket = {}; self.Cells[id] = bucket end
	local entry = {Key = key, X = x, Z = z, Cell = id}
	bucket[key] = entry; self.Entries[key] = entry; self.Count += 1
end
function Index:Remove(key)
	local entry = self.Entries[key]
	if not entry then return end
	local bucket = self.Cells[entry.Cell]
	bucket[key] = nil
	if next(bucket) == nil then self.Cells[entry.Cell] = nil end
	self.Entries[key] = nil; self.Count -= 1
end
function Index:Visit(x, z, range, callback)
	if range ~= range or range < 0 then return end
	local squared = range * range
	local function visit(entry)
		local dx, dz = entry.X - x, entry.Z - z
		if dx * dx + dz * dz <= squared then callback(entry.Key) end
	end
	if range == math.huge then
		for _, entry in pairs(self.Entries) do visit(entry) end
		return
	end
	local minX, maxX = math.floor((x-range)/self.Size), math.floor((x+range)/self.Size)
	local minZ, maxZ = math.floor((z-range)/self.Size), math.floor((z+range)/self.Size)
	if (maxX-minX+1) * (maxZ-minZ+1) > self.Count then
		for _, entry in pairs(self.Entries) do visit(entry) end
	else
		for cx = minX,maxX do
			for cz = minZ,maxZ do
				local bucket = self.Cells[cx .. ':' .. cz]
				if bucket then for _, entry in pairs(bucket) do visit(entry) end end
			end
		end
	end
end
return Index
