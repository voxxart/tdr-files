local Cleanup = require('../Tower Defense R/ServerScriptService/TowerSystem/Cleanup')
local order = {}
local scope = Cleanup.new()
scope:Add(function() table.insert(order, 'first') end)
scope:Add({Destroy = function() table.insert(order, 'second') end})
scope:Add(function()
	table.insert(order, 'third')
	scope:Destroy() -- Reentrant disposal must be harmless.
	scope:Add({Destroy = function() table.insert(order, 'late') end})
end)
scope:Destroy()
scope:Destroy()
assert(table.concat(order, ',') == 'third,late,second,first', 'Expected reverse disposal, including late resources')
assert(#scope._items == 0, 'Disposed resources must not be retained')
local destroyed = 0
scope:Add({Destroy = function() destroyed += 1 end})
assert(destroyed == 1, 'Late table resources must be destroyed immediately')
print('Cleanup lifecycle checks passed')
