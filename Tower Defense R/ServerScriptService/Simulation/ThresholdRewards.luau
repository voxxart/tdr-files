local Rewards = {}
function Rewards.new(thresholds)
	local awarded = {}
	return function(health)
		local count = 0
		for index, threshold in thresholds do
			if not awarded[index] and health <= threshold then
				awarded[index] = true
				count += 1
			end
		end
		return count
	end
end
return Rewards
