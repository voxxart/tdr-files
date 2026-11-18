-- Flat HP damage, independent of the target's maximum health.
local DamageAmount = {}

function DamageAmount.Flat(amount)
	if type(amount) ~= "number" or amount ~= amount or math.abs(amount) == math.huge then
		return 0
	end
	return math.max(0, amount)
end

return DamageAmount
