local Ledger = require('../Tower Defense R/ServerScriptService/Simulation/ResourceLedger')
local ledger = Ledger.new()
local creates, cleans = 0, 0
local tower = {}
local function create()
	creates += 1
	return function() cleans += 1 end
end
assert(ledger:Acquire(tower, create))
assert(ledger:Acquire(tower, create))
assert(creates == 1, 'Overlapping orbs must share the original cash snapshot')
ledger:Release(tower)
assert(cleans == 0, 'First expiry must not remove another orb effect')
ledger:Release(tower); ledger:Release(tower)
assert(cleans == 1 and next(ledger._entries) == nil)
assert(not ledger:Acquire(tower, function() return nil end))
assert(next(ledger._entries) == nil, 'Rejected external resources must not be owned')
print('Resource ledger checks passed: overlap, last-owner release, repeated cleanup, rejected ownership')
