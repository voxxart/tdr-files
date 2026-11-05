local TowerAppearance = {}

-- ============================================================
-- RENDER / EFFECT HELPERS
-- ============================================================

local function isRenderable(object)
	-- MeshPart and UnionOperation already inherit from BasePart.
	return object:IsA("BasePart")
end

local function getUpgradeTransparency(object)
	-- HumanoidRootPart should NEVER become visible from an upgrade.
	if object.Name == "HumanoidRootPart"
		or object.Name == "HRP"
	then
		return 1
	end

	-- Supported setup:
	--
	-- Part
	-- └─ Transparency (NumberValue)
	--
	-- Example:
	-- Transparency.Value = 0.55
	local transparencyValue =
		object:FindFirstChild("Transparency")

	if transparencyValue
		and transparencyValue:IsA("NumberValue")
	then
		return math.clamp(
			transparencyValue.Value,
			0,
			1
		)
	end

	-- Optional attribute version:
	--
	-- UpgradeTransparency = 0.55
	local transparencyAttribute =
		object:GetAttribute("UpgradeTransparency")

	if typeof(transparencyAttribute) == "number" then
		return math.clamp(
			transparencyAttribute,
			0,
			1
		)
	end

	-- Normal upgrade parts become fully visible.
	return 0
end

local function enableUpgradeEffect(object)
	-- Any Beam introduced by this upgrade level
	-- becomes enabled.
	if object:IsA("Beam") then
		object.Enabled = true
		return
	end

	-- Only automatically enable ParticleEmitters named:
	--
	-- Effect1
	-- Effect2
	-- Effect3
	-- etc.
	if object:IsA("ParticleEmitter") or object:IsA("Fire") then
		local effectNumber =
			tonumber(
				string.match(
					object.Name,
					"^Effect(%d+)$"
				)
			)

		if effectNumber
			and effectNumber >= 1
		then
			object.Enabled = true
		end
	end
end

-- ============================================================
-- UPDATE OBJECTVALUE SUPPORT
-- ============================================================
--
-- Supported:
--
-- Update
-- Update1
-- Update2
-- Update3
-- etc.
--
-- Multiple children may also all be named exactly "Update".
--
-- Each ObjectValue points at an existing tower visual that
-- should be disabled when this upgrade is revealed.
-- ============================================================

local function isUpdateObjectValue(object)
	if not object:IsA("ObjectValue") then
		return false
	end

	return object.Name == "Update"
		or string.match(
			object.Name,
			"^Update%d+$"
		) ~= nil
end

local function disableOneObject(object)
	-- Parts / MeshParts / Unions.
	if object:IsA("BasePart") then
		object.Transparency = 1
		return
	end

	-- Decals / Textures.
	if object:IsA("Decal")
		or object:IsA("Texture")
	then
		object.Transparency = 1
		return
	end

	-- Effects.
	if object:IsA("Beam")
		or object:IsA("ParticleEmitter")
		or object:IsA("Trail")
		or object:IsA("Smoke")
		or object:IsA("Fire")
		or object:IsA("Sparkles")
		or object:IsA("Light")
		or object:IsA("Highlight")
	then
		object.Enabled = false
		return
	end

	-- World-space GUIs.
	if object:IsA("BillboardGui")
		or object:IsA("SurfaceGui")
	then
		object.Enabled = false
		return
	end

	-- Normal GUI objects.
	if object:IsA("GuiObject") then
		object.Visible = false
	end
end

local function disableUpdatedTarget(target)
	if not target then
		return
	end

	-- Disable the actual target.
	disableOneObject(target)

	-- Disable everything inside it too.
	for _, descendant in ipairs(
		target:GetDescendants()
		) do
		disableOneObject(descendant)
	end
end

local function processUpdateObjectValues(
	sourceObject,
	processedTargets
)
	for _, child in ipairs(
		sourceObject:GetChildren()
		) do
		if isUpdateObjectValue(child) then
			local target =
				child.Value

			-- Ignore:
			--
			-- nil references
			-- self references
			-- duplicate Update references during this upgrade
			if target
				and target ~= sourceObject
				and not processedTargets[target]
			then
				processedTargets[target] = true

				disableUpdatedTarget(
					target
				)
			end
		end
	end
end

-- ============================================================
-- REVEAL HELPERS
-- ============================================================

local function reveal(
	object,
	processedTargets
)
	if isRenderable(object) then
		object.Transparency =
			getUpgradeTransparency(object)
	end

	processUpdateObjectValues(
		object,
		processedTargets
	)

	enableUpgradeEffect(object)
end

local function revealTree(
	root,
	processedTargets
)
	reveal(
		root,
		processedTargets
	)

	for _, object in ipairs(
		root:GetDescendants()
		) do
		reveal(
			object,
			processedTargets
		)
	end
end

-- ============================================================
-- WEAPON HELPERS
-- ============================================================
--
-- Recognized weapon assemblies:
--
-- Weapon
-- Weapon2
-- Weapon3
-- Weapon4
-- Weapon5
-- etc.
--
-- Things like:
--
-- WeaponGlow
-- WeaponEffect
-- WeaponPart
--
-- are NOT treated as entire weapon assemblies.
-- ============================================================

local function isWeaponObject(object)
	return object.Name == "Weapon"
		or string.match(
			object.Name,
			"^Weapon%d+$"
		) ~= nil
end

-- ============================================================
-- FIND WEAPONS INSIDE AN UPGRADE LEVEL
-- ============================================================

local function findWeaponTemplates(folder)
	local templates = {}

	for _, object in ipairs(
		folder:GetDescendants()
		) do
		if isWeaponObject(object) then

			-- Prevent a weapon-named descendant inside another
			-- weapon from becoming a separate weapon assembly.
			--
			-- Example:
			--
			-- Weapon
			-- └─ Weapon2
			--
			-- Weapon2 would NOT be handled separately.
			local insideAnotherWeapon = false

			local ancestor =
				object.Parent

			while ancestor
				and ancestor ~= folder
			do
				if isWeaponObject(
					ancestor
					) then
					insideAnotherWeapon = true
					break
				end

				ancestor =
					ancestor.Parent
			end

			if not insideAnotherWeapon then
				table.insert(
					templates,
					object
				)
			end
		end
	end

	return templates
end

-- ============================================================
-- FIND CURRENT LIVE WEAPON
-- ============================================================
--
-- Finds the currently active weapon with the exact same name.
--
-- Examples:
--
-- Weapon  -> Weapon
-- Weapon2 -> Weapon2
-- Weapon3 -> Weapon3
--
-- Objects still sitting inside UpgradeModels are ignored.
-- ============================================================

local function findLiveWeapon(
	model,
	upgradeModels,
	weaponName
)
	-- Preferred location:
	-- weapons normally live directly under the tower.
	local direct =
		model:FindFirstChild(
			weaponName
		)

	if direct
		and not direct:IsDescendantOf(
			upgradeModels
		)
	then
		return direct
	end

	-- Legacy/nested fallback.
	for _, object in ipairs(
		model:GetDescendants()
		) do
		if object.Name == weaponName
			and not object:IsDescendantOf(
				upgradeModels
			)
		then
			return object
		end
	end

	return nil
end

-- ============================================================
-- MOVE WEAPON INTO LIVE TOWER
-- ============================================================
--
-- IMPORTANT:
--
-- NO Clone().
--
-- The Weapon already exists inside THIS tower's cloned
-- UpgradeModels hierarchy.
--
-- We simply move that exact object:
--
--     weaponTemplate.Parent = model
--
-- If an older live weapon with the same name already exists,
-- that old weapon is destroyed first.
-- ============================================================

local function moveWeaponIntoTower(
	model,
	upgradeModels,
	weaponTemplate,
	processedTargets
)
	if not weaponTemplate
		or not weaponTemplate.Parent
	then
		return nil
	end

	local weaponName =
		weaponTemplate.Name

	if not isWeaponObject(
		weaponTemplate
		) then
		return nil
	end

	-- Find the currently active version of this weapon.
	local oldWeapon =
		findLiveWeapon(
			model,
			upgradeModels,
			weaponName
		)

	-- ========================================================
	-- REMOVE PREVIOUS VERSION
	-- ========================================================
	--
	-- For the main Weapon, this will normally find something.
	--
	-- For Weapon2 / Weapon3, this will normally be nil because
	-- those weapons are first introduced at their final level.
	-- ========================================================

	if oldWeapon
		and oldWeapon ~= weaponTemplate
	then
		oldWeapon:Destroy()
	end

	-- ========================================================
	-- MOVE THE ACTUAL UPGRADE WEAPON
	-- ========================================================
	--
	-- NO:
	--
	-- weaponTemplate:Clone()
	--
	-- Just move the existing object directly into the tower.
	-- ========================================================

	weaponTemplate.Parent =
		model

	-- Reveal its parts/effects and process any Update values
	-- it contains.
	revealTree(
		weaponTemplate,
		processedTargets
	)

	return weaponTemplate
end

-- ============================================================
-- CHECK IF OBJECT BELONGS TO A WEAPON TEMPLATE
-- ============================================================
--
-- Normally all weapon templates have already been moved before
-- we reveal the remaining upgrade contents.
--
-- This helper is kept as additional protection in case a weapon
-- could not be moved for some unexpected reason.
-- ============================================================

local function isInsideWeaponTemplate(
	object,
	weaponTemplates
)
	for _, weaponTemplate in ipairs(
		weaponTemplates
		) do
		if object == weaponTemplate then
			return true
		end

		if weaponTemplate.Parent
			and object:IsDescendantOf(
				weaponTemplate
			)
		then
			return true
		end
	end

	return false
end

-- ============================================================
-- APPLY ONE UPGRADE LEVEL
-- ============================================================

function TowerAppearance.ApplyUpgrade(
	model,
	level
)
	if not model then
		return false,
			"No tower model supplied"
	end

	-- Find UpgradeModels recursively so nested appearance
	-- structures remain supported.
	local upgradeModels =
		model:FindFirstChild(
			"UpgradeModels",
			true
		)

	if not upgradeModels then
		return false,
			"Tower has no UpgradeModels folder"
	end

	-- Prefer direct level folder.
	--
	-- Fall back to recursive lookup for legacy/nested setups.
	local folder =
		upgradeModels:FindFirstChild(
			tostring(level)
		)
		or upgradeModels:FindFirstChild(
			tostring(level),
			true
		)

	if not folder then
		-- An upgrade does not have to contain visual changes.
		return true
	end

	-- One shared table for the entire upgrade application.
	--
	-- If multiple Update values point at the same object,
	-- that target is only processed once.
	local processedTargets = {}

	-- ========================================================
	-- FIND ALL WEAPONS BEFORE MOVING THEM
	-- ========================================================
	--
	-- This MUST happen first because once a weapon is moved,
	-- it is no longer a descendant of this level folder.
	-- ========================================================

	local weaponTemplates =
		findWeaponTemplates(
			folder
		)

	-- ========================================================
	-- MOVE ALL WEAPONS
	-- ========================================================
	--
	-- Weapon:
	--     Old Weapon destroyed.
	--     New Weapon moved directly into tower.
	--
	-- Weapon2:
	--     Usually nothing to destroy.
	--     Weapon2 moved directly into tower.
	--
	-- Weapon3:
	--     Same behavior.
	--
	-- NOTHING is cloned.
	-- ========================================================

	for _, weaponTemplate in ipairs(
		weaponTemplates
		) do
		moveWeaponIntoTower(
			model,
			upgradeModels,
			weaponTemplate,
			processedTargets
		)
	end

	-- ========================================================
	-- REVEAL EVERYTHING ELSE
	-- ========================================================
	--
	-- Weapons have already physically moved out of the upgrade
	-- folder, so normally they won't appear in GetDescendants().
	--
	-- The weapon-template check is still kept as a safeguard.
	-- ========================================================

	for _, object in ipairs(
		folder:GetDescendants()
		) do
		if not isInsideWeaponTemplate(
			object,
			weaponTemplates
			) then
			reveal(
				object,
				processedTargets
			)
		end
	end

	return true
end

-- ============================================================
-- APPLY EVERY LEVEL UP TO A GIVEN LEVEL
-- ============================================================

function TowerAppearance.ApplyThroughLevel(
	model,
	level
)
	for current = 1, level do
		TowerAppearance.ApplyUpgrade(
			model,
			current
		)
	end
end

return TowerAppearance