local Lifetime = {}
function Lifetime.State(record, wave, now, modelPresent)
	if record.ReleaseAt then
		return if now >= record.ReleaseAt then 'Expired' else 'Linger'
	end
	if not modelPresent then return 'Expired' end
	if wave >= record.EndWave then
		record.ReleaseAt = now + 3
		return 'Linger'
	end
	return 'Active'
end
return Lifetime
