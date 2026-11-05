-- ServerScriptService/EnemySystem/EnemyFlags.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyData = require(ReplicatedStorage.GameModules:WaitForChild("EnemyData"))

local EnemyFlags = {}
local FLAGS = EnemyData.Flags

function EnemyFlags.Has(flags, flag)
	return bit32.band(flags or 0, flag) ~= 0
end

function EnemyFlags.Add(flags, flag)
	return bit32.bor(flags or 0, flag)
end

function EnemyFlags.Remove(flags, flag)
	return bit32.band(flags or 0, bit32.bnot(flag))
end

function EnemyFlags.FromEnemyStats(stats)
	local flags = 0
	if not stats then return flags end

	local function truthy(name)
		local value = stats:FindFirstChild(name)
		if not value then return false end

		if value:IsA("BoolValue") then
			return value.Value
		end

		return true
	end

	if truthy("Hidden") then flags = EnemyFlags.Add(flags, FLAGS.Hidden) end
	if truthy("Flying") then flags = EnemyFlags.Add(flags, FLAGS.Flying) end
	if truthy("Invincible") or truthy("Inivincible") then
		flags = EnemyFlags.Add(flags, FLAGS.Invincible)
	end
	if truthy("NoCash") then flags = EnemyFlags.Add(flags, FLAGS.NoCash) end
	if truthy("Aggro") then flags = EnemyFlags.Add(flags, FLAGS.Aggro) end
	if truthy("Lead") then flags = EnemyFlags.Add(flags, FLAGS.Lead) end
	if truthy("NoStun") then flags = EnemyFlags.Add(flags, FLAGS.NoStun) end
	if truthy("InstaKill") then flags = EnemyFlags.Add(flags, FLAGS.InstaKill) end

	return flags
end

return EnemyFlags
