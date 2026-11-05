-- Own resources explicitly; one failing destructor must not retain the rest.
local Cleanup = {}
Cleanup.__index = Cleanup

local function dispose(item)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		-- Unparented instances can still own connections and descendants.
		item:Destroy()
	elseif type(item) == "function" then
		item()
	elseif type(item) == "table" and type(item.Destroy) == "function" then
		item:Destroy()
	end
end

local function safelyDispose(item)
	local ok, err = pcall(dispose, item)
	if not ok then
		warn("Cleanup failed:", err)
	end
end

function Cleanup.new()
	return setmetatable({ _items = {}, _destroyed = false }, Cleanup)
end

function Cleanup:Add(item)
	if self._destroyed then
		safelyDispose(item)
	else
		table.insert(self._items, item)
	end
	return item
end

function Cleanup:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	for i = #self._items, 1, -1 do
		local item = self._items[i]
		self._items[i] = nil
		safelyDispose(item)
	end
end

return Cleanup
