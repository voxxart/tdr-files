local Sequence = require('../Tower Defense R/ServerScriptService/Simulation/AttackSequence')
local function run(cancel, targetValid, failImpact)
	local damage, cleanup, waits = 0, 0, 0
	local active = true
	local ok, result = pcall(Sequence.Run, {
		Active = function() return active end,
		Start = function() end,
		Wait = function()
			waits += 1
			if cancel and waits == 1 then active = false end
			return active
		end,
		ValidTarget = function() return targetValid end,
		Windup = 2, Recovery = 2,
		Impact = function()
			if failImpact then error('impact failed') end
			damage += 1
		end,
		Cleanup = function() cleanup += 1 end,
	})
	assert(cleanup == 1, 'Every exit must release movement/visual ownership')
	return ok, result, damage, waits
end
local ok, result, damage, waits = run(false, true, false)
assert(ok and result and damage == 1 and waits == 2)
ok, result, damage = run(true, true, false)
assert(ok and not result and damage == 0, 'Cancellation during windup must prevent damage')
ok, result, damage = run(false, false, false)
assert(ok and not result and damage == 0, 'Lost target must prevent damage')
ok = run(false, true, true)
assert(not ok, 'Errors must propagate after cleanup')
print('Attack sequence checks passed: impact, cancellation, target loss, error cleanup')
local impacts, released = 0, false
local active = true
local stage = 0
Sequence.Run({
	Active = function() return active end,
	Start = function() end,
	ValidTarget = function() return true end,
	Windup = 1, Recovery = 0.67,
	Wait = function(seconds)
		stage += 1
		if stage == 1 then assert(seconds == 1) else
			assert(seconds == 0.67)
			active = false
		end
		return active
	end,
	Impact = function() impacts += 1 end,
	Cleanup = function() released = true end,
})
assert(impacts == 1 and released, 'Recovery cancellation must clean up without repeating/undoing impact')
print('Delayed impact and recovery cancellation checks passed')
