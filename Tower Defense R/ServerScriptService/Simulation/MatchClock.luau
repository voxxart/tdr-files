-- Engine-independent match generations and game-time deadlines.
local MatchClock = {}
MatchClock.__index = MatchClock

function MatchClock.new()
	return setmetatable({Generation = 0, Running = false, Time = 0, _jobs = {}}, MatchClock)
end

function MatchClock:Stop()
	self.Running = false
	table.clear(self._jobs) -- Release callback captures immediately.
end

function MatchClock:Begin()
	self:Stop()
	self.Generation += 1
	self.Time = 0
	self.Running = true
	return self.Generation
end

function MatchClock:IsCurrent(generation)
	return self.Running and generation == self.Generation
end

function MatchClock:After(generation, seconds, callback)
	assert(type(seconds) == 'number' and seconds >= 0 and seconds < math.huge, 'Invalid delay')
	if not self:IsCurrent(generation) then return nil end
	local job = {Generation = generation, Deadline = self.Time + seconds, Callback = callback}
	table.insert(self._jobs, job)
	return function()
		job.Callback = nil -- Release captured entities even before the next tick.
	end
end

function MatchClock:Advance(dt, speed)
	assert(dt >= 0 and dt < math.huge and speed >= 0 and speed < math.huge, 'Invalid clock step')
	if not self.Running then return end
	self.Time += dt * speed
	local ready = {}
	for i = #self._jobs, 1, -1 do
		local job = self._jobs[i]
		if not job.Callback or job.Deadline <= self.Time then
			table.remove(self._jobs, i)
			if job.Callback then table.insert(ready, job) end
		end
	end
	-- Detach due work before dispatch: callbacks can stop/restart the match.
	for i = #ready, 1, -1 do
		local job = ready[i]
		if job.Callback and self:IsCurrent(job.Generation) then
			local ok, err = pcall(job.Callback)
			if not ok then warn('Match callback failed:', err) end
		end
		job.Callback = nil
	end
end

return MatchClock
