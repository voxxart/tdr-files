local DamageAmount = {}
function DamageAmount.Percent(currentHealth, maxHealth, fraction, roundRemaining)
	if roundRemaining then
		return currentHealth - math.round(currentHealth - maxHealth * fraction)
	end
	return math.round(maxHealth * fraction)
end
return DamageAmount
