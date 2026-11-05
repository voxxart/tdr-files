local Info = workspace:WaitForChild("Info")
local Modifiers = Info:WaitForChild("Modifiers")

local LastLifeModifier = Modifiers:WaitForChild("Last Life")
local DoubleEnemyHPModifier = Modifiers:WaitForChild("Double HP")
local DeathWishModifier = Modifiers:WaitForChild("Death Wish")
local ReducedPlacement = Modifiers:WaitForChild("Reduced Placement")
local GenerousFarms = Modifiers:WaitForChild("Generous Farms")
local CheaperUpgrades = Modifiers:WaitForChild("Cheaper Upgrades")
local IncreasedBaseHP = Modifiers:WaitForChild("Extra Lives")
local MoreStartingCash = Modifiers:WaitForChild("More Starting Cash")

local Rep = game:GetService("ReplicatedStorage")
local DeathWishLighting = Rep:WaitForChild("Particle"):WaitForChild("DeathWishLighting")

local Ambience = workspace:WaitForChild("Ambience")
local DeathAmbience = Ambience:WaitForChild("DeathWish")

local baseEnemyHPMulti = 1
local BasePlacement = 1

local originalHealth
local originalMaxHealth
local originalOverheal

local ActiveDeathLighting

local DeathWishCashGiven = {}
local StartingCashGiven = {}

local OriginalInflation
local OriginalEcoDebuff


---------------------------------------------------
-- GET BASE STATS
---------------------------------------------------

local function getBase()
	local map = workspace:WaitForChild("Map")

	local folder = map:FindFirstChildOfClass("Folder")
	while not folder do
		task.wait(0.5)
		folder = map:FindFirstChildOfClass("Folder")
	end

	local base = folder:WaitForChild("Base", 10)
	if not base then
		return nil
	end

	return base:WaitForChild("EnemyStats", 10)
end


---------------------------------------------------
-- LAST LIFE / EXTRA LIVES
---------------------------------------------------

local function SaveOriginalHealth(stats)

	if originalMaxHealth then
		return
	end

	originalHealth = stats.Health.Value
	originalMaxHealth = stats.MaxHealth.Value

	local overheal = stats:FindFirstChild("OverHealMaxHealth")

	if overheal then
		originalOverheal = overheal.Value
	end

end


local function ApplyLastLife()

	local stats = getBase()
	if not stats then return end

	SaveOriginalHealth(stats)

	local overheal = stats:FindFirstChild("OverHealMaxHealth")

	stats.Health.Value = 1
	stats.MaxHealth.Value = 1

	if overheal then
		overheal.Value = 3
	end

end


local function ApplyExtraLife()

	local stats = getBase()
	if not stats then return end

	SaveOriginalHealth(stats)

	local overheal = stats:FindFirstChild("OverHealMaxHealth")

	stats.Health.Value = 450
	stats.MaxHealth.Value = 450

	if overheal then
		overheal.Value = 1350
	end

end


local function RemoveHealthModifier()

	local stats = getBase()
	if not stats then return end

	if originalMaxHealth then

		stats.MaxHealth.Value = originalMaxHealth
		stats.Health.Value = originalHealth or originalMaxHealth

		local overheal = stats:FindFirstChild("OverHealMaxHealth")

		if overheal and originalOverheal then
			overheal.Value = originalOverheal
		end

	end


	originalHealth = nil
	originalMaxHealth = nil
	originalOverheal = nil

end

local function UpdateGenerousFarms()

	local farmModifier = workspace.Info.Modifiers.GenerousFarms:FindFirstChild("FarmModifierBuff")

	if not farmModifier then
		return
	end

	if GenerousFarms.Value then
		print("modifier active")
		farmModifier.Value = 1.3
	else
		print("modifier not active")
		farmModifier.Value = 1
	end

end



local function UpdateLastLife()

	if LastLifeModifier.Value then

		ApplyLastLife()

	elseif not IncreasedBaseHP.Value then

		RemoveHealthModifier()

	end

end


local function UpdateMoreLife()

	if IncreasedBaseHP.Value then

		ApplyExtraLife()

	elseif not LastLifeModifier.Value then

		RemoveHealthModifier()

	end

end

---------------------------------------------------
-- DEATH WISH EFFECTS
---------------------------------------------------

local function EnableDeathWishEffects()

	if not ActiveDeathLighting then

		ActiveDeathLighting = DeathWishLighting:Clone()
		ActiveDeathLighting.Name = "DeathWishLighting"
		ActiveDeathLighting.Parent = game.Lighting

		for _, child in ipairs(ActiveDeathLighting:GetChildren()) do
			child.Parent = game.Lighting
		end

		ActiveDeathLighting:Destroy()


		game.Lighting.TimeOfDay = 0
		game.Lighting.Ambient = Color3.fromRGB(100,100,100)
		game.Lighting.Brightness = 1
		game.Lighting.ColorShift_Top = Color3.fromRGB(0,0,0)
		game.Lighting.ColorShift_Bottom = Color3.fromRGB(0,0,0)
		game.Lighting.EnvironmentDiffuseScale = 1
		game.Lighting.EnvironmentSpecularScale = 1
		game.Lighting.OutdoorAmbient = Color3.fromRGB(70,70,70)

	end


	DeathAmbience.Playing = true


	for _, audio in ipairs(Ambience:GetChildren()) do

		if audio:IsA("Sound") and audio ~= DeathAmbience then
			audio.Playing = false
		end

	end

end



local function DisableDeathWishEffects()

	if ActiveDeathLighting then
		ActiveDeathLighting:Destroy()
		ActiveDeathLighting = nil
	end


	DeathAmbience.Playing = false

end



---------------------------------------------------
-- ECONOMY MODIFIERS
---------------------------------------------------

local function UpdateStartingCash()

	if MoreStartingCash.Value then

		for _, plr in ipairs(game.Players:GetPlayers()) do

			local cash = plr:FindFirstChild("Cash")

			if cash and not StartingCashGiven[plr] then

				cash.Value += 400
				StartingCashGiven[plr] = true

			end

		end

	else

		table.clear(StartingCashGiven)

	end

end



local function UpdateUpgradeModifiers()

	local modifierFolder = Info:FindFirstChild("Modifier")

	if not modifierFolder then
		return
	end


	local deathWishInfo = modifierFolder:FindFirstChild("DeathWishInfo")

	if not deathWishInfo then
		return
	end


	local inflation = deathWishInfo:FindFirstChild("Inflation")
	local ecoDebuff = deathWishInfo:FindFirstChild("EcoDebuff")


	if inflation then

		if OriginalInflation == nil then
			OriginalInflation = inflation.Value
		end


		if CheaperUpgrades.Value then

			inflation.Value = 0.7

		else

			inflation.Value = OriginalInflation

		end

	end



	if ecoDebuff then

		if OriginalEcoDebuff == nil then
			OriginalEcoDebuff = ecoDebuff.Value
		end


		if GenerousFarms.Value then

			ecoDebuff.Value = 1.3

		else

			ecoDebuff.Value = OriginalEcoDebuff

		end

	end

end



---------------------------------------------------
-- HP MULTIPLIER
---------------------------------------------------

local function UpdateHPMultiplier()

	local multi = Info:FindFirstChild("EnemyHPMultiplier")

	if not multi then
		return
	end


	local value = baseEnemyHPMulti



	if DeathWishModifier.Value then


		value += (0.125 * Info.PlrValue.Value)


		task.delay(5 / Info.GameSpeed.Value, function()

			if DeathWishModifier.Value then
				EnableDeathWishEffects()
			end

		end)



		ApplyLastLife()



		for _, plr in ipairs(game.Players:GetPlayers()) do

			if plr:FindFirstChild("Cash") and not DeathWishCashGiven[plr] then

				plr.Cash.Value += 450
				DeathWishCashGiven[plr] = true

			end

		end


	else


		DisableDeathWishEffects()


		table.clear(DeathWishCashGiven)


		if not LastLifeModifier.Value then
			RemoveHealthModifier()
		end

	end



	if DoubleEnemyHPModifier.Value then
		value *= 2
	end



	multi.Value = value

end



---------------------------------------------------
-- PLACEMENT REDUCTION
---------------------------------------------------

local function UpdatePlacement()

	local placementInfo = Modifiers:WaitForChild("PlacementInfo")

	local placementModified = placementInfo:FindFirstChild("PlacementModified")

	if not placementModified then
		return
	end



	local value = BasePlacement



	if ReducedPlacement.Value or DeathWishModifier.Value then

		value = 0.75

	end



	placementModified.Value = value

end



---------------------------------------------------
-- CONNECTIONS
---------------------------------------------------

LastLifeModifier:GetPropertyChangedSignal("Value"):Connect(UpdateLastLife)

IncreasedBaseHP:GetPropertyChangedSignal("Value"):Connect(UpdateMoreLife)

DeathWishModifier:GetPropertyChangedSignal("Value"):Connect(UpdateHPMultiplier)

DeathWishModifier:GetPropertyChangedSignal("Value"):Connect(UpdatePlacement)

DoubleEnemyHPModifier:GetPropertyChangedSignal("Value"):Connect(UpdateHPMultiplier)

ReducedPlacement:GetPropertyChangedSignal("Value"):Connect(UpdatePlacement)

MoreStartingCash:GetPropertyChangedSignal("Value"):Connect(UpdateStartingCash)

CheaperUpgrades:GetPropertyChangedSignal("Value"):Connect(UpdateUpgradeModifiers)

GenerousFarms:GetPropertyChangedSignal("Value"):Connect(UpdateGenerousFarms)


---------------------------------------------------
-- PLAYER CONNECTION
---------------------------------------------------

game.Players.PlayerAdded:Connect(function(plr)

	task.wait(1)


	if MoreStartingCash.Value then

		local cash = plr:FindFirstChild("Cash")

		if cash and not StartingCashGiven[plr] then

			cash.Value += 400
			StartingCashGiven[plr] = true

		end

	end

end)



---------------------------------------------------
-- INITIAL LOAD
---------------------------------------------------

UpdateLastLife()

UpdateMoreLife()

UpdateHPMultiplier()

UpdatePlacement()

UpdateStartingCash()

UpdateUpgradeModifiers()

UpdateGenerousFarms()