local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local modules = ReplicatedStorage:WaitForChild("Modules")
local health = require(modules:WaitForChild("Health"))
local GameWrapUp = false
local cash = Players.LocalPlayer:WaitForChild("Cash")
local towers = ReplicatedStorage:WaitForChild("Towers")

local events = ReplicatedStorage:WaitForChild("Events")
local setTimeText = events:WaitForChild("SetTextTime")
local skipButon = events:WaitForChild("SkipButton")
local damageEvent = ReplicatedStorage.Events:FindFirstChild("BaseDamaged")
local HttpService = game:GetService("HttpService")
local TowerIcons = require(ReplicatedStorage.GameModules:WaitForChild("TowerIcons"))
local UpgradeIcons = require(game.ReplicatedStorage.GameModules:WaitForChild("UpgradeIcons"))
local TowerData = require(ReplicatedStorage.GameModules:WaitForChild("TowerData"))

local functions = ReplicatedStorage:WaitForChild("Functions")
local requestTowerFunction = functions:WaitForChild("RequestTower")
local spawnTowerFunction = functions:WaitForChild("SpawnTower")
local sellTowerFunction = functions:WaitForChild("SellTower")
local changeModeFunction = functions:WaitForChild("ChangeTowerMode")
local upgradeTowerFunction = functions:WaitForChild("UpgradeTower")
local getDataFunction = functions:WaitForChild("GetData")
local voteSkip = functions:WaitForChild("VoteSkip")
local SpeedUpCooldown = events:WaitForChild("SpeedupCooldown")
local speedup1 = functions:WaitForChild("SpeedUp1")
local speedup2 = functions:WaitForChild("SpeedUp2")

local camera = workspace.CurrentCamera
local gui = script.Parent
local hoverGui = gui.MobHoverGui
local UnitHoverGui = gui.UnitHoverGui
local TowerhoverGui = gui.TowerHoverGui
local upgradeGui = gui.UpgradeUI
local advancedStatsUI = require(ReplicatedStorage.GameModules:WaitForChild("AdvancedStatsUI")).new(upgradeGui.Stats.Main)
script.Destroying:Connect(function() advancedStatsUI:Destroy() end)
local info = workspace:WaitForChild("Info")

hoverGui.Active = false
UnitHoverGui.Active = false
TowerhoverGui.Active = false

local hoveredInstance = nil
local selectedTower = nil
local towerToSpawn = nil
local canPlace = false
local rotation = 0
local plr = Players.LocalPlayer
local placedTowers = plr.PlacedTowers
local lastTouch = tick()
local lastTouchAIm = tick()
local currentPreviewCFrame = nil

local hoveredModel = nil
local hoveredKind = nil



local slotAnimator = require(ReplicatedStorage.GameModules:WaitForChild("PlacementSlotAnimator")).new()
script.Destroying:Connect(function() slotAnimator:Destroy() end)

local placementRequestSerial = 0

local function beginPlacementRequest()
	placementRequestSerial += 1
	return placementRequestSerial
end

local function placementRequestIsCurrent(requestSerial)
	return requestSerial == placementRequestSerial and not GameWrapUp
end


-- Global table to track cooldowns (one per map)
local GlobalCooldowns = {} -- key: ability name, value: seconds remaining

function Comma(Amount)
	while true do
		Amount, k = string.gsub(Amount, "^(-?%d+)(%d%d%d)", '%1,%2')
		if (k == 0) then
			break
		end
	end
	return Amount
end
local function newRequestId()
	return HttpService:GenerateGUID(false)
end

-- ============================================================
-- TOWER DATA / APPEARANCE HELPERS
-- ============================================================

local RESERVED_UPGRADE_KEYS = {
	Cost = true,
	Config = true,
	Stats = true,
	Behaviors = true,
	Name = true,
	UpgradeName = true,
}
for index=1,10 do RESERVED_UPGRADE_KEYS["AdvancedStats"..index]=true end

local function getCanonicalTowerName(model)
	if not model then return nil end

	local attr = model:GetAttribute("TowerName")
	if typeof(attr) == "string" and attr ~= "" then
		return attr
	end

	local towerNameValue = model:FindFirstChild("TowerName")
	if towerNameValue and towerNameValue:IsA("StringValue") and towerNameValue.Value ~= "" then
		return towerNameValue.Value
	end

	return model.Name
end

local function getTowerLevel(model)
	if not model then return 0 end

	local attr = model:GetAttribute("TowerLevel")
	if typeof(attr) == "number" then
		return attr
	end

	local config = model:FindFirstChild("Config")
	local level = config and config:FindFirstChild("Level")
	return level and level.Value or 0
end

local function getTowerDefinition(towerName)
	return TowerData.Towers and TowerData.Towers[towerName] or nil
end

local function getUpgradeDefinition(towerName, level)
	local definition = getTowerDefinition(towerName)
	return definition and definition.Upgrades and definition.Upgrades[level] or nil
end


local function getUpgradeNameForLevel(towerName, level)
	local definition = getTowerDefinition(towerName)

	if not definition then
		return level == 0
			and towerName
			or ("Level " .. tostring(level))
	end

	level = math.max(0, math.floor(level or 0))

	-- Level 0 metadata lives directly on the tower definition.
	if level == 0 then
		return definition.UpgradeName
			or definition.Name
			or towerName
	end

	local upgrade =
		definition.Upgrades
		and definition.Upgrades[level]

	if upgrade then
		return upgrade.UpgradeName
			or upgrade.Name
			or ("Level " .. tostring(level))
	end

	return "Level " .. tostring(level)
end

local function getStatsForLevel(towerName, level)
	local definition = getTowerDefinition(towerName)
	if not definition then
		return {}
	end

	local stats = {}

	for key, value in pairs(definition.Stats or {}) do
		stats[key] = value
	end

	for currentLevel = 1, level do
		local upgrade = definition.Upgrades and definition.Upgrades[currentLevel]

		if upgrade then
			for key, value in pairs(upgrade) do
				if not RESERVED_UPGRADE_KEYS[key] then
					stats[key] = value
				end
			end

			if upgrade.Stats then
				for key, value in pairs(upgrade.Stats) do
					stats[key] = value
				end
			end
		end
	end

	return stats
end

local function hasNextUpgrade(model)
	if not model then return false end
	local towerName = getCanonicalTowerName(model)
	local nextLevel = getTowerLevel(model) + 1
	return getUpgradeDefinition(towerName, nextLevel) ~= nil
end


local function getMaxUpgradeLevel(towerName)
	local definition = getTowerDefinition(towerName)
	local upgrades = definition and definition.Upgrades

	if typeof(upgrades) ~= "table" then
		return 0
	end

	local maxLevel = 0

	for level in pairs(upgrades) do
		if typeof(level) == "number" and level > maxLevel then
			maxLevel = level
		end
	end

	return maxLevel
end

-- Placement previews should never apply skin-hiding transparency to Default.
-- The Default appearance keeps the transparency authored in the actual model.
-- We only clear LocalTransparencyModifier, which can otherwise make an
-- otherwise-visible Default model disappear locally.
local function preparePlaceholderAppearance(model, appearanceName)
	if not model then
		return
	end

	local hasSkin =
		typeof(appearanceName) == "string"
		and appearanceName ~= ""
		and appearanceName ~= "Default"

	model:SetAttribute("HasSkin", hasSkin)

	if hasSkin then
		return
	end

	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			-- Do NOT overwrite object.Transparency here.
			-- Some technical parts are intentionally transparent in the source.
			object.LocalTransparencyModifier = 0
		end
	end
end

local function getSellValue(model)
	if not model then return 0 end

	local totalSpent = model:GetAttribute("TotalSpent")

	if typeof(totalSpent) ~= "number" then
		local config = model:FindFirstChild("Config")
		local totalSpentValue = config and config:FindFirstChild("TotalSpent")
		totalSpent = totalSpentValue and totalSpentValue.Value or 0
	end

	local sellPercent =
		(TowerData.Settings and TowerData.Settings.SellPercent)
		or 0.5

	return math.max(0, math.floor(totalSpent * sellPercent))
end

local function legacySkinToAppearance(towerName, skinName)
	if typeof(skinName) ~= "string" or skinName == "" then
		return nil
	end

	-- Already in the new appearance format.
	local towerFolder = towers:FindFirstChild(towerName)
	if towerFolder and towerFolder:FindFirstChild(skinName) then
		return skinName
	end

	-- Legacy examples:
	-- "Retro Trooper"  -> "Retro"
	-- "Golden Trooper" -> "Golden"
	if skinName == towerName then
		return "Default"
	end

	local suffix = " " .. towerName
	if #skinName > #suffix and string.sub(skinName, -#suffix) == suffix then
		return string.sub(skinName, 1, #skinName - #suffix)
	end

	return nil
end

local function getSelectedAppearanceName(towerName, selectedSkins)
	if typeof(selectedSkins) ~= "table" then
		return "Default"
	end

	-- New save format:
	-- SelectedSkins = {
	--     Trooper = "Retro",
	--     Commander = "Beach",
	-- }
	local direct = selectedSkins[towerName]
	if typeof(direct) == "string" and direct ~= "" then
		return legacySkinToAppearance(towerName, direct) or direct
	end

	-- Backwards compatibility with the old array format.
	for _, skinName in ipairs(selectedSkins) do
		local appearance = legacySkinToAppearance(towerName, skinName)
		if appearance and appearance ~= "Default" then
			return appearance
		end
	end

	return "Default"
end

local function getTowerAppearance(towerName, playerData)
	local towerFolder = towers:FindFirstChild(towerName)
	if not towerFolder then
		return nil, nil
	end

	local selectedSkins =
		playerData
		and playerData.SelectedSkins
		or {}

	local appearanceName =
		getSelectedAppearanceName(
			towerName,
			selectedSkins
		)

	local appearance =
		towerFolder:FindFirstChild(appearanceName)

	if not appearance then
		appearanceName = "Default"
		appearance = towerFolder:FindFirstChild("Default")
	end

	return appearance, appearanceName
end

local function getPlacementCost(towerName, fallbackConfig)
	local definition = getTowerDefinition(towerName)

	if definition and definition.Cost ~= nil then
		return definition.Cost
	end

	local price = fallbackConfig and fallbackConfig:FindFirstChild("Price")
	return price and price.Value or 0
end
damageEvent.OnClientEvent:Connect(function()
	gui.Sounds.Damage:Play()

	local healthBar = gui.Info.GameStats.Health
	local originalPosition = UDim2.new(0.201, 0,0.082, 0)
	local offsetPosition = UDim2.new(0.201, 2,0.082, 0)

	-- Set to original position before tween
	healthBar.Position = originalPosition

	-- Tween to offset position
	healthBar:TweenPosition(offsetPosition, "Out", "Elastic", 0.3, true, function()
		-- After first tween completes, tween back
		healthBar:TweenPosition(originalPosition, "Out", "Quad", 0.2)
	end)
end)

local rotationTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)


local placementModified = workspace.Info.Modifiers.PlacementInfo.PlacementModified

local baseTowers = {
	[1] = 40,
	[2] = 30,
	[3] = 25,
	[4] = 20,
	[5] = 15,
	[6] = 15,
}

local function getPlacement()
	local amountOfPlayers = workspace.Info.PlrValue.Value
	local baseLimit = baseTowers[amountOfPlayers] or baseTowers[6]

	return math.floor(baseLimit * placementModified.Value)
end

setTimeText.OnClientEvent:Connect(function(min, sec)
	-- Pad minutes and seconds with a leading zero if they are less than 10
	local minText = min < 10 and "0" .. min or tostring(min)
	local secText = sec < 10 and "0" .. sec or tostring(sec)

	-- Concatenate the formatted time
	gui.Info.Timer.Count.Text = minText .. ":" .. secText
end)

local smoothMousePos = Vector2.new()
local smoothnessFactor = 0.15

local function SmoothMousePosition(newMousePos)
	smoothMousePos = smoothMousePos:Lerp(newMousePos, smoothnessFactor)
	return smoothMousePos
end

--------------------------------------------------
-- BORDER CHECK
--------------------------------------------------
local function isInsideBorder(position: Vector3)
	local towersFolder = workspace:FindFirstChild("Towers")
	if not towersFolder then return false end

	for _, towerModel in ipairs(towersFolder:GetChildren()) do
		local border = towerModel:FindFirstChild("Border")
		if border and border:IsA("BasePart") then
			local relative = border.CFrame:PointToObjectSpace(position)
			local size = border.Size

			if math.abs(relative.X) <= size.X/2 and
				math.abs(relative.Y) <= size.Y/2 and
				math.abs(relative.Z) <= size.Z/2 then
				return true
			end
		end
	end

	return false
end

--------------------------------------------------
-- PLACEMENT RAYCAST
--------------------------------------------------
-- Placement should always follow the real mouse position directly.
-- Do NOT reuse the hover/selection raycast here because that function
-- may return a tower Model instead of a RaycastResult, which makes the
-- placement loop stop before it can move the preview.
local function PlacementRaycast(model)
	local mousePosition = UserInputService:GetMouseLocation()
	local mouseRay = camera:ViewportPointToRay(
		mousePosition.X,
		mousePosition.Y
	)

	local rayCastParams = RaycastParams.new()
	rayCastParams.FilterType = Enum.RaycastFilterType.Exclude
	rayCastParams.IgnoreWater = true

	local blackList = { camera }

	if model then
		table.insert(blackList, model)
	end

	-- Placement should ray through already-placed towers and hit the map
	-- underneath. Overlap is still rejected by isInsideBorder().
	local towersFolder = workspace:FindFirstChild("Towers")
	if towersFolder then
		table.insert(blackList, towersFolder)
	end

	-- Ignore range visuals.
	local dependencies = workspace:FindFirstChild("GameDependencies")
	if dependencies then
		local rangeFolder = dependencies:FindFirstChild("Range")
		if rangeFolder then
			table.insert(blackList, rangeFolder)
		end
	end

	-- Ignore players.
	for _, player in ipairs(game.Players:GetPlayers()) do
		if player.Character then
			table.insert(blackList, player.Character)
		end
	end

	rayCastParams.FilterDescendantsInstances = blackList

	local result = workspace:Raycast(
		mouseRay.Origin,
		mouseRay.Direction * 1000,
		rayCastParams
	)

	if not result then
		return nil, mousePosition, false
	end

	return result, mousePosition, isInsideBorder(result.Position)
end

local interaction = require(ReplicatedStorage.GameModules:WaitForChild("TowerInteraction")).new(workspace, plr:WaitForChild("PlayerGui"))
local actionGate = require(ReplicatedStorage.GameModules:WaitForChild("TowerActionGate")).new()
script.Destroying:Connect(function() interaction:Destroy() end)

local function MouseRaycast(model, position)
	position = position or UserInputService:GetMouseLocation()
	local result, target, kind = interaction:Pick(position, model)
	return result, position, false, target, kind
end

local function MouseRaycast2(model)
	local mousePosition = UserInputService:GetMouseLocation()
	local smoothMousePos = SmoothMousePosition(mousePosition)
	local mouseRay = camera:ViewportPointToRay(smoothMousePos.X, smoothMousePos.Y)


	local rayCastParams = RaycastParams.new()
	rayCastParams.FilterType = Enum.RaycastFilterType.Exclude
	rayCastParams.CollisionGroup = "Aim" -- 👈 IMPORTANT ADDITION

	-- Build blacklist
	local blackList = { camera }

	-- Ignore preview model ONLY
	if model and not model:IsDescendantOf(workspace:FindFirstChild("Towers")) then
		table.insert(blackList, model)
	end

	for _, player in ipairs(game.Players:GetPlayers()) do
		if player.Character then
			table.insert(blackList, player.Character)
		end
	end

	rayCastParams.FilterDescendantsInstances = blackList
	rayCastParams.IgnoreWater = true

	--------------------------------------------------
	-- PRIMARY RAY
	--------------------------------------------------
	local result = workspace:Raycast(
		mouseRay.Origin,
		mouseRay.Direction * 1000,
		rayCastParams
	)

	if result then
		local blocked = isInsideBorder(result.Position)

		-- Tower selection
		local tower = result.Instance:FindFirstAncestorWhichIsA("Model")
		if tower and tower:FindFirstChild("IsTower") then
			return tower, smoothMousePos, blocked
		end

		-- Ground hit
		return result, smoothMousePos, blocked
	end

	--------------------------------------------------
	-- FALLBACK: tower snapping
	--------------------------------------------------
	local FAT_RADIUS = 1

	local sphereParams = OverlapParams.new()
	sphereParams.FilterType = Enum.RaycastFilterType.Exclude
	sphereParams.FilterDescendantsInstances = blackList

	local sphereCenter = mouseRay.Origin + mouseRay.Direction * 60
	local nearbyParts = workspace:GetPartBoundsInRadius(
		sphereCenter,
		FAT_RADIUS,
		sphereParams
	)

	local closestTower
	local closestDist = math.huge

	for _, part in ipairs(nearbyParts) do
		local tower = part:FindFirstAncestorWhichIsA("Model")
		if tower and tower:FindFirstChild("IsTower") then
			local hrp = tower.PrimaryPart or tower:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = (hrp.Position - mouseRay.Origin).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestTower = tower
				end
			end
		end
	end

	if closestTower then
		local blocked = isInsideBorder(closestTower.PrimaryPart.Position)
		return closestTower, smoothMousePos, blocked
	end

	--------------------------------------------------
	-- Nothing hit
	--------------------------------------------------
	return nil, smoothMousePos, false
end

local GuiService = game:GetService("GuiService")

local function clamp(n, a, b)
	return math.max(a, math.min(b, n))
end

local function HoverOverMob(mob, mousePos)
	if not mob then
		hoverGui.Visible = false
		return
	end

	local EnemyStats = mob:FindFirstChild("EnemyStats")

	if not EnemyStats then
		hoverGui.Visible = false
		return
	end

	-- Health UI
	local maxH = EnemyStats.MaxHealth.Value
	local curH = EnemyStats.Health.Value
	local percent = (maxH > 0) and (curH / maxH) or 0

	hoverGui.HealthFrame.Health.CurrentHealth.Size = UDim2.new(percent, 0, 1, 0)
	hoverGui.HealthFrame.Count.Text = Comma(curH) .. "/" .. Comma(maxH)
	hoverGui.EnemyName.Text = EnemyStats.Parent.Name

	-- Attributes
	hoverGui.Attributes.Hidden.Visible = EnemyStats:FindFirstChild("Hidden") ~= nil
	hoverGui.Attributes.NoCash.Visible = EnemyStats:FindFirstChild("NoCash") ~= nil
	hoverGui.Attributes.Invincible.Visible = EnemyStats:FindFirstChild("Invincible") ~= nil
	hoverGui.Attributes.Lead.Visible = EnemyStats:FindFirstChild("Lead") ~= nil
	hoverGui.Attributes.ExplosionResist.Visible = EnemyStats:FindFirstChild("Lead") ~= nil
	hoverGui.Attributes.NoStun.Visible = EnemyStats:FindFirstChild("NoStun") ~= nil
	hoverGui.Attributes.Aggro.Visible = EnemyStats:FindFirstChild("Aggro") ~= nil

	local def = EnemyStats:FindFirstChild("Defense")
	if def then
		hoverGui.Attributes.Defense.Visible = true
		hoverGui.Attributes.Defense.Input.Text = def.DefensePercentValue.Value .. "%"
	else
		hoverGui.Attributes.Defense.Visible = false
	end
	local def2 = EnemyStats:FindFirstChild("ExplosionDefense")
	if def2 then
		hoverGui.Attributes.ExplosionResist.Visible = true
		hoverGui.Attributes.ExplosionResist.Input.Text = def2.DefensePercentValue.Value .. "%"
	else
		hoverGui.Attributes.ExplosionResist.Visible = false
	end
	local shield = EnemyStats:FindFirstChild("ShieldHealth")
	if shield and shield.Health.Value > 0 then
		hoverGui.HealthFrame.Health.CurrentShield.Visible = true
		hoverGui.HealthFrame.Count.Text = "" .. (tostring(shield.Health.Value) + tostring(EnemyStats.Health.Value)) .. "/" .. tostring(EnemyStats.MaxHealth.Value)
		local percent2 = (shield.Health.Value > 0) and (shield.Health.Value / shield.MaxHealth.Value) or 0
		hoverGui.HealthFrame.Health.CurrentShield.Size = UDim2.new(percent2, 0, 1, 0)
	else
		hoverGui.HealthFrame.Health.CurrentShield.Visible = false
	end
	-- ===== Cursor-follow position (same fix as tooltips) =====
	-- Offsets you wanted (right next to cursor)
	local PIXEL_OFFSET_X = 12
	local PIXEL_OFFSET_Y = 7

	-- mousePos is screen pixels (usually includes topbar inset)
	local inset = GuiService:GetGuiInset()
	local mx = mousePos.X - inset.X
	local my = mousePos.Y - inset.Y

	-- convert to hoverGui parent's local space
	local parent = hoverGui.Parent
	local localX = (mx - parent.AbsolutePosition.X) + PIXEL_OFFSET_X
	local localY = (my - parent.AbsolutePosition.Y) + PIXEL_OFFSET_Y

	-- clamp inside parent
	local parentSize = parent.AbsoluteSize
	local tipSize = hoverGui.AbsoluteSize

	localX = clamp(localX, 0, parentSize.X - tipSize.X)
	localY = clamp(localY, 0, parentSize.Y - tipSize.Y)

	hoverGui.Position = UDim2.fromOffset(localX, localY)
	hoverGui.Visible = true
end

local currentUnitRangeCircle = nil
local currentUnitRangeConnection = nil
local currentHoveredUnitModel = nil

local function ClearUnitRangeCircle()
	if currentUnitRangeConnection then
		currentUnitRangeConnection:Disconnect()
		currentUnitRangeConnection = nil
	end
	if currentUnitRangeCircle then
		currentUnitRangeCircle:Destroy()
		currentUnitRangeCircle = nil
	end
	currentHoveredUnitModel = nil
end


local function HoverOverUnit(mob, mousePos)
	if not mob then
		UnitHoverGui.Visible = false
		ClearUnitRangeCircle()
		return
	end

	local EnemyStats = mob:FindFirstChild("EnemyStats")

	if not EnemyStats then
		UnitHoverGui.Visible = false
		ClearUnitRangeCircle()
		return
	end

	local function clamp(n, a, b)
		return math.max(a, math.min(b, n))
	end

	if not EnemyStats then
		UnitHoverGui.Visible = false
		return
	end

	-- Health UI
	local maxH = EnemyStats.MaxHealth.Value
	local curH = EnemyStats.Health.Value
	local percent = (maxH > 0) and (curH / maxH) or 0

	UnitHoverGui.HealthFrame.Health.Size = UDim2.new(percent,0,1,0)
	UnitHoverGui.HealthFrame.Count.Text = Comma(curH) .. "/" .. Comma(maxH)
	UnitHoverGui.EnemyName.Text = EnemyStats.Parent.Name

	-- Only (re)create the range circle when we're hovering a NEW unit
	if currentHoveredUnitModel ~= mob then
		ClearUnitRangeCircle()

		local hasRange = mob:FindFirstChild("Config") and mob.Config:FindFirstChild("Range")
		if hasRange then
			CreateRangeCircleUnit(mob, true)
		end

		currentHoveredUnitModel = mob
	end


	-- Attributes
	if EnemyStats:FindFirstChild("Attacks") and not mob.Config:FindFirstChild("SecondaryAttack") then
		local Config = EnemyStats.Parent:WaitForChild("Config")
		UnitHoverGui.Attributes.Damage.Visible = true
		UnitHoverGui.Attributes.Cooldown.Visible = true
		UnitHoverGui.Attributes.Range.Visible = true
		UnitHoverGui.Attributes.SplashDamage.Visible = false

		UnitHoverGui.Attributes.Damage.Input.Text = Config.Damage.Value
		UnitHoverGui.Attributes.Cooldown.Input.Text = Config.Cooldown.Value
		UnitHoverGui.Attributes.Range.Input.Text = Config.Range.Value
	elseif EnemyStats:FindFirstChild("Attacks") and mob.Config:FindFirstChild("SecondaryAttack") then
		local Config = EnemyStats.Parent:WaitForChild("Config")
		UnitHoverGui.Attributes.Damage.Visible = true
		UnitHoverGui.Attributes.Cooldown.Visible = true
		UnitHoverGui.Attributes.Range.Visible = true
		UnitHoverGui.Attributes.SplashDamage.Visible = true

		UnitHoverGui.Attributes.Damage.Input.Text = Config.Damage.Value
		UnitHoverGui.Attributes.Cooldown.Input.Text = Config.Cooldown.Value
		UnitHoverGui.Attributes.Range.Input.Text = Config.Range.Value
		UnitHoverGui.Attributes.SplashDamage.Input.Text = Config.SecondaryAttack.Damage.Value
	else

		UnitHoverGui.Attributes.Damage.Visible = false
		UnitHoverGui.Attributes.Cooldown.Visible = false
		UnitHoverGui.Attributes.Range.Visible = false
		UnitHoverGui.Attributes.SplashDamage.Visible = false
	end

	-- ===== Cursor follow (FIXED) =====
	local PIXEL_OFFSET_X = 15
	local PIXEL_OFFSET_Y = 1

	local inset = GuiService:GetGuiInset()
	local mx = mousePos.X - inset.X
	local my = mousePos.Y - inset.Y

	local parent = UnitHoverGui.Parent
	local localX = (mx - parent.AbsolutePosition.X) + PIXEL_OFFSET_X
	local localY = (my - parent.AbsolutePosition.Y) + PIXEL_OFFSET_Y

	local parentSize = parent.AbsoluteSize
	local tipSize = UnitHoverGui.AbsoluteSize

	localX = clamp(localX, 0, parentSize.X - tipSize.X)
	localY = clamp(localY, 0, parentSize.Y - tipSize.Y)

	UnitHoverGui.Position = UDim2.fromOffset(localX, localY)
	UnitHoverGui.Visible = true
end

local function HoverOverTower(mob, mousePos)
	if not mob then
		TowerhoverGui.Visible = false
		return
	end

	local EnemyStats = mob:FindFirstChild("Config")

	if not EnemyStats then
		TowerhoverGui.Visible = false
		return
	end


	-- Health UI
	local maxH = EnemyStats.Health.MaxHealth.Value
	local curH = EnemyStats.Health.HealthValue.Value
	local percent = (maxH > 0) and (curH / maxH) or 0

	TowerhoverGui.HealthBar.Health.Size = UDim2.new(percent,0,1,0)
	TowerhoverGui.HealthBar.Count.Text = Comma(curH) .. "/" .. Comma(maxH) .. " HP"
	TowerhoverGui.TowerInfo.TowerName.Text = string.upper(getCanonicalTowerName(EnemyStats.Parent))
	TowerhoverGui.TowerInfo.Level.Text = "LVL. " .. EnemyStats.Level.Value

	if EnemyStats:FindFirstChild("Flying") then
		TowerhoverGui.Attributes.Defense.Visible = true
		TowerhoverGui.Attributes.Defense.Input.Text = "15%"
	else
		TowerhoverGui.Attributes.Defense.Visible = false
	end

	-- ===== Cursor follow (FIXED) =====
	local PIXEL_OFFSET_X = 15
	local PIXEL_OFFSET_Y = 1

	local inset = GuiService:GetGuiInset()
	local mx = mousePos.X - inset.X
	local my = mousePos.Y - inset.Y

	local parent = TowerhoverGui.Parent
	local localX = (mx - parent.AbsolutePosition.X) + PIXEL_OFFSET_X
	local localY = (my - parent.AbsolutePosition.Y) + PIXEL_OFFSET_Y

	local parentSize = parent.AbsoluteSize
	local tipSize = TowerhoverGui.AbsoluteSize

	local localX = clamp(localX, 0, parentSize.X - tipSize.X)
	local localY = clamp(localY, 0, parentSize.Y - tipSize.Y)

	TowerhoverGui.Position = UDim2.fromOffset(localX, localY)
	TowerhoverGui.Visible = true
end

local function setAnimation(object, animName)
	if not object then
		return nil
	end

	-- Search recursively because some tower appearances nest these.
	local controller =
		object:FindFirstChild("AnimationController", true)
		or object:FindFirstChildOfClass("AnimationController")

	local animationsFolder =
		object:FindFirstChild("Animations", true)

	if not (controller and animationsFolder) then
		return nil
	end

	local animator =
		controller:FindFirstChildOfClass("Animator")

	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	-- New tower format:
	--
	-- Animations
	-- ├─ 0
	-- │  ├─ Idle
	-- │  └─ Attack
	-- ├─ 1
	-- │  ├─ Idle
	-- │  └─ Attack
	-- ...
	--
	-- Placement previews are level 0, while placed/upgraded towers use
	-- their live TowerLevel / Config.Level.
	local level = math.max(
		0,
		math.floor(getTowerLevel(object))
	)

	local levelFolder =
		animationsFolder:FindFirstChild(
			tostring(level)
		)

	local animationObject

	if levelFolder then
		animationObject =
			levelFolder:FindFirstChild(animName)
	end

	-- Legacy fallback:
	-- Animations/Idle
	-- Animations/Attack
	if not animationObject then
		animationObject =
			animationsFolder:FindFirstChild(animName)
	end

	-- Graceful fallback if a particular level has no animation set.
	-- Search downward toward level 0 before giving up.
	if not animationObject then
		for fallbackLevel = level - 1, 0, -1 do
			local fallbackFolder =
				animationsFolder:FindFirstChild(
					tostring(fallbackLevel)
				)

			local fallbackAnimation =
				fallbackFolder
				and fallbackFolder:FindFirstChild(animName)

			if fallbackAnimation then
				animationObject = fallbackAnimation
				break
			end
		end
	end

	if not animationObject
		or not animationObject:IsA("Animation")
	then
		return nil
	end

	-- Reuse an already-loaded matching animation track.
	-- Attribute the track with its level so level 0 Idle and level 1 Idle
	-- are not mistaken for the same animation.
	for _, track in ipairs(
		animator:GetPlayingAnimationTracks()
		) do
		if track.Name == animName
			and track:GetAttribute("TowerLevel") == level
		then
			return track
		end
	end

	local animationTrack
	local success, err =
		pcall(function()
			animationTrack =
			animator:LoadAnimation(animationObject)
		end)

	if not success or not animationTrack then
		warn(
			"Failed to load tower animation:",
			object.Name,
			animName,
			err
		)

		return nil
	end

	animationTrack.Name = animName
	animationTrack:SetAttribute("TowerLevel", level)

	return animationTrack
end

local function playAnimation(object, animName)
	local animationTrack = setAnimation(object, animName)

	if not animationTrack then
		warn("Animation Track Does Not Exist for", object.Name, animName)
		return
	end

	-- Default speed
	local speed = 1

	-- Optional: adjust speed based on known unit types
	local lowerName = object.Name:lower()
	if string.find(lowerName, "trooper") and animName == "Idle" then
		speed = 0.1
	elseif string.find(lowerName, "conscript") then
		speed = 0.15
	elseif string.find(lowerName, "juggernaut") then
		speed = 0.5
	end

	-- Idle should continuously animate for placement previews and normal towers.
	if animName == "Idle" then
		animationTrack.Looped = true
	end

	animationTrack:Play()
	animationTrack:AdjustSpeed(speed)
end

local selectedRangeCircle
local function clearSelectedRange()
	if selectedRangeCircle then selectedRangeCircle:Destroy(); selectedRangeCircle = nil end
end
script.Destroying:Connect(clearSelectedRange)
local function CreateRangeCircle(tower, placeholder)
	if not placeholder then clearSelectedRange() end
	if not tower or not tower.PrimaryPart then
		warn("No Primary Part Found In Tower")
		return
	end

	local range = tower.Config.Range.Value
	local height = (tower.PrimaryPart.Size.Y / 0.75) + tower.HipHeight.Value

	local offset
	if tower.Config:FindFirstChild("Flying") then
		offset = CFrame.new(0, -height - 6.5, 0)
	else
		offset = CFrame.new(0, -height, 0)
	end

	local isBehemoth = tower.Config:FindFirstChild("BehemothStats")

	--------------------------------------------------------------------------------
	-- CLONE MODEL
	--------------------------------------------------------------------------------
	local rangeModel = ReplicatedStorage.Particle.Range:Clone()
	rangeModel.Name = "Range"

	local p = rangeModel.mainPart
	p.CanCollide = false
	p.Anchored = true
	p.Size = Vector3.new(0, 0, 0)
	p.Transparency = isBehemoth and 1 or 0.8

	if tower.Config:FindFirstChild("MissileSilo") then
		p.Color = Color3.fromRGB(255, 0, 0)
	else
		p.Color = Color3.fromRGB(0, 85, 255)
	end

	--------------------------------------------------------------------------------
	-- BEHEMOTH RINGS
	--------------------------------------------------------------------------------
	local MinP, MidP, LP

	if isBehemoth then
		MinP = Instance.new("Part")
		MinP.Name = "mainMinPart"
		MinP.Shape = Enum.PartType.Cylinder
		MinP.Transparency = 0.6
		MinP.Material = Enum.Material.Neon
		MinP.Color = Color3.fromRGB(255, 0, 0)
		MinP.Size = Vector3.new(0, 0, 0)
		MinP.TopSurface = Enum.SurfaceType.Smooth
		MinP.BottomSurface = Enum.SurfaceType.Smooth
		MinP.CanCollide = false
		MinP.Anchored = true
		MinP.Parent = rangeModel

		MidP = Instance.new("Part")
		MidP.Name = "mainMidPart"
		MidP.Shape = Enum.PartType.Cylinder
		MidP.Transparency = 0.7
		MidP.Material = Enum.Material.Neon
		MidP.Color = Color3.fromRGB(255, 170, 0)
		MidP.Size = Vector3.new(0, 0, 0)
		MidP.TopSurface = Enum.SurfaceType.Smooth
		MidP.BottomSurface = Enum.SurfaceType.Smooth
		MidP.CanCollide = false
		MidP.Anchored = true
		MidP.Parent = rangeModel

		LP = Instance.new("Part")
		LP.Name = "mainLongPart"
		LP.Shape = Enum.PartType.Cylinder
		LP.Transparency = 0.8
		LP.Material = Enum.Material.Neon
		LP.Color = Color3.fromRGB(0, 255, 0)
		LP.Size = Vector3.new(0, 0, 0)
		LP.TopSurface = Enum.SurfaceType.Smooth
		LP.BottomSurface = Enum.SurfaceType.Smooth
		LP.CanCollide = false
		LP.Anchored = true
		LP.Parent = rangeModel
	end

	--------------------------------------------------------------------------------
	-- HEARTBEAT UPDATE
	--------------------------------------------------------------------------------
	local heartbeat
	heartbeat = RunService.Heartbeat:Connect(function()
		if not rangeModel.Parent or not tower or not tower.Parent or not tower.PrimaryPart then
			heartbeat:Disconnect()
			return
		end

		local position
		if tower.Config:FindFirstChild("Aviator") then
			position = tower:FindFirstChild("UpgradeModels")["0"].Plane:FindFirstChild("RotatePart").RangeFollow.WorldPosition
		else
			position = tower.PrimaryPart.Position
		end
		local updatedCFrame = CFrame.new(position) * offset * CFrame.Angles(0, 0, math.rad(90))

		p.CFrame = updatedCFrame

		if isBehemoth then
			if MinP then MinP.CFrame = updatedCFrame * CFrame.new(0, 0.015, 0) end
			if MidP then MidP.CFrame = updatedCFrame * CFrame.new(0, 0.03, 0) end
			if LP then LP.CFrame = updatedCFrame * CFrame.new(0, 0.045, 0) end
		end
	end)

	rangeModel.Destroying:Connect(function() heartbeat:Disconnect() end)

	--------------------------------------------------------------------------------
	-- PLACEHOLDER MODE
	--------------------------------------------------------------------------------
	if placeholder then

		if info.Modifiers["Death Wish"].Value == true then 
			TweenService:Create(
				p,
				TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{Size = Vector3.new(0.2, ((range * info.Modifiers.DeathWishInfo.RangeReduction.Value) * 2), ((range * info.Modifiers.DeathWishInfo.RangeReduction.Value) * 2))}
			):Play()
		else
			TweenService:Create(
				p,
				TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{Size = Vector3.new(0.2, range * 2, range * 2)}
			):Play()
		end

		rangeModel.Parent = workspace.GameDependencies.Range

		--------------------------------------------------------------------------------
		-- NORMAL MODE
		--------------------------------------------------------------------------------
	else
		p.Size = Vector3.new(0.2, range * 2, range * 2)

		if isBehemoth then
			local minRange = range * 0.33
			local midRange = range * 0.66
			MinP.Size = Vector3.new(0.2, minRange * 2, minRange * 2)
			MidP.Size = Vector3.new(0.2, midRange * 2, midRange * 2)
			LP.Size = Vector3.new(0.2, range * 2, range * 2)
		end

		rangeModel.Parent = workspace.CurrentCamera
		selectedRangeCircle = rangeModel
	end
end

function CreateRangeCircleUnit(tower, placeholder)
	if not tower or not tower.PrimaryPart then
		warn("No Primary Part Found In Tower")
		return
	end

	local range = tower.Config.Range.Value
	local height = (tower.PrimaryPart.Size.Y / 0.75)
	local offset = CFrame.new(0, -height, 0)

	local rangeModel = ReplicatedStorage.Particle.Range:Clone()
	rangeModel.Name = "Range"

	local p = rangeModel.mainPart
	p.CanCollide = false
	p.Anchored = true
	p.Size = Vector3.new(0, 0, 0)
	p.Transparency = 0.99

	local heartbeat
	heartbeat = RunService.Heartbeat:Connect(function()
		if not tower or not tower.Parent or not tower.PrimaryPart then
			heartbeat:Disconnect()
			if currentUnitRangeConnection == heartbeat then
				currentUnitRangeConnection = nil
			end
			return
		end

		local position
		if tower.Config:FindFirstChild("Aviator") then
			position = tower.Plane.RotatePart.RangeFollow.WorldPosition
		else
			position = tower.PrimaryPart.Position
		end
		local updatedCFrame = CFrame.new(position) * offset * CFrame.Angles(0, 0, math.rad(90))
		p.CFrame = updatedCFrame
	end)

	if placeholder then
		TweenService:Create(
			p,
			TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{Size = Vector3.new(0.2, range * 2, range * 2)}
		):Play()
		rangeModel.Parent = workspace.GameDependencies.Range
	else
		p.Size = Vector3.new(0.2, range * 2, range * 2)
		rangeModel.Parent = workspace.Camera
	end

	-- track it so it can be cleaned up later
	currentUnitRangeCircle = rangeModel
	currentUnitRangeConnection = heartbeat
end


local function setBorderTransparency(transparency)
	local map = workspace.Map:FindFirstChildOfClass("Folder")
	if map and map:FindFirstChild("Borders") then
		for _, border in ipairs(map.Borders:GetChildren()) do
			border.Transparency = transparency
		end
	end

	for _, BorderTower in ipairs(workspace.Towers:GetChildren()) do
		for _, part in ipairs(BorderTower:GetChildren()) do
			if part.Name == "Border" then
				part.Transparency = transparency
			end
		end
	end
end

local function RemovePlaceholderTower(cancelPendingRequests)
	-- Normal cancel/removal invalidates any InvokeServer calls that are still
	-- waiting. AddPlaceholderTower passes false when it is merely switching
	-- from one valid preview to another.
	if cancelPendingRequests ~= false then
		placementRequestSerial += 1
		slotAnimator:Select(nil)
	end

	canPlace = false
	currentPreviewCFrame = nil

	-- Reset any cliff placement visibility even if towerToSpawn is already nil.
	local mapFolder = workspace:FindFirstChild("Map")
	if mapFolder then
		local map = mapFolder:FindFirstChildOfClass("Folder")
		if map and map:FindFirstChild("CliffPlacement") then
			for _, child in ipairs(map.CliffPlacement:GetChildren()) do
				if child:IsA("BasePart") and child.Transparency < 1 then
					child.Transparency = 1
				end
			end
		end
	end

	gui.DesktopControls.Visible = false

	local dependencies = workspace:FindFirstChild("GameDependencies")
	local rangeFolder = dependencies and dependencies:FindFirstChild("Range")
	if rangeFolder then
		rangeFolder:ClearAllChildren()
	end

	-- Destroy the tracked preview.
	if towerToSpawn then
		towerToSpawn:Destroy()
		towerToSpawn = nil
	end

	-- Safety net for any preview that somehow became untracked.
	-- New previews are tagged by AddPlaceholderTower below.
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model")
			and child:GetAttribute("PlacementPreview") == true
		then
			child:Destroy()
		end
	end

	rotation = 0
	setBorderTransparency(1)
end


local function AddPlaceholderTower(towerName, requestSerial, suppliedPlayerData, slotIndex)
	-- Direct callers are still supported.
	if requestSerial == nil then
		requestSerial = beginPlacementRequest()
	end

	-- This request already lost to a newer key/button press.
	if not placementRequestIsCurrent(requestSerial) then
		return
	end

	local playerData = suppliedPlayerData

	if not playerData then
		playerData = getDataFunction:InvokeServer()

		-- InvokeServer yields. A different tower may have been selected while
		-- we were waiting, so NEVER continue unless this is still newest.
		if not placementRequestIsCurrent(requestSerial) then
			return
		end
	end

	if not playerData then
		return
	end

	local appearanceTemplate, appearanceName =
		getTowerAppearance(towerName, playerData)

	if not appearanceTemplate then
		warn("No appearance found for tower:", towerName)
		return
	end

	-- Only the winning request is allowed to remove/replace the current preview.
	RemovePlaceholderTower(false)

	if not placementRequestIsCurrent(requestSerial) then
		return
	end

	towerToSpawn = appearanceTemplate:Clone()

	-- Lets RemovePlaceholderTower clean up an untracked preview defensively.
	towerToSpawn:SetAttribute("PlacementPreview", true)

	-- The visible model can be Default/Retro/Beach, but gameplay identity
	-- must always remain the real tower name.
	towerToSpawn:SetAttribute("TowerName", towerName)
	towerToSpawn:SetAttribute("AppearanceName", appearanceName or "Default")

	-- Placement is always the base tower, so animation lookup should use
	-- Animations/0 regardless of any stale Level value stored in the template.
	towerToSpawn:SetAttribute("TowerLevel", 0)

	local previewConfig = towerToSpawn:FindFirstChild("Config")
	local previewLevel =
		previewConfig
		and previewConfig:FindFirstChild("Level")

	if previewLevel and previewLevel:IsA("ValueBase") then
		previewLevel.Value = 0
	end

	-- IMPORTANT:
	-- A tower with no equipped skin uses Default exactly as authored.
	-- Nothing in placement is allowed to hide its visible model parts.
	preparePlaceholderAppearance(
		towerToSpawn,
		appearanceName or "Default"
	)

	towerToSpawn.Parent = workspace

	for _, obj in ipairs(towerToSpawn:GetDescendants()) do
		if obj:IsA("BasePart") then obj.CollisionGroup = "Tower" end
	end

	if not towerToSpawn.PrimaryPart then
		local hrp = towerToSpawn:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			towerToSpawn.PrimaryPart = hrp
		end
	end

	if not towerToSpawn.PrimaryPart then
		slotAnimator:Select(nil)
		warn("Tower appearance has no PrimaryPart:", towerName, appearanceName)
		towerToSpawn:Destroy()
		towerToSpawn = nil
		return
	end

	-- Put the preview under the current mouse immediately instead of
	-- visibly spawning at world origin and waiting for RenderStepped.
	local initialResult = PlacementRaycast(towerToSpawn)

	if initialResult and initialResult.Position then
		local initialY =
			initialResult.Position.Y
			+ towerToSpawn.HipHeight.Value
			+ (towerToSpawn.PrimaryPart.Size.Y / 0.7)

		local initialCFrame =
			CFrame.new(
				initialResult.Position.X,
				initialY,
				initialResult.Position.Z
			)
			* CFrame.Angles(0, math.rad(rotation), 0)

		towerToSpawn:SetPrimaryPartCFrame(initialCFrame)
		currentPreviewCFrame = initialCFrame
		PrevPos = initialCFrame
	else
		-- Fallback only; normal placement should hit the map immediately.
		towerToSpawn:SetPrimaryPartCFrame(CFrame.new(0, 5, 0))
	end

	playAnimation(towerToSpawn, "Idle")

	local head = towerToSpawn:FindFirstChild("Head", true)
	if head then
		local buffCheck = ReplicatedStorage.Particle.BuffCheck:Clone()
		buffCheck.Parent = head
		buffCheck.Adornee = head
		buffCheck.Firerate.Visible = false
		buffCheck.Range.Visible = false
		buffCheck.Damage.Visible = false
		buffCheck.AOEHeal.Visible = false
	end

	local h = Instance.new("Highlight")
	h.Name = "Highlight"
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.FillTransparency = 0.8
	h.OutlineColor = Color3.new(1, 1, 1)
	h.OutlineTransparency = 0
	h.Parent = towerToSpawn

	setBorderTransparency(0.3)
	CreateRangeCircle(towerToSpawn, true)

	if towerToSpawn.Config:FindFirstChild("Aviator") then
		local ringPath = towerToSpawn:FindFirstChild("RingPath")
		if ringPath then
			ringPath.Transparency = 0.8
		end
	end

	gui.DesktopControls.Visible = true
	slotAnimator:Select(slotIndex)
end

local function requestPlacementForTower(towerName, requestSerial, playerData, slotIndex)
	if not towerName then
		return
	end

	requestSerial = requestSerial or beginPlacementRequest()

	local allowedToSpawn =
		requestTowerFunction:InvokeServer(towerName)

	-- requestTowerFunction also yields.
	if not placementRequestIsCurrent(requestSerial) then
		return
	end

	if allowedToSpawn then
		AddPlaceholderTower(
			towerName,
			requestSerial,
			playerData,
			slotIndex
		)
	end
end

local function requestPlacementSlot(slotIndex)
	-- IMPORTANT: serial is created BEFORE the first InvokeServer.
	-- Therefore the LAST key physically pressed always wins.
	local requestSerial = beginPlacementRequest()

	local playerData = getDataFunction:InvokeServer()

	if not placementRequestIsCurrent(requestSerial) then
		return
	end

	if not playerData
		or typeof(playerData.SelectedTowers) ~= "table"
	then
		return
	end

	local towerName = playerData.SelectedTowers[slotIndex]
	if not towerName then
		return
	end

	gui.Sounds.Click:Play()

	requestPlacementForTower(
		towerName,
		requestSerial,
		playerData,
		slotIndex
	)
end

function TargetAirStrike()
	local Particle = ReplicatedStorage.Particle.AirstrikeAim:Clone()
	Particle.Parent = workspace.Visual

end

local function ColorPlaceholderTower(color)
	towerToSpawn.Highlight.OutlineColor = color
end
local damageStatConnection:RBXScriptConnection 
local damageConnection:RBXScriptConnection
local SpentConnection:RBXScriptConnection
local AmmoConnection:RBXScriptConnection
local AmmunitionConnection:RBXScriptConnection
local Beamer:RBXScriptConnection
local Rebuild:RBXScriptConnection
local Overheat:RBXScriptConnection
local ShieldRegen:RBXScriptConnection
local SpawnerConnection1:RBXScriptConnection
local SoulsConnection:RBXScriptConnection
-- Explicitly tracked so changing selection never leaves level listeners behind.
local levelValueConnection:RBXScriptConnection
local levelAttributeConnection:RBXScriptConnection

-- ============================================================
-- OWNER BOX COLOR
-- ============================================================
-- Blue while another upgrade exists; purple when fully maxed.
local OWNER_BOX_NORMAL_COLOR = BrickColor.new(0.431373, 0.6, 0.792157)
local OWNER_BOX_MAX_COLOR = BrickColor.new(0.654902, 0.368627, 0.607843)

local function updateOwnerBoxColor(towerModel)
	if not towerModel or not towerModel.Parent then
		return
	end

	local config = towerModel:FindFirstChild("Config")
	local owner = config and config:FindFirstChild("Owner")

	if not owner or owner.Value ~= Players.LocalPlayer.Name then
		return
	end

	local ownerBox =
		towerModel:FindFirstChild("Box")
		or towerModel:FindFirstChild("HeliBox")

	if not ownerBox then
		return
	end

	local coloredPart = ownerBox:FindFirstChild("Box")

	if not coloredPart or not coloredPart:IsA("BasePart") then
		return
	end

	coloredPart.BrickColor =
		hasNextUpgrade(towerModel)
		and OWNER_BOX_NORMAL_COLOR
		or OWNER_BOX_MAX_COLOR
end

local function updateUpgradeLevelDisplay(towerModel)
	if not towerModel then
		return
	end

	local towerName = getCanonicalTowerName(towerModel)
	local currentLevel = math.max(0, math.floor(getTowerLevel(towerModel)))
	local maxLevel = getMaxUpgradeLevel(towerName)

	-- If this tower has not been migrated to TowerData yet, fall back to MaxLevel.
	if maxLevel <= 0 then
		local legacyMax = towerModel:FindFirstChild("MaxLevel")
		if legacyMax and legacyMax:IsA("ValueBase") then
			maxLevel = legacyMax.Value
		end
	end

	-- Hide every level-bar layout first so an old selection cannot bleed through.
	local barLayouts = {
		upgradeGui.Upgrade:FindFirstChild("Level2"),
		upgradeGui.Upgrade:FindFirstChild("Level4"),
		upgradeGui.Upgrade:FindFirstChild("Level5"),
		upgradeGui.Upgrade:FindFirstChild("Level6"),
	}

	for _, layout in ipairs(barLayouts) do
		if layout then
			layout.Visible = false
		end
	end

	-- Preserve your existing GUI mapping.
	-- A one-upgrade tower uses the Level2 layout in the current UI.
	local bars

	if maxLevel == 1 then
		bars = upgradeGui.Upgrade:FindFirstChild("Level2")
	else
		bars = upgradeGui.Upgrade:FindFirstChild("Level" .. tostring(maxLevel))
	end

	if bars then
		bars.Visible = true

		-- Do not assume the bars are contiguous or hard-code a loop count.
		-- We read the number out of "Level1", "Level2", etc.
		for _, levelBar in ipairs(bars:GetChildren()) do
			local levelNumber =
				tonumber(string.match(levelBar.Name, "^Level(%d+)$"))

			if levelNumber then
				local enabled =
					levelBar:FindFirstChild("Enable")

				if enabled then
					enabled.Visible =
						levelNumber <= currentLevel
				end
			end
		end
	end

	-- Optional text support: if your GUI has either of these labels,
	-- it will automatically show the current module-backed level.
	local levelText =
		upgradeGui.Upgrade:FindFirstChild("CurrentLevel", true)
		or upgradeGui.Upgrade:FindFirstChild("LevelText", true)

	if levelText and levelText:IsA("TextLabel") then
		if maxLevel > 0 then
			levelText.Text =
				"Level "
				.. tostring(currentLevel)
				.. "/"
				.. tostring(maxLevel)
		else
			levelText.Text =
				"Level " .. tostring(currentLevel)
		end
	end
end

-- Reaper unlock BoolValue names. These determine BUTTON VISIBILITY only.
-- In particular SluaghHoard must continue checking Reaper.Slaugh.
local REAPER_REQUIREMENT_NAMES = {
	SkeletonHoard = "Skeleton",
	GiantSkeletonHoard = "Giant Skeleton",
	SluaghHoard = "Slaugh",
	ForgottenKnight = "ForgottenKnight",
	HallowGaurd = "HallowGaurd",
}

-- SoulRequirements may use a different child name from the visibility BoolValue.
-- ONLY the Sluagh soul cost should read Reaper.SoulRequirements.Sluagh.
local REAPER_SOUL_COST_NAME_OVERRIDES = {
	SluaghHoard = "Sluagh",
}

local function refreshReaperRequirementLabels(model)
	local config = model and model:FindFirstChild("Config")
	local reaper = config and config:FindFirstChild("Reaper")
	if not reaper then return end

	local requirements = reaper:FindFirstChild("SoulRequirements")
	local abilities = upgradeGui.TowerStats.Abilities

	for buttonName, unitName in pairs(REAPER_REQUIREMENT_NAMES) do
		local button = abilities:FindFirstChild(buttonName)
		local label = button and (button:FindFirstChild("Textlabel") or button:FindFirstChild("TextLabel"))
		if label and label:IsA("TextLabel") then
			local costName = REAPER_SOUL_COST_NAME_OVERRIDES[buttonName] or unitName
			local requirement = requirements and requirements:FindFirstChild(costName)
			local amount = requirement and (requirement:IsA("IntValue") or requirement:IsA("NumberValue"))
				and tostring(requirement.Value) or "?"
			local text = amount .. " Souls / 1"
			if label.Text ~= text then
				label.Text = text
			end
		end
	end
end

local currentSelectionId = 0
local function refreshAdvancedStats(tower)
	advancedStatsUI:ShowLevel(getTowerDefinition(getCanonicalTowerName(tower)), getTowerLevel(tower), tower)
end
local function toggleTowerInfo()
	if selectedTower then refreshAdvancedStats(selectedTower) else advancedStatsUI:Clear() end
	clearSelectedRange()
	interaction:Update(hoveredModel, selectedTower)
	gui.OtherGameStats.MaxTowersBanner.TextLabel.Text = tostring(placedTowers.Value) .. "/" .. tostring(getPlacement())
	currentSelectionId += 1
	local thisSelection = currentSelectionId

	if damageConnection and damageConnection.Connected then
		damageConnection:Disconnect()
	end
	if damageStatConnection and damageStatConnection.Connected then
		damageStatConnection:Disconnect()
	end
	if SpentConnection and SpentConnection.Connected then
		SpentConnection:Disconnect()
	end
	if Rebuild and Rebuild.Connected then
		Rebuild:Disconnect()
	end
	if Overheat and Overheat.Connected then
		Overheat:Disconnect()
	end
	if ShieldRegen and ShieldRegen.Connected then
		ShieldRegen:Disconnect()
	end
	if SoulsConnection and SoulsConnection.Connected then
		SoulsConnection:Disconnect()
	end
	if AmmoConnection and AmmoConnection.Connected then
		AmmoConnection:Disconnect()
	end
	if AmmunitionConnection and AmmunitionConnection.Connected then
		AmmunitionConnection:Disconnect()
	end
	if SpawnerConnection1 and SpawnerConnection1.Connected then
		SpawnerConnection1:Disconnect()
	end
	if levelValueConnection and levelValueConnection.Connected then
		levelValueConnection:Disconnect()
	end
	levelValueConnection = nil

	if levelAttributeConnection and levelAttributeConnection.Connected then
		levelAttributeConnection:Disconnect()
	end
	levelAttributeConnection = nil

	if Beamer and Beamer.Connected then
		Beamer:Disconnect()
	end
	if selectedTower then
		CreateRangeCircle(selectedTower)
		upgradeGui:TweenPosition(
			UDim2.new(0.006, 0,0.527, 0),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Back,
			0.5,
			true
		)


		-- Always derive the displayed level from the live in-place tower.
		-- TowerData defines the max level; TowerLevel/Config.Level defines current.
		updateUpgradeLevelDisplay(selectedTower)
		updateOwnerBoxColor(selectedTower)

		local config = selectedTower:FindFirstChild("Config")
		local configSnapshot = config

		-- Keep level progress synced even if the level changes while this tower
		-- stays selected. Both representations are supported during migration.
		local selectedForLevelUI = selectedTower
		local levelValue = config and config:FindFirstChild("Level")

		if levelValue and levelValue:IsA("ValueBase") then
			levelValueConnection =
				levelValue:GetPropertyChangedSignal("Value"):Connect(function()
					if selectedTower == selectedForLevelUI
						and selectedForLevelUI.Parent
					then
						updateUpgradeLevelDisplay(selectedForLevelUI)
						updateOwnerBoxColor(selectedForLevelUI)
						refreshAdvancedStats(selectedForLevelUI)
					end
				end)
		end

		levelAttributeConnection =
			selectedForLevelUI
			:GetAttributeChangedSignal("TowerLevel")
			:Connect(function()
				if selectedTower == selectedForLevelUI
					and selectedForLevelUI.Parent
				then
					updateUpgradeLevelDisplay(selectedForLevelUI)
					updateOwnerBoxColor(selectedForLevelUI)
						refreshAdvancedStats(selectedForLevelUI)
				end
			end)

		upgradeGui.TowerStats.TowerStatistics.Damage.Value.Text = config.Damage.Value
		local DPS_PER_SECOND = 1 / config.Cooldown.Value
		local TOTAL_DPS = DPS_PER_SECOND * config.Damage.Value

		if config:FindFirstChild("Burst") and config.Burst.Value == true then
			local TOTAL_DPS_BURST = math.round((config.Damage.Value * config.MaxBurst.Value) / (config.Delay.Value + ((config.MaxBurst.Value - 1) * config.Cooldown.Value)))
			upgradeGui.TowerStats.TowerStatistics.DPS.Value.Text = math.round(TOTAL_DPS_BURST) .. " DPS"
		elseif config:FindFirstChild("DPS") then
			upgradeGui.TowerStats.TowerStatistics.DPS.Value.Text = math.round(config.DPS.Value) .. " DPS"
		elseif config:FindFirstChild("RocketDPS") then
			upgradeGui.TowerStats.TowerStatistics.DPS.Value.Text = math.round(TOTAL_DPS + config.RocketDPS.Value) .. " DPS"
		elseif config:FindFirstChild("PelletCount") then
			local TOTAL_DPS_Shotgunner = (config.Damage.Value * config.PelletCount.Value) / config.Cooldown.Value

			TOTAL_DPS_Shotgunner = math.round(TOTAL_DPS_Shotgunner * 100) / 100

			upgradeGui.TowerStats.TowerStatistics.DPS.Value.Text = TOTAL_DPS_Shotgunner .. " DPS"
		else
			upgradeGui.TowerStats.TowerStatistics.DPS.Value.Text = math.round(TOTAL_DPS) .. " DPS"
		end

		if config:FindFirstChild("ExtraStat1") then
			upgradeGui.Stats.Main.Extra1.Visible = true
			upgradeGui.Stats.Main.Extra1.Value.Text = config.ExtraStat1.Value
		else
			upgradeGui.Stats.Main.Extra1.Visible = false
		end
		if config:FindFirstChild("ExtraStat2") then
			upgradeGui.Stats.Main.Extra2.Visible = true
			upgradeGui.Stats.Main.Extra2.Value.Text = config.ExtraStat2.Value
		else
			upgradeGui.Stats.Main.Extra2.Visible = false
		end
		upgradeGui.TowerStats.TowerStatistics.Range.Value.Text = config.Range.Value
		upgradeGui.TowerStats.TowerStatistics.Cooldown.Value.Text = config.Cooldown.Value
		local selectedTowerName = getCanonicalTowerName(selectedTower)
		local selectedTowerLevel = getTowerLevel(selectedTower)

		upgradeGui.TowerName.Text =
			""
			.. tostring(selectedTower.Config.Owner.Value)
			.. "'s "
			..selectedTowerName

		if config:FindFirstChild("Spawner") and not config:FindFirstChild("DPS") then
			upgradeGui.TowerStats.UnitQueue.Visible = true
			upgradeGui.TowerStats.UnitQueue.UnitName.Text = "" .. config.Unit.Value
			upgradeGui.TowerStats.UnitQueue.UnitIcon.UnitIcon.Image = "rbxassetid://" .. config.UnitIcon.Value
			upgradeGui.TowerStats.TowerStatistics.Damage.Visible = false
			upgradeGui.TowerStats.TowerStatistics.Cooldown.Visible = false
			upgradeGui.TowerStats.TowerStatistics.Range.Visible = false
			upgradeGui.TowerStats.TowerStatistics.DPS.Visible = false
		elseif config:FindFirstChild("Spawner") and config:FindFirstChild("DPS") then
			upgradeGui.TowerStats.UnitQueue.Visible = true
			upgradeGui.TowerStats.UnitQueue.UnitName.Text = "" .. config.Unit.Value
			upgradeGui.TowerStats.UnitQueue.UnitIcon.UnitIcon.Image = "rbxassetid://" .. config.UnitIcon.Value
			upgradeGui.TowerStats.TowerStatistics.Damage.Visible = false
			upgradeGui.TowerStats.TowerStatistics.Cooldown.Visible = false
			upgradeGui.TowerStats.TowerStatistics.Range.Visible = false
			upgradeGui.TowerStats.TowerStatistics.DPS.Visible = true
		elseif config:FindFirstChild("Farm") then
			upgradeGui.TowerStats.UnitQueue.Visible = false
			upgradeGui.TowerStats.TowerStatistics.Damage.Visible = false
			upgradeGui.TowerStats.TowerStatistics.Cooldown.Visible = false
			upgradeGui.TowerStats.TowerStatistics.Range.Visible = false
			upgradeGui.TowerStats.TowerStatistics.DPS.Visible = false
		elseif config:FindFirstChild("Commander") then
			upgradeGui.TowerStats.UnitQueue.Visible = false
			upgradeGui.TowerStats.TowerStatistics.Damage.Visible = false
			upgradeGui.TowerStats.TowerStatistics.Cooldown.Visible = false
			upgradeGui.TowerStats.TowerStatistics.Range.Visible = true
			upgradeGui.TowerStats.TowerStatistics.DPS.Visible = false
		else
			upgradeGui.TowerStats.UnitQueue.Visible = false
			upgradeGui.TowerStats.TowerStatistics.Damage.Visible = true
			upgradeGui.TowerStats.TowerStatistics.Cooldown.Visible = true
			upgradeGui.TowerStats.TowerStatistics.Range.Visible = true
			upgradeGui.TowerStats.TowerStatistics.DPS.Visible = true
		end

		local TweenService = game:GetService("TweenService")

		local rangeLabel =  upgradeGui.TowerStats.TowerStatistics.Range.Value

		config.Range.Changed:Connect(function()
			rangeLabel.Text = tostring(config.Range.Value)
		end)

		local cooldownLabel =  upgradeGui.TowerStats.TowerStatistics.Cooldown.Value

		-- Ensure UIScale exists
		local uiScale = cooldownLabel:FindFirstChildOfClass("UIScale")
		if not uiScale then
			uiScale = Instance.new("UIScale")
			uiScale.Parent = cooldownLabel
			uiScale.Scale = 1
		end

		config.Cooldown.Changed:Connect(function()
			cooldownLabel.Text = tostring(config.Cooldown.Value)
		end)


		local reaperCheck = config:FindFirstChild("Reaper")
		local hasReaperButtons = false
		if reaperCheck then
			for _, flagName in ipairs({"Skeleton", "Giant Skeleton", "Slaugh", "ForgottenKnight", "HallowGaurd"}) do
				local flag = reaperCheck:FindFirstChild(flagName)
				if flag and flag:IsA("BoolValue") and flag.Value then
					hasReaperButtons = true
					break
				end
			end
		end

		upgradeGui.TowerStats.Abilities.Visible =
			(config:FindFirstChild("Ability") and config.Ability.Value == true)
			or hasReaperButtons

		local abilitiesFolder = upgradeGui.TowerStats.Abilities

		local abilities = {
			"CTA",
			"Gunslinger",
			"Pistoleer",
			"Pursuit",
			"Follow",
			"SergeantRage",
			"Cavalry",
			"SkeletonHoard",
			"SluaghHoard",
			"HallowGaurd",
			"GiantSkeletonHoard",
			"ForgottenKnight",
		}

		local function applyState()
			local isOwner = config.Owner.Value == Players.LocalPlayer.Name
			local isDisabled = config:FindFirstChild("DISABLED", true) ~= nil

			local state

			if isDisabled then
				state = {
					active = false,
					interactable = false,
					lockedVisible = false,
					disabledVisible = true,
				}
			else
				if isOwner then
					state = {
						active = true,
						interactable = true,
						lockedVisible = false,
						disabledVisible = false,
					}
				else
					state = {
						active = false,
						interactable = false,
						lockedVisible = true,
						disabledVisible = false,
					}
				end
			end

			for _, name in ipairs(abilities) do
				local ability = abilitiesFolder[name]

				ability.Active = state.active
				ability.Interactable = state.interactable

				if ability:FindFirstChild("Locked") then
					ability.Locked.Visible = state.lockedVisible
				end

				if ability:FindFirstChild("Disabled") then
					ability.Disabled.Visible = state.disabledVisible
				end
			end
		end

		config.ChildAdded:Connect(function(child)
			if child.Name == "DISABLED" then
				applyState()
			end
		end)

		config.ChildRemoved:Connect(function(child)
			if child.Name == "DISABLED" then
				applyState()
			end
		end)

		applyState()

		if selectedTower.Config:FindFirstChild("MissileSilo") then
			local Status = selectedTower.Config.Settings.Status

			if Status:FindFirstChild("Ready") and Status.Ready.Value == true then
				--logic here later
			end
		end

		if selectedTower.Config:FindFirstChild("CTA") and selectedTower.Config.CTA.Value == true then
			upgradeGui.TowerStats.Abilities.CTA.Visible = true
		else
			upgradeGui.TowerStats.Abilities.CTA.Visible = false
		end

		-- Reaper abilities are optional; ordinary towers don't have Config.Reaper.
		-- These names deliberately match the GUI and existing Config bool names.
		local reaperFolder = config:FindFirstChild("Reaper")
		for buttonName, flagName in pairs(REAPER_REQUIREMENT_NAMES) do
			local flag = reaperFolder and reaperFolder:FindFirstChild(flagName)
			abilitiesFolder[buttonName].Visible = flag ~= nil
				and flag:IsA("BoolValue")
				and flag.Value == true
		end

		-- Show the cost per *one* summon as soon as a Reaper is selected.
		refreshReaperRequirementLabels(selectedTower)

		if selectedTower.Config:FindFirstChild("CavlryAbility") then
			upgradeGui.TowerStats.Abilities.Cavalry.Visible = true
		else
			upgradeGui.TowerStats.Abilities.Cavalry.Visible = false
		end

		if selectedTower.Config:FindFirstChild("SergeantRage") and selectedTower.Config.SergeantRage.Value == true then
			upgradeGui.TowerStats.Abilities.SergeantRage.Visible = true
		else
			upgradeGui.TowerStats.Abilities.SergeantRage.Visible = false
		end

		if selectedTower.Config:FindFirstChild("Gunslinger") then
			upgradeGui.TowerStats.Abilities.Gunslinger.Visible = true
		else
			upgradeGui.TowerStats.Abilities.Gunslinger.Visible = false
		end

		if selectedTower.Config:FindFirstChild("Pistoleer") then
			upgradeGui.TowerStats.Abilities.Pistoleer.Visible = true
		else
			upgradeGui.TowerStats.Abilities.Pistoleer.Visible = false
		end

		if selectedTower.Config:FindFirstChild("PossibleModes") then
			upgradeGui.TowerStats.Abilities.Follow.Visible = true
		else
			upgradeGui.TowerStats.Abilities.Follow.Visible = false
		end

		if selectedTower.Config:FindFirstChild("PossibleModes") and selectedTower.Config.PossibleModes:FindFirstChild("Pursuit") and selectedTower.Config.PossibleModes.Pursuit.Value == true then
			upgradeGui.TowerStats.Abilities.Pursuit.Visible = true
		else
			upgradeGui.TowerStats.Abilities.Pursuit.Visible = false
		end

		if selectedTower.Config:FindFirstChild("Cash") then
			upgradeGui.TowerStats.TowerStatistics.Cash.Visible = true
			upgradeGui.TowerStats.TowerStatistics.Cash.Value.Text = "$" .. selectedTower.Config.Cash.Value
		else
			upgradeGui.TowerStats.TowerStatistics.Cash.Visible = false
		end

		if selectedTower.Config:FindFirstChild("Kills") then
			upgradeGui.ChargeBar.Visible = true
			upgradeGui.RebuildBar.Visible = false
			upgradeGui.SoulBar.Visible = false
			upgradeGui.ChargeBar.Count.Text = "" .. config.Kills.Value .. "/" .. config.KillCount.Value
			local percent = config.Kills.Value / config.KillCount.Value
			upgradeGui.ChargeBar.Charge.Size = UDim2.new(percent,0,1,0)
		elseif selectedTower.Config:FindFirstChild("MaxAmmo") then
			upgradeGui.SoulBar.Visible = false
			upgradeGui.ChargeBar.Visible = true
			upgradeGui.RebuildBar.Visible = false
			upgradeGui.ChargeBar.Count.Text = "" .. config.CurrentAmmo.Value .. "/" .. config.MaxAmmo.Value
			local percent = config.CurrentAmmo.Value / config.MaxAmmo.Value
			upgradeGui.ChargeBar.Charge.Size = UDim2.new(percent,0,1,0)
		elseif selectedTower.Config:FindFirstChild("Scrambler") then
			upgradeGui.SoulBar.Visible = false
			upgradeGui.RebuildBar.Visible = true
			upgradeGui.RebuildBar.Count.Text = "" .. math.round(config.TimeUntilRebuild.Value) .. " Sec / " .. config.RebuildTime.Value .. " Sec"
			local percent = config.TimeUntilRebuild.Value / config.RebuildTime.Value
			upgradeGui.RebuildBar.Charge.Size = UDim2.new(percent,0,1,0)
			upgradeGui.ChargeBar.Visible = false
		elseif selectedTower.Config:FindFirstChild("StunShields") and selectedTower.Config.StunShields.Enabled.Value == true then
			upgradeGui.SoulBar.Visible = false
			upgradeGui.ShieldBar.Visible = true
			upgradeGui.RebuildBar.Visible = false
			upgradeGui.ShieldBar.Count.Text = "Shield Regen: " .. config.StunShields.Countdown.Value .. " Seconds"
			local percent = config.StunShields.Countdown.Value / config.StunShields.ShieldRegenTime.Value
			upgradeGui.ShieldBar.Charge.Size = UDim2.new(percent,0,1,0)
			upgradeGui.ChargeBar.Visible = false
		elseif selectedTower.Config:FindFirstChild("Reaper") then
			upgradeGui.SoulBar.Visible = true
			upgradeGui.ShieldBar.Visible = false
			upgradeGui.RebuildBar.Visible = false
			upgradeGui.SoulBar.Count.Text = "" .. math.round(config.Reaper.Souls.Value) .. " / " .. config.Reaper.MaxSouls.Value .. ""
			local percent = config.Reaper.Souls.Value / config.Reaper.MaxSouls.Value
			upgradeGui.SoulBar.Charge.Size = UDim2.new(percent,0,1,0)
			upgradeGui.ChargeBar.Visible = false
		else
			upgradeGui.ChargeBar.Visible = false
			upgradeGui.RebuildBar.Visible = false
			upgradeGui.ShieldBar.Visible = false
			upgradeGui.SoulBar.Visible = false
		end

		upgradeGui.ExtraButtons.ExtraStats.TotalDamage.Count.Text = "" .. Comma(config.TotalDamage.Value)
		upgradeGui.ExtraButtons.ExtraStats.TotalSpent.Count.Text = "$" .. Comma(config.TotalSpent.Value)

		upgradeGui.TowerStats.TowerStatistics.Hidden.Visible = config.HiddenDetection.Value
		upgradeGui.TowerStats.TowerStatistics.Flying.Visible = config.FlyingDetection.Value
		if config:FindFirstChild("LeadDetection") then
			upgradeGui.TowerStats.TowerStatistics.Lead.Visible = config.LeadDetection.Value
		else
			upgradeGui.TowerStats.TowerStatistics.Lead.Visible = false
		end

		-- Update Tower Icon in Viewport
		-- Update Tower Icon
		local icon = upgradeGui.Upgrade.ImageArea.ImageLabel
		local towerName = getCanonicalTowerName(selectedTower)
		local currentLevel = config.Level.Value

		local towerIcons = UpgradeIcons[towerName]

		if towerIcons then
			local levelIcon = towerIcons[currentLevel]

			if levelIcon and levelIcon.ImageID then
				icon.Image = "rbxassetid://" .. tostring(levelIcon.ImageID)
			else
				warn("No icon found for " .. towerName .. " level " .. tostring(currentLevel))
				icon.Image = ""
			end
		else
			warn("No UpgradeIcons entry found for tower: " .. towerName)
			icon.Image = ""
		end

		local towerName = getCanonicalTowerName(selectedTower)
		local currentLevel = getTowerLevel(selectedTower)
		local nextLevel = currentLevel + 1
		local nextUpgrade = getUpgradeDefinition(towerName, nextLevel)
		local currentStats = getStatsForLevel(towerName, currentLevel)
		local nextStats = nextUpgrade and getStatsForLevel(towerName, nextLevel) or nil

		damageConnection = config.TotalDamage.Changed:Connect(function()
			upgradeGui.ExtraButtons.ExtraStats.TotalDamage.Count.Text =
				"" .. Comma(config.TotalDamage.Value)
		end)

		damageStatConnection = config.Damage.Changed:Connect(function()
			if thisSelection ~= currentSelectionId then return end
			if not selectedTower or not selectedTower.Parent then return end

			local cfg = selectedTower.Config
			local dmg = cfg.Damage.Value
			local cd = cfg.Cooldown.Value

			upgradeGui.TowerStats.TowerStatistics.Damage.Value.Text = Comma(dmg)

			local dpsPerSecond = 1 / cd
			local dps

			if cfg:FindFirstChild("Burst") and cfg.Burst.Value == true then
				dps = (dpsPerSecond * dmg) / cfg.Delay.Value
			elseif cfg:FindFirstChild("DPS") then
				dps = cfg.DPS.Value
			elseif cfg:FindFirstChild("PelletCount") then
				dps = (dmg * cfg.PelletCount.Value) / cd
			else
				dps = dpsPerSecond * dmg
			end

			upgradeGui.TowerStats.TowerStatistics.DPS.Value.Text =
				math.round(dps) .. " DPS"
		end)

		SpentConnection = config.TotalSpent.Changed:Connect(function()
			upgradeGui.ExtraButtons.ExtraStats.TotalSpent.Count.Text =
				"$" .. Comma(config.TotalSpent.Value)
		end)

		if config:FindFirstChild("Kills") then
			AmmoConnection = config.Kills.Changed:Connect(function()
				upgradeGui.ChargeBar.Count.Text =
					"" .. config.Kills.Value .. "/" .. config.KillCount.Value

				local percent = config.Kills.Value / config.KillCount.Value
				upgradeGui.ChargeBar.Charge.Size = UDim2.new(percent,0,1,0)
			end)
		end

		if config:FindFirstChild("MaxAmmo") then
			AmmunitionConnection = config.CurrentAmmo.Changed:Connect(function()
				upgradeGui.ChargeBar.Count.Text =
					"" .. config.CurrentAmmo.Value .. "/" .. config.MaxAmmo.Value

				local percent = config.CurrentAmmo.Value / config.MaxAmmo.Value
				upgradeGui.ChargeBar.Charge.Size = UDim2.new(percent,0,1,0)
			end)
		end

		if config:FindFirstChild("Scrambler") then
			AmmunitionConnection = config.TimeUntilRebuild.Changed:Connect(function()
				upgradeGui.RebuildBar.Count.Text =
					"" .. math.round(config.TimeUntilRebuild.Value)
					.. " Sec / "
					.. config.RebuildTime.Value
					.. " Sec"

				local percent = config.TimeUntilRebuild.Value / config.RebuildTime.Value
				upgradeGui.RebuildBar.Charge.Size = UDim2.new(percent,0,1,0)
			end)
		end

		if config:FindFirstChild("Spawner") and config:FindFirstChild("SpawnTimer") then
			SpawnerConnection1 = config.SpawnTimer.Changed:Connect(function()
				upgradeGui.TowerStats.UnitQueue.Count.Text =
					"" .. math.round(config.SpawnTimer.Value) .. "s"

				local percent = config.SpawnTimer.Value / config.SpawnCooldown.Value
				upgradeGui.TowerStats.UnitQueue.CooldownBar.Bar.Size =
					UDim2.new(1,0,percent,0)
			end)
		end

		if config:FindFirstChild("StunShields") then
			ShieldRegen = config.StunShields.Countdown.Changed:Connect(function()
				upgradeGui.ShieldBar.Count.Text =
					"Shield Regen: "
					.. config.StunShields.Countdown.Value
					.. " Seconds"

				local percent =
					config.StunShields.Countdown.Value
					/ config.StunShields.ShieldRegenTime.Value

				upgradeGui.ShieldBar.Charge.Size = UDim2.new(percent,0,1,0)
			end)
		end

		if config:FindFirstChild("Reaper") then
			SoulsConnection = config.Reaper.Souls.Changed:Connect(function()
				upgradeGui.SoulBar.Count.Text =
					"" .. math.round(config.Reaper.Souls.Value)
					.. " / "
					.. config.Reaper.MaxSouls.Value
					.. ""

				local percent =
					config.Reaper.Souls.Value
					/ config.Reaper.MaxSouls.Value

				upgradeGui.SoulBar.Charge.Size = UDim2.new(percent,0,1,0)
			end)
		end

		if config:FindFirstChild("MaxOverCharge") then
			Beamer = config.OverCharge.Changed:Connect(function()
				upgradeGui.ChargeBar.Count.Text =
					"" .. config.OverCharge.Value .. "/" .. config.MaxOverCharge.Value

				local percent = config.OverCharge.Value / config.MaxOverCharge.Value
				upgradeGui.ChargeBar.Charge.Size = UDim2.new(percent,0,1,0)
			end)
		end

		upgradeGui.ExtraButtons.Target.TextArea.Text =
			"[Z] " .. config.TargetMode.Value

		local statsMain = upgradeGui.Stats.Main

		statsMain.Damage.Visible = false
		statsMain.Range.Visible = false
		statsMain.Cooldown.Visible = false
		statsMain.Eco.Visible = false
		statsMain.HiddenGain.Visible = false
		statsMain.FlyingGain.Visible = false
		statsMain.LeadGain.Visible = false

		local function different(a, b)
			return a ~= nil and b ~= nil and a ~= b
		end

		if nextStats then
			if different(currentStats.Damage, nextStats.Damage) then
				statsMain.Damage.Visible = true
				statsMain.Damage.Value.Text =
					tostring(currentStats.Damage) .. " → " .. tostring(nextStats.Damage)
			end

			if different(currentStats.Range, nextStats.Range) then
				statsMain.Range.Visible = true
				statsMain.Range.Value.Text =
					tostring(currentStats.Range) .. " → " .. tostring(nextStats.Range)
			end

			if different(currentStats.Firerate, nextStats.Firerate) then
				statsMain.Cooldown.Visible = true
				statsMain.Cooldown.Value.Text =
					tostring(currentStats.Firerate) .. " → " .. tostring(nextStats.Firerate)
			end

			if currentStats.HiddenDetection ~= nextStats.HiddenDetection
				and nextStats.HiddenDetection == true
			then
				statsMain.HiddenGain.Visible = true
			end

			if currentStats.FlyingDetection ~= nextStats.FlyingDetection
				and nextStats.FlyingDetection == true
			then
				statsMain.FlyingGain.Visible = true
			end

			if currentStats.LeadDetection ~= nextStats.LeadDetection
				and nextStats.LeadDetection == true
			then
				statsMain.LeadGain.Visible = true
			end

			local currentEco =
				currentStats.CashReward
				or currentStats.Cash

			local nextEco =
				nextStats.CashReward
				or nextStats.Cash

			if different(currentEco, nextEco) then
				statsMain.Eco.Visible = true
				statsMain.Eco.Value.Text =
					"$" .. tostring(currentEco or 0)
					.. " → $"
					.. tostring(nextEco)
			end
		end

		local isOwner =
			config.Owner.Value == Players.LocalPlayer.Name

		if isOwner then
			upgradeGui.ExtraButtons.Target.Interactable = true
			upgradeGui.ExtraButtons.Sell.Interactable = true
			upgradeGui.NonOwner.Visible = false

			if nextUpgrade then
				upgradeGui.Upgrade.Visible = true
				upgradeGui.Upgrade.Interactable = true

				upgradeGui.Upgrade.UpgradeName.Text =
					getUpgradeNameForLevel(
						towerName,
						nextLevel
					)

				local upgradePrice = nextUpgrade.Cost or 0

				if info.Modifiers["Death Wish"].Value == true then
					upgradePrice = math.round(
						upgradePrice
							* info.Modifiers.DeathWishInfo.Inflation.Value
					)
				end

				upgradeGui.Upgrade.UpgradePrice.Text =
					"$" .. Comma(upgradePrice)
			else
				upgradeGui.Upgrade.Visible = true
				upgradeGui.Upgrade.Interactable = false
				upgradeGui.Upgrade.UpgradeName.Text = "Maxed"
				upgradeGui.Upgrade.UpgradePrice.Text = ""

				if config:FindFirstChild("ExtraStat1") then
					statsMain.Extra1.Visible = true
					statsMain.Extra1.Value.Text =
						tostring(config.ExtraStat1.Value)
				else
					statsMain.Extra1.Visible = true
					statsMain.Extra1.Value.Text =
						"No Further Upgrade Stats!"
				end

				if config:FindFirstChild("ExtraStat2") then
					statsMain.Extra2.Visible = true
					statsMain.Extra2.Value.Text =
						tostring(config.ExtraStat2.Value)
				else
					statsMain.Extra2.Visible = false
				end
			end

			local sellValue = getSellValue(selectedTower)

			if info.Modifiers["Death Wish"].Value == true then
				sellValue = math.round(
					sellValue
						* info.Modifiers.DeathWishInfo.Inflation.Value
				)
			end

			upgradeGui.ExtraButtons.Sell.TextArea.Text =
				"[X] Sell: $" .. Comma(sellValue)
		else
			upgradeGui.ExtraButtons.Target.Interactable = false
			upgradeGui.Upgrade.Interactable = false
			upgradeGui.ExtraButtons.Sell.Interactable = false
			upgradeGui.NonOwner.Visible = true

			if nextUpgrade then
				upgradeGui.Upgrade.UpgradeName.Text =
					getUpgradeNameForLevel(
						towerName,
						nextLevel
					)

				local upgradePrice = nextUpgrade.Cost or 0

				if info.Modifiers["Death Wish"].Value == true then
					upgradePrice = math.round(
						upgradePrice
							* info.Modifiers.DeathWishInfo.Inflation.Value
					)
				end

				upgradeGui.Upgrade.UpgradePrice.Text =
					"$" .. Comma(upgradePrice)
			else
				upgradeGui.Upgrade.UpgradeName.Text = "Maxed"
				upgradeGui.Upgrade.UpgradePrice.Text = ""
			end

			upgradeGui.Abilities.CTA.Visible = false
			upgradeGui.Abilities.Follow.Visible = false
			upgradeGui.Abilities.Pursuit.Visible = false
		end
	else
		if damageConnection and damageConnection.Connected then
			damageConnection:Disconnect()
		end

		if damageStatConnection and damageStatConnection.Connected then
			damageStatConnection:Disconnect()
		end
		if SpentConnection and SpentConnection.Connected then
			SpentConnection:Disconnect()
		end

		if AmmoConnection and AmmoConnection.Connected then
			AmmoConnection:Disconnect()
		end

		if Beamer and Beamer.Connected then
			Beamer:Disconnect()
		end

		if AmmunitionConnection and AmmunitionConnection.Connected then
			AmmunitionConnection:Disconnect()
		end

		if SpawnerConnection1 and SpawnerConnection1.Connected then
			SpawnerConnection1:Disconnect()
		end

		if Rebuild and Rebuild.Connected then
			Rebuild:Disconnect()
		end

		if SoulsConnection and SoulsConnection.Connected then
			SoulsConnection:Disconnect()
		end



		if Overheat and Overheat.Connected then
			Overheat:Disconnect()
		end



		-- Hide the Upgrade GUI if no tower is selected
		upgradeGui:TweenPosition(
			UDim2.new(-0.75, 0,0.536, 0),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Back,
			0.5,
			true
		)
	end
end

events.SpawnUnit.OnClientEvent:Connect(function(unitName)
	events.SpawnUnit:FireServer(unitName)
end)

placedTowers.Changed:Connect(function()
	gui.OtherGameStats.MaxTowersBanner.TextLabel.Text = tostring(placedTowers.Value) .. "/" .. tostring(getPlacement())
end)

--MODIFIERS--
workspace.Info.Modifiers["Half Cash"].Changed:Connect(function()
	gui.Modifiers.HalfCash.Visible = workspace.Info.Modifiers["Half Cash"].Value
end)
workspace.Info.Modifiers["Double HP"].Changed:Connect(function()
	gui.Modifiers.MoreHP.Visible = workspace.Info.Modifiers["Double HP"].Value
end)
workspace.Info.Modifiers["Death Wish"].Changed:Connect(function()
	gui.Modifiers.DeathWish.Visible = workspace.Info.Modifiers["Death Wish"].Value
end)
workspace.Info.Modifiers["Reduced Placement"].Changed:Connect(function()
	gui.Modifiers.ReducedPlacement.Visible = workspace.Info.Modifiers["Reduced Placement"].Value
end)
workspace.Info.Modifiers.NoWaveReward.Changed:Connect(function()
	gui.Modifiers.NoWaveReward.Visible = workspace.Info.Modifiers.NoWaveReward.Value
end)
workspace.Info.Modifiers["Last Life"].Changed:Connect(function()
	gui.Modifiers.LastLife.Visible = workspace.Info.Modifiers["Last Life"].Value
end)

workspace.Info.Modifiers["Generous Farms"].Changed:Connect(function()
	gui.Modifiers.GenerousFarms.Visible = workspace.Info.Modifiers["Generous Farms"].Value
end)


--GAME SETTINGS--
--Sound Settings--
gui.Settings.OpenSettings.Button.Activated:Connect(function()
	gui.FullSettings.Visible = not gui.FullSettings.Visible
end)

gui.FullSettings.Buttons.Timescale.Open.Activated:Connect(function()
	local data = getDataFunction:InvokeServer() -- no player param

	local unlocked = tonumber(data and data.UnlockedTimescale) or 0
	local isUnlocked = unlocked >= 1

	print(unlocked)

	if isUnlocked then
		gui.FullSettings.SettingsArea.Timescale.Visible = true
		gui.FullSettings.SettingsArea.Gen.Visible = true
		gui.FullSettings.SettingsArea.General.Visible = false
		gui.FullSettings.SettingsArea.Sound.Visible = false
	else
		events.NotifcationSend:FireServer()
		gui.FullSettings.SettingsArea.Timescale.Visible = false
		gui.FullSettings.SettingsArea.Gen.Visible = false
	end
end)
-- Close button
gui.FullSettings.Buttons.General.Open.Activated:Connect(function()
	gui.FullSettings.SettingsArea.General.Visible = true
	gui.FullSettings.SettingsArea.Timescale.Visible = false
	gui.FullSettings.SettingsArea.Sound.Visible = false
	gui.FullSettings.SettingsArea.Gen.Visible = false
end)

gui.FullSettings.Buttons.Sound.Open.Activated:Connect(function()
	gui.FullSettings.SettingsArea.General.Visible = false
	gui.FullSettings.SettingsArea.Timescale.Visible = false
	gui.FullSettings.SettingsArea.Sound.Visible = true
	gui.FullSettings.SettingsArea.Gen.Visible = false
end)
--END OF GAME SETTINGS--
local template = gui:WaitForChild("Cash") -- your original "Cash" frame

local tweenInfoIn = TweenInfo.new(
	0.4,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.Out
)

local tweenInfoOut = TweenInfo.new(
	0.4,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.In
)

-- Max size (the original)
local MAX_SIZE = UDim2.new(0.179, 0, 0.057, 0)

ReplicatedStorage.Events.MoneyDebuff.OnClientEvent:Connect(function()
	-- Clone so multiple can exist at once
	local popup = template:Clone()
	popup.Parent = gui
	popup.Visible = true

	-- Random tilt + random screen position
	popup.Rotation = math.random(-30, 30)
	popup.Position = UDim2.new(
		math.random(10, 90) / 100, -- random X (10%–90% to avoid clipping)
		0,
		math.random(10, 90) / 100, -- random Y (10%–90% to avoid clipping)
		0
	)

	-- Start small
	popup.Size = UDim2.new(0, 0, 0, 0)

	-- Tween in
	local tweenIn = TweenService:Create(popup, tweenInfoIn, { Size = MAX_SIZE })
	tweenIn:Play()
	tweenIn.Completed:Wait()

	-- Hold for 2 seconds
	task.wait(2)

	-- Tween out
	local tweenOut = TweenService:Create(popup, tweenInfoOut, { Size = UDim2.new(0, 0, 0, 0) })
	tweenOut:Play()
	tweenOut.Completed:Wait()

	-- Clean up
	popup:Destroy()
end)

local debounce = false
local debounceTime = 0.15

local function spawnNewTower()
	if debounce then return end
	debounce = true
	task.delay(debounceTime, function() debounce = false end)

	if not canPlace then return end
	if not currentPreviewCFrame then return end
	if not towerToSpawn then return end

	-- Use authoritative CFrame
	local targetCFrame = currentPreviewCFrame
	local pos = targetCFrame.Position
	local _, y, _ = targetCFrame:ToOrientation()
	local cleanCFrame = CFrame.new(pos) * CFrame.Angles(0, y, 0)

	local placedRequestSerial = placementRequestSerial

	-- Spawn tower on server
	local placedtower = spawnTowerFunction:InvokeServer(
		getCanonicalTowerName(towerToSpawn),
		cleanCFrame,
		nil,
		newRequestId()
	)
	if not placedtower then return end


	local soundFolder = gui.Sounds
	local repParticles = ReplicatedStorage.Particle
	local rootPart = placedtower:FindFirstChild("HumanoidRootPart")

	if placedtower.HumanoidRootPart:FindFirstChild("PlaceParticle") then
		local particle = rootPart:FindFirstChild("PlaceParticle")
		if particle then particle:Emit(10) end
	else
		local particle = repParticles.Place:Clone()
		particle.Parent = rootPart
		particle:Emit(10)
	end

	if placedtower.Config:FindFirstChild("Golden") then
		soundFolder.Golden:Play()

	elseif placedtower.Config:FindFirstChild("Creator") then
		soundFolder.creator:Play()

	elseif placedtower.Name == "War Machine" then
		soundFolder.land:Play()
		events.WarMachinePlaced:FireServer(placedtower)

	elseif placedtower.Config:FindFirstChild("IMPOSTA") then
		soundFolder.land:Play()
		events.ImpostaPlaced:FireServer(placedtower)
	elseif placedtower.HumanoidRootPart:FindFirstChild("PlacementSound") then
		placedtower.HumanoidRootPart.PlacementSound:Play()
	else
		soundFolder.land:Play()
	end

	-- =========================
	-- 📦 BOX / VISUAL LOGIC
	-- =========================
	if placementRequestIsCurrent(placedRequestSerial) then RemovePlaceholderTower() end
	toggleTowerInfo()

	if placedtower.Config.Owner.Value == Players.LocalPlayer.Name and not placedtower.Config:FindFirstChild("Flying") then

		local boxheight
		if placedtower.Config:FindFirstChild("GoldenTurret") then
			boxheight = placedtower.PrimaryPart.Size.Y + placedtower.HipHeight.Value + 1.25
		elseif placedtower.Config:FindFirstChild("MortarCannon") then
			boxheight = placedtower.PrimaryPart.Size.Y + placedtower.HipHeight.Value + 1.9
		else
			boxheight = placedtower.PrimaryPart.Size.Y + placedtower.HipHeight.Value + 0.4
		end
		local boxOffset = CFrame.new(0, -boxheight, 0)

		local boxPrefab = repParticles:WaitForChild("Box")
		local box = boxPrefab:Clone()

		box.Size = Vector3.new(
			placedtower.PrimaryPart.Size.Y * 1.75,
			placedtower.PrimaryPart.Size.Y * 1.75,
			placedtower.PrimaryPart.Size.Y * 1.75
		)

		box.Parent = placedtower
		box.CFrame = placedtower.PrimaryPart.CFrame * boxOffset

		updateOwnerBoxColor(placedtower)

	elseif placedtower.Config.Owner.Value == Players.LocalPlayer.Name and placedtower.Config:FindFirstChild("Flying") then

		local boxheight = placedtower.PrimaryPart.Size.Y + placedtower.HipHeight.Value + 6.75
		local boxOffset = CFrame.new(0, -boxheight, 0)

		local boxPrefab = repParticles:WaitForChild("HeliBox")
		local box = boxPrefab:Clone()

		box.Parent = placedtower
		box.CFrame = placedtower.PrimaryPart.CFrame * boxOffset

		local weld = Instance.new("WeldConstraint")	
		weld.Part0 = box
		weld.Part1 = placedtower.PrimaryPart
		weld.Parent = box

		updateOwnerBoxColor(placedtower)
	end
end


gui.DesktopControls.Cancel.Cancel.Activated:Connect(function()
	RemovePlaceholderTower()
	gui.Sounds.Click:Play()
end)

local TextChatService = game:GetService("TextChatService")

skipButon.OnClientEvent:Connect(function(t, f)
	if t then
		gui.SkipFrame.Visible = true
		gui.SkipFrame.UpgradeArea.ButtonArea.Skip.Visible = true
		gui.SkipFrame.UpgradeArea.ButtonArea.Pass.Visible = true
		if f then
			gui.SkipFrame.Visible = false
			gui.SkipFrame.UpgradeArea.ButtonArea.Skip.Visible = false
			gui.SkipFrame.UpgradeArea.ButtonArea.Pass.Visible = false
		end
		if workspace.Info.PlrValue.Value > 1 then
			gui.SkipFrame.Title.Text = "Skip Wave? (" .. workspace.Info.VoteSkipValue.Value .. "/" .. (workspace.Info.PlrValue.Value - 1) .. ")"
		else
			gui.SkipFrame.Title.Text = "Skip Wave? (" .. workspace.Info.VoteSkipValue.Value .. "/" .. workspace.Info.PlrValue.Value .. ")"
		end
	end
end)
events.SkipWaveHide.OnClientEvent:Connect(function()
	gui.SkipFrame.Visible = false
end)


local CTAButton = upgradeGui.TowerStats.Abilities.CTA

CTAButton.Activated:Connect(function()
	if not selectedTower then return end
	local config = selectedTower.Config
	if config.CanBuff.Value ~= "Yes" then return end

	local abilityName = "CTA"
	local cooldownTime
	if info.Modifiers["Death Wish"].Value == true then
		cooldownTime = math.round(config.BuffCooldown.Value * info.Modifiers.DeathWishInfo.AbilityBuffer.Value)
	else
		cooldownTime = config.BuffCooldown.Value
	end

	-- Initialize if not exists
	if not GlobalCooldowns[abilityName] then
		GlobalCooldowns[abilityName] = 0
	end

	-- If global cooldown active, ignore activation
	if GlobalCooldowns[abilityName] > 0 then
		-- Optional: feedback to player
		print("CTA is on global cooldown! Wait " .. GlobalCooldowns[abilityName] .. "s")
		return
	end

	-- Start global cooldown
	GlobalCooldowns[abilityName] = cooldownTime

	local buff = CTAButton
	buff.Cooldown.Visible = true
	buff.Active = false
	buff.Cooldown.Count.Text = tostring(GlobalCooldowns[abilityName])
	buff.Cooldown.Parent = buff
	buff.Visible = true

	-- Fire server event
	local BuffTower = ReplicatedStorage.Events:WaitForChild("CommanderBuff")
	BuffTower:FireServer(selectedTower)

	-- Countdown loop
	task.spawn(function()
		while GlobalCooldowns[abilityName] > 0 do
			task.wait(1 / workspace.Info.GameSpeed.Value)
			GlobalCooldowns[abilityName] -= 1
			buff.Cooldown.Count.Text = tostring(math.max(GlobalCooldowns[abilityName],0))
		end

		buff.Cooldown.Visible = false
		buff.Active = true
	end)
end)

-- ============================================================
-- REAPER SUMMONS + HOLD INDICATOR
-- Tap: 1 unit with a 1-second cooldown on this Reaper only.
-- Hold 2s: max affordable units with full cooldown on this Reaper,
--          plus 10s soft cooldown on the player's other Reapers.
-- The client only draws the progress bar; server validates/executes.
-- ============================================================
local reaperSpawnEvent = events:WaitForChild("ReaperSpawn")
local REAPER_HOLD_SECONDS = 2
local REAPER_PROGRESS_DELAY = 0.4 -- No progress UI for quick clicks/taps.

local reaperAbilityNames = {
	"SkeletonHoard",
	"GiantSkeletonHoard",
	"SluaghHoard",
	"ForgottenKnight",
	"HallowGaurd",
}

local currentReaperPress = nil
local reaperHoldIndicators = {} -- [button] = {Track, Fill}

-- Created in code so no new objects are required in your Studio UI.
-- Uses a thin animated cyan bar along the bottom of the held button.
local function getReaperHoldIndicator(button)
	local existing = reaperHoldIndicators[button]
	if existing then return existing end

	local track = Instance.new("Frame")
	track.Name = "ReaperHoldIndicator"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -3)
	track.Size = UDim2.new(1, -8, 0, 5)
	track.BackgroundColor3 = Color3.fromRGB(8, 19, 32)
	track.BackgroundTransparency = 0.18
	track.BorderSizePixel = 0
	track.Active = false
	track.Visible = false
	track.ZIndex = button.ZIndex + 10
	track.Parent = button

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	fill.BorderSizePixel = 0
	fill.Active = false
	fill.ZIndex = track.ZIndex + 1
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 135, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 239, 255)),
	})
	gradient.Parent = fill

	existing = {Track = track, Fill = fill}
	reaperHoldIndicators[button] = existing
	return existing
end

local function hideReaperHoldIndicator(press)
	if not press then return end
	if press.ProgressTween then
		press.ProgressTween:Cancel()
		press.ProgressTween = nil
	end
	if press.Indicator then
		press.Indicator.Track.Visible = false
		press.Indicator.Fill.Size = UDim2.fromScale(0, 1)
		press.Indicator.Fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
		press.Indicator.Fill.UIGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 135, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 239, 255)),
		})
	end
end

local function cancelReaperPress()
	if not currentReaperPress then return end
	local old = currentReaperPress
	currentReaperPress = nil
	hideReaperHoldIndicator(old)
	reaperSpawnEvent:FireServer(old.Tower, old.ButtonName, "Cancel")
end

local function canRequestReaper(towerModel, button)
	if not (towerModel and towerModel.Parent == workspace.Towers) then return false end
	if not (button and button.Visible and button.Active and button.Interactable) then return false end
	local cfg = towerModel:FindFirstChild("Config")
	if not cfg then return false end
	local owner = cfg:FindFirstChild("Owner")
	local reaper = cfg:FindFirstChild("Reaper")
	if not (owner and owner.Value == plr.Name and reaper) then return false end
	if cfg:FindFirstChild("DISABLED", true) then return false end
	local hp = cfg:FindFirstChild("Health")
	local healthVal = hp and hp:FindFirstChild("HealthValue")
	if healthVal and healthVal.Value <= 0 then return false end
	return true
end

local function beginReaperPress(button, input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local selected = selectedTower
	if not canRequestReaper(selected, button) then return end

	if currentReaperPress then
		cancelReaperPress()
	end

	local press = {
		Tower = selected,
		Button = button,
		ButtonName = button.Name,
		Input = input,
		InputType = input.UserInputType,
		Started = os.clock(),
		Indicator = getReaperHoldIndicator(button),
	}
	currentReaperPress = press
	reaperSpawnEvent:FireServer(selected, button.Name, "Press")

	-- Delay first so an ordinary click/tap never flashes the indicator.
	task.delay(REAPER_PROGRESS_DELAY, function()
		if currentReaperPress ~= press then return end
		if not (press.Button.Parent and press.Button.Visible) then return end

		local indicator = press.Indicator
		local elapsed = os.clock() - press.Started
		local fraction = math.clamp(elapsed / REAPER_HOLD_SECONDS, 0, 1)
		indicator.Fill.Size = UDim2.fromScale(fraction, 1)
		indicator.Track.Visible = true

		-- Fill smoothly from the actual elapsed time to the 2s threshold.
		local timeLeft = math.max(0, REAPER_HOLD_SECONDS - elapsed)
		if timeLeft > 0 then
			local tween = TweenService:Create(
				indicator.Fill,
				TweenInfo.new(timeLeft, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
				{Size = UDim2.fromScale(1, 1)}
			)
			press.ProgressTween = tween
			tween:Play()
			tween.Completed:Connect(function(state)
				if currentReaperPress == press and state == Enum.PlaybackState.Completed then
					indicator.Fill.UIGradient.Color = ColorSequence.new(Color3.fromRGB(77, 235, 166))
				end
			end)
		else
			indicator.Fill.Size = UDim2.fromScale(1, 1)
			indicator.Fill.UIGradient.Color = ColorSequence.new(Color3.fromRGB(77, 235, 166))
		end
	end)
end

-- The player can release outside the button; also distinguishes touch IDs.
UserInputService.InputEnded:Connect(function(input)
	local held = currentReaperPress
	if not held then return end
	if held.InputType ~= input.UserInputType then return end
	if held.InputType == Enum.UserInputType.Touch and held.Input ~= input then return end

	currentReaperPress = nil
	hideReaperHoldIndicator(held)
	local action = (selectedTower == held.Tower and held.Tower.Parent)
		and "Release" or "Cancel"
	reaperSpawnEvent:FireServer(held.Tower, held.ButtonName, action)
end)

for _, buttonName in ipairs(reaperAbilityNames) do
	local button = upgradeGui.TowerStats.Abilities:WaitForChild(buttonName)
	-- New summon buttons may not have their own cooldown frame yet.
	if not button:FindFirstChild("Cooldown") then
		local template = upgradeGui.TowerStats.Abilities.CTA:FindFirstChild("Cooldown")
		if template then
			local cooldown = template:Clone()
			cooldown.Name = "Cooldown"
			cooldown.Visible = false
			cooldown.Parent = button
		end
	end

	button.InputBegan:Connect(function(input)
		beginReaperPress(button, input)
	end)

	-- Optional keyboard/gamepad UI activation: one unit (no hold animation).
	-- Mouse/touch excluded to prevent duplicate fire on release.
	button.Activated:Connect(function(input)
		if not input then return end
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.Keyboard
			or tostring(inputType):find("Gamepad") then
			if canRequestReaper(selectedTower, button) then
				reaperSpawnEvent:FireServer(selectedTower, button.Name, "Tap")
			end
		end
	end)
end

-- Server owns the timers and replicates remaining cooldowns as attributes.
-- A single summon affects this tower only; MAX affects this + other Reapers.
task.spawn(function()
	while true do
		task.wait(0.1)

		if currentReaperPress
			and (selectedTower ~= currentReaperPress.Tower
				or not currentReaperPress.Tower.Parent
				or not currentReaperPress.Button.Visible) then
			cancelReaperPress()
		end

		local model = selectedTower
		local config = model and model:FindFirstChild("Config")
		local reaper = config and config:FindFirstChild("Reaper")
		local owner = config and config:FindFirstChild("Owner")
		local healthFolder = config and config:FindFirstChild("Health")
		local healthValue = healthFolder and healthFolder:FindFirstChild("HealthValue")

		-- Existing 0.1s cooldown refresh also keeps costs current after upgrades
		-- or edits to SoulRequirements, without adding more loops/connections.
		if reaper then
			refreshReaperRequirementLabels(model)
		end

		local remaining = 0
		if reaper then
			remaining = math.max(
				model:GetAttribute("ReaperSpawnHardCooldown") or 0,
				model:GetAttribute("ReaperSpawnSoftCooldown") or 0
			)
		end

		-- Full hold completed on server, so the cooldown is visible now.
		if remaining > 0 and currentReaperPress
			and currentReaperPress.Tower == model then
			cancelReaperPress()
		end

		local allowed = model and model.Parent == workspace.Towers
			and owner and owner.Value == plr.Name
			and (not healthValue or healthValue.Value > 0)
			and not (config and config:FindFirstChild("DISABLED", true))
			and remaining <= 0

		for _, buttonName in ipairs(reaperAbilityNames) do
			local button = upgradeGui.TowerStats.Abilities[buttonName]
			local cooldown = button:FindFirstChild("Cooldown")
			if cooldown then
				cooldown.Visible = button.Visible and reaper ~= nil and remaining > 0
				if cooldown.Visible then
					local count = cooldown:FindFirstChild("Count")
					if count then count.Text = tostring(math.ceil(remaining)) end
				end
			end
			button.Active = allowed and button.Visible or false
			button.Interactable = allowed and button.Visible or false
		end
	end
end)

local SerGeantRageButton = upgradeGui.TowerStats.Abilities.SergeantRage

SerGeantRageButton.Activated:Connect(function()
	if not selectedTower then return end
	local config = selectedTower.Config
	if config.CanBuff.Value ~= "Yes" then return end

	local abilityName = "Bloodlust"
	local cooldownTime
	if info.Modifiers["Death Wish"].Value == true then
		cooldownTime = math.round(config.BuffCooldown.Value * info.Modifiers.DeathWishInfo.AbilityBuffer.Value)
	else
		cooldownTime = config.BuffCooldown.Value
	end

	-- Initialize if not exists
	if not GlobalCooldowns[abilityName] then
		GlobalCooldowns[abilityName] = 0
	end

	-- If global cooldown active, ignore activation
	if GlobalCooldowns[abilityName] > 0 then
		-- Optional: feedback to player
		print("CTA is on global cooldown! Wait " .. GlobalCooldowns[abilityName] .. "s")
		return
	end

	-- Start global cooldown
	GlobalCooldowns[abilityName] = cooldownTime

	local buff = SerGeantRageButton
	buff.Cooldown.Visible = true
	buff.Active = false
	buff.Cooldown.Count.Text = tostring(GlobalCooldowns[abilityName])
	buff.Cooldown.Parent = buff
	buff.Visible = true

	-- Fire server event
	local BuffTower = ReplicatedStorage.Events:WaitForChild("SergeantBuff")
	BuffTower:FireServer(selectedTower)

	-- Countdown loop
	task.spawn(function()
		while GlobalCooldowns[abilityName] > 0 do
			task.wait(1 / workspace.Info.GameSpeed.Value)
			GlobalCooldowns[abilityName] -= 1
			buff.Cooldown.Count.Text = tostring(math.max(GlobalCooldowns[abilityName],0))
		end

		buff.Cooldown.Visible = false
		buff.Active = true
	end)
end)

local TankButton = upgradeGui.TowerStats.Abilities.Cavalry

TankButton.Activated:Connect(function()
	if not selectedTower then return end
	local config = selectedTower.Config
	if config.CanBuff.Value ~= "Yes" then return end

	if plr.Cash.Value < config.AbilityCost.Value then
		return
	end

	local abilityName = "Cavalry"
	local cooldownTime
	if info.Modifiers["Death Wish"].Value == true then
		cooldownTime = math.round(config.BuffCooldown.Value * info.Modifiers.DeathWishInfo.AbilityBuffer.Value)
	else
		cooldownTime = config.BuffCooldown.Value
	end

	-- Initialize if not exists
	if not GlobalCooldowns[abilityName] then
		GlobalCooldowns[abilityName] = 0
	end

	-- If global cooldown active, ignore activation
	if GlobalCooldowns[abilityName] > 0 then
		-- Optional: feedback to player
		print("CTA is on global cooldown! Wait " .. GlobalCooldowns[abilityName] .. "s")
		return
	end

	-- Start global cooldown
	GlobalCooldowns[abilityName] = cooldownTime

	local buff = TankButton
	buff.Cooldown.Visible = true
	buff.Active = false
	buff.Cooldown.Count.Text = tostring(GlobalCooldowns[abilityName])
	buff.Cooldown.Parent = buff
	buff.Visible = true

	-- Fire server event
	local BuffTower = ReplicatedStorage.Events:WaitForChild("TankSpawn")
	BuffTower:FireServer(selectedTower)

	-- Countdown loop
	task.spawn(function()
		while GlobalCooldowns[abilityName] > 0 do
			task.wait(1 / workspace.Info.GameSpeed.Value)
			GlobalCooldowns[abilityName] -= 1
			buff.Cooldown.Count.Text = tostring(math.max(GlobalCooldowns[abilityName],0))
		end

		buff.Cooldown.Visible = false
		buff.Active = true
	end)
end)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GunslingerButton = upgradeGui.TowerStats.Abilities.Gunslinger

------------------------------------------------
-- STATE
------------------------------------------------
local selecting = false
local aimModel = nil
local followConn = nil
local clickConn = nil

------------------------------------------------
-- MAIN
------------------------------------------------
GunslingerButton.Activated:Connect(function()
	if not selectedTower then return end

	local config = selectedTower.Config
	if config.CanBuff.Value ~= "Yes" then return end

	local MAX_AIM_RANGE = config.Range and config.Range.Value or 60

	local abilityName = "Gunslinger"
	local cooldownTime
	if info.Modifiers["Death Wish"].Value == true then
		cooldownTime = math.round(config.BuffCooldown.Value * info.Modifiers.DeathWishInfo.AbilityBuffer.Value)
	else
		cooldownTime = config.BuffCooldown.Value
	end

	GlobalCooldowns[abilityName] = GlobalCooldowns[abilityName] or 0
	if GlobalCooldowns[abilityName] > 0 then return end

	GlobalCooldowns[abilityName] = cooldownTime

	------------------------------------------------
	-- SNAPSHOT TOWER (IMPORTANT CHANGE)
	------------------------------------------------
	local lockedTower = selectedTower

	local function getTowerPos()
		if not lockedTower then return nil end
		local root = lockedTower.PrimaryPart or lockedTower:FindFirstChild("HumanoidRootPart")
		return root and root.Position
	end

	------------------------------------------------
	-- UI
	------------------------------------------------
	local buff = GunslingerButton
	buff.Cooldown.Visible = true
	buff.Active = false
	buff.Cooldown.Count.Text = tostring(cooldownTime)
	gui.Messages.AimOutlaw.Visible = true

	------------------------------------------------
	-- AIM MODEL
	------------------------------------------------
	aimModel = ReplicatedStorage.Particle.AssignBounty:Clone()
	aimModel.Parent = workspace.Visual

	selecting = true
	local targetPosition = nil

	local lastTouchAim = 0

	------------------------------------------------
	-- CLEANUP
	------------------------------------------------
	local function cleanup()
		selecting = false
		gui.Messages.AimOutlaw.Visible = false

		if followConn then followConn:Disconnect() end
		if clickConn then clickConn:Disconnect() end

		if aimModel then
			aimModel:Destroy()
			aimModel = nil
		end
	end

	------------------------------------------------
	-- AIM LOOP (NO AUTO CANCEL NOW)
	------------------------------------------------
	followConn = RunService.RenderStepped:Connect(function()
		if not selecting or not aimModel or not aimModel.PrimaryPart then return end

		local result = MouseRaycast2(aimModel)

		local towerPos = getTowerPos()
		if not towerPos then return end

		local targetPos

		if typeof(result) == "Instance"
			and result:IsA("Model")
			and result.PrimaryPart then

			targetPos = result.PrimaryPart.Position

		elseif typeof(result) == "RaycastResult" then
			targetPos = result.Position
		end

		if targetPos then
			local offset = targetPos - towerPos

			if offset.Magnitude > MAX_AIM_RANGE then
				targetPos = towerPos + offset.Unit * MAX_AIM_RANGE
			end

			targetPosition = targetPos
			aimModel:PivotTo(CFrame.new(targetPos))
		end
	end)


	------------------------------------------------
	-- CONFIRM INPUT
	------------------------------------------------
	clickConn = UserInputService.InputBegan:Connect(function(input, gp)
		if not selecting then return end

		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		------------------------------------------------
		-- MOBILE DOUBLE TAP
		------------------------------------------------
		if input.UserInputType == Enum.UserInputType.Touch then
			local now = tick()
			local timeSince = now - lastTouchAim
			lastTouchAim = now

			if timeSince > 0.25 then
				return
			end
		end

		------------------------------------------------
		-- CONFIRM
		------------------------------------------------
		if not targetPosition then return end

		cleanup()

		local BuffTower = ReplicatedStorage.Events:WaitForChild("OutlawBuff")

		-- send LOCKED tower, not current selectedTower
		BuffTower:FireServer(lockedTower, targetPosition)
	end)

	------------------------------------------------
	-- COOLDOWN
	------------------------------------------------
	task.spawn(function()
		while GlobalCooldowns[abilityName] > 0 do
			task.wait(1 / workspace.Info.GameSpeed.Value)
			GlobalCooldowns[abilityName] -= 1
			buff.Cooldown.Count.Text = tostring(math.max(GlobalCooldowns[abilityName], 0))
		end

		buff.Cooldown.Visible = false
		buff.Active = true
	end)
end)

local FollowButton = upgradeGui.TowerStats.Abilities.Follow
FollowButton.Activated:Connect(function()
	if not selectedTower then return end
	local config = selectedTower.Config
	if config.CanBuff.Value ~= "Yes" then return end

	local abilityName = "Follow"
	local cooldownTime
	if info.Modifiers["Death Wish"].Value == true then
		cooldownTime = math.round(config.BuffCooldown.Value * info.Modifiers.DeathWishInfo.AbilityBuffer.Value)
	else
		cooldownTime = config.BuffCooldown.Value
	end

	if not GlobalCooldowns[abilityName] then
		GlobalCooldowns[abilityName] = 0
	end

	if GlobalCooldowns[abilityName] > 0 then
		print("Follow is on global cooldown! Wait " .. GlobalCooldowns[abilityName] .. "s")
		return
	end

	GlobalCooldowns[abilityName] = cooldownTime

	local buff = FollowButton
	buff.Cooldown.Visible = true
	buff.Active = false
	buff.Cooldown.Count.Text = tostring(GlobalCooldowns[abilityName])
	buff.Cooldown.Parent = buff
	buff.Visible = true

	local BuffTower = ReplicatedStorage.Events.Helicopter:WaitForChild("Follow")
	BuffTower:FireServer(selectedTower)

	task.spawn(function()
		while GlobalCooldowns[abilityName] > 0 do
			task.wait(1 / workspace.Info.GameSpeed.Value)
			GlobalCooldowns[abilityName] -= 1
			buff.Cooldown.Count.Text = tostring(math.max(GlobalCooldowns[abilityName],0))
		end
		buff.Cooldown.Visible = false
		buff.Active = true
	end)
end)

-- PURSUIT Ability
local PursuitButton = upgradeGui.TowerStats.Abilities.Pursuit
PursuitButton.Activated:Connect(function()
	if not selectedTower then return end
	local config = selectedTower.Config
	if config.CanBuff.Value ~= "Yes" then return end

	local abilityName = "Pursuit"
	local cooldownTime
	if info.Modifiers["Death Wish"].Value == true then
		cooldownTime = math.round(config.BuffCooldown.Value * info.Modifiers.DeathWishInfo.AbilityBuffer.Value)
	else
		cooldownTime = config.BuffCooldown.Value
	end

	if not GlobalCooldowns[abilityName] then
		GlobalCooldowns[abilityName] = 0
	end

	if GlobalCooldowns[abilityName] > 0 then
		print("Pursuit is on global cooldown! Wait " .. GlobalCooldowns[abilityName] .. "s")
		return
	end

	GlobalCooldowns[abilityName] = cooldownTime

	local buff = PursuitButton
	buff.Cooldown.Visible = true
	buff.Active = false
	buff.Cooldown.Count.Text = tostring(GlobalCooldowns[abilityName])
	buff.Cooldown.Parent = buff
	buff.Visible = true

	local BuffTower = ReplicatedStorage.Events.Helicopter:WaitForChild("Pursuit")
	BuffTower:FireServer(selectedTower)

	task.spawn(function()
		while GlobalCooldowns[abilityName] > 0 do
			task.wait(1 / workspace.Info.GameSpeed.Value)
			GlobalCooldowns[abilityName] -= 1
			buff.Cooldown.Count.Text = tostring(math.max(GlobalCooldowns[abilityName],0))
		end
		buff.Cooldown.Visible = false
		buff.Active = true
	end)
end)


--FINISH COMMANDER LOGIC--

local originalSize = gui.SkipFrame.UpgradeArea.ButtonArea.Skip.Upgrade.Size
local pressedSize = originalSize - UDim2.new(0, 6, 0, 6) 
local inTweenInfo = TweenInfo.new(0.02, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local outTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
gui.SkipFrame.UpgradeArea.ButtonArea.Skip.Upgrade.Activated:Connect(function()
	gui.Sounds.Skip:Play()
	local shrink = TweenService:Create(gui.SkipFrame.UpgradeArea.ButtonArea.Skip.Upgrade, inTweenInfo, { Size = pressedSize })
	local grow = TweenService:Create(gui.SkipFrame.UpgradeArea.ButtonArea.Skip.Upgrade, outTweenInfo, { Size = originalSize })
	shrink:Play()
	shrink.Completed:Wait()
	grow:Play()
	gui.SkipFrame.UpgradeArea.ButtonArea.Skip.Visible = false
	gui.SkipFrame.UpgradeArea.ButtonArea.Pass.Visible = false
	gui.SkipFrame.Visible = false
	voteSkip:InvokeServer()
end)
local originalSize = gui.SkipFrame.UpgradeArea.ButtonArea.Pass.Upgrade.Size
local pressedSize = originalSize - UDim2.new(0, 6, 0, 6) 
local inTweenInfo = TweenInfo.new(0.02, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local outTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
gui.SkipFrame.UpgradeArea.ButtonArea.Pass.Upgrade.Activated:Connect(function()
	gui.Sounds.Skip:Play()
	local shrink = TweenService:Create(gui.SkipFrame.UpgradeArea.ButtonArea.Pass.Upgrade, inTweenInfo, { Size = pressedSize })
	local grow = TweenService:Create(gui.SkipFrame.UpgradeArea.ButtonArea.Pass.Upgrade, outTweenInfo, { Size = originalSize })
	shrink:Play()
	shrink.Completed:Wait()
	grow:Play()
	gui.SkipFrame.UpgradeArea.ButtonArea.Skip.Visible = false
	gui.SkipFrame.UpgradeArea.ButtonArea.Pass.Visible = false
	gui.SkipFrame.Visible = false
end)

workspace.Info.VoteSkipValue.Changed:Connect(function()
	if workspace.Info.PlrValue.Value > 1 then
		gui.SkipFrame.Title.Text = "Skip Wave? (" .. workspace.Info.VoteSkipValue.Value .. "/" .. (workspace.Info.PlrValue.Value - 1) .. ")"
	else
		gui.SkipFrame.Title.Text = "Skip Wave? (" .. workspace.Info.VoteSkipValue.Value .. "/" .. workspace.Info.PlrValue.Value .. ")"
	end
end)

SpeedUpCooldown.OnClientEvent:Connect(function()
	gui.FullSettings.SettingsArea.Timescale.Default.Button.Interactable = false
	gui.FullSettings.SettingsArea.Timescale.SpeedUp.Button.Interactable = false

	local label = gui.FullSettings.SettingsArea.Gen.Title
	local TIMER_BINDING_NAME = "Timer"

	local function StartTimer(duration)
		local delayEvent = Instance.new("BindableEvent")
		local endTime = tick() + duration
		local lastSecondShown = nil

		RunService:BindToRenderStep(TIMER_BINDING_NAME, Enum.RenderPriority.Last.Value - 1, function()
			local timeLeft = endTime - tick()
			local seconds = math.ceil(timeLeft)

			-- Only update the label when seconds change
			if seconds ~= lastSecondShown and seconds > 0 then
				lastSecondShown = seconds
				label.Text = string.format("Timescale Cooldown: %d", seconds)
			end

			if timeLeft <= 0 then
				label.Text = "Timescale Ready"
				RunService:UnbindFromRenderStep(TIMER_BINDING_NAME)

				gui.FullSettings.SettingsArea.Timescale.Default.Button.Interactable = true
				gui.FullSettings.SettingsArea.Timescale.SpeedUp.Button.Interactable = true

				delayEvent:Fire()
			end
		end)

		delayEvent.Event:Wait()
	end

	StartTimer(120)
end)

--[[if info.PlrValue.Value >= 2 then
	gui.TimescaleSettings.SettingsMenu.Timescale.Base.Icon.Visible = true
	gui.TimescaleSettings.SettingsMenu.Timescale.Speed.Icon.Visible = true
	gui.TimescaleSettings.SettingsMenu.Timescale.Base.Upgrade.Interactable = false
	gui.TimescaleSettings.SettingsMenu.Timescale.Speed.Upgrade.Interactable = false
else
	gui.TimescaleSettings.SettingsMenu.Timescale.Base.Icon.Visible = false
	gui.TimescaleSettings.SettingsMenu.Timescale.Speed.Icon.Visible = false
	gui.TimescaleSettings.SettingsMenu.Timescale.Base.Upgrade.Interactable = true
	gui.TimescaleSettings.SettingsMenu.Timescale.Speed.Upgrade.Interactable = true
end]]--


gui.FullSettings.SettingsArea.Timescale.Default.Button.Activated:Connect(function()
	print("1x speed pressed")
	gui.FullSettings.SettingsArea.Timescale.Default.Button.Interactable = false
	gui.FullSettings.SettingsArea.Timescale.SpeedUp.Button.Interactable = false
	local speedUpFunction = ReplicatedStorage.Functions.SpeedUp1
	speedUpFunction:InvokeServer()
end)

gui.FullSettings.SettingsArea.Timescale.SpeedUp.Button.Activated:Connect(function()
	print("2x speed pressed")
	gui.FullSettings.SettingsArea.Timescale.Default.Button.Interactable = false
	gui.FullSettings.SettingsArea.Timescale.SpeedUp.Button.Interactable = false
	local speedUpFunction = ReplicatedStorage.Functions.SpeedUp2
	speedUpFunction:InvokeServer()
end)

workspace.Info.GameSpeed.Changed:Connect(function(change)
	gui.FullSettings.SettingsArea.Gen.Cooldown.Text = "Current Gamespeed: (" .. workspace.Info.GameSpeed.Value .. ")"

	if change == 1.5 then
		gui.FullSettings.SettingsArea.Timescale.Default.Button.UIStroke.Disabled.Enabled = true
		gui.FullSettings.SettingsArea.Timescale.Default.Button.UIStroke.EnabledVFX.Enabled = false
		gui.FullSettings.SettingsArea.Timescale.SpeedUp.Button.UIStroke.Disabled.Enabled = false
		gui.FullSettings.SettingsArea.Timescale.SpeedUp.Button.UIStroke.EnabledVFX.Enabled = true
	elseif change == 1 then
		gui.FullSettings.SettingsArea.Timescale.Default.Button.UIStroke.Disabled.Enabled = false
		gui.FullSettings.SettingsArea.Timescale.Default.Button.UIStroke.EnabledVFX.Enabled = true
		gui.FullSettings.SettingsArea.Timescale.SpeedUp.Button.UIStroke.Disabled.Enabled = true
		gui.FullSettings.SettingsArea.Timescale.SpeedUp.Button.UIStroke.EnabledVFX.Enabled = false
	else
	end
	local msg = gui.Messages.Message:Clone()
	msg.Visible = true
	msg.Parent = gui.Messages

	-- set text
	msg.Main.Text = tostring( "Timescale Changed to " .. workspace.Info.GameSpeed.Value .. "!")
	msg.Main2.Text = tostring( "Timescale Changed to " .. workspace.Info.GameSpeed.Value .. "!")

	-- little slide-in tween (works best if msg.Position is set)
	local startPos = msg.Position + UDim2.fromOffset(0, 10)
	local endPos = msg.Position

	msg.Position = startPos
	msg.BackgroundTransparency = 1
	msg.Main.TextTransparency = 1
	msg.Main2.TextTransparency = 1

	local inInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(msg, inInfo, { Position = endPos, BackgroundTransparency = 1 }):Play()
	TweenService:Create(msg.Main, inInfo, { TextTransparency = 0 }):Play()
	TweenService:Create(msg.Main2, inInfo, { TextTransparency = 0 }):Play()

	-- stay for 4s then fade out
	task.delay(4, function()
		if not msg or not msg.Parent then return end

		local outInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		local outTween = TweenService:Create(msg, outInfo, {
			Position = endPos - UDim2.fromOffset(0, 10),
			BackgroundTransparency = 1,
		})
		TweenService:Create(msg.Main, outInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(msg.Main2, outInfo, { TextTransparency = 1 }):Play()

		outTween:Play()
		outTween.Completed:Wait()

		if msg then msg:Destroy() end
	end)
end)

-- Buttons and hotkeys share validation and one pending mutation per tower.
local function performTowerAction(action)
	local tower = selectedTower
	local live, kind = interaction:Resolve(tower)
	if live ~= tower or kind ~= "Tower" or GameWrapUp then return end
	local owner = tower.Config:FindFirstChild("Owner")
	if not owner or owner.Value ~= plr.Name then return end
	if action == "Upgrade" and not hasNextUpgrade(tower) then return end
	local remote = if action == "Upgrade" then upgradeTowerFunction elseif action == "Sell" then sellTowerFunction else changeModeFunction
	local ok, success = actionGate:Run(tower, function(captured)
		return remote:InvokeServer(captured)
	end)
	if not ok then
		if success then warn("Tower action failed:", action, success) end
		return
	end
	if not success then return end
	if action ~= "Target" then gui.Sounds.Upgrade:Play() end
	if action == "Upgrade" and tower.Parent then
		local root = tower:FindFirstChild("HumanoidRootPart")
		if root then
			local particle = ReplicatedStorage.Particle.Upgrade:Clone()
			particle.Parent = root; particle:Emit(5)
			game:GetService("Debris"):AddItem(particle, 5)
		end
	end
	-- A response for tower A must never close or repaint tower B's panel.
	if selectedTower ~= tower then return end
	if action == "Sell" then selectedTower = nil end
	toggleTowerInfo()
end
upgradeGui.Upgrade.Activated:Connect(function() performTowerAction("Upgrade") end)
gui.UpgradeUI.ExtraButtons.Sell.Activated:Connect(function() performTowerAction("Sell") end)
gui.UpgradeUI.ExtraButtons.Target.Activated:Connect(function() performTowerAction("Target") end)

events.BPCurrencyClient.OnClientEvent:Connect(function(amount)
	gui.BpCurrnecy.Text = "BP Currency: " .. amount
	gui.BpCurrnecy.Visible = true
end)

gui.DesktopControls.Rotate.Rotate.Activated:Connect(function()
	if not towerToSpawn then
		return
	end

	gui.Sounds.Rotate:Play()
	rotation += 90
end)


-- ============================================================
-- HOTKEY TABLE
-- Put this before UserInputService.InputBegan
-- ============================================================

local towerSlotKeys = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}


UserInputService.InputBegan:Connect(function(input, processed)
	if processed then 
		return
	end

	if towerToSpawn then 
		if input.UserInputType == Enum.UserInputType.MouseButton1 then 
			spawnNewTower()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local timeSinceLastTouch = tick() - lastTouch
			if timeSinceLastTouch <= 0.25 then
				spawnNewTower()
			end
			lastTouch = tick()
		elseif input.KeyCode == Enum.KeyCode.R then
			gui.Sounds.Rotate:Play()
			rotation += 90
		elseif input.KeyCode == Enum.KeyCode.Q then
			RemovePlaceholderTower()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		local pointer = if input.UserInputType == Enum.UserInputType.Touch then Vector2.new(input.Position.X, input.Position.Y) else UserInputService:GetMouseLocation()
		if interaction:IsBlocked(pointer) or GameWrapUp then return end
		local _, _, _, clicked, kind = MouseRaycast(nil, pointer)
		selectedTower = if kind == "Tower" then clicked else nil

		toggleTowerInfo()
	end


	if UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.E then
		performTowerAction("Upgrade")
	elseif input.KeyCode == Enum.KeyCode.X then
		performTowerAction("Sell")
	elseif input.KeyCode == Enum.KeyCode.Z then
		performTowerAction("Target")
	elseif input.KeyCode == Enum.KeyCode.Escape then
		selectedTower = nil
		toggleTowerInfo()
	end

	local slotIndex = towerSlotKeys[input.KeyCode]

	if slotIndex then
		requestPlacementSlot(slotIndex)
	end
end)
ReplicatedStorage.Events.Error.OnClientEvent:Connect(function(message)
	if gui.Sounds and gui.Sounds:FindFirstChild("Error") then
		gui.Sounds.Error:Play()
	end

	local errorGui = gui.Info.Errors.Error:Clone()
	errorGui.Visible = true

	if errorGui:FindFirstChild("Message") and errorGui.Message:IsA("TextLabel") then
		errorGui.Message.Text = message or "An error occurred"
	else
		warn("Error GUI Message text label missing")
	end

	errorGui.Parent = gui.Info.Errors

	task.delay(3, function()
		if errorGui and errorGui.Parent then
			errorGui:Destroy()
		end
	end)
end)

local TweenSpd = 0.5
local Tweeninfo = TweenInfo.new(TweenSpd, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0)

local TOWER_SWAY = 60
local PrevPos = CFrame.new()
local SWAY_FACTOR = 0.25 -- tweak this to match old feel

RunService.RenderStepped:Connect(function()
	if GameWrapUp and towerToSpawn then RemovePlaceholderTower() end
	if selectedTower and (not interaction:Resolve(selectedTower) or GameWrapUp) then
		selectedTower = nil
		toggleTowerInfo()
	end
	interaction:Update(if not towerToSpawn and not GameWrapUp then hoveredModel else nil, selectedTower)
	local result, mousePos, blocked = nil, nil, false

	-- If placing a tower
	if towerToSpawn then
		hoveredModel, hoveredKind = nil, nil
		hoverGui.Visible = false; TowerhoverGui.Visible = false; UnitHoverGui.Visible = false
		ClearUnitRangeCircle()
		result, mousePos, blocked = PlacementRaycast(towerToSpawn)


		if not result or not result.Position then
			hoveredInstance = nil
			hoverGui.Visible = false
			TowerhoverGui.Visible = false
			UnitHoverGui.Visible = false
			canPlace = false
			return
		end

		-- Tower placement preview
		local isCliffTower = towerToSpawn.Config:FindFirstChild("CliffTower")
		local rangeModel = workspace.GameDependencies.Range:WaitForChild("Range")
		local mainPart = rangeModel:FindFirstChild("mainPart")
		local map = workspace.Map:FindFirstChildOfClass("Folder")

		-- Cliff visuals
		for _, child in ipairs(map.CliffPlacement:GetChildren()) do
			child.Transparency = isCliffTower and 0.8 or 1
		end

		-- Placement validation
		local validPlacement = false

		if not blocked then
			local hitInstance = result.Instance
			local hitParent = hitInstance and hitInstance.Parent

			if hitParent then
				if hitParent.Name == "TowerArea" and not isCliffTower then
					validPlacement = true
				elseif hitParent.Name == "CliffPlacement" and isCliffTower then
					validPlacement = true
				end
			end
		end

		canPlace = validPlacement

		-- Color feedback
		local color = validPlacement and Color3.fromRGB(0, 85, 255) or Color3.new(1,0.333,0.333)
		TweenService:Create(mainPart, TweenInfo.new(0.1), {Color = color}):Play()
		ColorPlaceholderTower(color)

		-- Raw target (authoritative) CFrame for placement
		local x, y, z = result.Position.X, result.Position.Y + towerToSpawn.HipHeight.Value + (towerToSpawn.PrimaryPart.Size.Y / 0.7), result.Position.Z
		local targetCFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotation), 0)
		currentPreviewCFrame = targetCFrame -- 🔥 this is used in spawnNewTower

		-- Buff detection
		local buffCheck = towerToSpawn:FindFirstChild("BuffCheck", true)
		if buffCheck then
			local placeholderPos = towerToSpawn.PrimaryPart.Position
			local isBeamer = towerToSpawn.Config:FindFirstChild("BeamerSettings") ~= nil

			local hasFirerate = false
			local hasRange = false
			local hasDamage = false
			local hasAOEHeal = false

			for _, supportTower in ipairs(workspace.Towers:GetChildren()) do
				local config = supportTower:FindFirstChild("Config")
				if not config then
					continue
				end

				local supportRoot = supportTower.PrimaryPart or supportTower:FindFirstChild("HumanoidRootPart")
				if not supportRoot then
					continue
				end

				local range = config:FindFirstChild("Range")
				local rangeValue = range and range.Value or 0

				if (supportRoot.Position - placeholderPos).Magnitude > rangeValue then
					continue
				end

				-- Regular Buffs
				local buffs = config:FindFirstChild("Buffs")
				if buffs then
					if buffs:FindFirstChild("FirerateBuff") then
						hasFirerate = true
					end

					if buffs:FindFirstChild("RangeBuff") then
						hasRange = true
					end
				end

				-- Damage Buffs
				local damageBuffs = config:FindFirstChild("DamageBuffs")
				if damageBuffs then
					local damageBuff = damageBuffs:FindFirstChild("DamageBuff")
					if damageBuff then
						if not isBeamer then
							hasDamage = true
						end

						local check = damageBuff:FindFirstChild("Check")
						local disabled = damageBuff:FindFirstChild("Disabled")

						if check then
							check.Visible = not isBeamer
						end

						if disabled then
							disabled.Visible = isBeamer
						end
					end
				end

				-- AOE Heal
				local aoeHeal = config:FindFirstChild("AOEHeal")
				if aoeHeal and aoeHeal:FindFirstChild("Tree") then
					hasAOEHeal = true
				end
			end

			buffCheck.Firerate.Visible = hasFirerate
			buffCheck.Range.Visible = hasRange
			buffCheck.Damage.Visible = hasDamage
			buffCheck.AOEHeal.Visible = hasAOEHeal
		end

		-- Subtle sway + smooth lerp for preview
		local delta = (targetCFrame.Position - PrevPos.Position)
		local sway = CFrame.Angles(
			math.rad(delta.Z * TOWER_SWAY * SWAY_FACTOR),
			0,
			math.rad(-delta.X * TOWER_SWAY * SWAY_FACTOR)
		)
		local visualCFrame = targetCFrame * sway
		local newCF = towerToSpawn.PrimaryPart.CFrame:Lerp(visualCFrame, 0.35)
		towerToSpawn:SetPrimaryPartCFrame(newCF)
		PrevPos = newCF

		-- Range positioning
		local height = towerToSpawn.HipHeight.Value + (towerToSpawn.PrimaryPart.Size.Y / 0.7)

	else
		if GameWrapUp then
			hoveredModel, hoveredKind = nil, nil
			hoverGui.Visible = false; TowerhoverGui.Visible = false; UnitHoverGui.Visible = false
			ClearUnitRangeCircle()
			return
		end
		result, mousePos, _, hoveredModel, hoveredKind = MouseRaycast(nil)
		interaction:Update(hoveredModel, selectedTower)

		hoveredInstance =
			result
			and result.Instance
			or nil

		if hoveredModel then
			if hoveredKind == "Mob" then
				ClearUnitRangeCircle()

				HoverOverMob(
					hoveredModel,
					mousePos
				)

				TowerhoverGui.Visible = false
				UnitHoverGui.Visible = false

			elseif hoveredKind == "Tower" then
				ClearUnitRangeCircle()

				HoverOverTower(
					hoveredModel,
					mousePos
				)

				hoverGui.Visible = false
				UnitHoverGui.Visible = false

			elseif hoveredKind == "Unit" then
				HoverOverUnit(
					hoveredModel,
					mousePos
				)

				hoverGui.Visible = false
				TowerhoverGui.Visible = false
			end

		else
			hoveredModel = nil
			hoveredKind = nil

			hoverGui.Visible = false
			TowerhoverGui.Visible = false
			UnitHoverGui.Visible = false
			ClearUnitRangeCircle()
		end
	end
end)
events.FinalWave.OnClientEvent:Connect(function(color)
	gui.Info.Wave.Count.TextColor3 = color
end)

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetMedalStatus = functions:WaitForChild("GetMedalStatus")

local function tweenObject(object, duration, properties, easingStyle, easingDirection)
	local tweenInfo = TweenInfo.new(
		duration or 0.5,
		easingStyle or Enum.EasingStyle.Quint,
		easingDirection or Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(object, tweenInfo, properties)
	tween:Play()

	return tween
end

local function popIn(object, delayTime)
	task.delay(delayTime or 0, function()
		if not object then return end

		local originalSize = object.Size
		local originalRotation = object.Rotation

		object.Size = UDim2.new(
			originalSize.X.Scale * 0.75,
			originalSize.X.Offset * 0.75,
			originalSize.Y.Scale * 0.75,
			originalSize.Y.Offset * 0.75
		)

		object.Rotation = originalRotation - 4

		tweenObject(
			object,
			0.45,
			{
				Size = originalSize,
				Rotation = originalRotation
			},
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		)
	end)
end

local function fadeIn(object, delayTime)
	task.delay(delayTime or 0, function()
		if not object then return end

		if object:IsA("TextLabel") or object:IsA("TextButton") then
			local originalTransparency = object.TextTransparency
			object.TextTransparency = 1

			tweenObject(object, 0.4, {
				TextTransparency = originalTransparency
			})
		elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
			local originalTransparency = object.ImageTransparency
			object.ImageTransparency = 1

			tweenObject(object, 0.4, {
				ImageTransparency = originalTransparency
			})
		elseif object:IsA("Frame") then
			local originalTransparency = object.BackgroundTransparency
			object.BackgroundTransparency = 1

			tweenObject(object, 0.4, {
				BackgroundTransparency = originalTransparency
			})
		end
	end)
end
local function animateCount(label, finalValue, duration, suffix, sound)
	suffix = suffix or ""

	local startValue = 0
	local startTime = tick()

	local function smoothstep(t)
		return t * t * (3 - 2 * t)
	end

	-- Give this counter its own sound
	local counterSound = nil

	if sound then
		counterSound = sound:Clone()
		counterSound.Parent = sound.Parent
	end

	task.spawn(function()
		local lastValue = -1
		local soundCooldown = 0

		while true do
			local elapsed = tick() - startTime
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local smooth = smoothstep(alpha)

			local current = math.floor(
				startValue + (finalValue - startValue) * smooth
			)

			if current ~= lastValue then
				lastValue = current
				label.Text = tostring(current) .. suffix

				-- Don't start another sound once we're finished
				if alpha < 1 and counterSound and tick() >= soundCooldown then
					counterSound:Play()
					soundCooldown = tick() + 0.08
				end
			end

			-- Finished
			if alpha >= 1 then
				label.Text = tostring(finalValue) .. suffix

				-- IMPORTANT:
				-- Immediately stop any sound that is still playing.
				if counterSound then
					counterSound:Stop()
					counterSound:Destroy()
				end

				break
			end

			task.wait()
		end
	end)
end

local function DisplayEndScreen(status)
	GameWrapUp = true

	local screen = gui.EndScreen
	local info = workspace.Info
	local difficulty = info.Gamemode.Value

	local map = workspace.Map:FindFirstChildOfClass("Folder").Name
	local modeBonus = workspace.Info.DifficultyMultiplier
	local modeBonusPerc = workspace.Info.DifficultyMultiplierPercent

	------------------------------------------------
	-- FIRST TIME MEDAL
	------------------------------------------------

	local isFirstTimeMedal = false

	if status == "VICTORY"
		and (
			difficulty == "Easy"
				or difficulty == "Normal"
				or difficulty == "Hard"
		)
	then

		local success, result =
			pcall(function()

				return GetMedalStatus:InvokeServer(
					map,
					difficulty
				)

			end)

		if success then
			isFirstTimeMedal = result == true
		else
			warn("Failed to check medal status")
		end

	end

	------------------------------------------------
	-- MEDAL DISPLAY
	------------------------------------------------

	local medals =
		screen:FindFirstChild("Medal")

	if medals then

		-- Hide all medals first
		for _, medal in ipairs(medals:GetChildren()) do

			if medal:IsA("ImageLabel")
				or medal:IsA("ImageButton")
			then

				medal.Visible = false

			end

		end

		-- Show the medal earned this game
		if isFirstTimeMedal then

			local medal =
				medals:FindFirstChild(difficulty)

			if medal
				and (
					medal:IsA("ImageLabel")
						or medal:IsA("ImageButton")
				)
			then

				medal.Visible = true

			end

		end

	end

	------------------------------------------------
	-- FIRST TIME COMPLETION DISPLAY
	------------------------------------------------

	local firstTimeCompletion =
		screen.ExtraStats.Rewards.FirstCompletion

	firstTimeCompletion.Visible =
		isFirstTimeMedal

	------------------------------------------------
	-- SKIN REWARD
	------------------------------------------------

	local skinReward =
		screen.Rewards.Rewards.Skin

	-- Always hide the skin first.
	skinReward.Visible = false

	-- Helper function to handle confetti
	local function handleConfetti(isTriumph)
		local children = workspace.Confetti:GetChildren()
		for _, child in ipairs(children) do
			local emitterNames = {"Five", "Four", "Three", "Two", "One"}
			for _, name in ipairs(emitterNames) do
				local emitter = child:FindFirstChild(name)
				if emitter then
					emitter.Enabled = isTriumph
					if isTriumph then
						emitter:Emit(99)
					end
				end
			end
		end
	end

	if info.Gamemode.Value == "Hardcore" then
		screen.Rewards.Rewards.Coins.Visible = false
		screen.Rewards.Rewards.Gems.LayoutOrder = -5
	else
		screen.Rewards.Rewards.Coins.Visible = true
	end

	-- Setup UI based on the status
	if status == "GAME OVER" then
		screen.Failure:Play()
		workspace.Ambience:FindFirstChildOfClass("Sound"):Stop()
		screen.Outcome.UpgradeName.Text = "You Lose"
		screen.Outcome.UpgradeName.Lose.Enabled = true
		screen.Outcome.UpgradeName.Win.Enabled = false
		screen.ExtraStats.Rewards.Map.Amount.Text = map
		screen.ExtraStats.Rewards.Time.Amount.Text = workspace.Info.TotalGameTime.Minutes.Value .. " min & " .. workspace.Info.TotalGameTime.Seconds.Value .. " sec"
		screen.ExtraStats.Rewards.Difficulty.Amount.Text = info.Gamemode.Value .. ""
		screen.Bar.Win.Enabled = false
		screen.Bar.Lose.Enabled = true
	elseif status == "VICTORY" then
		handleConfetti(true)
		screen.Triumph:Play()
		workspace.Ambience:FindFirstChildOfClass("Sound"):Stop()
		screen.ExtraStats.Rewards.Map.Amount.Text = map
		screen.ExtraStats.Rewards.Time.Amount.Text = workspace.Info.TotalGameTime.Minutes.Value .. " min & " .. workspace.Info.TotalGameTime.Seconds.Value .. " sec"
		screen.ExtraStats.Rewards.Difficulty.Amount.Text = info.Gamemode.Value .. ""

		-- Hard Mode Skin Reward
		if difficulty == "Hard" then
			skinReward.Visible = true
		end

		screen.Outcome.UpgradeName.Lose.Enabled = false
		screen.Outcome.UpgradeName.Win.Enabled = true
	end

	local Multiplier = 1

	local modifierBonus = {
		["Double HP"] = 0.06,
		["Last Life"] = 0.04,
		["Reduced Placement"] = 0.02,
		["Death Wish"] = 1,
		["More Starting Cash"] = -0.3,
		["Generous Farms"] = -0.65,
		["Extra Lives"] = -0.4,
	}


	local modsFolder = workspace.Info:WaitForChild("Modifiers")

	for modName, bonus in pairs(modifierBonus) do
		local flag = modsFolder:FindFirstChild(modName)
		if flag and flag.Value == true then
			Multiplier += (bonus)
		end
	end

	local Coins, exp, wins, gems, BP = 0, 0, 0,0, 0
	local wave = info.Wave.Value
	local isTriumph = status == "VICTORY"

	-- Calculate rewards based on difficulty and wave
	local function calculateRewards(baseCoins, baseExp, basevictoryWins, baseGems, baseBP)
		local Coins = math.floor(baseCoins * wave)
		local experience = math.floor(baseExp * wave)
		local gems = math.floor(baseGems or 0)
		local BP = math.floor(baseBP or 0)
		local victoryWins = isTriumph and 1 or 0
		return Coins, experience, victoryWins, gems, BP
	end
	if difficulty == "Easy" then
		if wave <= 5 then
			Coins, exp, wins, gems, BP = calculateRewards(
				3 * modeBonus.Value,
				0.75 * modeBonus.Value,
				0,0,0
			)
		elseif wave <= 10 then
			Coins, exp, wins, gems, BP = calculateRewards(
				5 * modeBonus.Value,
				1.25 * modeBonus.Value,
				0,0,25
			)
		elseif wave <= 15 then
			Coins, exp, wins, gems, BP = calculateRewards(
				7 * modeBonus.Value,
				2 * modeBonus.Value,
				0,0,55
			)
		elseif wave <= 18 then
			Coins, exp, wins, gems, BP = calculateRewards(
				9 * modeBonus.Value,
				2.75 * modeBonus.Value,
				0,0,80
			)
		elseif wave <= 20 then
			Coins, exp, wins, gems, BP = calculateRewards(
				11 * modeBonus.Value,
				3.5 * modeBonus.Value,
				0,0,95
			)
		end

		if isTriumph then
			Coins = math.round(210 * modeBonus.Value * Multiplier)
			exp = math.round(75 * Multiplier * modeBonus.Value)
			wins = 1
			gems = math.round(20 * modeBonus.Value * Multiplier)
			BP = 110
		end


	elseif difficulty == "Normal" then
		if wave <= 7 then
			Coins, exp, wins, gems, BP = calculateRewards(
				4 * modeBonus.Value,
				0.75 * modeBonus.Value,
				0,0,0
			)
		elseif wave <= 13 then
			Coins, exp, wins, gems, BP = calculateRewards(
				7 * modeBonus.Value,
				1.25 * modeBonus.Value,
				0,0,60
			)
		elseif wave <= 19 then
			Coins, exp, wins, gems, BP = calculateRewards(
				10 * modeBonus.Value,
				1.75 * modeBonus.Value,
				0,0,100
			)
		elseif wave <= 23 then
			Coins, exp, wins, gems, BP = calculateRewards(
				13 * modeBonus.Value,
				2.25 * modeBonus.Value,
				0,0,125
			)
		elseif wave <= 26 then
			Coins, exp, wins, gems, BP = calculateRewards(
				15 * modeBonus.Value,
				2.75 * modeBonus.Value,
				0,0,150
			)
		end

		if isTriumph then
			Coins = math.round(500 * modeBonus.Value * Multiplier)
			exp = math.round(175 * Multiplier * modeBonus.Value)
			wins = 1
			gems = math.round(45 * modeBonus.Value * Multiplier)
			BP = 175
		end
	elseif difficulty == "Hard" then
		if wave <= 8 then
			Coins, exp, wins, gems, BP = calculateRewards(
				4 * modeBonus.Value,
				1 * modeBonus.Value,
				0,0,15
			)
		elseif wave <= 15 then
			Coins, exp, wins, gems, BP = calculateRewards(
				7 * modeBonus.Value,
				1.75 * modeBonus.Value,
				0,0,60
			)
		elseif wave <= 22 then
			Coins, exp, wins, gems, BP = calculateRewards(
				11 * modeBonus.Value,
				2.5 * modeBonus.Value,
				0,0,110
			)
		elseif wave <= 28 then
			Coins, exp, wins, gems, BP = calculateRewards(
				15 * modeBonus.Value,
				3.25 * modeBonus.Value,
				0,0,140
			)
		elseif wave <= 32 then
			Coins, exp, wins, gems, BP = calculateRewards(
				20 * modeBonus.Value,
				4 * modeBonus.Value,
				0,0,170
			)
		end

		if isTriumph then
			Coins = math.round(1050 * modeBonus.Value * Multiplier)
			exp = math.round(295 * Multiplier * modeBonus.Value)
			wins = 1
			gems = math.round(80 * modeBonus.Value * Multiplier)
			BP = 200
		end
	elseif difficulty == "Insane" then
		if wave <= 10 then
			Coins, exp, wins, gems = calculateRewards(8* modeBonus.Value, 1* modeBonus.Value,0* modeBonus.Value, 0* modeBonus.Value)
		elseif wave <= 26 then
			Coins, exp, wins, gems = calculateRewards(10* modeBonus.Value, 3* modeBonus.Value,0* modeBonus.Value,0* modeBonus.Value)
		end
		if isTriumph then
			Coins, exp, wins, gems = math.round(1450 * modeBonus.Value * Multiplier), math.round(math.floor(7.25 * wave * 1.52)* modeBonus.Value * Multiplier), 1, math.round(120 * modeBonus.Value * Multiplier)
		end
	elseif difficulty == "Chaos" then
		if wave <= 10 then
			Coins, exp, wins, gems = calculateRewards(8* modeBonus.Value, 1* modeBonus.Value,0* modeBonus.Value, 0* modeBonus.Value)
		elseif wave <= 26 then
			Coins, exp, wins, gems = calculateRewards(10* modeBonus.Value, 3* modeBonus.Value,0* modeBonus.Value,0* modeBonus.Value)
		end
		if isTriumph then
			Coins, exp, wins, gems = math.round(2150 * modeBonus.Value * Multiplier), math.round(math.floor(8.25 * wave * 1.52)* modeBonus.Value * Multiplier), 1, math.round(175 * modeBonus.Value * Multiplier)
		end
	elseif difficulty == "Hardcore" then
		if wave <= 10 then
			exp, wins, gems = calculateRewards(1* modeBonus.Value,0* modeBonus.Value, 0* modeBonus.Value)
		elseif wave <= 26 then
			exp, wins, gems = calculateRewards( 3* modeBonus.Value,0* modeBonus.Value,0* modeBonus.Value)
		end
		if isTriumph then
			exp, wins, gems = math.round(math.floor(12.25 * wave * 4.52)* modeBonus.Value * Multiplier), 1, math.round(3450 * modeBonus.Value * Multiplier)
		end
	end

	------------------------------------------------
	-- FIRST TIME MEDAL REWARD BONUS
	------------------------------------------------

	if isFirstTimeMedal then

		Coins = math.round(Coins * 1.40)
		exp = math.round(exp * 1.40)
		gems = math.round(gems * 1.40)
	end

	-- Update UI with calculated rewards
	screen.Outcome.UpgradeName.Text = status
	local rewardSound = gui.Sounds:FindFirstChild("Reward")

	animateCount(screen.Rewards.Rewards.Coins.Rewards, Coins, 2, " Coins", rewardSound)
	animateCount(screen.Rewards.Rewards.Exp.Rewards, exp, 2, " Exp", rewardSound)
	animateCount(screen.Rewards.Rewards.Gems.Rewards, gems, 2, " Gems", rewardSound)
	animateCount(screen.ExtraStats.Rewards.EnemyKills.Amount, plr.Kills.Value, 2, " Kills", rewardSound)
	animateCount(screen.Rewards.Rewards.EventCurrency.Rewards, BP, 2, " 🎃", rewardSound)
	animateCount(screen.ExtraStats.Rewards.RewardMultiplier.Amount, (Multiplier - 1) + modeBonus.Value, 2, "x Rewards", rewardSound)
	screen.Size = UDim2.new(0, 0, 0, 0)

	if modeBonus.Value > 1 then
		screen.Rewards.Rewards.Coins.Multiplier.Visible = true
		screen.Rewards.Rewards.Gems.Multiplier.Visible = true
		screen.Rewards.Rewards.Exp.Multiplier.Visible = true
		screen.Rewards.Rewards.Coins.MultiplierAmount.Text = "+"..modeBonusPerc.Value .. "%"
		screen.Rewards.Rewards.Gems.MultiplierAmount.Text = "+"..modeBonusPerc.Value .. "%"
		screen.Rewards.Rewards.Exp.MultiplierAmount.Text = "+"..modeBonusPerc.Value .. "%"
		screen.Rewards.Rewards.Coins.MultiplierAmount.Visible = true
		screen.Rewards.Rewards.Gems.MultiplierAmount.Visible = true
		screen.Rewards.Rewards.Exp.MultiplierAmount.Visible = true
	elseif modeBonus.Value < 1 then
		screen.Rewards.Rewards.Coins.Multiplier.Visible = true
		screen.Rewards.Rewards.Gems.Multiplier.Visible = true
		screen.Rewards.Rewards.Exp.Multiplier.Visible = true
		screen.Rewards.Rewards.Coins.Multiplier.Rotation = 180
		screen.Rewards.Rewards.Gems.Multiplier.Rotation = 180
		screen.Rewards.Rewards.Exp.Multiplier.Rotation = 180
		screen.Rewards.Rewards.Coins.MultiplierAmount.Text = ""..modeBonusPerc.Value .. "%"
		screen.Rewards.Rewards.Gems.MultiplierAmount.Text = ""..modeBonusPerc.Value .. "%"
		screen.Rewards.Rewards.Exp.MultiplierAmount.Text = ""..modeBonusPerc.Value .. "%"
		screen.Rewards.Rewards.Coins.MultiplierAmount.Visible = true
		screen.Rewards.Rewards.Gems.MultiplierAmount.Visible = true
		screen.Rewards.Rewards.Exp.MultiplierAmount.Visible = true
	elseif modeBonus.Value == 1 then
		screen.Rewards.Rewards.Coins.Multiplier.Visible = false
		screen.Rewards.Rewards.Gems.Multiplier.Visible = false
		screen.Rewards.Rewards.Exp.Multiplier.Visible = false
		screen.Rewards.Rewards.Coins.MultiplierAmount.Visible = false
		screen.Rewards.Rewards.Gems.MultiplierAmount.Visible = false
		screen.Rewards.Rewards.Exp.MultiplierAmount.Visible = false
	end

	-- Tween position and size
	screen:TweenPosition(
		UDim2.new(0.5, 0,0.5, 0),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Back,
		0.5,
		true
	)

	local tweenStyle = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)
	local zoomTween = TweenService:Create(screen, tweenStyle, {Size = UDim2.new(0.402, 0, 0.425, 0)})
	zoomTween:Play()

	-- ==========================================
	-- BEAUTIFUL REWARD REVEAL
	-- ==========================================

	local rewards = screen.Rewards.Rewards

	-- Slight initial fade for the reward container
	if rewards:IsA("Frame") then
		local originalTransparency = rewards.BackgroundTransparency
		rewards.BackgroundTransparency = 1

		tweenObject(rewards, 0.5, {
			BackgroundTransparency = originalTransparency
		})
	end

	-- Animate individual rewards in sequence
	popIn(rewards.Coins, 0.15)
	popIn(rewards.Exp, 0.25)
	popIn(rewards.Gems, 0.35)

	-- Hard Mode skin gets a special reveal
	if difficulty == "Hard" and status == "VICTORY" then
		task.delay(0.55, function()
			if not skinReward.Visible then
				return
			end

			local originalSize = skinReward.Size
			local originalRotation = skinReward.Rotation

			skinReward.Size = UDim2.new(
				originalSize.X.Scale * 0.5,
				originalSize.X.Offset * 0.5,
				originalSize.Y.Scale * 0.5,
				originalSize.Y.Offset * 0.5
			)

			skinReward.Rotation = -8

			-- First little overshoot
			tweenObject(
				skinReward,
				0.35,
				{
					Size = UDim2.new(
						originalSize.X.Scale * 1.08,
						originalSize.X.Offset * 1.08,
						originalSize.Y.Scale * 1.08,
						originalSize.Y.Offset * 1.08
					),
					Rotation = 3
				},
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			)

			task.wait(0.35)

			-- Settle into the normal size
			tweenObject(
				skinReward,
				0.25,
				{
					Size = originalSize,
					Rotation = originalRotation
				},
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
		end)
	end

	-- Outcome text drops in slightly after the panel
	task.delay(0.2, function()
		local outcome = screen.Outcome.UpgradeName

		if outcome then
			local originalPosition = outcome.Position

			outcome.Position = UDim2.new(
				originalPosition.X.Scale,
				originalPosition.X.Offset,
				originalPosition.Y.Scale - 0.08,
				originalPosition.Y.Offset
			)

			tweenObject(outcome, 0.55, {
				Position = originalPosition
			}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end)

	-- Setup exit button event
	local events = ReplicatedStorage:WaitForChild("Events")
	local exitEvent = events:WaitForChild("ExitGame")
	local clicked
	clicked = screen.Return.Upgrade.Upgrade.Activated:Connect(function()
		clicked:Disconnect()
		exitEvent:FireServer()
		screen:TweenPosition(
			UDim2.new(0.5, 0,1.5, 0),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Back,
			0.5,
			true
		)
	end)
end

gui.GameSelectionControls.OpenMapVoting.Button.Activated:Connect(function()
	if gui.Voting.Visible == false then
		gui.Voting.Visible = true
	else
		gui.Voting.Visible = false
	end
end)

gui.GameSelectionControls.OpenModifierVoting.Button.Activated:Connect(function()
	if gui.ModifierVoting.Visible == false then
		gui.ModifierVoting.Visible = true
	else
		gui.ModifierVoting.Visible = false
	end
end)

gui.Voting.MapArea.ButtonArea.CloseMapMenu.Upgrade.Activated:Connect(function()
	if gui.Voting.Visible == true then
		gui.Voting.Visible = false
	end
end)

local function SetupGameGui()
	if not info.GameRunning.Value then
		return
	end

	gui.Voting.Visible = false
	gui.ModeVoting.Visible = false
	gui.Info.GameStats.Health.Visible = true
	gui.Towers.Visible = true

	------------------------------------------------
	-- GAME MODE MESSAGE
	------------------------------------------------

	task.delay(0.1, function()
		local modeGui = gui.Messages.Mode
		modeGui.Visible = true

		local gameModeL =
			modeGui:FindFirstChild(
				info.Gamemode.Value
			)

		if not gameModeL then
			return
		end

		gameModeL.Visible = true

		-- Start state
		local startPos =
			gameModeL.Position
			+ UDim2.fromOffset(0, 10)

		local endPos =
			gameModeL.Position

		gameModeL.Position = startPos
		gameModeL.TextTransparency = 1

		-- Tween IN
		local inInfo =
			TweenInfo.new(
				0.18,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			)

		TweenService:Create(
			gameModeL,
			inInfo,
			{
				Position = endPos,
				TextTransparency = 0
			}
		):Play()

		-- Hold
		task.wait(5)

		-- Tween OUT
		local outInfo =
			TweenInfo.new(
				0.18,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			)

		local outTween =
			TweenService:Create(
				gameModeL,
				outInfo,
				{
					Position =
					endPos
					- UDim2.fromOffset(0, 10),

					TextTransparency = 1
				}
			)

		outTween:Play()
		outTween.Completed:Wait()

		gameModeL.Visible = false
		modeGui.Visible = false
	end)

	------------------------------------------------
	-- MAP HEALTH
	------------------------------------------------

	local map =
		workspace.Map:FindFirstChildOfClass("Folder")

	if map then

		health.Setup(
			map:WaitForChild("Base"),
			gui.Info.GameStats.Health
		)

	else

		workspace.Map.ChildAdded:Connect(function(newMap)

			health.Setup(
				newMap:WaitForChild("Base"),
				gui.Info.GameStats.Health
			)

		end)

	end

	------------------------------------------------
	-- WAVE COUNTER
	------------------------------------------------

	local waveLabel =
		gui.Info.Wave.Count

	local waveUIScale =
		waveLabel:FindFirstChildOfClass("UIScale")

	if not waveUIScale then

		waveUIScale =
			Instance.new("UIScale")

		waveUIScale.Parent =
			waveLabel

		waveUIScale.Scale = 1

	end

	local wavePopInfo =
		TweenInfo.new(
			0.12,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)

	local waveSettleInfo =
		TweenInfo.new(
			0.15,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		)

	info.Wave.Changed:Connect(function(change)

		waveLabel.Text =
			"Wave " .. change

		waveLabel.TextTransparency = 1
		waveUIScale.Scale = 0.8

		local popTween =
			TweenService:Create(
				waveUIScale,
				wavePopInfo,
				{
					Scale = 1.15
				}
			)

		local fadeTween =
			TweenService:Create(
				waveLabel,
				wavePopInfo,
				{
					TextTransparency = 0
				}
			)

		popTween:Play()
		fadeTween:Play()

		popTween.Completed:Wait()

		local settleTween =
			TweenService:Create(
				waveUIScale,
				waveSettleInfo,
				{
					Scale = 1
				}
			)

		settleTween:Play()

	end)

	------------------------------------------------
	-- MONEY
	------------------------------------------------

	local cashLabel =
		gui.OtherGameStats.MoneyBanner.TextLabel

	local cashUIScale =
		cashLabel:FindFirstChildOfClass("UIScale")

	if not cashUIScale then

		cashUIScale =
			Instance.new("UIScale")

		cashUIScale.Parent =
			cashLabel

		cashUIScale.Scale = 1

	end

	local cashPopInfo =
		TweenInfo.new(
			0.12,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)

	local cashSettleInfo =
		TweenInfo.new(
			0.15,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		)

	cash.Changed:Connect(function()

		cashLabel.Text =
			"$" .. Comma(cash.Value)

		cashUIScale.Scale = 0.8

		local popTween =
			TweenService:Create(
				cashUIScale,
				cashPopInfo,
				{
					Scale = 1.05
				}
			)

		popTween:Play()
		popTween.Completed:Wait()

		local settleTween =
			TweenService:Create(
				cashUIScale,
				cashSettleInfo,
				{
					Scale = 1
				}
			)

		settleTween:Play()

	end)

	cashLabel.Text =
		"$" .. Comma(cash.Value)

	------------------------------------------------
	-- TIMER
	------------------------------------------------

	info.Timer.Changed:Connect(function(change)

		gui.Info.Timer.Count.Text =
			change

	end)

	------------------------------------------------
	-- MAX TOWERS
	------------------------------------------------

	gui.OtherGameStats.MaxTowersBanner.TextLabel.Text =
		tostring(placedTowers.Value)
		.. "/"
		.. tostring(getPlacement())

	------------------------------------------------
	-- PLAYER DATA
	------------------------------------------------

	local playerData =
		getDataFunction:InvokeServer()

	if not playerData then
		return
	end

	------------------------------------------------
	-- FIND SKIN FOR TOWER
	------------------------------------------------

	local function getSkinForTower(
		towerName,
		selectedSkins
	)
		if not towerName or typeof(selectedSkins) ~= "table" then
			return nil
		end

		-- New format.
		local direct = selectedSkins[towerName]
		if typeof(direct) == "string" and direct ~= "" and direct ~= "Default" then
			return direct
		end

		-- Legacy array format. Return the original key because TowerIcons
		-- may still be keyed as "Retro Trooper", "Golden Trooper", etc.
		for _, skinName in ipairs(selectedSkins) do
			local appearance = legacySkinToAppearance(towerName, skinName)
			if appearance and appearance ~= "Default" then
				return skinName
			end
		end

		return nil
	end
	------------------------------------------------
	-- GET TOWER ICON
	------------------------------------------------

	local function getTowerIcon(
		towerName,
		skinName
	)

		if not towerName then
			return nil
		end

		local towerIcons =
			TowerIcons[towerName]

		if not towerIcons then
			return nil
		end

		------------------------------------------------
		-- SKIN
		------------------------------------------------

		if skinName then
			if towerIcons[skinName] then
				return towerIcons[skinName].IconID
			end

			-- New appearance key ("Retro") with legacy icon key
			-- ("Retro Trooper").
			local legacyKey = skinName .. " " .. towerName

			if towerIcons[legacyKey] then
				return towerIcons[legacyKey].IconID
			end
		end

		------------------------------------------------
		-- BASE TOWER
		------------------------------------------------

		if towerIcons[towerName] then

			return towerIcons[towerName].IconID

		end

		return nil

	end

	------------------------------------------------
	-- TOWER INSTANCES
	------------------------------------------------

	local TowerViewportType = {
	}

	------------------------------------------------
	-- CREATE SELECTED TOWERS
	------------------------------------------------

	for i, tower in pairs(
		playerData.SelectedTowers
		) do

		------------------------------------------------
		-- FIND ACTUAL TOWER INSTANCE
		------------------------------------------------

		local towerInstance

		if table.find(
			TowerViewportType,
			tower
			)
		then

			local towerFolder =
				ReplicatedStorage.Towers.TowerViewports
				:FindFirstChild(tower)

			if towerFolder then

				towerInstance =
					towerFolder:FindFirstChild(tower)

			end

		else

			towerInstance =
				select(1, getTowerAppearance(tower, playerData))

		end

		------------------------------------------------
		-- FIND EQUIPPED SKIN
		------------------------------------------------

		local equippedSkinName =
			getSkinForTower(
				tower,
				playerData.SelectedSkins
			)

		------------------------------------------------
		-- FIND ICON
		------------------------------------------------

		local iconID =
			getTowerIcon(
				tower,
				equippedSkinName
			)

		------------------------------------------------
		-- MAKE SURE TOWER EXISTS
		------------------------------------------------

		if towerInstance then

			local button =
				gui.Towers.SelectedTowers
				:FindFirstChild("Template")

			local config =
				towerInstance:WaitForChild(
					"Config"
				)

			local placementCost = getPlacementCost(tower, config)

			if button then

				------------------------------------------------
				-- BUTTON NAME
				------------------------------------------------

				button.Name =
					tower

				------------------------------------------------
				-- PATTERN IMAGE
				------------------------------------------------

				local pattern =
					button.Button:FindFirstChild(
						"Pattern"
					)

				if pattern then

					-- Clear previous icon first
					pattern.Image = ""

					if iconID then

						pattern.Image =
							"rbxassetid://"
							.. tostring(iconID)

					else

						warn(
							"No tower icon found for:",
							tower,
							"Skin:",
							equippedSkinName
						)

					end

				end

				------------------------------------------------
				-- PRICE
				------------------------------------------------

				if info.Modifiers[
					"Death Wish"
					].Value == true
				then

					button.Price.Text =
						"$"
						.. Comma(
							math.round(
								placementCost
								* info.Modifiers
								.DeathWishInfo
								.Inflation.Value
							)
						)

				else

					button.Price.Text =
						"$"
						.. Comma(
							placementCost
						)

				end

				------------------------------------------------
				-- LAYOUT
				------------------------------------------------

				button.LayoutOrder =
					i

				button.Parent =
					gui.Towers.SelectedTowers

				------------------------------------------------
				-- MAKE VISIBLE
				------------------------------------------------

				button.Visible = true
				slotAnimator:Register(i, button)

				------------------------------------------------
				-- BUTTON CLICK
				------------------------------------------------

				button.Button.Activated:Connect(function()
					gui.Sounds.Click:Play()

					local requestSerial = beginPlacementRequest()

					requestPlacementForTower(
						tower,
						requestSerial,
						nil,
						i
					)
				end)

			end

		else

			warn(
				"Tower not found:",
				tower
			)

		end

	end
end

info.Timer.Changed:Connect(function(change)
	gui.Info.Timer.Count.Text = change
end)

local function getNextYPosition()
	local highestY = 0.05
	for _, frame in ipairs(gui.BossHealthFrame:GetChildren()) do
		if frame.Name == "Boss" and frame.Visible and frame ~= gui.BossHealthFrame.Boss then
			local frameY = frame.Position.Y.Scale
			if frameY > highestY then
				highestY = frameY
			end
		end
	end
	if highestY > 0.05 then
		return highestY + 0.12
	end
	return 0.05
end

function SetUpBossGui(boss)
	local bossHealth = gui.BossHealthFrame.Boss:Clone()
	bossHealth.Parent = gui.BossHealthFrame

	local targetSize = UDim2.new(0.997, 0, 0.096, 0)
	local targetPosition = UDim2.new(0.5, 0, getNextYPosition(), 0)

	bossHealth.Size = UDim2.new(0, 0, 0.096, 0)
	bossHealth.Position = targetPosition
	bossHealth.AnchorPoint = Vector2.new(0.5, 0.5)
	bossHealth.Visible = true

	local bossHumanoid = boss:FindFirstChild("EnemyStats")
	if not bossHumanoid then
		bossHealth:Destroy()
		return
	end

	bossHealth.Attributes.Hidden.Visible = boss.EnemyStats:FindFirstChild("Hidden") ~= nil
	bossHealth.Attributes.NoCash.Visible = boss.EnemyStats:FindFirstChild("NoCash") ~= nil
	bossHealth.Attributes.Invincible.Visible = boss.EnemyStats:FindFirstChild("Invincible") ~= nil
	bossHealth.Attributes.Lead.Visible = boss.EnemyStats:FindFirstChild("Lead") ~= nil
	bossHealth.Attributes.ExplosionResist.Visible = boss.EnemyStats:FindFirstChild("Lead") ~= nil
	bossHealth.Attributes.NoStun.Visible = boss.EnemyStats:FindFirstChild("NoStun") ~= nil

	local def = boss.EnemyStats:FindFirstChild("Defense")
	if def then
		bossHealth.Attributes.Defense.Visible = true
		bossHealth.Attributes.Defense.Input.Text = def.DefensePercentValue.Value .. "%"
	else
		bossHealth.Attributes.Defense.Visible = false
	end

	local def2 = boss.EnemyStats:FindFirstChild("ExplosionDefense")
	if def2 then
		bossHealth.Attributes.ExplosionResist.Visible = true
		bossHealth.Attributes.ExplosionResist.Input.Text = def2.DefensePercentValue.Value .. "%"
	else
		bossHealth.Attributes.ExplosionResist.Visible = false
	end

	-- === APPEAR ANIMATION ===
	bossHealth.Health.Count.TextTransparency = 1
	bossHealth.Health.Count.UIStroke.Transparency = 1
	bossHealth.Attributes.Size = UDim2.new(0, 0, 0.418, 0)
	for _, desc in ipairs(bossHealth.Attributes:GetDescendants()) do
		if desc:IsA("UIStroke") then
			desc.Enabled = false
		end
	end

	local tweenIn = TweenService:Create(bossHealth,
		TweenInfo.new(1.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = targetSize }
	)
	tweenIn:Play()
	tweenIn.Completed:Connect(function()
		local textFadeIn = TweenService:Create(bossHealth.Health.Count,
			TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		)
		local strokeFadeIn = TweenService:Create(bossHealth.Health.Count.UIStroke,
			TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Transparency = 0 }
		)
		local attributesFadeIn = TweenService:Create(bossHealth.Attributes,
			TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0.438, 0, 0.418, 0) }
		)
		task.wait(0.6)
		textFadeIn:Play()
		strokeFadeIn:Play()
		attributesFadeIn:Play()
		attributesFadeIn.Completed:Connect(function()
			for _, desc in ipairs(bossHealth.Attributes:GetDescendants()) do
				if desc:IsA("UIStroke") then
					desc.Enabled = true
				end
			end
		end)
	end)

	local Shield = bossHumanoid:FindFirstChild("ShieldHealth")

	local healthConnection
	local shieldConnection
	local ancestryConnection
	local isCleaningUp = false

	-- === DISAPPEAR ANIMATION + CLEANUP ===
	local function cleanup()
		if isCleaningUp then return end
		isCleaningUp = true

		if healthConnection then healthConnection:Disconnect() end
		if shieldConnection then shieldConnection:Disconnect() end
		if ancestryConnection then ancestryConnection:Disconnect() end

		if bossHealth and bossHealth.Parent then
			for _, desc in ipairs(bossHealth.Attributes:GetDescendants()) do
				if desc:IsA("UIStroke") then
					desc.Enabled = false
				end
			end

			local textFadeOut = TweenService:Create(bossHealth.Health.Count,
				TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ TextTransparency = 1 }
			)
			local strokeFadeOut = TweenService:Create(bossHealth.Health.Count.UIStroke,
				TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Transparency = 1 }
			)
			local attributesFadeOut = TweenService:Create(bossHealth.Attributes,
				TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0, 0, 0.418, 0) }
			)
			textFadeOut:Play()
			strokeFadeOut:Play()
			attributesFadeOut:Play()
			textFadeOut.Completed:Connect(function()
				local tweenOut = TweenService:Create(bossHealth,
					TweenInfo.new(1.05, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
					{ Size = UDim2.new(0, 0, 0.096, 0) }
				)
				tweenOut:Play()
				tweenOut.Completed:Connect(function()
					if bossHealth then
						bossHealth:Destroy()
					end
				end)
			end)
		end
	end

	local function update()
		if not boss.Parent or bossHumanoid.Health.Value <= 0 then
			cleanup()
			return
		end

		local health = bossHumanoid.Health.Value
		local maxHealth = bossHumanoid.MaxHealth.Value
		local percent = health / maxHealth

		local shieldHealth = 0
		local shieldPercent = 0

		if Shield and Shield.Health.Value > 0 then
			shieldHealth = Shield.Health.Value
			shieldPercent = Shield.Health.Value / Shield.MaxHealth.Value
			bossHealth.Health.ShieldBar.Visible = true
		else
			bossHealth.Health.ShieldBar.Visible = false
		end

		local newSize = UDim2.new(percent, 0, 1, 0)
		local shieldSize = UDim2.new(shieldPercent, 0, 0.5, 0)

		bossHealth.Health.Bar:TweenSize(newSize, Enum.EasingDirection.Out, Enum.EasingStyle.Linear, 0.25, true)
		bossHealth.Health.ShieldBar:TweenSize(shieldSize, Enum.EasingDirection.Out, Enum.EasingStyle.Linear, 0.25, true)

		local totalHealth = health + shieldHealth
		bossHealth.Health.Count.Text =
			string.upper(boss.Name) .. " : " .. Comma(totalHealth) .. " / " .. Comma(maxHealth) .. " HP"
	end

	healthConnection = bossHumanoid.Health.Changed:Connect(update)

	if Shield then
		shieldConnection = Shield.Health.Changed:Connect(update)
	end

	if boss.EnemyStats:FindFirstChild("Defense") then
		boss.EnemyStats.Defense.DefensePercentValue.Changed:Connect(function()
			local d = boss.EnemyStats:FindFirstChild("Defense")
			if d then
				bossHealth.Attributes.Defense.Visible = true
				bossHealth.Attributes.Defense.Input.Text = d.DefensePercentValue.Value .. "%"
			else
				bossHealth.Attributes.Defense.Visible = false
			end
		end)
	end

	local function refreshAttributes()
		bossHealth.Attributes.Hidden.Visible = boss.EnemyStats:FindFirstChild("Hidden") ~= nil
		bossHealth.Attributes.NoCash.Visible = boss.EnemyStats:FindFirstChild("NoCash") ~= nil
		bossHealth.Attributes.Invincible.Visible = boss.EnemyStats:FindFirstChild("Invincible") ~= nil
		bossHealth.Attributes.Lead.Visible = boss.EnemyStats:FindFirstChild("Lead") ~= nil
		bossHealth.Attributes.NoStun.Visible = boss.EnemyStats:FindFirstChild("NoStun") ~= nil
	end

	boss.EnemyStats.ChildAdded:Connect(refreshAttributes)
	boss.EnemyStats.ChildRemoved:Connect(refreshAttributes)

	ancestryConnection = boss.AncestryChanged:Connect(function(_, parent)
		if not parent then
			cleanup()
		end
	end)

	update()
end

local bossEvent = ReplicatedStorage.Events.BossEvent

bossEvent.OnClientEvent:Connect(function(boss)
	SetUpBossGui(boss)
end)

local function SetupVoteGui()
	if not info.Voting.Value then
		return
	end

	gui.Voting.Visible = true

	local events = ReplicatedStorage:WaitForChild("Events")
	local voteEvent = events:WaitForChild("VoteForMap")
	local voteCountUpdate = events:WaitForChild("UpdateVoteCount")
	local maps = gui.Voting.MapArea.MapFrame:GetChildren()

	for i, button in ipairs(maps) do
		if button:IsA("Frame") then
			local VoteButton = button:FindFirstChild("VoteButton")
			VoteButton:FindFirstChild("Activate").Activated:Connect(function()
				voteEvent:FireServer(button.Name)
			end)
		end
	end

	voteCountUpdate.OnClientEvent:Connect(function(mapScores)
		for name, voteInfo in pairs(mapScores) do
			local button = gui.Voting.MapArea.MapFrame:FindFirstChild(name)
			local VoteButton = button:FindFirstChild("VoteButton")
			if VoteButton then
				VoteButton.TextLabel.Text = "VOTE [" .. #voteInfo .. "]"
			end
		end
	end)
end

local function SetupModifierVoteGui()
	if not info.ModifierVoting.Value then
		return
	end

	local plrCount = info.PlrValue.Value
	local playerSlots = {
		gui.GameSelectionControls.OpenModifierVoting.Players.One,
		gui.GameSelectionControls.OpenModifierVoting.Players.Two,
		gui.GameSelectionControls.OpenModifierVoting.Players.Three,
		gui.GameSelectionControls.OpenModifierVoting.Players.Four
	}

	-- Show player slots based on player count
	for i, slot in ipairs(playerSlots) do
		slot.Visible = i <= plrCount
	end

	local PlrVotes = 0
	local votedPlayers = {}

	local events = ReplicatedStorage:WaitForChild("Events")
	local voteEvent = events:WaitForChild("VoteForModifier")
	local voteCountUpdate = events:WaitForChild("UpdateModifierVoteCount")
	local buttons = {}

	for _, v in ipairs(gui.ModifierVoting.Modifers.Top:GetChildren()) do
		table.insert(buttons, v)
	end

	for _, v in ipairs(gui.ModifierVoting.Modifers.Bottom:GetChildren()) do
		table.insert(buttons, v)
	end

	local voteColors = {
		Color3.fromRGB(255, 0, 0),
		Color3.fromRGB(0, 85, 255),
		Color3.fromRGB(0, 170, 0),
		Color3.fromRGB(255, 255, 0)
	}

	local function UpdatePlayerVotes()
		for i, slot in ipairs(playerSlots) do
			if i <= PlrVotes then
				slot.ImageColor3 = voteColors[i]
			else
				slot.ImageColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end

	for _, button in ipairs(buttons) do
		if button:IsA("Frame") then
			local VoteButton = button:FindFirstChild("VoteButton")

			VoteButton:FindFirstChild("Activate").Activated:Connect(function()
				local player = game.Players.LocalPlayer

				-- Always allow voting
				voteEvent:FireServer(button.Name)


				gui.ModifierVoting.Info.Title.TitleText.Text = "" .. button.Name .. " Info"


				for _, ModInfo in ipairs(gui.ModifierVoting.Info.Extra:GetChildren()) do
					if ModInfo:IsA("Frame") then
						ModInfo.Visible = (ModInfo.Name == button.Name)
					end
				end

				-- Only count the player once for the player indicator
				if not votedPlayers[player.Name] then
					votedPlayers[player.Name] = true
					PlrVotes += 1

					print("Players voted:", PlrVotes)
					UpdatePlayerVotes()
				end
			end)
		end
	end

	voteCountUpdate.OnClientEvent:Connect(function(scores)
		for name, voteInfo in pairs(scores) do
			local button =
				gui.ModifierVoting.Modifers.Top:FindFirstChild(name)
				or gui.ModifierVoting.Modifers.Bottom:FindFirstChild(name)

			if button then
				local voteButton = button:FindFirstChild("VoteButton")
				if voteButton then
					voteButton.TextLabel.Text = "VOTE [" .. #voteInfo .. "]"
				end
			end
		end
	end)
end

local function SetupModeVoteGui()
	if not info.GamemodeVoting.Value then
		return
	end
	gui.Voting.Visible = false
	gui.GameSelectionControls.Visible = false
	gui.ModeVoting.Visible = true
	gui.ModifierVoting.Visible = false
	local events = ReplicatedStorage:WaitForChild("Events")
	local voteEvent = events:WaitForChild("VoteForMode")
	local voteCountUpdate = events:WaitForChild("UpdateModeVoteCount")
	local modes = gui.ModeVoting.Modes:GetChildren()

	for i, button in ipairs(modes) do
		if button:IsA("Frame") then
			button.Button.Activated:Connect(function()
				voteEvent:FireServer(button.Name)
			end)
		end
	end

	voteCountUpdate.OnClientEvent:Connect(function(mapScores)
		for name, voteInfo in pairs(mapScores) do
			local button = gui.ModeVoting.Modes:FindFirstChild(name)
			if button then
				button.VoteCount.Text = #voteInfo
			end
		end
	end)
end
local function LoadGui()
	local TweenService = game:GetService("TweenService")

	local messageFrame = gui.Info.Messages
	local messageText = messageFrame.ActualMessage.Message

	local tweenTime = 0.4
	local introTweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local outroTweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

	local originalPosition = messageFrame.Position
	local hiddenPosition = originalPosition - UDim2.new(0, 0, 1.3, 0)

	messageFrame.Position = hiddenPosition
	messageFrame.Visible = false

	local function playIntro()
		messageFrame.Visible = true
		local tween = TweenService:Create(messageFrame, introTweenInfo, { Position = originalPosition })
		tween:Play()
	end

	local function playOutro(callback)
		local tween = TweenService:Create(messageFrame, outroTweenInfo, { Position = hiddenPosition })
		tween:Play()
		tween.Completed:Connect(function()
			messageFrame.Visible = false
			if callback then callback() end
		end)
	end

	messageText.Text = info.Message.Value

	info.Message.Changed:Connect(function(change)
		messageText.Text = change

		if change == "" then
			task.delay(2, function()
				playOutro()
			end)
		else
			playIntro()
			task.delay(2, function()
				playOutro()
			end)

			if change == "VICTORY" or change == "GAME OVER" and GameWrapUp == false then
				DisplayEndScreen(change)
			end
		end
	end)



	SetupVoteGui()
	SetupModifierVoteGui()
	SetupModeVoteGui()
	SetupGameGui()

	info.GameRunning.Changed:Connect(SetupGameGui)
	info.Voting.Changed:Connect(SetupVoteGui)
	info.ModifierVoting.Changed:Connect(SetupModifierVoteGui)
	info.GamemodeVoting.Changed:Connect(SetupModeVoteGui)
end

LoadGui()
