local CombatProfiles = require(game.ReplicatedStorage.GameModules.CombatProfiles)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerData = require(ReplicatedStorage.GameModules:WaitForChild("TowerData"))

local TowerStats = {}

local CORE_ALIASES = {
	Firerate = "Cooldown",
}

local RESERVED = {
	Cost = true,
	Config = true,
	Stats = true,
	Behaviors = true,
	Secondary = true,

	-- Display-only metadata. Never mirror these into Config as gameplay stats.
	Name = true,
	UpgradeName = true,
}

local function cloneDictionary(source)
	local out = {}

	for k, v in pairs(source or {}) do
		if typeof(v) == "table" then
			out[k] = cloneDictionary(v)
		else
			out[k] = v
		end
	end

	return out
end

local function mergeDictionary(target, source)
	for k, v in pairs(source or {}) do
		if typeof(v) == "table" then
			if typeof(target[k]) ~= "table" then
				target[k] = {}
			end

			mergeDictionary(target[k], v)
		else
			target[k] = v
		end
	end

	return target
end

local function getDefinition(name)
	return TowerData.Towers[name]
end

function TowerStats.GetDefinition(name)
	return getDefinition(name)
end

function TowerStats.GetSellPercent()
	return (TowerData.Settings and TowerData.Settings.SellPercent) or 0.5
end

function TowerStats.GetPlacementCost(name, fallbackConfig)
	local def = getDefinition(name)

	if def and def.Cost ~= nil then
		return def.Cost
	end

	local value = fallbackConfig and fallbackConfig:FindFirstChild("Price")
	return value and value.Value or nil
end

function TowerStats.GetUpgrade(name, level)
	local def = getDefinition(name)
	local upgrade = def and def.Upgrades and def.Upgrades[level] or nil

	-- Upgrades may contain non-level metadata values.
	-- Only an actual table is a usable upgrade definition.
	if typeof(upgrade) ~= "table" then
		return nil
	end

	return upgrade
end

function TowerStats.GetUpgradeCost(name, level)
	local upgrade = TowerStats.GetUpgrade(name, level)
	return upgrade and upgrade.Cost or nil
end

-- Returns the display/upgrade name for ANY tower level.
--
-- Level 0 reads from the tower definition itself:
--     UpgradeName = "Basic Helicopter"
--
-- Level 1+ reads from the matching upgrade:
--     Upgrades[1].UpgradeName = "Improved Rotors"
--
-- `Name` remains supported as a legacy alias.
function TowerStats.GetUpgradeName(name, level)
	local def = getDefinition(name)

	if not def then
		return level == 0
			and name
			or ("Level " .. tostring(level))
	end

	level = math.max(0, math.floor(level or 0))

	if level == 0 then
		return def.UpgradeName
			or def.Name
			or name
	end

	local upgrade =
		def.Upgrades
		and def.Upgrades[level]

	if typeof(upgrade) == "table" then
		return upgrade.UpgradeName
			or upgrade.Name
			or ("Level " .. tostring(level))
	end

	return "Level " .. tostring(level)
end

function TowerStats.GetStatsForLevel(name, level, fallbackConfig)
	local def = getDefinition(name)
	local result = {}

	if def and def.Stats then
		result = cloneDictionary(def.Stats)
	elseif fallbackConfig then
		-- Compatibility path while towers are migrated into TowerData.
		for _, object in ipairs(fallbackConfig:GetChildren()) do
			if object:IsA("NumberValue")
				or object:IsA("IntValue")
				or object:IsA("BoolValue")
				or object:IsA("StringValue")
			then
				result[object.Name] = object.Value
			end
		end
	end

	if def and def.Upgrades then
		for current = 1, level do
			local upgrade = def.Upgrades[current]

			if typeof(upgrade) == "table" then
				for key, value in pairs(upgrade) do
					if not RESERVED[key] then
						if typeof(value) == "table" then
							if typeof(result[key]) ~= "table" then
								result[key] = {}
							end
							mergeDictionary(result[key], value)
						else
							result[key] = value
						end
					end
				end

				if upgrade.Stats then
					for key, value in pairs(upgrade.Stats) do
						if typeof(value) == "table" then
							if typeof(result[key]) ~= "table" then
								result[key] = {}
							end
							mergeDictionary(result[key], value)
						else
							result[key] = value
						end
					end
				end
			end
		end
	end

	result.DamageType = CombatProfiles.Resolve(name, result.DamageType)
	return result
end

local function getValueClassName(value)
	local t = typeof(value)

	if t == "boolean" then
		return "BoolValue"
	elseif t == "string" then
		return "StringValue"
	elseif t == "number" then
		return "NumberValue"
	end

	return nil
end

local function ensureValue(parent, name, value)
	if not parent then
		return nil
	end

	-- IMPORTANT:
	-- Tables are structured config data, not ValueBase values.
	-- Never try to assign a table into .Value.
	local className = getValueClassName(value)
	if not className then
		return nil
	end

	local existing = parent:FindFirstChild(name)

	if existing then
		if not existing:IsA("ValueBase") then
			-- Do not destroy folders/models used by special tower systems.
			-- Example: Config.Health, Config.MineStats, Config.Secondary.
			return nil
		end

		-- NumberValue/IntValue can both safely accept normal numeric stats.
		-- For other types, avoid throwing if an authored Config object has
		-- an unexpected ValueBase class.
		local ok = pcall(function()
			existing.Value = value
		end)

		if ok then
			return existing
		end

		warn(
			"[TowerStats] Could not apply",
			name,
			"to",
			existing:GetFullName(),
			"(incompatible Value type)"
		)

		return nil
	end

	local object = Instance.new(className)
	object.Name = name
	object.Value = value
	object.Parent = parent

	return object
end

local function applyMaxHealthMirror(config, value)
	if typeof(value) ~= "number" then
		return
	end

	local healthFolder = config:FindFirstChild("Health")
	if not healthFolder then
		return
	end

	local maxHealth = healthFolder:FindFirstChild("MaxHealth")
	if maxHealth and maxHealth:IsA("ValueBase") then
		maxHealth.Value = value
	end
end

-- Writes a compatibility mirror into Config so the existing special tower logic keeps working.
-- TowerData/runtime remains the source of truth for core balance.
function TowerStats.ApplyStatsToConfig(config, stats)
	if not config or not stats then
		return
	end

	for statName, value in pairs(stats) do
		-- Structured tables are intentionally not shoved into a ValueBase.
		-- They can still be consumed by TowerData logic or upgrade.Config.
		if typeof(value) == "table" then
			continue
		end

		local configName = CORE_ALIASES[statName] or statName

		-- MaxHealth's real gameplay location is Config.Health.MaxHealth.
		-- Keep that synchronized for tower damage, Medic, passive regen, etc.
		-- We ALSO preserve the old top-level compatibility mirror below.
		if statName == "MaxHealth" then
			applyMaxHealthMirror(config, value)
		end

		-- Preserve live support buffs. Their Original* value should become the new base.
		if configName == "Cooldown" and config:FindFirstChild("OriginalCooldown") then
			config.OriginalCooldown.Value = value

		elseif configName == "Range" and config:FindFirstChild("OriginalRange") then
			config.OriginalRange.Value = value

		elseif configName == "Damage" and config:FindFirstChild("OriginalDamage") then
			config.OriginalDamage.Value = value

		else
			ensureValue(config, configName, value)
		end
	end
end

local function setByPath(root, path, value)
	if not root or typeof(path) ~= "string" or path == "" then
		return false
	end

	local current = root
	local chunks = string.split(path, ".")

	for i = 1, #chunks - 1 do
		current = current and current:FindFirstChild(chunks[i])

		if not current then
			return false
		end
	end

	if not current then
		return false
	end

	return ensureValue(current, chunks[#chunks], value) ~= nil
end

function TowerStats.ApplyUpgradeConfigOverrides(config, upgrade)
	if not (config and upgrade and upgrade.Config) then
		return
	end

	for path, value in pairs(upgrade.Config) do
		if typeof(value) ~= "table" then
			local applied = setByPath(config, path, value)

			if not applied then
				warn(
					"[TowerStats] Could not apply Config override:",
					path
				)
			end
		end
	end
end

-- ============================================================
-- SECONDARY ATTACKS
-- ============================================================
-- Secondary attacks remain the SAME old Config.Secondary system used by
-- TowerServer. TowerData only decides when Config.Secondary exists and what
-- values are mirrored into it.
--
-- This keeps the original Rocket/Laser/AOE/splash/burst behavior completely
-- intact while allowing an in-place upgrade to unlock or improve it.

function TowerStats.HasSecondaryDefinition(name)
	local def = getDefinition(name)

	if not def then
		return false
	end

	if def.Secondary ~= nil then
		return true
	end

	for _, upgrade in pairs(def.Upgrades or {}) do
		-- Some TowerData definitions may store non-upgrade metadata
		-- alongside numbered upgrade tables. Ignore those safely.
		if typeof(upgrade) == "table"
			and upgrade.Secondary ~= nil
		then
			return true
		end
	end

	return false
end

function TowerStats.GetSecondaryForLevel(name, level)
	local def = getDefinition(name)

	if not def then
		return nil, false
	end

	local managed = TowerStats.HasSecondaryDefinition(name)

	-- If this tower has never moved its secondary attack into TowerData,
	-- preserve the old Config.Secondary folder exactly as-is.
	if not managed then
		return nil, false
	end

	local result = nil

	local function applySecondaryPatch(patch)
		if patch == nil then
			return
		end

		-- Explicit `Secondary = false` completely removes it.
		if patch == false then
			result = nil
			return
		end

		if typeof(patch) ~= "table" then
			return
		end

		if result == nil then
			result = {}
		end

		mergeDictionary(result, patch)
	end

	applySecondaryPatch(def.Secondary)

	for current = 1, level do
		local upgrade = def.Upgrades and def.Upgrades[current]

		if typeof(upgrade) == "table" then
			applySecondaryPatch(upgrade.Secondary)
		end
	end

	return result, true
end

function TowerStats.ApplySecondaryToConfig(config, secondaryData, managed)
	if not config or not managed then
		return config and config:FindFirstChild("Secondary")
	end

	local secondary = config:FindFirstChild("Secondary")

	-- `Enabled = false` and `Secondary = false` both mean the attack should
	-- not exist at this level.
	if not secondaryData or secondaryData.Enabled == false then
		if secondary then
			secondary:Destroy()
		end

		return nil
	end

	if secondary and not secondary:IsA("Folder") then
		secondary:Destroy()
		secondary = nil
	end

	if not secondary then
		secondary = Instance.new("Folder")
		secondary.Name = "Secondary"
		secondary.Parent = config
	end

	-- The resolved module table is cumulative and authoritative for its
	-- ValueBase children. Remove an old value if it is no longer present.
	for _, child in ipairs(secondary:GetChildren()) do
		if child:IsA("ValueBase")
			and child.Name ~= "Enabled"
			and secondaryData[child.Name] == nil
		then
			child:Destroy()
		end
	end

	for key, value in pairs(secondaryData) do
		if key ~= "Enabled" and typeof(value) ~= "table" then
			ensureValue(secondary, key, value)
		end
	end

	return secondary
end

function TowerStats.CalculateSellValue(totalSpent)
	return math.max(
		0,
		math.floor(
			(totalSpent or 0)
				* TowerStats.GetSellPercent()
		)
	)
end

return TowerStats
