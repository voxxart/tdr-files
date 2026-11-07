-- Own asynchronous work without coupling cancellation to Roblox Instances.
local TaskScope = {}
TaskScope.__index = TaskScope
function TaskScope.new(context)
	return setmetatable({_context = context, _threads = {}, _delays = {}, _cleanup = {}, Cancelled = false}, TaskScope)
end
function TaskScope:Active()
	return not self.Cancelled and self._context.Active()
end
function TaskScope:OnCancel(callback)
	if self.Cancelled then callback(); return function() end end
	self._cleanup[callback] = true
	return function() self._cleanup[callback] = nil end
end
function TaskScope:Spawn(callback, ...)
	if not self:Active() then return nil end
	local args = table.pack(...)
	local thread
	thread = coroutine.create(function()
		if self:Active() then
			local ok, err = pcall(callback, table.unpack(args, 1, args.n))
			if not ok and self:Active() then self._context.Report(err) end
		end
		self._threads[thread] = nil
	end)
	self._threads[thread] = true
	self._context.Start(thread)
	return thread
end
function TaskScope:Delay(seconds, callback, ...)
	if not self:Active() then return nil end
	local args = table.pack(...)
	local token = {}
	self._delays[token] = true
	local cancel = self._context.After(seconds, function()
		self._delays[token] = nil
		self:Spawn(callback, table.unpack(args, 1, args.n))
	end)
	if self._delays[token] then self._delays[token] = cancel end
	return cancel
end
function TaskScope:Wait(seconds)
	if not self:Active() or not self._context.Wait(seconds, function() return self:Active() end) then
		error('Boss task cancelled', 0)
	end
end
function TaskScope:Cancel()
	if self.Cancelled then return end
	self.Cancelled = true
	for _, cancel in pairs(self._delays) do if type(cancel) == 'function' then cancel() end end
	table.clear(self._delays)
	for thread in pairs(self._threads) do
		if thread ~= coroutine.running() and coroutine.status(thread) ~= 'dead' then
			local ok, err = pcall(self._context.Cancel, thread)
			if not ok then self._context.Report(err) end
		end
	end
	table.clear(self._threads)
	for callback in pairs(self._cleanup) do
		local ok, err = pcall(callback)
		if not ok then self._context.Report(err) end
		self._cleanup[callback] = nil
	end
end
return TaskScope
