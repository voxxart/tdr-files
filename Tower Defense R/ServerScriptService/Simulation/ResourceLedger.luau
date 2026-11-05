-- Reference-count resources shared by overlapping area effects.
local Ledger = {}
Ledger.__index = Ledger
function Ledger.new() return setmetatable({_entries = {}}, Ledger) end
function Ledger:Acquire(key, create)
	local entry = self._entries[key]
	if entry then entry.Count += 1; return true end
	local cleanup = create()
	if not cleanup then return false end
	self._entries[key] = {Count = 1, Cleanup = cleanup}
	return true
end
function Ledger:Release(key)
	local entry = self._entries[key]
	if not entry then return end
	entry.Count -= 1
	if entry.Count > 0 then return end
	self._entries[key] = nil
	entry.Cleanup()
end
return Ledger
