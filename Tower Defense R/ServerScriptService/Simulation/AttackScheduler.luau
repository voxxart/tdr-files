-- Engine-independent attack registry. Behaviors provide game-time cooldowns.
local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new(context)
	return setmetatable({_context = context, _entries = {}}, Scheduler)
end

function Scheduler:Remove(entity)
	local entry = self._entries[entity]
	if entry then
		entry.Cancelled = true
		self._entries[entity] = nil
	end
end

function Scheduler:Add(entity, generation, behavior)
	if self._entries[entity] then return end
	if not self._context.IsCurrent(generation) then return end
	local entry = {Generation = generation, Cancelled = false, Busy = false, Behavior = behavior}
	entry.Next = self._context.Now() + behavior.Cooldown()
	self._entries[entity] = entry
	entry.Active = function()
		return not entry.Cancelled and self._entries[entity] == entry
			and self._context.IsCurrent(entry.Generation) and self._context.Alive(entity)
	end
end

function Scheduler:Step()
	local context = self._context
	local now = context.Now()
	for entity, entry in pairs(self._entries) do
		local active = entry.Active
		if not active() then
			self:Remove(entity)
		elseif not entry.Busy and now >= entry.Next then
			entry.Busy = true
			entry.Next = now + entry.Behavior.Cooldown()
			context.Dispatch(function()
				-- Dispatch can be deferred; revalidate immediately before execution.
				if active() then
					local ok, err = pcall(entry.Behavior.Run, active)
					if not ok then context.Report(err) end
				end
				entry.Busy = false
			end)
		end
	end
end

return Scheduler
