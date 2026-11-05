local Aura = require('../Tower Defense R/ServerScriptService/Simulation/AuraController')
local applied, removed = 0, 0
local bindings = {}
local aura = Aura.new(function(caster, target)
	applied += 1
	bindings[target] = caster
	return function() removed += 1; bindings[target] = nil end
end, function(err) error(err) end)
local a, b, x, y = {}, {}, {}, {}
aura:Step(a, {x,y})
aura:Step(a, {x,y})
assert(applied == 2 and removed == 0, 'Repeated ticks must not duplicate resources')
aura:Step(a, {y})
assert(removed == 1 and bindings[x] == nil)
aura:Step(b, {y})
assert(applied == 3 and removed == 2 and bindings[y] == b, 'Caster handoff must rebind resources')
aura:Step(nil, {})
assert(removed == 3 and next(bindings) == nil)
aura:Clear(); aura:Clear()
assert(removed == 3, 'Cleanup must be idempotent')
local ready = false
local retry = Aura.new(function()
	if not ready then return nil end
	return function() removed += 1 end
end, function(err) error(err) end)
retry:Step(a,{x})
assert(next(retry._owned) == nil)
ready = true; retry:Step(a,{x}); retry:Clear()
assert(removed == 4, 'Incomplete targets must be retried, then released')
print('Aura checks passed: deduplication, target removal, caster handoff, stop, retry')
