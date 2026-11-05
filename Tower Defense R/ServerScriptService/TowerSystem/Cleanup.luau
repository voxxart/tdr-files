local Cleanup = {}
Cleanup.__index = Cleanup

function Cleanup.new()
	return setmetatable({
		_items = {},
		_destroyed = false,
	}, Cleanup)
end

function Cleanup:Add(item)
	if self._destroyed then
		if typeof(item) == "RBXScriptConnection" then item:Disconnect()
		elseif typeof(item) == "Instance" then item:Destroy()
		elseif type(item) == "function" then pcall(item) end
		return item
	end
	table.insert(self._items, item)
	return item
end

function Cleanup:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	for i = #self._items, 1, -1 do
		local item = self._items[i]
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			if item.Connected then item:Disconnect() end
		elseif kind == "Instance" then
			if item.Parent then item:Destroy() end
		elseif type(item) == "function" then
			pcall(item)
		elseif type(item) == "table" and type(item.Destroy) == "function" then
			pcall(item.Destroy, item)
		end
		self._items[i] = nil
	end
end

return Cleanup
