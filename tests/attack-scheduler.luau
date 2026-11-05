local Scheduler = require('../Tower Defense R/ServerScriptService/Simulation/AttackScheduler')
local Clock = require('../Tower Defense R/ServerScriptService/Simulation/MatchClock')
local clock = Clock.new()
local generation = clock:Begin()
local queued, runs = {}, 0
local alive = true
local scheduler = Scheduler.new({
	Now = function() return clock.Time end,
	IsCurrent = function(g) return clock:IsCurrent(g) end,
	Alive = function() return alive end,
	Dispatch = function(callback) table.insert(queued, callback) end,
	Report = function(err) error(err) end,
})
local entity = {}
local activeDuringRun
local behavior = {Cooldown = function() return 3 end, Run = function(active)
	runs += 1
	activeDuringRun = active
end}
scheduler:Add(entity, generation, behavior)
scheduler:Add(entity, generation, behavior)
clock:Advance(1, 1); scheduler:Step()
assert(#queued == 0)
clock:Advance(10, 0); scheduler:Step()
assert(#queued == 0, 'Pause must not advance cooldown')
clock:Advance(1, 2); scheduler:Step()
assert(#queued == 1)
clock:Advance(10, 1); scheduler:Step()
assert(#queued == 1, 'Busy attacks must not overlap')
queued[1](); table.clear(queued)
assert(runs == 1 and activeDuringRun())
scheduler:Remove(entity)
assert(not activeDuringRun(), 'Tag removal must cancel an in-flight summon group')
scheduler:Add(entity, generation, behavior)
clock:Advance(3, 1); scheduler:Step()
alive = false
queued[1](); table.clear(queued)
assert(runs == 1, 'Death before dispatch must suppress the attack')
scheduler:Step()
assert(next(scheduler._entries) == nil, 'Dead entries must be released')
alive = true
scheduler:Add(entity, generation, behavior)
clock:Advance(3, 1); scheduler:Step()
clock:Stop(); clock:Begin()
queued[1](); table.clear(queued)
scheduler:Step()
assert(runs == 1 and next(scheduler._entries) == nil, 'Restart must invalidate pending attacks')
print('Attack scheduler checks passed: cooldown, pause, speed, overlap, removal, death, restart')

-- Spawner has a distinct first delay and reads its cooldown at each cast.
local liveCooldown = 5
local casts = 0
local current = clock.Generation
scheduler:Add(entity, current, {
	InitialCooldown = function() return 0.5 end,
	Cooldown = function() return liveCooldown end,
	Run = function() casts += 1 end,
})
clock:Advance(0.49, 1); scheduler:Step()
assert(#queued == 0)
clock:Advance(0.02, 1); scheduler:Step()
assert(#queued == 1, 'First cast should use initial stagger')
queued[1](); table.clear(queued)
liveCooldown = 2
clock:Advance(5, 1); scheduler:Step()
queued[1](); table.clear(queued)
clock:Advance(2, 1); scheduler:Step()
assert(#queued == 1, 'Subsequent casts must read live cooldown')
queued[1](); table.clear(queued)
assert(casts == 3)
scheduler:Remove(entity)
print('Spawner initial stagger and live cooldown checks passed')
