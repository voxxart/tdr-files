local Runtime = {}
local active, byModel = {}, {}
function Runtime.Add(model, data)
	local existing = byModel[model]
	if existing then return existing end
	data.Model = model; data.Index = #active + 1; data.Cleaned = false
	active[data.Index] = data; byModel[model] = data
	return data
end
function Runtime.Get(model) return byModel[model] end
function Runtime.List() return active end
function Runtime.Remove(model)
	local data = byModel[model]
	if not data then return end
	byModel[model] = nil; data.Cleaned = true
	local index, last = data.Index, active[#active]
	active[index] = last
	if last then last.Index = index end
	active[#active] = nil; data.Index = nil
	return data
end
return Runtime
