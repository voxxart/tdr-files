local Policy = {}
function Policy.Better(candidate, best, mode, prioritizeFlying)
	if not best then return true end
	if candidate.Aggro ~= best.Aggro then return candidate.Aggro end
	if prioritizeFlying and candidate.Flying ~= best.Flying then return candidate.Flying end
	if mode == 'Near' then return candidate.Distance < best.Distance end
	if mode == 'Last' then return candidate.Alpha < best.Alpha end
	if mode == 'Strong' then return candidate.Health > best.Health end
	if mode == 'Weak' then return candidate.Health < best.Health end
	return candidate.Alpha > best.Alpha
end
return Policy
