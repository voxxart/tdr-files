local Scope = require('../Tower Defense R/ServerScriptService/Simulation/TaskScope')
local Clock = require('../Tower Defense R/ServerScriptService/Simulation/MatchClock')
local clock = Clock.new()
local generation = clock:Begin()
local alive, errors, calls, cleaned = true, {}, 0, 0
local scope = Scope.new({
	Active = function() return alive and clock:IsCurrent(generation) end,
	Start = function(thread)
		local ok, err = coroutine.resume(thread)
		assert(ok, err)
	end,
	Cancel = function(thread) coroutine.close(thread) end,
	After = function(seconds, callback) return clock:After(generation, seconds, callback) end,
	Wait = function(_, active)
		coroutine.yield()
		return active()
	end,
	Report = function(err) table.insert(errors, err) end,
})
scope:OnCancel(function() cleaned += 1 end)
scope:Spawn(function() calls += 1; scope:Wait(2); calls += 100 end)
assert(calls == 1 and next(scope._threads) ~= nil)
scope:Delay(2, function()
	calls += 1
	scope:Delay(2, function() calls += 100 end)
end)
clock:Advance(1,1)
assert(calls == 1)
clock:Advance(1,1)
assert(calls == 2, 'Delayed callbacks must run and inherit scope ownership')
scope:Cancel(); scope:Cancel()
clock:Advance(10,1)
assert(calls == 2 and cleaned == 1 and next(scope._threads) == nil and next(scope._delays) == nil)
scope:Spawn(function() calls += 100 end)
assert(calls == 2 and #errors == 0)
local late = 0
scope:OnCancel(function() late += 1 end)
assert(late == 1)
local valid = true
local other = Scope.new({
	Active = function() return valid end,
	Start = function(thread) assert(coroutine.resume(thread)) end,
	Cancel = function(thread) coroutine.close(thread) end,
	After = function(_, callback) callback(); return function() end end,
	Wait = function() return false end,
	Report = function(err) table.insert(errors,err) end,
})
other:Spawn(function() other:Wait(1); calls += 100 end)
assert(#errors == 1, 'An unexpected wait failure on a live scope must be reported')
valid = false
other:Spawn(function() calls += 100 end)
assert(calls == 2)
print('Task scope checks passed: nested delays, suspended work, cancellation, cleanup, inactive guards')
local cleanedEarly = 0
local disposable = Scope.new({
	Active = function() return true end,
	Start = function(thread) assert(coroutine.resume(thread)) end,
	Cancel = function(thread) coroutine.close(thread) end,
	After = function() return function() end end,
	Wait = function() return true end,
	Report = function(err) error(err) end,
})
local detach = disposable:OnCancel(function() cleanedEarly += 1 end)
detach(); disposable:Cancel()
assert(cleanedEarly == 0, 'Completed leases must release their cancellation callbacks')
local restarted = clock:Begin()
local stale = Scope.new({
	Active = function() return clock:IsCurrent(restarted) end,
	Start = function(thread) assert(coroutine.resume(thread)) end,
	Cancel = function(thread) coroutine.close(thread) end,
	After = function(seconds, callback) return clock:After(restarted, seconds, callback) end,
	Wait = function() return true end,
	Report = function(err) error(err) end,
})
stale:Delay(1, function() calls += 1000 end)
clock:Stop(); clock:Begin(); clock:Advance(10,1)
assert(calls == 2, 'Boss callbacks cannot cross match generations')
stale:Cancel()
print('Task scope lease and restart checks passed')
