--// TOWER SERVER — optimised
--// Key fixes vs original:
--//  • FindTarget uses squared distance + cached MobSet (no GetChildren per call)
--//  • Heartbeat uses os_clock (not time()), skips cooldownVal when not needed
--//  • Cowboy removed from Heartbeat loop (DoAttackLogic already calls it)
--//  • target:Destroy() removed from DoAttackLogic (mob.Move owns destruction)
--//  • Cash reward uses Players:GetPlayers() result cached per-wave
--//  • Splash/Flamethrower receive the mob snapshot instead of re-fetching
--//  • Secondary attack guarded with isBursting flag to prevent thread spam
--//  • FireRateSupport/DamageSupport ChildAdded uses AncestryChanged guard
--//  • SellLocks cleaned up in a finally-style pattern
--//  • PlayerMutex/PlacementLocks/PendingPlacements cleaned on player leave
--//  • isInsideBorder uses TowerSet instead of GetChildren
--//  • SharedSlowedEnemies decay moved to a single shared Heartbeat

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace      = game:GetService("Workspace")
local Debris         = game:GetService("Debris")
local UnitMod        = require(game.ServerScriptService.Main.Unit)
local MineMod 		 = require(game.ServerScriptService.Main.Mine)

local TowerSystemFolder = game.ServerScriptService:WaitForChild("TowerSystem")
local TowerStats = require(TowerSystemFolder:WaitForChild("TowerStats"))
local TowerAppearance = require(TowerSystemFolder:WaitForChild("TowerAppearance"))
local SupportService = require(TowerSystemFolder:WaitForChild("SupportService"))
local TowerRuntime = require(TowerSystemFolder:WaitForChild("TowerRuntime"))
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Targeting = require(TowerSystemFolder:WaitForChild("Targeting"))
local SecondaryAttack = require(TowerSystemFolder:WaitForChild("SecondaryAttack"))
local BurstAttack = require(TowerSystemFolder:WaitForChild("BurstAttack"))
local PrimaryAttack = require(TowerSystemFolder:WaitForChild("PrimaryAttack"))
local CombatScheduler = require(TowerSystemFolder:WaitForChild("CombatScheduler"))
local ProjectileService = require(TowerSystemFolder:WaitForChild("ProjectileService"))

local task_spawn = task.spawn
local task_defer = task.defer
local task_delay = task.delay
local task_wait  = task.wait
local os_clock   = os.clock
local math_max   = math.max
local math_min   = math.min
local math_clamp = math.clamp
local math_round = math.round
local math_huge  = math.huge
local math_abs   = math.abs
local math_sqrt  = math.sqrt
local math_random = math.random

local events    = ReplicatedStorage:WaitForChild("Events")
local functions = ReplicatedStorage:WaitForChild("Functions")

-- Reaper summon requests (one RemoteEvent for every summon button).
local ReaperSpawn = events:FindFirstChild("ReaperSpawn")
if not ReaperSpawn then
	ReaperSpawn = Instance.new("RemoteEvent")
	ReaperSpawn.Name = "ReaperSpawn"
	ReaperSpawn.Parent = events
end
assert(ReaperSpawn:IsA("RemoteEvent"), "Events.ReaperSpawn must be a RemoteEvent")

-- Single event for max-summon casting: Start -> Lightning -> End.
-- Cosmetic events only; attack suppression is enforced by the server.
local ReaperSummonFX = events:FindFirstChild("ReaperSummonFX")
if not ReaperSummonFX then
	ReaperSummonFX = Instance.new("RemoteEvent")
	ReaperSummonFX.Name = "ReaperSummonFX"
	ReaperSummonFX.Parent = events
end
assert(ReaperSummonFX:IsA("RemoteEvent"), "Events.ReaperSummonFX must be a RemoteEvent")


local animateTowerEvent    = events:WaitForChild("AnimateTower")
local ReplicateEffectsEvent = events:WaitForChild("ReplicateEffects")
local ErrorEvent           = ReplicatedStorage.Events:WaitForChild("Error")

local spawnTowerFunction   = functions:WaitForChild("SpawnTower")
local requestTowerFunction = functions:WaitForChild("RequestTower")
local sellTowerFunction    = functions:WaitForChild("SellTower")
local changeModeFunction   = functions:WaitForChild("ChangeTowerMode")

repeat task.wait() until _G.DataStore and _G.DataStore.GetPlayerData
local PlayerDataModule = _G.DataStore

local CommanderBuff  = ReplicatedStorage.Events:WaitForChild("CommanderBuff")
local ParticleFolder = ReplicatedStorage:WaitForChild("Particle")

local Info            = Workspace:WaitForChild("Info")
local TowersWorkspace = Workspace:WaitForChild("Towers")
local MobsFolder      = Workspace:WaitForChild("Mobs")
local TowersFolder    = ReplicatedStorage:WaitForChild("Towers")
local MinesFolder = ReplicatedStorage:WaitForChild("Mines")

local DeathWishModifier = Info.Modifiers["Death Wish"]
local DeathWishInfo     = Info.Modifiers.DeathWishInfo
local applyDeathWishRange -- assigned later, after FireRateManager exists
local FireRateManager, DamageManager -- forward-declared so upgrade logic can trigger recomputation

local function getAbilityCooldownMultiplier()
	if DeathWishModifier.Value == true and DeathWishInfo:FindFirstChild("AbilityBuffer") then
		return DeathWishInfo.AbilityBuffer.Value
	end
	return 1
end

local function getAbilityNerfFactor()
	if DeathWishModifier.Value == true and DeathWishInfo:FindFirstChild("AbilityNerf") then
		return DeathWishInfo.AbilityNerf.Value
	end
	return 1
end

local function getEcoDebuffMultiplier()
	if DeathWishModifier.Value == true and DeathWishInfo:FindFirstChild("EcoDebuff") then
		return DeathWishInfo.EcoDebuff.Value - ((Info.PlrValue.Value - 1) * 0.05)
	end
	return 1
end

-- Scales how far a multiplier sits above 1.0 by the nerf factor, so a
-- 1.325 firerate buff at AbilityNerf = 0.5 becomes 1.1625, not a flat
-- percentage subtracted off. A nerf of 1 = no change.
local function effectiveBuffMultiplier(raw)
	return 1 + (raw - 1) * getAbilityNerfFactor()
end

local tower  = {}
local Towers = {}   -- [model] = data table

function Comma(Amount)
	while true do
		Amount, k = string.gsub(Amount, "^(-?%d+)(%d%d%d)", '%1,%2')
		if (k == 0) then
			break
		end
	end
	return Amount
end

-- ============================================================
-- GAME SPEED (cached)
-- ============================================================
local GameSpeedValue = Info:FindFirstChild("GameSpeed")
local GAME_SPEED = 1
if GameSpeedValue then
	GAME_SPEED = (GameSpeedValue.Value ~= 0 and GameSpeedValue.Value) or 1
	GameSpeedValue:GetPropertyChangedSignal("Value"):Connect(function()
		GAME_SPEED = (GameSpeedValue.Value ~= 0 and GameSpeedValue.Value) or 1
	end)
end

local function getGameSpeed() return math_max(GAME_SPEED, 0.0001) end

-- ============================================================
-- LIVE MOB SET  (replaces GetChildren() in FindTarget hot path)
-- ============================================================
local MobSet = {}
for _, m in ipairs(MobsFolder:GetChildren()) do MobSet[m] = true end
MobsFolder.ChildAdded:Connect(function(m)   MobSet[m] = true  end)
MobsFolder.ChildRemoved:Connect(function(m) MobSet[m] = nil   end)

-- ============================================================
-- PASSIVE TOWER HEALTH REGEN
--
-- Rules:
--   • A tower must go 5 real seconds without losing HP.
--   • After that, it regenerates 1% of its CURRENT MaxHealth per second.
--   • Any later HP loss immediately restarts the 5-second delay.
--   • Healing (Medic/Tree/etc.) and regen itself do NOT restart the delay.
--   • Dead towers (HP <= 0) are never revived.
--
-- Performance:
--   • ONE shared 1-second loop for every tower.
--   • ONE Value-change connection per tower, only to timestamp real HP loss.
--   • No Heartbeat/RenderStepped work and no per-tower regen threads.
--   • ChildRemoved always disconnects the health connection, preventing leaks.
-- ============================================================
local TOWER_REGEN_DELAY    = 5
local TOWER_REGEN_PERCENT  = 0.01
local TOWER_REGEN_INTERVAL = 1

-- Weak keys are an extra safety net. Towers are still explicitly removed and
-- their connections disconnected as soon as they leave Workspace.Towers.
local TowerRegenStates = setmetatable({}, { __mode = "k" })

-- ============================================================
-- SERVER-AUTHORITATIVE TREE STUN SHIELDS
--
-- The old Tree implementation tried to cancel a stun from a Config.ChildAdded
-- listener. The global stun system has its own ChildAdded listener, so callback
-- order could let the stun start before Tree got a chance to set Stunned = 0.
--
-- This registry lets the stun system check the shield BEFORE applying any stun.
-- It is also used by the HP protection path so shielded damage is treated as
-- blocked damage rather than real tower damage.
-- ============================================================
local ActiveTowerStunShields = setmetatable({}, { __mode = "k" })

local function registerTowerStunShield(towerModel, consumeCallback)
	if not (towerModel and consumeCallback) then
		return
	end

	local bucket = ActiveTowerStunShields[towerModel]
	if not bucket then
		bucket = {}
		ActiveTowerStunShields[towerModel] = bucket
	end

	bucket[consumeCallback] = true
end

local function unregisterTowerStunShield(towerModel, consumeCallback)
	local bucket = ActiveTowerStunShields[towerModel]
	if not bucket then
		return
	end

	if consumeCallback then
		bucket[consumeCallback] = nil
	end

	if next(bucket) == nil then
		ActiveTowerStunShields[towerModel] = nil
	end
end

local function hasActiveTowerStunShield(towerModel)
	local bucket = ActiveTowerStunShields[towerModel]
	return bucket ~= nil and next(bucket) ~= nil
end

local function consumeTowerStunShields(towerModel, reason)
	local bucket = ActiveTowerStunShields[towerModel]
	if not bucket then
		return false
	end

	-- Copy first because each callback unregisters itself while being consumed.
	local callbacks = {}
	for callback in pairs(bucket) do
		callbacks[#callbacks + 1] = callback
	end

	if #callbacks == 0 then
		ActiveTowerStunShields[towerModel] = nil
		return false
	end

	for _, callback in ipairs(callbacks) do
		local ok, err = pcall(callback, reason)
		if not ok then
			warn("[Tree StunShield] Failed to consume shield:", err)
		end
	end

	return true
end

local function unregisterTowerRegen(towerModel)
	local state = TowerRegenStates[towerModel]
	if not state then
		return
	end

	TowerRegenStates[towerModel] = nil

	if state.HealthConnection then
		state.HealthConnection:Disconnect()
		state.HealthConnection = nil
	end
end

local function registerTowerRegen(towerModel)
	if not towerModel
		or not towerModel:IsA("Model")
		or TowerRegenStates[towerModel]
	then
		return
	end

	local config = towerModel:FindFirstChild("Config")
	local healthFolder = config and config:FindFirstChild("Health")
	local healthValue = healthFolder and healthFolder:FindFirstChild("HealthValue")
	local maxHealthValue = healthFolder and healthFolder:FindFirstChild("MaxHealth")

	if not (
		healthValue
			and maxHealthValue
			and healthValue:IsA("ValueBase")
			and maxHealthValue:IsA("ValueBase")
		) then
		return
	end

	local now = os_clock()
	local state = {
		Health = healthValue,
		MaxHealth = maxHealthValue,
		LastHealth = healthValue.Value,

		-- Normally a newly placed tower starts at full HP, so this value
		-- does not matter until damage occurs. If this script happens to
		-- register an already-damaged tower, make it wait the full delay.
		LastDamage = (healthValue.Value < maxHealthValue.Value)
			and now
			or -math_huge,
		HealthConnection = nil,
	}

	TowerRegenStates[towerModel] = state

	state.HealthConnection =
		healthValue:GetPropertyChangedSignal("Value"):Connect(function()
			local currentHealth = healthValue.Value
			local previousHealth = state.LastHealth

			-- Only an actual, unshielded HP decrease counts as damage.
			-- Tree stun shields restore blocked damage immediately, so a hit
			-- absorbed by one should not restart passive regen either.
			if currentHealth < previousHealth then
				if not hasActiveTowerStunShield(towerModel) then
					state.LastDamage = os_clock()
				end
			end

			state.LastHealth = currentHealth
		end)
end

-- One shared low-frequency worker. Even at the maximum practical tower count,
-- this is only a small handful of numeric checks per tower once each second.
task_spawn(function()
	while true do
		task_wait(TOWER_REGEN_INTERVAL / GameSpeedValue.Value)

		local now = os_clock()

		for towerModel, state in pairs(TowerRegenStates) do
			-- ChildRemoved normally handles this immediately. These checks are
			-- intentional fallback protection if another script destroys pieces
			-- of a tower in an unusual order.
			if not towerModel:IsDescendantOf(TowersWorkspace)
				or not state.Health.Parent
				or not state.MaxHealth.Parent
			then
				unregisterTowerRegen(towerModel)
				continue
			end

			local health = state.Health.Value
			local maxHealth = state.MaxHealth.Value

			-- Never revive dead towers, and do nothing for invalid/full HP.
			if health <= 0
				or maxHealth <= 0
				or health >= maxHealth
			then
				continue
			end

			-- Taking damage always pushes regen back another 5 seconds.
			if (now - state.LastDamage) < TOWER_REGEN_DELAY / GameSpeedValue.Value then
				continue
			end

			local regenAmount = maxHealth * TOWER_REGEN_PERCENT
			local newHealth = math_min(health + regenAmount, maxHealth)

			-- Keep the comparison snapshot synchronized BEFORE writing the
			-- Value. This guarantees the regen write itself can never look like
			-- damage, even if signal callbacks are resumed slightly later.
			state.LastHealth = newHealth
			state.Health.Value = newHealth
		end
	end
end)

-- ============================================================
-- REAPER SOUL COLLECTION (SERVER-AUTHORITATIVE)
--
-- Earn one soul per Config.Reaper.SoulCollectionRate damage added to
-- Config.TotalDamage, with a hard cap of Config.Reaper.MaxSouls.
-- Damage earned while at the cap is discarded, NOT banked. Spending souls
-- therefore does not re-credit old damage. Unfinished damage only carries
-- over while the tower has room for more souls.
--
-- Connections are per Reaper; no polling or extra Heartbeat workers.
-- ============================================================
local ReaperSoulTracking = setmetatable({}, {__mode = "k"})

local function unregisterReaperSoulTracking(model)
	local state = ReaperSoulTracking[model]
	if not state then return end
	ReaperSoulTracking[model] = nil
	for _, connection in ipairs(state.Connections) do
		connection:Disconnect()
	end
end

local function registerReaperSoulTracking(model)
	if not model or not model:IsA("Model") or ReaperSoulTracking[model] then return end
	local config = model:FindFirstChild("Config")
	local reaper = config and config:FindFirstChild("Reaper")
	if not reaper then return end

	local totalDamage = config:FindFirstChild("TotalDamage")
	local souls = reaper:FindFirstChild("Souls")
	local rate = reaper:FindFirstChild("SoulCollectionRate")
	local maxSouls = reaper:FindFirstChild("MaxSouls")

	local function numericValue(value)
		return value and (value:IsA("IntValue") or value:IsA("NumberValue"))
	end
	if not (numericValue(totalDamage) and numericValue(souls) and numericValue(rate)) then return end
	if not numericValue(maxSouls) then
		warn("[Reaper] Config.Reaper.MaxSouls (IntValue/NumberValue) is missing from", model.Name)
		return
	end

	local function getCap()
		local cap = maxSouls.Value
		if cap ~= cap or cap == math.huge then return 0 end
		return math_max(0, math.floor(cap))
	end

	-- If an upgrade lowers MaxSouls (or another script adjusts Souls),
	-- immediately clamp the stored value. This never creates any souls.
	local function clampSouls()
		local cap = getCap()
		local value = math_clamp(souls.Value, 0, cap)
		if souls.Value ~= value then
			souls.Value = value
		end
		return value, cap
	end

	local startingDamage = math_max(0, totalDamage.Value)
	local startingRate = rate.Value
	local state = {
		LastTotal = startingDamage,
		Remainder = startingRate > 0 and startingRate < math_huge
			and (startingDamage % startingRate) or 0,
		Connections = {},
	}
	ReaperSoulTracking[model] = state

	local initialSouls, initialCap = clampSouls()
	if initialSouls >= initialCap then
		state.Remainder = 0
	end

	local function settleSouls()
		if ReaperSoulTracking[model] ~= state or model.Parent ~= TowersWorkspace then return end

		local currentTotal = totalDamage.Value
		if currentTotal ~= currentTotal or currentTotal == math_huge then return end
		currentTotal = math_max(0, currentTotal)
		local delta = currentTotal - state.LastTotal
		state.LastTotal = currentTotal

		if delta < 0 then
			state.Remainder = 0
			return
		end

		local currentSouls, cap = clampSouls()
		if currentSouls >= cap then
			-- Do not bank damage while full. Prevents souls popping in
			-- from previously earned damage after the next summon.
			state.Remainder = 0
			return
		end

		local required = rate.Value
		if required <= 0 or required ~= required or required == math.huge then return end
		state.Remainder += delta
		local earned = math.floor(state.Remainder / required)
		if earned <= 0 then return end

		state.Remainder -= earned * required
		souls.Value = math_min(cap, currentSouls + earned)
		if souls.Value >= cap then
			-- Any excess from the hit that filled the meter is lost.
			state.Remainder = 0
		end
	end

	table.insert(state.Connections, totalDamage:GetPropertyChangedSignal("Value"):Connect(settleSouls))
	table.insert(state.Connections, rate:GetPropertyChangedSignal("Value"):Connect(settleSouls))
	table.insert(state.Connections, souls:GetPropertyChangedSignal("Value"):Connect(function()
		if ReaperSoulTracking[model] ~= state then return end
		local current, cap = clampSouls()
		if current >= cap then state.Remainder = 0 end
	end))
	table.insert(state.Connections, maxSouls:GetPropertyChangedSignal("Value"):Connect(function()
		if ReaperSoulTracking[model] ~= state then return end
		local current, cap = clampSouls()
		if current >= cap then state.Remainder = 0 end
	end))
end

-- ============================================================
-- LIVE TOWER SET  (for border checks, avoids GetChildren)
-- ============================================================
local TowerSet = {}
for _, t in ipairs(TowersWorkspace:GetChildren()) do
	TowerSet[t] = true
	registerTowerRegen(t)
	registerReaperSoulTracking(t)
end

TowersWorkspace.ChildAdded:Connect(function(t)
	TowerSet[t] = true
	registerTowerRegen(t)
	registerReaperSoulTracking(t)
end)

TowersWorkspace.ChildRemoved:Connect(function(t)
	unregisterReaperSoulTracking(t)
	unregisterTowerRegen(t)
	ActiveTowerStunShields[t] = nil
	TowerSet[t] = nil
	Towers[t]   = nil  -- also unregister from scheduler
end)

-- ============================================================
-- CACHED PLAYER LIST  (refreshed on join/leave only)
-- ============================================================
local CachedPlayers = Players:GetPlayers()
Players.PlayerAdded:Connect(function()   CachedPlayers = Players:GetPlayers() end)
Players.PlayerRemoving:Connect(function() CachedPlayers = Players:GetPlayers() end)

-- ============================================================
-- PLACEMENT LIMITS
-- ============================================================
local PlrValue = Info:WaitForChild("PlrValue")
local PlacementModified = workspace.Info.Modifiers.PlacementInfo.PlacementModified

local baseLimits = {
	[1] = 40,
	[2] = 30,
	[3] = 25,
	[4] = 20,
	[5] = 15,
	[6] = 15,
}

local function getPlacementLimit()
	local base = baseLimits[PlrValue.Value] or baseLimits[6]
	return math.floor(base * PlacementModified.Value)
end

local IndiTowerPlacements = {}

-- Only committed placements count. Remove their counters exactly once when
-- they leave Workspace.Towers (Sell, death, or a direct Destroy()).
local CommittedPlacements = setmetatable({}, { __mode = "k" })
TowersWorkspace.ChildRemoved:Connect(function(model)
	local entry = CommittedPlacements[model]
	if not entry then return end
	CommittedPlacements[model] = nil

	local owner = entry.owner
	if not owner or owner.Parent ~= Players then return end

	local placed = owner:FindFirstChild("PlacedTowers")
	if placed then placed.Value = math_max(0, placed.Value - 1) end

	local byName = IndiTowerPlacements[owner]
	local record = byName and byName[entry.name]
	if record then record.Count = math_max(0, record.Count - 1) end
end)
local DynamicTowerLimits = {
	["Helicopter"] = { 6, 5, 4, 3 },
	["Tree"]       = { 4, 4, 3, 3 },
	["Railgunner"] = { 15, 12, 10, 8 },
	["Mob Farm"] = { 10, 10, 8, 8 },
	["Beamer"] = { 12, 8, 5, 4 },
	["Motor Pool"] = { 7, 5, 5, 4 },
}

-- ============================================================
-- BORDER TEMPLATE
-- ============================================================
local _borderTemplate
local function getBorderTemplate()
	if _borderTemplate then return _borderTemplate end
	local p = Instance.new("Part")
	p.Name = "Border"; p.Shape = Enum.PartType.Block
	p.Transparency = 1; p.BrickColor = BrickColor.new("Persimmon")
	p.Size = Vector3.new(1,0.5,1); p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false; p.CanQuery = true; p.Anchored = true
	p.CollisionGroup = "Border"
	_borderTemplate = p
	return p
end

local function getDynamicLimit(towerName)
	local n = #Players:GetPlayers()
	local limits = DynamicTowerLimits[towerName]

	if limits then
		return limits[math_clamp(n, 1, #limits)]
	end

	local towerFolder = TowersFolder:FindFirstChild(towerName)
	local defaultModel =
		towerFolder
		and towerFolder:FindFirstChild("Default")

	if defaultModel then
		local config = defaultModel:FindFirstChild("Config")

		if config then
			local limit = config:FindFirstChild("Limit")

			if limit then
				return limit.Value
			end
		end
	end

	return math_huge
end

-- Uses TowerSet (no GetChildren allocation)
local function isInsideBorder(position)
	for towerModel in pairs(TowerSet) do
		local border = towerModel:FindFirstChild("Border")
		if border and border:IsA("BasePart") then
			local rel = border.CFrame:PointToObjectSpace(position)
			local s   = border.Size
			if math_abs(rel.X) <= s.X/2
				and math_abs(rel.Y) <= s.Y/2
				and math_abs(rel.Z) <= s.Z/2 then
				return true
			end
		end
	end
	return false
end

-- Converts both the new appearance names and the old saved skin names.
--
-- New:
--     SelectedSkins = {
--         Trooper = "Retro",
--     }
--
-- Legacy:
--     SelectedSkins = {
--         "Retro Trooper",
--         "Beach Commander",
--     }
--
-- It also supports a direct legacy value:
--     SelectedSkins.Trooper = "Retro Trooper"
local function legacySkinToAppearance(towerName, skinName)
	if typeof(skinName) ~= "string" or skinName == "" then
		return nil
	end

	local towerFolder = TowersFolder:FindFirstChild(towerName)
	if not towerFolder then
		return nil
	end

	-- Already the new appearance name, e.g. "Retro".
	if towerFolder:FindFirstChild(skinName) then
		return skinName
	end

	-- A saved value matching the tower name means Default.
	if skinName == towerName then
		return "Default"
	end

	-- Legacy examples:
	-- "Retro Trooper"  -> "Retro"
	-- "Golden Trooper" -> "Golden"
	local suffix = " " .. towerName

	if #skinName > #suffix
		and string.sub(skinName, -#suffix) == suffix
	then
		local appearanceName =
			string.sub(
				skinName,
				1,
				#skinName - #suffix
			)

		if towerFolder:FindFirstChild(appearanceName) then
			return appearanceName
		end
	end

	return nil
end

local function getSelectedAppearanceName(towerName, selectedSkins)
	if typeof(selectedSkins) ~= "table" then
		return "Default"
	end

	-- Preferred/new dictionary format.
	local direct = selectedSkins[towerName]

	if typeof(direct) == "string" and direct ~= "" then
		return legacySkinToAppearance(towerName, direct)
			or direct
	end

	-- Backwards compatibility with the old array format.
	for _, skinName in ipairs(selectedSkins) do
		local appearanceName =
			legacySkinToAppearance(
				towerName,
				skinName
			)

		if appearanceName and appearanceName ~= "Default" then
			return appearanceName
		end
	end

	return "Default"
end

local function getTowerAppearance(player, towerName)
	local towerFolder =
		TowersFolder:FindFirstChild(towerName)

	if not towerFolder then
		return nil
	end

	local pd =
		PlayerDataModule.GetPlayerData(player)

	local appearanceName =
		getSelectedAppearanceName(
			towerName,
			pd and pd.SelectedSkins
		)

	local appearance =
		towerFolder:FindFirstChild(appearanceName)

	if not appearance then
		warn(
			"[Tower.Spawn] Equipped appearance missing:",
			towerName,
			appearanceName,
			"- using Default"
		)

		appearanceName = "Default"
		appearance =
			towerFolder:FindFirstChild("Default")
	end

	return appearance, appearanceName
end

-- ============================================================
-- HELPERS
-- ============================================================

local function setCollisionGroupRecursive(model, group)
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then obj.CollisionGroup = group end
	end
end

-- ============================================================
-- ERROR REMOTE
-- ============================================================
function tower.Error(player, message)
	ErrorEvent:FireClient(player, message)
end

-- ============================================================
-- CHANGE MODE
-- ============================================================
function tower.ChangeMode(player, model)
	if model and model:FindFirstChild("Config") then
		local t = model.Config:FindFirstChild("TargetMode")
		if not t then return false end
		local modes = {"First","Last","Near","Strong","Weak"}
		local i = table.find(modes, t.Value) or 1
		t.Value = modes[i < #modes and i+1 or 1]
		return true
	end
	return false
end
changeModeFunction.OnServerInvoke = tower.ChangeMode

-- ============================================================
-- SELL  (finally-style lock release)
-- ============================================================
local function getCanonicalTowerName(model)
	return model:GetAttribute("TowerName") or model.Name
end

local SellLocks = {}

function tower.Sell(player, model)
	if not model or SellLocks[model] then return false end
	local config = model:FindFirstChild("Config")
	if not config or config:FindFirstChild("SellLock") then return false end

	local owner = config:FindFirstChild("Owner")
	if player and (not owner or owner.Value ~= player.Name) then return false end

	SellLocks[model] = true
	local ok, result = pcall(function()
		removeOccupancy(model)

		local runtime = TowerRuntime.Get(model)
		local totalSpent = runtime and runtime.TotalSpent
			or model:GetAttribute("TotalSpent")
			or (config:FindFirstChild("TotalSpent") and config.TotalSpent.Value)
			or 0

		if player then
			local cash = player:FindFirstChild("Cash")
			if cash then
				local sellValue = TowerStats.CalculateSellValue(totalSpent)
				if DeathWishModifier.Value == true then
					sellValue = math.round(sellValue * DeathWishInfo.Inflation.Value)
				end
				cash.Value += sellValue
			end

			-- Placement counters are released by Workspace.Towers.ChildRemoved.
			-- This also covers forced destruction and Sell(nil, model).
		end

		Towers[model] = nil
		TowerRuntime.Remove(model)
		if model:IsDescendantOf(game) then model:Destroy() end
		return true
	end)

	SellLocks[model] = nil
	if not ok then
		warn("[Tower.Sell]", result)
		return false
	end
	return result == true
end

sellTowerFunction.OnServerInvoke = tower.Sell

-- ============================================================
-- IN-PLACE UPGRADE
-- Core stats come from TowerData/TowerStats. The model itself survives.
-- UpgradeModels/<level> handles visuals, including skin-specific visuals.
-- ============================================================
local UpgradeLocks = setmetatable({}, { __mode = "k" })

local function getTowerLevel(model, config)
	local attr = model:GetAttribute("TowerLevel")
	if typeof(attr) == "number" then return attr end
	local level = config and config:FindFirstChild("Level")
	return level and level.Value or 0
end

local function setTowerLevel(model, config, level)
	model:SetAttribute("TowerLevel", level)
	local value = config and config:FindFirstChild("Level")
	if value and value:IsA("ValueBase") then value.Value = level end
end

local function setTotalSpent(model, config, runtime, amount)
	model:SetAttribute("TotalSpent", amount)
	if runtime then runtime.TotalSpent = amount end
	local value = config and config:FindFirstChild("TotalSpent")
	if value and value:IsA("ValueBase") then value.Value = amount end
end

function tower.CanUpgrade(player, model)
	if not player or not model or not model:IsDescendantOf(TowersWorkspace) then return false end
	local config = model:FindFirstChild("Config")
	if not config then return false end
	local owner = config:FindFirstChild("Owner")
	if not owner or owner.Value ~= player.Name then return false end

	local nextLevel = getTowerLevel(model, config) + 1
	local upgrade = TowerStats.GetUpgrade(getCanonicalTowerName(model), nextLevel)
	if not upgrade then return false end
	local cost = upgrade.Cost
	if cost == nil then return false end
	if DeathWishModifier.Value then
		cost = math.round(cost * DeathWishInfo.Inflation.Value)
	end
	local cash = player:FindFirstChild("Cash")
	return cash ~= nil and cash.Value >= cost
end

local function captureTowerHealth(config)
	local healthFolder = config:FindFirstChild("Health")
	if not healthFolder then
		return nil
	end

	local healthValue = healthFolder:FindFirstChild("HealthValue")
	local maxHealthValue = healthFolder:FindFirstChild("MaxHealth")

	if not healthValue or not maxHealthValue then
		return nil
	end

	return math.max(
		0,
		maxHealthValue.Value - healthValue.Value
	)
end

local function captureTowerAmmo(config)
	local currentAmmo = config:FindFirstChild("CurrentAmmo")
	local maxAmmo = config:FindFirstChild("MaxAmmo")

	if not (
		currentAmmo
			and maxAmmo
			and currentAmmo:IsA("ValueBase")
			and maxAmmo:IsA("ValueBase")
		) then
		return nil
	end

	return {
		Current = currentAmmo.Value,
		Max = maxAmmo.Value,
	}
end

local function applyTowerAmmoUpgrade(config, oldAmmoState)
	if not oldAmmoState then
		return
	end

	local currentAmmo = config:FindFirstChild("CurrentAmmo")
	local maxAmmo = config:FindFirstChild("MaxAmmo")

	if not (
		currentAmmo
			and maxAmmo
			and currentAmmo:IsA("ValueBase")
			and maxAmmo:IsA("ValueBase")
		) then
		return
	end

	local difference =
		maxAmmo.Value - oldAmmoState.Max

	currentAmmo.Value =
		math.clamp(
			oldAmmoState.Current + difference,
			0,
			maxAmmo.Value
		)
end

local function applyTowerHealth(config, newMaxHealth, missingHealth)
	if newMaxHealth == nil then
		return
	end

	local healthFolder = config:FindFirstChild("Health")
	if not healthFolder then
		return
	end

	local healthValue = healthFolder:FindFirstChild("HealthValue")
	local maxHealthValue = healthFolder:FindFirstChild("MaxHealth")

	if not healthValue or not maxHealthValue then
		return
	end

	maxHealthValue.Value = newMaxHealth

	healthValue.Value = math.clamp(
		newMaxHealth - (missingHealth or 0),
		0,
		newMaxHealth
	)
end

local function applyVisualElevation(towerModel, amount)
	amount = amount or 0

	local hrp =
		towerModel:FindFirstChild("HumanoidRootPart")

	if not hrp then
		return
	end

	-- Usually the joint connecting HRP -> Torso / body.
	local rootJoint =
		hrp:FindFirstChild("RootJoint")
		or hrp:FindFirstChildWhichIsA("Motor6D")

	if not rootJoint then
		warn(
			"[VisualElevation] No root Motor6D found for",
			towerModel:GetFullName()
		)
		return
	end

	-- Save the ORIGINAL offset once so upgrading multiple times
	-- never stacks elevation accidentally.
	if rootJoint:GetAttribute("OriginalC0") == nil then
		rootJoint:SetAttribute(
			"OriginalC0",
			rootJoint.C0
		)
	end

	local originalC0 =
		rootJoint:GetAttribute("OriginalC0")

	rootJoint.C0 =
		originalC0
		* CFrame.new(0, 0, amount)
end

local function getMedicBeam(towerModel)
	local weapon = towerModel:FindFirstChild("Weapon")
	local mainNeon = weapon and weapon:FindFirstChild("MainNeon")
	if not mainNeon then
		return nil, nil
	end

	local beam = mainNeon:FindFirstChild("Beam")
	local start = mainNeon:FindFirstChild("Start")
	local lens = start and start:FindFirstChild("Lens")

	return beam, lens
end

-- ============================================================
-- PHASER UPGRADE DAMAGE PROTECTION
--
-- Config.Damage doubles as the live displayed Phaser damage while LockedOn.
-- Because of that, normal upgrade stat application must NOT overwrite Damage
-- in the middle of a lock. The new TowerData base damage is instead stored in
-- the Phaser runtime and becomes the live/base Damage as soon as the lock ends.
-- ============================================================

local function copyStatsWithoutDamage(stats)
	local copy = {}

	for key, value in pairs(stats or {}) do
		if key ~= "Damage" then
			copy[key] = value
		end
	end

	return copy
end

local function copyUpgradeWithoutDamageOverride(upgrade)
	if not (upgrade and upgrade.Config) then
		return upgrade
	end

	local hasDamageOverride = false

	for path in pairs(upgrade.Config) do
		if path == "Damage" then
			hasDamageOverride = true
			break
		end
	end

	if not hasDamageOverride then
		return upgrade
	end

	local upgradeCopy = {}

	for key, value in pairs(upgrade) do
		upgradeCopy[key] = value
	end

	local configCopy = {}

	for path, value in pairs(upgrade.Config) do
		if path ~= "Damage" then
			configCopy[path] = value
		end
	end

	upgradeCopy.Config = configCopy

	return upgradeCopy
end

local function getUpgradePhaserState(model, config)
	if not (config and config:FindFirstChild("BeamerSettings")) then
		return nil, false
	end

	local data = Towers[model]

	if not (data and data.isPhaser) then
		return data, false
	end

	return data, data.phaserPhase == "LockedOn"
end

local function getUpgradedPhaserBaseDamage(newStats, upgrade)
	local damage =
		newStats
		and newStats.Damage

	-- A direct Config.Damage override, if one is intentionally authored,
	-- takes precedence over the normal core-stat mirror.
	local configOverrides =
		upgrade
		and upgrade.Config

	if configOverrides
		and typeof(configOverrides.Damage) ~= "table"
		and configOverrides.Damage ~= nil
	then
		damage = configOverrides.Damage
	end

	return damage
end

function tower.Upgrade(player, model)
	if not player or not model or UpgradeLocks[model] then return false end
	if not model:IsDescendantOf(TowersWorkspace) then return false end

	local config = model:FindFirstChild("Config")
	if not config then return false end
	local owner = config:FindFirstChild("Owner")
	if not owner or owner.Value ~= player.Name then return false end

	UpgradeLocks[model] = true
	local ok, result = pcall(function()
		local currentLevel = getTowerLevel(model, config)
		local nextLevel = currentLevel + 1
		local upgrade = TowerStats.GetUpgrade(getCanonicalTowerName(model), nextLevel)
		if not upgrade then return false end

		local rawCost = upgrade.Cost
		if rawCost == nil then return false end
		local cost = rawCost
		if DeathWishModifier.Value then
			cost = math.round(cost * DeathWishInfo.Inflation.Value)
		end

		local cash = player:FindFirstChild("Cash")
		if not cash or cash.Value < cost then
			tower.Error(player, "Not enough cash to upgrade!")
			return false
		end

		local missingHealth = captureTowerHealth(config)
		local oldAmmoState = captureTowerAmmo(config)

		-- Calculate first; commit only after all required data exists.
		local newStats = TowerStats.GetStatsForLevel(getCanonicalTowerName(model), nextLevel, config)
		cash.Value -= cost

		local runtime = TowerRuntime.Get(model)
		if not runtime then
			runtime = TowerRuntime.Create(
				model,
				player,
				getCanonicalTowerName(model),
				currentLevel,
				model:GetAttribute("TotalSpent") or 0
			)
		end

		-- Phaser damage is special:
		--
		-- While LockedOn, Config.Damage is the CURRENT ramped beam damage.
		-- Do not overwrite it with the newly upgraded base damage, even for
		-- a single scheduler frame. That would make the displayed/live damage
		-- jump and can interfere with continuous Phaser behavior.
		--
		-- Instead, remember the new base damage in runtime. The current lock
		-- keeps its exact phaserDamage, and the new base takes effect once the
		-- Phaser is no longer LockedOn.
		local phaserData, phaserLockedOn =
			getUpgradePhaserState(
				model,
				config
			)

		local upgradedPhaserBaseDamage =
			getUpgradedPhaserBaseDamage(
				newStats,
				upgrade
			)

		if phaserLockedOn then
			TowerStats.ApplyStatsToConfig(
				config,
				copyStatsWithoutDamage(newStats)
			)

			TowerStats.ApplyUpgradeConfigOverrides(
				config,
				copyUpgradeWithoutDamageOverride(upgrade)
			)
		else
			TowerStats.ApplyStatsToConfig(
				config,
				newStats
			)

			TowerStats.ApplyUpgradeConfigOverrides(
				config,
				upgrade
			)
		end

		-- Keep a dedicated authoritative BASE damage for Phaser.
		--
		-- This is deliberately updated even while LockedOn, because it is only
		-- the stored baseline; data.phaserDamage remains untouched until the
		-- current lock ends. Therefore there is zero mid-lock DPS reset.
		if phaserData
			and phaserData.isPhaser
			and upgradedPhaserBaseDamage ~= nil
		then
			phaserData.phaserBaseDamage =
				upgradedPhaserBaseDamage
		end

		applyTowerAmmoUpgrade(
			config,
			oldAmmoState
		)

		-- Secondary attacks keep their original Config.Secondary behavior.
		-- TowerData only unlocks/updates the compatibility folder here.
		local secondaryData, secondaryManaged =
			TowerStats.GetSecondaryForLevel(
				getCanonicalTowerName(model),
				nextLevel
			)

		TowerStats.ApplySecondaryToConfig(
			config,
			secondaryData,
			secondaryManaged
		)

		applyTowerHealth(
			config,
			newStats.MaxHealth,
			missingHealth
		)

		local oldMedicBeam, oldMedicLens =
			getMedicBeam(model)

		local medicBeamState = nil

		if oldMedicBeam then
			medicBeamState = {
				Attachment1 = oldMedicBeam.Attachment1,
				BeamEnabled = oldMedicBeam.Enabled,
				LensEnabled =
					oldMedicLens
					and oldMedicLens.Enabled
					or false,
			}
		end

		TowerAppearance.ApplyUpgrade(model, nextLevel)

		if medicBeamState then
			local newBeam, newLens =
				getMedicBeam(model)

			if newBeam
				and medicBeamState.Attachment1
				and medicBeamState.Attachment1.Parent
			then
				newBeam.Attachment1 =
					medicBeamState.Attachment1

				newBeam.Enabled =
					medicBeamState.BeamEnabled

				if newLens then
					newLens.Enabled =
						medicBeamState.LensEnabled
				end
			end
		end

		local elevation =
			upgrade.VisualElevation or 0

		applyVisualElevation(
			model,
			elevation
		)

		setTowerLevel(model, config, nextLevel)
		runtime.Level = nextLevel
		local totalSpent = (runtime.TotalSpent or 0) + rawCost
		setTotalSpent(model, config, runtime, totalSpent)

		-- BaseRange is the unmodified module range; Death Wish then derives live Range.
		if newStats.Range ~= nil then
			local baseRange = config:FindFirstChild("BaseRange")
			if not baseRange then
				baseRange = Instance.new("NumberValue")
				baseRange.Name = "BaseRange"
				baseRange.Parent = config
			end
			baseRange.Value = newStats.Range
		end

		applyDeathWishRange(model)
		if FireRateManager.recomputeAll then FireRateManager.recomputeAll() end
		if DamageManager.recomputeAll then DamageManager.recomputeAll() end

		return model
	end)

	UpgradeLocks[model] = nil
	if not ok then
		warn("[Tower.Upgrade]", result)
		return false
	end
	return result
end

local upgradeTowerFunction = functions:FindFirstChild("UpgradeTower")
if upgradeTowerFunction and upgradeTowerFunction:IsA("RemoteFunction") then
	upgradeTowerFunction.OnServerInvoke = tower.Upgrade
end

-- ============================================================
-- PLACEMENT LOCKS
-- ============================================================
-- ============================================================
-- PLACEMENT / SPAWN — AUTHORITATIVE SERVER LOGIC
-- ============================================================

local LastRequestId      = {}
local PlaceThrottle      = {}
local PlayerMutex        = {}
local PlacementLocks     = {}
local PendingPlacements  = {}
local UpgradeTargetLocks = {}

local PLACE_COOLDOWN = 0.1
local MIN_DISTANCE   = 4

-- ============================================================
-- AUTHORITATIVE OCCUPANCY SYSTEM
--
-- This is the ACTUAL source of truth for tower placement.
--
-- TowerSet is only a secondary safety check.
-- Workspace replication is NOT trusted for the race check.
--
-- PlacementOccupancy:
-- [towerModel] = {
--     Position = Vector3,
--     Radius = number,
--     Owner = Player,
-- }
--
-- PlacementSpatialHash:
-- [cellKey] = {
--     [towerModel] = true
-- }
-- ============================================================

local PlacementOccupancy = {}
local PlacementSpatialHash = {}

local SPATIAL_CELL_SIZE = 4

-- ============================================================
-- NUMBER / VECTOR VALIDATION
-- ============================================================

local function isFiniteNumber(n)
	return n == n
		and n ~= math_huge
		and n ~= -math_huge
end

local function isValidVector3(v)
	return typeof(v) == "Vector3"
		and isFiniteNumber(v.X)
		and isFiniteNumber(v.Y)
		and isFiniteNumber(v.Z)
end

local function isValidPlacementCFrame(cframe)
	if typeof(cframe) ~= "CFrame" then
		return false
	end

	local components = { cframe:GetComponents() }

	for _, value in ipairs(components) do
		if not isFiniteNumber(value) then
			return false
		end
	end

	return isValidVector3(cframe.Position)
end

-- ============================================================
-- SPATIAL HASH
-- ============================================================

local function getSpatialCell(x, y, z)
	return math.floor(x / SPATIAL_CELL_SIZE) .. ","
		.. math.floor(y / SPATIAL_CELL_SIZE) .. ","
		.. math.floor(z / SPATIAL_CELL_SIZE)
end

local function getSpatialKey(position)
	return getSpatialCell(
		position.X,
		position.Y,
		position.Z
	)
end

-- ============================================================
-- ADD OCCUPANCY
-- ============================================================

local function addOccupancy(model, position, radius, owner)

	local entry = {
		Position = position,
		Radius = radius,
		Owner = owner,
	}

	PlacementOccupancy[model] = entry

	local key = getSpatialKey(position)

	local bucket = PlacementSpatialHash[key]

	if not bucket then
		bucket = {}
		PlacementSpatialHash[key] = bucket
	end

	bucket[model] = true
end

-- ============================================================
-- REMOVE OCCUPANCY
-- ============================================================

function removeOccupancy(model)

	local entry = PlacementOccupancy[model]

	if not entry then
		return
	end

	local key = getSpatialKey(entry.Position)

	local bucket = PlacementSpatialHash[key]

	if bucket then

		bucket[model] = nil

		if next(bucket) == nil then
			PlacementSpatialHash[key] = nil
		end
	end

	PlacementOccupancy[model] = nil
end

-- ============================================================
-- AUTHORITATIVE OCCUPANCY CHECK
--
-- Checks the actual radius against every nearby spatial cell.
--
-- The spatial hash is ONLY an optimization.
-- The final decision is always based on exact distance.
-- ============================================================

local function isPositionOccupied(position, radius, ignoredModel)

	if not isValidVector3(position) then
		return true
	end

	local cellX = math.floor(position.X / SPATIAL_CELL_SIZE)
	local cellY = math.floor(position.Y / SPATIAL_CELL_SIZE)
	local cellZ = math.floor(position.Z / SPATIAL_CELL_SIZE)

	for x = cellX - 1, cellX + 1 do

		for y = cellY - 1, cellY + 1 do

			for z = cellZ - 1, cellZ + 1 do

				local key = getSpatialCell(
					x * SPATIAL_CELL_SIZE,
					y * SPATIAL_CELL_SIZE,
					z * SPATIAL_CELL_SIZE
				)

				local bucket = PlacementSpatialHash[key]

				if bucket then

					for existingModel in pairs(bucket) do

						if existingModel ~= ignoredModel then

							local existing =
								PlacementOccupancy[existingModel]

							if existing then

								local distance =
									(existing.Position - position).Magnitude

								if distance <
									(existing.Radius + radius)
								then
									return true
								end
							end
						end
					end
				end
			end
		end
	end

	return false
end

-- ============================================================
-- CLEAN STALE OCCUPANCY
-- ============================================================

local function cleanupOccupancy()

	for model in pairs(PlacementOccupancy) do

		if not model:IsDescendantOf(game) then
			removeOccupancy(model)
		end
	end
end

task.spawn(function()

	while true do
		task.wait(5)
		cleanupOccupancy()
	end
end)

-- ============================================================
-- KEEP OCCUPANCY SYNCHRONIZED WITH ACTUAL TOWERS
--
-- IMPORTANT:
-- This is NOT the race protection.
-- The reservation system above is.
--
-- This just prevents stale entries if another system destroys
-- a tower without going through tower.Sell().
-- ============================================================

TowersWorkspace.ChildRemoved:Connect(function(t)

	TowerSet[t] = nil
	Towers[t] = nil
	TowerRuntime.Remove(t)

	removeOccupancy(t)
end)

-- ============================================================
-- PREVIOUS TOWER VALIDATION
-- ============================================================

local function validatePrevious(player, previous)

	if not previous
		or not previous.Parent
	then
		return false
	end

	if not previous:IsDescendantOf(TowersWorkspace) then
		return false
	end

	local cfg = previous:FindFirstChild("Config")

	if not cfg then
		return false
	end

	local owner = cfg:FindFirstChild("Owner")

	if not owner
		or owner.Value ~= player.Name
	then
		return false
	end

	return true
end

-- ============================================================
-- CHECK SPAWN
--
-- This is only the client-facing pre-check.
--
-- tower.Spawn() repeats the important checks independently.
-- Never trust this function as the security layer.
-- ============================================================

function tower.CheckSpawn(player, name, previous)

	-- New architecture: upgrades mutate the existing tower in place.
	if previous then
		return tower.CanUpgrade(player, previous)
	end

	if not player
		or not player:IsDescendantOf(Players)
	then
		return false
	end

	if typeof(name) ~= "string" then
		return false
	end

	local towerFolder =
		TowersFolder:FindFirstChild(name)

	local towerExists =
		towerFolder
		and towerFolder:FindFirstChild("Default")

	if not towerExists then
		return false
	end

	if previous
		and not validatePrevious(player, previous)
	then
		return false
	end

	local cash = player:FindFirstChild("Cash")

	if not cash then
		return false
	end

	local config = towerExists:FindFirstChild("Config")
	if not config then return false end

	local price = TowerStats.GetPlacementCost(name, config)
	if price == nil then return false end
	if DeathWishModifier.Value == true then
		price = math.round(price * DeathWishInfo.Inflation.Value)
	end

	if cash.Value < price then

		tower.Error(
			player,
			"You Need $"
				.. (price - cash.Value)
				.. " to place!"
		)

		return false
	end

	IndiTowerPlacements[player] =
		IndiTowerPlacements[player] or {}

	local plrTowers =
		IndiTowerPlacements[player]

	local maxAllowed =
		getPlacementLimit()

	local placed =
		(
			player:FindFirstChild("PlacedTowers")
			and player.PlacedTowers.Value
		)
		or 0

	local limit =
		getDynamicLimit(name)

	local count =
		(
			plrTowers[name]
			and plrTowers[name].Count
		)
		or 0

	-- Upgrades do not consume another global tower slot.
	if previous
		or placed < maxAllowed
	then

		if count < limit then
			return true
		end

		tower.Error(
			player,
			"You can only place "
				.. limit
				.. " "
				.. towerExists.TowerName.Value
				.. "(s)!"
		)

		return false
	end

	tower.Error(
		player,
		"You Can Only Place "
			.. maxAllowed
			.. " Towers!"
	)

	return false
end

requestTowerFunction.OnServerInvoke = tower.CheckSpawn

-- ============================================================
-- SPAWN
--
-- THIS IS THE FINAL AUTHORITY.
-- ============================================================

function tower.Spawn(
	player,
	name,
	cframe,
	previous,
	requestId
)

	-- Compatibility with the old client: a Spawn request carrying `previous` is now an in-place upgrade.
	if previous then
		return tower.Upgrade(player, previous)
	end

	-- ========================================================
	-- BASIC VALIDATION
	-- ========================================================

	if not player
		or not player:IsDescendantOf(Players)
	then
		return false
	end

	if typeof(name) ~= "string" then
		return false
	end

	if not isValidPlacementCFrame(cframe) then

		tower.Error(
			player,
			"Invalid tower position!"
		)

		return false
	end

	local isUpgrade = false

	-- ========================================================
	-- PLAYER MUTEX
	--
	-- Stops this player's requests from overlapping.
	-- ========================================================

	if PlayerMutex[player] then
		return false
	end

	PlayerMutex[player] = true

	-- ========================================================
	-- UNLOCK FUNCTION
	-- ========================================================

	local function fullUnlock()

		PlayerMutex[player] = nil
		PlacementLocks[player] = nil

		if isUpgrade
			and previous
		then
			UpgradeTargetLocks[previous] = nil
		end
	end

	-- ========================================================
	-- REQUEST ID PROTECTION
	-- ========================================================

	if requestId ~= nil then

		local requestType =
			typeof(requestId)

		if requestType ~= "string"
			and requestType ~= "number"
		then

			fullUnlock()
			return false
		end

		if LastRequestId[player] == requestId then

			fullUnlock()
			return false
		end
	end

	-- ========================================================
	-- UPGRADE TARGET LOCK
	-- ========================================================

	if isUpgrade then

		if not previous
			or not previous:IsDescendantOf(TowersWorkspace)
		then

			fullUnlock()
			return false
		end

		if UpgradeTargetLocks[previous] then

			fullUnlock()
			return false
		end

		UpgradeTargetLocks[previous] = true
	end

	-- ========================================================
	-- PLACEMENT LOCK
	-- ========================================================

	if PlacementLocks[player] then

		fullUnlock()
		return false
	end

	PlacementLocks[player] = true

	-- ========================================================
	-- THROTTLE NORMAL PLACEMENT
	-- ========================================================

	if not isUpgrade then

		local now = os_clock()

		local last =
			PlaceThrottle[player]

		if last
			and (now - last) < PLACE_COOLDOWN
		then

			fullUnlock()
			return false
		end
	end

	-- ========================================================
	-- VALIDATE UPGRADE
	-- ========================================================

	if isUpgrade then

		if not validatePrevious(
			player,
			previous
			) then

			fullUnlock()
			return false
		end
	end

	-- ========================================================
	-- RECENT PENDING PLACEMENTS
	--
	-- This is an additional same-player protection.
	-- ========================================================

	if not isUpgrade then

		PendingPlacements[player] =
			PendingPlacements[player] or {}

		local pp =
			PendingPlacements[player]

		local now = os_clock()

		for i = #pp, 1, -1 do

			local data = pp[i]

			if (now - data.Time) > 1 then

				table.remove(pp, i)

			elseif
				(data.Position - cframe.Position).Magnitude
				< MIN_DISTANCE
			then

				fullUnlock()
				return false
			end
		end

		table.insert(
			pp,
			{
				Position = cframe.Position,
				Time = now,
			}
		)
	end

	-- ========================================================
	-- PLAYER DATA / PLACEMENT TABLE
	-- ========================================================

	IndiTowerPlacements[player] =
		IndiTowerPlacements[player] or {}

	local plrTowers =
		IndiTowerPlacements[player]

	-- ========================================================
	-- GET TOWER TEMPLATE
	-- ========================================================

	-- ========================================================
	-- GET TOWER APPEARANCE
	-- ========================================================

	local towerTemplate, resolvedAppearanceName =
		getTowerAppearance(player, name)

	if not towerTemplate then
		fullUnlock()
		return false
	end

	local newTower = towerTemplate:Clone()

	-- Gameplay identity stays as the tower name regardless of appearance.
	newTower:SetAttribute("TowerName", name)

	-- Keep the actual server-authoritative appearance on the placed tower.
	newTower:SetAttribute(
		"AppearanceName",
		resolvedAppearanceName
			or towerTemplate.Name
			or "Default"
	)

	-- ========================================================
	-- CONFIG
	-- ========================================================

	local cfg =
		newTower:FindFirstChild("Config")

	if cfg then
		local baseStats = TowerStats.GetStatsForLevel(name, 0, cfg)
		TowerStats.ApplyStatsToConfig(cfg, baseStats)

		-- A placed tower is a new live entity, not the template's saved damage state.
		-- Core combat rejects zero-health towers, so initialize both health mirrors.
		applyTowerHealth(cfg, baseStats.MaxHealth, 0)

		-- If this tower has a module-defined secondary attack at level 0,
		-- mirror it into Config.Secondary so all the original attack code
		-- continues to work unchanged.
		local secondaryData, secondaryManaged =
			TowerStats.GetSecondaryForLevel(name, 0)

		TowerStats.ApplySecondaryToConfig(
			cfg,
			secondaryData,
			secondaryManaged
		)

		newTower:SetAttribute("TowerLevel", 0)
	end

	if not cfg then

		newTower:Destroy()
		fullUnlock()
		return false
	end

	-- ========================================================
	-- PRIMARY PART
	-- ========================================================

	local hrp =
		newTower:FindFirstChild(
			"HumanoidRootPart"
		)

	if not (
		hrp
			and hrp:IsA("BasePart")
		) then

		newTower:Destroy()
		fullUnlock()
		return false
	end

	newTower.PrimaryPart = hrp

	-- ========================================================
	-- PRICE
	-- ========================================================

	local rawPrice = TowerStats.GetPlacementCost(name, cfg) or 0
	local price = rawPrice
	if DeathWishModifier.Value == true then
		price = math.round(rawPrice * DeathWishInfo.Inflation.Value)
	end

	-- ========================================================
	-- CASH
	-- ========================================================

	local cash =
		player:FindFirstChild("Cash")

	if not cash
		or cash.Value < price
	then

		tower.Error(
			player,
			isUpgrade
				and "Not enough cash to upgrade!"
				or "Not enough cash!"
		)

		newTower:Destroy()
		fullUnlock()

		return false
	end

	-- ========================================================
	-- LIMITS
	-- ========================================================

	local Limit =
		getDynamicLimit(name)

	plrTowers[name] =
		plrTowers[name]
		or {
			Count = 0,
			Limit = Limit,
		}

	-- ========================================================
	-- FINAL GLOBAL LIMIT
	-- ========================================================

	if not isUpgrade then

		local maxAllowed =
			getPlacementLimit()

		local placedStat =
			player:FindFirstChild(
				"PlacedTowers"
			)

		if placedStat
			and placedStat.Value >= maxAllowed
		then

			newTower:Destroy()
			fullUnlock()

			return false
		end

		-- Refresh the dynamic limit from the server.
		plrTowers[name].Limit = Limit

		if plrTowers[name].Count
			>= plrTowers[name].Limit
		then

			newTower:Destroy()
			fullUnlock()

			return false
		end
	end

	-- ========================================================
	-- UPGRADE DATA
	-- ========================================================

	local oldMode = nil
	local oldTotalDamage = 0
	local oldTotalSpent = 0
	local aviatorPreviousAngle = nil

	if isUpgrade
		and previous
		and previous:FindFirstChild("Config")
	then

		local pc =
			previous.Config

		local targetMode =
			pc:FindFirstChild(
				"TargetMode"
			)

		if targetMode then
			oldMode = targetMode.Value
		end

		local totalDamage =
			pc:FindFirstChild(
				"TotalDamage"
			)

		if totalDamage then
			oldTotalDamage =
				totalDamage.Value
		end

		local totalSpent =
			pc:FindFirstChild(
				"TotalSpent"
			)

		if totalSpent then
			oldTotalSpent =
				totalSpent.Value
		end

		-- ====================================================
		-- AVIATOR ROTATION
		-- ====================================================

		if newTower.Config:FindFirstChild("Aviator") then
			local previousHRP = previous:FindFirstChild("HumanoidRootPart")
			local newHRP = newTower:FindFirstChild("HumanoidRootPart")

			local PreviousWeld =
				previousHRP and previousHRP:FindFirstChild("FlightPos")

			local RotateWeld =
				newHRP and newHRP:FindFirstChild("FlightPos")

			if RotateWeld and PreviousWeld then
				aviatorPreviousAngle = PreviousWeld.CurrentAngle

				-- Set it server-side immediately too
				RotateWeld.CurrentAngle = aviatorPreviousAngle
			end
		end
	end

	-- ========================================================
	-- CONFIG VALUES
	-- ========================================================

	local function makeValue(
		className,
		valueName,
		value
	)

		local v =
			Instance.new(className)

		v.Name = valueName
		v.Value = value
		v.Parent = cfg

		return v
	end

	makeValue(
		"StringValue",
		"Owner",
		player.Name
	)

	makeValue(
		"StringValue",
		"TargetMode",
		oldMode or "First"
	)

	makeValue(
		"IntValue",
		"TotalDamage",
		oldTotalDamage
	)

	makeValue(
		"IntValue",
		"TotalSpent",
		oldTotalSpent + price
	)

	-- ========================================================
	-- BORDER CHECK
	-- ========================================================

	if isInsideBorder(
		cframe.Position
		) then

		newTower:Destroy()
		fullUnlock()

		return false
	end

	-- ========================================================
	-- CALCULATE OCCUPANCY RADIUS
	-- ========================================================

	local newRadius =
		math_max(
			hrp.Size.X,
			hrp.Size.Z
		) / 2

	-- ========================================================
	-- AUTHORITATIVE OCCUPANCY CHECK
	--
	-- This is the IMPORTANT one.
	--
	-- If Player A and Player B submit the exact same
	-- placement, only the first server-side transaction
	-- gets through.
	-- ========================================================

	local ignoredModel = nil

	if isUpgrade then
		ignoredModel = previous
	end

	if isPositionOccupied(
		cframe.Position,
		newRadius,
		ignoredModel
		) then

		tower.Error(
			player,
			"Cannot place a tower here!"
		)

		newTower:Destroy()
		fullUnlock()

		return false
	end

	-- ========================================================
	-- SECONDARY REAL-WORLD CHECK
	--
	-- Protects against towers that somehow exist without
	-- an occupancy entry.
	-- ========================================================

	if not isUpgrade then

		for existingTower in pairs(TowerSet) do

			if existingTower
				and existingTower:IsDescendantOf(
					TowersWorkspace
				)
			then

				local existingHRP =
					existingTower:FindFirstChild(
						"HumanoidRootPart"
					)

				if existingHRP
					and existingHRP:IsA("BasePart")
				then

					local existingRadius =
						math_max(
							existingHRP.Size.X,
							existingHRP.Size.Z
						) / 2

					local distance =
						(
							existingHRP.Position
							- cframe.Position
						).Magnitude

					if distance
						< (newRadius + existingRadius)
					then

						tower.Error(
							player,
							"Cannot place a tower here!"
						)

						newTower:Destroy()
						fullUnlock()

						return false
					end
				end
			end
		end
	end

	-- ========================================================
	-- FINAL SERVER RESERVATION
	--
	-- THIS IS THE CRITICAL MOMENT.
	--
	-- The position becomes reserved BEFORE cash is removed
	-- and BEFORE the tower enters Workspace.
	--
	-- Therefore another Spawn() request cannot reserve the
	-- same location.
	-- ========================================================

	addOccupancy(
		newTower,
		cframe.Position,
		newRadius,
		player
	)

	local reservationActive = true

	-- ========================================================
	-- FAILURE CLEANUP
	-- ========================================================

	local function failPlacement()

		if reservationActive then

			removeOccupancy(
				newTower
			)

			reservationActive = false
		end

		if newTower
			and newTower:IsDescendantOf(game)
		then

			newTower:Destroy()
		end

		fullUnlock()

		return false
	end

	-- ========================================================
	-- FINAL CASH CHECK
	--
	-- Re-check immediately before committing.
	-- ========================================================

	if not cash
		or cash.Value < price
	then

		tower.Error(
			player,
			isUpgrade
				and "Not enough cash to upgrade!"
				or "Not enough cash!"
		)

		return failPlacement()
	end

	-- ========================================================
	-- FINAL LIMIT CHECK
	-- ========================================================

	if not isUpgrade then

		local maxAllowed =
			getPlacementLimit()

		local placedStat =
			player:FindFirstChild(
				"PlacedTowers"
			)

		if placedStat
			and placedStat.Value >= maxAllowed
		then

			return failPlacement()
		end

		plrTowers[name].Limit =
			getDynamicLimit(name)

		if plrTowers[name].Count
			>= plrTowers[name].Limit
		then

			return failPlacement()
		end
	end

	-- ========================================================
	-- COMMIT
	-- ========================================================

	cash.Value -= price
	newTower:SetAttribute("TowerLevel", 0)
	newTower:SetAttribute("TotalSpent", rawPrice)

	if not isUpgrade then

		plrTowers[name].Count += 1

		local ps =
			player:FindFirstChild(
				"PlacedTowers"
			)

		if ps then
			ps.Value += 1
		end
	end

	PlaceThrottle[player] =
		os_clock()

	-- ========================================================
	-- PLACE TOWER
	-- ========================================================

	hrp.CFrame = cframe
	hrp.Anchored = true

	CommittedPlacements[newTower] = { owner = player, name = name }
	newTower.Parent = TowersWorkspace

	local overhaulRuntime = TowerRuntime.Create(newTower, player, name, 0, rawPrice)
	overhaulRuntime.Level = 0
	overhaulRuntime.TotalSpent = rawPrice

	if aviatorPreviousAngle ~= nil then
		events.Aviator.HandleAviatorMovement:FireAllClients(
			newTower,
			aviatorPreviousAngle
		)
	end

	-- ========================================================
	-- RESERVATION IS NOW BACKED BY THE ACTUAL TOWER
	--
	-- Keep the occupancy entry.
	-- Just stop treating it as a temporary reservation.
	-- ========================================================

	reservationActive = false

	-- ========================================================
	-- BASE RANGE
	-- ========================================================

	if not cfg:FindFirstChild(
		"BaseRange"
		) then

		makeValue(
			"NumberValue",
			"BaseRange",
			cfg.Range.Value
		)
	end

	applyDeathWishRange(
		newTower
	)

	-- ========================================================
	-- CARRY OVER ATTACK DATA
	-- ========================================================

	local carryOverAttackData = nil

	if isUpgrade
		and previous
	then

		local prevData =
			Towers[previous]

		if prevData then

			carryOverAttackData = {

				nextAttack =
					prevData.nextAttack,

				lastAttack =
					prevData.lastAttack,

				nextSecondary =
					prevData.nextSecondary,
			}
		end
	end

	-- ========================================================
	-- DESTROY OLD TOWER AFTER NEW ONE IS COMMITTED
	-- ========================================================

	if isUpgrade
		and previous
		and previous.Parent
	then

		-- Remove the old tower's occupancy.
		removeOccupancy(
			previous
		)

		previous:Destroy()
	end

	-- ========================================================
	-- COLLISION GROUP
	-- ========================================================

	setCollisionGroupRecursive(newTower, "Tower")
	-- ========================================================
	-- BORDER
	-- ========================================================

	local borderSizeVal =
		newTower:FindFirstChild(
			"BorderSize"
		)

	local borderYVal =
		newTower:FindFirstChild(
			"BorderYValue"
		)

	if borderSizeVal
		and borderYVal
		and newTower.PrimaryPart
	then

		local height =
			(
				newTower.PrimaryPart.Size.Y / 2
			)
			+ borderYVal.Value

		local offset =
			Vector3.new(
				0,
				-height - 0.1,
				0
			)

		local border =
			getBorderTemplate():Clone()

		border.Size =
			Vector3.new(
				borderSizeVal.Value,
				0.5,
				borderSizeVal.Value
			)

		border.Position =
			newTower.PrimaryPart.Position
			+ offset

		border.Parent =
			newTower
	end

	-- ========================================================
	-- ATTACK LOOP
	-- ========================================================

	if not cfg:FindFirstChild(
		"NoAttack"
		) then

		tower.StartAttackLoop(
			newTower,
			player,
			carryOverAttackData
		)
	end

	-- ========================================================
	-- SUPPORT HANDLERS
	-- ========================================================

	local supportHandlers = {

		Commander =
			tower.FireRateSupport,

		SergeantRage =
			tower.DamageSupport,

		Farm =
			function(t)
				tower.Farm(
					t,
					player
				)
			end,

		Tree =
			function(t)
				tower.Tree(t)
			end,

		Medic =
			function(t)
				tower.Medic(
					t,
					player
				)
			end,

		SpawnCooldown =
			function(t)
				tower.Spawner(
					t,
					player
				)
			end,

		RebuildTime =
			function(t)
				tower.Scrambler(
					t,
					player
				)
			end,

		Aviator =
			tower.Aviator,

		MineStats =
			function(t)
				tower.MineLayer(t)
			end,
	}

	for tag, handler in pairs(
		supportHandlers
		) do

		if cfg:FindFirstChild(tag) then

			task_spawn(
				handler,
				newTower
			)
		end
	end

	-- ========================================================
	-- REQUEST ID COMMIT
	-- ========================================================

	if requestId ~= nil then

		LastRequestId[player] =
			requestId
	end

	-- ========================================================
	-- FINAL UNLOCK
	-- ========================================================

	fullUnlock()

	return newTower
end

spawnTowerFunction.OnServerInvoke =
	tower.Spawn

-- ============================================================
-- PLAYER CLEANUP
-- ============================================================

Players.PlayerRemoving:Connect(function(player)

	IndiTowerPlacements[player] = nil

	LastRequestId[player] = nil
	PlaceThrottle[player] = nil
	PlayerMutex[player] = nil
	PlacementLocks[player] = nil
	PendingPlacements[player] = nil

	-- Remove any occupancy entries owned by this player
	-- that somehow survived tower destruction.
	for model, data in pairs(PlacementOccupancy) do

		if data.Owner == player then
			removeOccupancy(model)
		end
	end
end)

-- ============================================================
-- REAPER CORRUPTION: isolated hostile-tower compatibility layer.
-- Normal targets, normal damage and normal scheduling remain unchanged.
-- The flag can be named either Config.Corruption or Config.Corrupted.
-- ============================================================
-- Loaded lazily when needed: TowerDeath itself requires TowerServer.
-- Requiring it during TowerServer initialisation creates a circular dependency.
local CorruptionTowerDeath
local CorruptionDeaths = setmetatable({}, {__mode = "k"})

local function isCorruptedTower(model)
	local cfg = model and model:FindFirstChild("Config")
	if not cfg then return false end
	for _, key in ipairs({"Corruption", "Corrupted"}) do
		local v = cfg:FindFirstChild(key)
		if v and v:IsA("BoolValue") and v.Value == true then return true end
	end
	return false
end

local function corruptionTargetPart(model)
	if not model then return nil end
	local part = model:FindFirstChild("Hitbox") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	return (part and part:IsA("BasePart")) and part or nil
end

local function corruptionOrigin(attacker)
	local cfg = attacker and attacker:FindFirstChild("Config")
	if cfg and cfg:FindFirstChild("Aviator") then
		local upgrades = attacker:FindFirstChild("UpgradeModels")
		local zero = upgrades and upgrades:FindFirstChild("0")
		local plane = zero and zero:FindFirstChild("Plane")
		local rotate = plane and plane:FindFirstChild("RotatePart")
		local follow = rotate and rotate:FindFirstChild("RangeFollow")
		if follow and follow:IsA("Attachment") then return follow.WorldPosition end
	end
	local part = corruptionTargetPart(attacker)
	return part and part.Position
end

local function validCorruptionVictim(attacker, target)
	if not (target and target:IsA("Model") and target.Parent == TowersWorkspace) then return false end
	if attacker == target or CorruptionDeaths[target] or isCorruptedTower(target) then return false end
	local cfg = target:FindFirstChild("Config")
	local healthFolder = cfg and cfg:FindFirstChild("Health")
	local health = healthFolder and healthFolder:FindFirstChild("HealthValue")
	return health ~= nil and health:IsA("ValueBase") and health.Value > 0
		and corruptionTargetPart(target) ~= nil
end

local function nearestCorruptionTower(attacker, range)
	local origin = corruptionOrigin(attacker)
	if not origin or type(range) ~= "number" or range <= 0 then return nil end
	local nearest, nearestDist = nil, range * range
	-- Use the existing live set; no GetChildren allocation per FindTarget.
	for other in pairs(TowerSet) do
		if validCorruptionVictim(attacker, other) then
			local p = corruptionTargetPart(other).Position
			local dx, dz = p.X - origin.X, p.Z - origin.Z
			local distance = dx * dx + dz * dz
			if distance <= nearestDist then
				nearest, nearestDist = other, distance
			end
		end
	end
	return nearest
end

local function corruptionDamage(attacker, victim, requestedDamage)
	if not validCorruptionVictim(attacker, victim) then return 0 end
	local value = victim.Config.Health.HealthValue
	local previous = value.Value
	local amount = math_max(0, tonumber(requestedDamage) or 0)
	if amount <= 0 then return 0 end
	-- Tree protection can restore HP synchronously. Measure actual damage
	-- after listeners, rather than treating a shielded hit as a kill.
	value.Value = math_max(0, previous - amount)
	local actual = math_max(0, previous - value.Value)
	if value.Value <= 0 and not CorruptionDeaths[victim] then
		CorruptionDeaths[victim] = true
		local ownerValue = victim.Config:FindFirstChild("Owner")
		local ownerName = ownerValue and ownerValue.Value
		local owner = typeof(ownerName) == "string" and Players:FindFirstChild(ownerName) or nil
		local animateDeath = events:FindFirstChild("AnimateTowerDeath")
		if animateDeath then animateDeath:FireAllClients(victim, "TowerDeath", victim) end
		task_defer(function()
			if victim.Parent ~= TowersWorkspace then return end
			local ok, err = pcall(function()
				CorruptionTowerDeath = CorruptionTowerDeath or require(game.ServerScriptService.Main.TowerDeath)
				CorruptionTowerDeath.KillTower(victim, owner)
			end)
			if not ok then warn("[Corruption] TowerDeath error:", err) end
		end)
		-- TowerDeath has its own 2/GameSpeed animation delay. Don't race it.
		task_delay(2 / getGameSpeed() + 1, function()
			if victim.Parent == TowersWorkspace and value.Parent and value.Value <= 0 then
				warn("[Corruption] TowerDeath did not remove", victim.Name, "- emergency sell")
				if not tower.Sell(nil, victim) and victim.Parent == TowersWorkspace then
					victim:Destroy()
				end
			end
			CorruptionDeaths[victim] = nil
		end)
	end
	return actual
end

local function corruptionArea(attacker, origin, radius, damage, limit, excluded)
	if not origin then return 0 end
	local count, total = 0, 0
	for other in pairs(TowerSet) do
		if other ~= excluded and validCorruptionVictim(attacker, other) then
			local part = corruptionTargetPart(other)
			if (part.Position - origin).Magnitude <= radius then
				total += corruptionDamage(attacker, other, damage)
				count += 1
				if limit and count >= limit then break end
			end
		end
	end
	return total
end

local function corruptionStunned(config)
	local untilTime = config:GetAttribute("StunnedUntil")
	if untilTime and os_clock() < untilTime then return true end
	local value = config:FindFirstChild("Stunned")
	if value and value:IsA("NumberValue") and value.Value > 0 then return true end
	return false
end

local function corruptionFace(attacker, victim)
	local origin = attacker.PrimaryPart or attacker:FindFirstChild("HumanoidRootPart")
	local targetPart = corruptionTargetPart(victim)
	if not origin or not targetPart then return end
	local p = origin.Position
	local q = targetPart.Position
	origin.CFrame = CFrame.new(p, Vector3.new(q.X, p.Y, q.Z))
end

local function corruptionChain(attacker, first, count, radius, damage)
	local hit, current = {}, first
	local total = 0
	for _ = 1, count do
		if not current or hit[current] or not validCorruptionVictim(attacker, current) then break end
		hit[current] = true
		total += corruptionDamage(attacker, current, damage)
		local part = corruptionTargetPart(current)
		if not part then break end
		local best, closest = nil, radius
		for other in pairs(TowerSet) do
			if not hit[other] and validCorruptionVictim(attacker, other) then
				local d = (corruptionTargetPart(other).Position - part.Position).Magnitude
				if d <= closest then best, closest = other, d end
			end
		end
		current = best
	end
	return total
end

-- Dedicated damage calculations, but the normal scheduler still owns ammo,
-- burst intervals and firing. Corruption never writes to EnemyStats.
local function corruptionPrimaryAttack(attacker, player, config)
	if not isCorruptedTower(attacker) or corruptionStunned(config) then return end
	local rng = config:FindFirstChild("Range")
	local victim = nearestCorruptionTower(attacker, rng and rng.Value)
	if not victim then return end
	if not tower.Ammo(config, attacker) then return end
	local damage = (config:FindFirstChild("Damage") and config.Damage.Value) or 0
	local total = 0
	local source = corruptionOrigin(attacker)
	local targetPosition = corruptionTargetPart(victim).Position
	-- Preserve Behemoth's distance multipliers.
	local bh = config:FindFirstChild("BehemothStats")
	local multiplierLogic = bh and bh:FindFirstChild("DamageMultiplierLogic")
	if multiplierLogic and source then
		local dist = (Vector3.new(targetPosition.X,0,targetPosition.Z) - Vector3.new(source.X,0,source.Z)).Magnitude
		for _, bandName in ipairs({"MinRange", "MidRange", "LongRange"}) do
			local band = multiplierLogic:FindFirstChild(bandName)
			local radius = band and band:FindFirstChild("Range")
			local mult = band and band:FindFirstChild("Multiplier")
			if radius and mult and dist <= radius.Value then damage = math_round(damage * mult.Value); break end
		end
	end

	if config:FindFirstChild("Splash") then
		-- The standard projectile reaches a captured aim point after travel.
		local speed = (config:FindFirstChild("ProjectileSpeed") and config.ProjectileSpeed.Value) or 50
		local travel = math_max((targetPosition - (source or targetPosition)).Magnitude / math_max(speed,0.01),0.05) / getGameSpeed()
		ReplicateEffectsEvent:FireAllClients(attacker, targetPosition, "SplashProjectile", travel)
		task_delay(travel, function()
			if attacker.Parent and isCorruptedTower(attacker) then
				local r = config:FindFirstChild("SplashRadius")
				local dealt = corruptionArea(attacker, targetPosition, (r and r.Value) or 0, damage)
				local tdv = config:FindFirstChild("TotalDamage")
				if tdv then tdv.Value += dealt end
			end
		end)
	elseif config:FindFirstChild("Shocker") then
		local sh = config.Shocker
		local chain = sh:FindFirstChild("ChainCount")
		total = corruptionChain(attacker, victim, (chain and chain.Value) or 1, 5, damage)
		local remoteFolder = events:FindFirstChild("Shocker")
		local shock = remoteFolder and remoteFolder:FindFirstChild("LightningBolt")
		if shock then shock:FireAllClients(attacker, {victim}) end
	else
		total = corruptionDamage(attacker, victim, damage)
	end

	-- Additional cone damage for Flamethrower, using the existing barrel setup.
	if config:FindFirstChild("BurnTime") and config:FindFirstChild("Flamethrower") then
		local barrel
		if attacker:GetAttribute("ModifiedFlamethrower") then
			local torso = attacker:FindFirstChild("Torso")
			barrel = torso and torso:FindFirstChild("AngleMessure")
		else
			local weapon = attacker:FindFirstChild("Weapon")
			local handle = weapon and weapon:FindFirstChild("Handle")
			barrel = handle and handle:FindFirstChild("Fire")
		end
		if barrel and barrel:IsA("Attachment") then
			local origin, forward = barrel.WorldPosition, barrel.WorldCFrame.LookVector
			for other in pairs(TowerSet) do
				if validCorruptionVictim(attacker, other) then
					local delta = corruptionTargetPart(other).Position - origin
					if delta.Magnitude > 0.001 and delta.Magnitude <= (rng and rng.Value or 0) then
						if math.acos(math_clamp(forward:Dot(delta.Unit), -1, 1)) <= math.rad(15) then
							total += corruptionDamage(attacker, other, damage)
						end
					end
				end
			end
		end
	end
	if config:FindFirstChild("AOE") and config:FindFirstChild("MaxHits") then
		total += corruptionArea(attacker, source, (rng and rng.Value) or 0, damage, config.MaxHits.Value, victim)
	end
	if config:FindFirstChild("PelletCount") then
		local weapon = attacker:FindFirstChild("Weapon")
		local handle = weapon and weapon:FindFirstChild("Handle")
		local muzzle = handle and handle:FindFirstChild("Start")
		if muzzle and muzzle:IsA("Attachment") then
			local spread = math.rad((config:FindFirstChild("SpreadAngle") and config.SpreadAngle.Value) or 10)
			for _ = 1, config.PelletCount.Value do
				local yaw = (math_random() - 0.5)*spread
				local pitch = (math_random() - 0.5)*spread
				local dir = (CFrame.fromAxisAngle(Vector3.yAxis,yaw) * CFrame.fromAxisAngle(Vector3.xAxis,pitch)):VectorToWorldSpace(muzzle.WorldCFrame.LookVector)
				for other in pairs(TowerSet) do
					if validCorruptionVictim(attacker, other) then
						local delta = corruptionTargetPart(other).Position - muzzle.WorldPosition
						if delta.Magnitude > 0.001 and delta.Magnitude <= (rng and rng.Value or 0)
							and math.acos(math_clamp(dir:Dot(delta.Unit),-1,1)) <= spread / 2 then
							total += corruptionDamage(attacker, other, damage)
						end
					end
				end
			end
		end
	end
	if not config:FindFirstChild("Aviator") and not config:FindFirstChild("Flying") then
		corruptionFace(attacker, victim)
	end
	animateTowerEvent:FireAllClients(attacker, "Attack", victim)
	local tdv = config:FindFirstChild("TotalDamage")
	if tdv then tdv.Value += total end
	local ammo = config:FindFirstChild("CurrentAmmo")
	if ammo then ammo.Value = math_max(0, ammo.Value - 1) end
end

local function corruptionSecondaryAttack(attacker, config, secondary)
	if not isCorruptedTower(attacker) or corruptionStunned(config) then return end
	local r = secondary:FindFirstChild("Range")
	local victim = nearestCorruptionTower(attacker, r and r.Value)
	if not victim then return end
	local damage = (secondary:FindFirstChild("Damage") and secondary.Damage.Value) or 0
	local attackType = (secondary:FindFirstChild("Type") and secondary.Type.Value) or "Default"
	local splashFlag = secondary:FindFirstChild("Splash")
	local splash = splashFlag and splashFlag.Value
	local point = corruptionTargetPart(victim).Position
	local actual = 0
	if attackType == "AOE" then
		actual = corruptionArea(attacker, corruptionOrigin(attacker), r and r.Value or 0, damage)
		local head = attacker:FindFirstChild("Head") or attacker:FindFirstChild("HumanoidRootPart")
		if head and ParticleFolder:FindFirstChild("Explosion") then
			local fx = ParticleFolder.Explosion:Clone(); fx.Parent = head
			local snd = fx:FindFirstChildWhichIsA("Sound",true)
			if snd then pcall(snd.Play,snd) end
			Debris:AddItem(fx, 2)
		end
	else
		if attackType == "Rocket" then
			local hf = events:FindFirstChild("Helicopter")
			local remote = hf and hf:FindFirstChild("FireRockets")
			local aviatorFolder = events:FindFirstChild("Aviator")
			local aviatorRemote = aviatorFolder and aviatorFolder:FindFirstChild("FireRockets")
			if config:FindFirstChild("Flying") and remote then remote:FireAllClients(attacker, victim)
			elseif config:FindFirstChild("Aviator") and aviatorRemote then aviatorRemote:FireAllClients(attacker,victim) end
		elseif attackType == "Laser" then
			local head = attacker:FindFirstChild("Head") or attacker:FindFirstChild("HumanoidRootPart")
			if head and head:IsA("BasePart") then
				local p0 = head.Position
				local dist = (point - p0).Magnitude
				if dist > 0 then
					local beam = Instance.new("Part")
					beam.Anchored = true; beam.CanCollide = false; beam.CanQuery = false
					beam.Material = Enum.Material.Neon; beam.Size = Vector3.new(0.2,0.2,dist)
					beam.CFrame = CFrame.lookAt(p0,point)*CFrame.new(0,0,-dist/2)
					beam.Parent = Workspace
					Debris:AddItem(beam,0.08)
				end
			end
		end
		if splash then
			local splashRadius = secondary:FindFirstChild("SplashRadius")
			-- Original SecondarySplash: direct hit PLUS splash hits on neighbors.
			actual = corruptionDamage(attacker, victim, damage)
			actual += corruptionArea(attacker, point, splashRadius and splashRadius.Value or 0, damage, nil, victim)
		else
			actual = corruptionDamage(attacker, victim, damage)
		end
	end
	if not config:FindFirstChild("Aviator") and not config:FindFirstChild("Flying") then
		corruptionFace(attacker, victim)
	end
	local tdv = config:FindFirstChild("TotalDamage")
	if tdv then tdv.Value += actual end
end

-- ============================================================
-- FIND TARGET  (squared distance, cached MobSet, no allocations)
-- ============================================================
function tower.FindTarget(newTower, range, mode)
	if isCorruptedTower(newTower) then return nearestCorruptionTower(newTower, range) end
	return Targeting.Find(newTower, range, mode)
end

-- ============================================================
-- FACE TARGET
-- ============================================================
function tower.FaceTargetInstant(newTower, target)
	local hrp    = newTower.PrimaryPart
	local hitbox = target:FindFirstChild("Hitbox")
	if not (hrp and hitbox) then return end
	local pos  = hrp.Position
	local tpos = hitbox.Position
	hrp.CFrame = CFrame.new(pos, Vector3.new(tpos.X, pos.Y, tpos.Z))
end

function tower.FacePositionInstant(newTower, position)
	local hrp = newTower.PrimaryPart or newTower:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local pos = hrp.Position
	hrp.CFrame = CFrame.new(pos, Vector3.new(position.X, pos.Y, position.Z))
end

function tower.FaceTarget(newTower, target, _)
	tower.FaceTargetInstant(newTower, target)
end

-- ============================================================
-- AMMO
-- ============================================================
function tower.Ammo(config, newTower)
	local cur     = config:FindFirstChild("CurrentAmmo")
	if not cur then return true end
	local maxAmmo = config:FindFirstChild("MaxAmmo")
	local reloadCd = config:FindFirstChild("ReloadCooldown")
	if not (maxAmmo and reloadCd) then return true end

	local reloading = config:FindFirstChild("Reloading")
	if not reloading then
		reloading = Instance.new("BoolValue")
		reloading.Name = "Reloading"; reloading.Value = false; reloading.Parent = config
	end

	if reloading.Value then return false end
	if cur.Value > 0 then return true end

	reloading.Value = true
	local hrp = newTower:FindFirstChild("HumanoidRootPart")
	if hrp then
		local s = hrp:FindFirstChild("Reload")
		if s then s.PlaybackSpeed = GAME_SPEED; s:Play() end
	end

	task_delay(reloadCd.Value / getGameSpeed(), function()
		if config.Parent then
			cur.Value = maxAmmo.Value
			reloading.Value = false
		end
	end)
	return false
end

-- ============================================================
-- BEHEMOTH
-- ============================================================

-- ============================================================
-- FIRE / BLEED / DEFENSE MELT / SLOWDOWN
-- ============================================================
function tower.Fire(newTower, target, duration, damage)
	local effects = target:FindFirstChild("Effects")
	if not effects then return end
	local bt = effects:FindFirstChild("BurnTime")
	local fd = effects:FindFirstChild("FireDamage")
	if not (bt and fd) then return end
	if duration >= bt.Value then bt.Value = duration; fd.Value = damage end
end

function tower.Bleed(newTower, target, duration, damage, stacks, timePerStack)
	local effects = target:FindFirstChild("Effects")
	if not effects then return end
	local bt = effects:FindFirstChild("BleedTime")
	local bd = effects:FindFirstChild("BleedDamage")
	local bs = effects:FindFirstChild("BleedStacks")
	local tp = effects:FindFirstChild("BleedTimePerStack")
	if not (bt and bd) then return end
	if duration >= bt.Value then
		bt.Value = duration; bd.Value = damage
		if bs then bs.Value = stacks end
		if tp then tp.Value = timePerStack end
	end
end

function tower.DefenseMelt(newTower, target)
	local cfg     = newTower.Config
	local meltCfg = cfg:FindFirstChild("DefenseMelt")
	if not meltCfg then return end

	local pct    = meltCfg:FindFirstChild("MeltPercentAmount")
	local tickV  = meltCfg:FindFirstChild("MeltPerTick")
	local tickPct = meltCfg:FindFirstChild("MeltPerTickPercent")
	if not (pct and tickV and tickPct) then return end

	local stats   = target:FindFirstChild("EnemyStats")
	local defense = stats and stats:FindFirstChild("Defense")
	if not defense then return end

	local dVal   = defense:FindFirstChild("DefenseValue")
	local dPct   = defense:FindFirstChild("DefensePercentValue")
	local global = target:FindFirstChild("Effects") and target.Effects:FindFirstChild("DefenseMelted")
	if not (dVal and dPct and global) then return end

	local localMelt = 0
	while target.Parent and defense.Parent do
		task_wait(1 / getGameSpeed())
		if localMelt >= pct.Value or global.Value >= pct.Value then break end
		local allowed = math_min(tickPct.Value, pct.Value - localMelt, pct.Value - global.Value)
		dVal.Value   -= tickV.Value
		dPct.Value   -= allowed
		localMelt    += allowed
		global.Value += allowed
		if dVal.Value <= 0 or dPct.Value <= 0 then defense:Destroy(); break end
	end
end

function tower.Slowdown(newTower, target)
	local cfg     = newTower.Config
	local slowCfg = cfg:FindFirstChild("SlowDown")
	if not slowCfg then return end
	local stats   = target:FindFirstChild("EnemyStats")
	local speed   = stats and stats:FindFirstChild("Speed")
	local orig    = stats and stats:FindFirstChild("OrigSpeed")
	if not speed then return end
	local effects = target:FindFirstChild("Effects")
	if not effects then return end
	local slowed  = effects:FindFirstChild("HasBeenSlowed")
	if not slowed or slowed.Value then return end
	local pct = slowCfg.SlowAmount.Value
	speed.Value = speed.Value * (1 - pct)
	if orig then orig.Value = orig.Value * (1 - pct) end
	slowed.Value = true
end

-- ============================================================
-- SPLASH  (accepts mob snapshot to avoid re-fetch)
-- ============================================================
function tower.Splash(centerPos, towerModel, mobSnapshot)
	local dmg    = towerModel.Config.Damage.Value
	local radius = towerModel.Config.SplashRadius.Value
	local tdv    = towerModel.Config:FindFirstChild("TotalDamage")
	local mobs   = mobSnapshot or MobsFolder:GetChildren()

	for _, mob in ipairs(mobs) do
		local hit   = mob:FindFirstChild("Hitbox")
		local stats = mob:FindFirstChild("EnemyStats")
		if not (hit and stats) then continue end
		if (hit.Position - centerPos).Magnitude > radius then continue end
		if stats:FindFirstChild("Invincible") then continue end

		local expDef = stats:FindFirstChild("ExplosionDefense")
		local adj    = expDef and math_round(dmg / (1 + expDef.DefenseValue.Value)) or dmg
		local old    = stats.Health.Value
		if old <= 0 then continue end
		local dealt  = math_min(adj, old)

		local shield = stats:FindFirstChild("ShieldHealth")
		if shield and shield.Health.Value > 0 then
			shield.Health.Value -= dealt
		else
			stats.Health.Value -= dealt
			if tdv then tdv.Value += dealt end
			if not stats:FindFirstChild("NoCash") then
				for _, plr in ipairs(CachedPlayers) do
					local c = plr:FindFirstChild("Cash")
					if c then c.Value += math_max(1, math_round(dealt * 0.55)) end
				end
			end
		end
	end
end

-- ============================================================
-- FIRE SPLASH PROJECTILE
-- Captures the target's current position (the "aim point"), fires
-- the shot to clients immediately for synced VFX, then resolves
-- damage at that fixed point after the travel delay.
-- If the target moves out of the splash radius before impact,
-- the shot effectively "misses" it.
-- ============================================================
function tower.FireSplashProjectile(newTower, target, config)
	ProjectileService.Launch(newTower, target, config,
		function(...) ReplicateEffectsEvent:FireAllClients(...) end,
		function(aim, model) tower.Splash(aim, model) end)
end

function tower.Aviator(newTower)
	local hrp = newTower:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local Speed = hrp:FindFirstChild("Speed")
	local Att   = hrp:FindFirstChild("FlightPos")
	if not (Speed and Att) then return end
	Att.MaxVelocity = Speed.Value * getGameSpeed()
end

local MinelayerEvents = ReplicatedStorage.Events:WaitForChild("MinelayerEvents")
local PlaceMineEvent  = MinelayerEvents:WaitForChild("PlaceMine")

function tower.MineLayer(newTower, player)
	SupportService.Register('MineLayer', newTower, function(scope)
		require(TowerSystemFolder.Supports.MineLayer).Start(scope, {
			GetGameSpeed = getGameSpeed,
			MineMod = MineMod,
			PlaceMineEvent = PlaceMineEvent,
			Tower = tower,
		}, newTower, player)
	end)
end

function tower.Flamethrower(newTower, mobSnapshot)
	local cfg  = newTower.Config
	local dmg  = cfg.Damage.Value
	local rng  = cfg.Range.Value
	local tdv  = cfg:FindFirstChild("TotalDamage")
	local half = math.rad(30) / 2

	local barrel
	if newTower:GetAttribute("ModifiedFlamethrower") then
		barrel = newTower:FindFirstChild("Torso")
			and newTower.Torso:FindFirstChild("AngleMessure")
	else
		barrel = newTower:FindFirstChild("Weapon")
			and newTower.Weapon:FindFirstChild("Handle")
			and newTower.Weapon.Handle:FindFirstChild("Fire")
	end
	if not barrel then return end

	local origin  = barrel.WorldPosition
	local forward = barrel.WorldCFrame.LookVector
	local mobs    = mobSnapshot or MobsFolder:GetChildren()

	for _, mob in ipairs(mobs) do
		local hit   = mob:FindFirstChild("Hitbox")
		local stats = mob:FindFirstChild("EnemyStats")
		if not (hit and stats) then continue end
		if stats:FindFirstChild("Invincible") then continue end

		local dir  = hit.Position - origin
		local dist = dir.Magnitude
		if dist > rng then continue end

		local dot   = forward:Dot(dir.Unit)
		local theta = math.acos(math_clamp(dot, -1, 1))
		if theta > half then continue end

		local expDef = stats:FindFirstChild("ExplosionDefense")
		local adj    = expDef and math_round(dmg / (1 + expDef.DefenseValue.Value)) or dmg
		local old    = stats.Health.Value
		if old <= 0 then continue end
		local dealt  = math_min(adj, old)

		local shield = stats:FindFirstChild("ShieldHealth")
		if shield and shield.Health.Value > 0 then
			shield.Health.Value -= dealt
		else
			stats.Health.Value -= dealt
		end
		if tdv then tdv.Value += dealt end

		local noShield = not (shield and shield.Health.Value > 0)
		if noShield and not stats:FindFirstChild("NoCash") then
			for _, plr in ipairs(CachedPlayers) do
				local c = plr:FindFirstChild("Cash")
				if c then c.Value += math_max(1, math_round(dealt * 0.55)) end
			end
		end
	end
end

function tower.AOE(targeted, obj, maxHits)
	local count = 0
	for mob in pairs(MobSet) do
		if count >= maxHits then break end
		if mob == targeted then continue end
		local hit   = mob:FindFirstChild("Hitbox")
		local stats = mob:FindFirstChild("EnemyStats")
		if hit and stats and (hit.Position - obj.HumanoidRootPart.Position).Magnitude <= obj.Config.Range.Value then
			local shield = stats:FindFirstChild("ShieldHealth")
			if shield and shield.Health.Value > 0 then
				shield.Health.Value -= obj.Config.Damage.Value
			else
				stats.Health.Value -= obj.Config.Damage.Value
				count += 1
			end
		end
	end
end


-- ============================================================
-- CORE ATTACK LOGIC
-- ============================================================
tower.DoAttackLogic = PrimaryAttack.new({
	Tower = tower, Towers = Towers, IsCorrupted = isCorruptedTower,
	CorruptionAttack = corruptionPrimaryAttack, Info = Info, MobsFolder = MobsFolder,
	Effects = ReplicateEffectsEvent, Animate = animateTowerEvent,
	GetPlayers = function() return CachedPlayers end,
})

-- ============================================================
-- WAVE VALUE
-- ============================================================
local WaveValue = Info:WaitForChild("Wave")

local function waitGameSeconds(seconds)
	if seconds <= 0 then return end
	local elapsed, step = 0, 0.1
	while elapsed < seconds do
		task_wait(step)
		elapsed += step * getGameSpeed()
	end
end

-- ============================================================
-- STUN HOOK SYSTEM  (unchanged from original — behaviour correct)
-- ============================================================
local TowersFolderWS = TowersWorkspace
local STUN_OFFSET    = CFrame.new(0, 0.5, 0)
local StunState      = setmetatable({}, { __mode = "k" })

local function safeGameSpeed()
	local s = getGameSpeed()
	return (type(s) == "number" and s > 0) and s or 1
end

local function getHeadPart(towerModel)
	local h = towerModel:FindFirstChild("Head")
	return (h and h:IsA("BasePart")) and h or nil
end

local function moveFxToHead(fx, head)
	if fx:IsA("BasePart") then
		fx.Anchored = true; fx.CanCollide = false; fx.CFrame = head.CFrame * STUN_OFFSET
	elseif fx:IsA("Model") then
		local p = fx.PrimaryPart or fx:FindFirstChildWhichIsA("BasePart")
		if p then
			fx.PrimaryPart = p; p.Anchored = true; p.CanCollide = false
			fx:PivotTo(head.CFrame * STUN_OFFSET)
		end
	end
end

local function getOrCreateAttach(head)
	local a = head:FindFirstChild("StunAttach")
	if not a then
		a = Instance.new("Attachment"); a.Name = "StunAttach"
		a.Position = Vector3.new(0, 0.5, 0); a.Parent = head
	end
	return a
end

local function destroyOurFx(head)
	local att = head:FindFirstChild("StunAttach")
	if att then
		local fx = att:FindFirstChild("Dizzy_StunSystem")
		if fx then fx:Destroy() end
	end
	local fx2 = head:FindFirstChild("Dizzy_StunSystem")
	if fx2 then fx2:Destroy() end
end

local function ensureDizzy(towerModel, config)
	if not (towerModel and towerModel.Parent and config and config.Parent) then return nil, nil end
	local head = getHeadPart(towerModel)
	if not head then return nil, nil end
	local att  = getOrCreateAttach(head)
	local existing = att:FindFirstChild("Dizzy_StunSystem") or head:FindFirstChild("Dizzy_StunSystem")
	if existing and existing.Parent then moveFxToHead(existing, head); return existing, head end
	local template = ParticleFolder:FindFirstChild("Dizzy")
	if not template then return nil, head end
	local fx = template:Clone(); fx.Name = "Dizzy_StunSystem"; fx:SetAttribute("StunFx", true)
	if fx:IsA("ParticleEmitter") or fx:IsA("Beam") or fx:IsA("Attachment") then fx.Parent = att
	else fx.Parent = head end
	moveFxToHead(fx, head)
	local sound = fx:FindFirstChildWhichIsA("Sound", true)
	if sound then task_spawn(function() pcall(sound.Play, sound) end) end
	return fx, head
end

local function startOrRefreshStun(towerModel, config, stunnedValueObj)
	if not (towerModel and towerModel.Parent and config and config.Parent) then return end
	if not (stunnedValueObj and stunnedValueObj.Parent == config) then return end

	-- ========================================================
	-- TREE STUN SHIELD — AUTHORITATIVE PRE-STUN BLOCK
	--
	-- IMPORTANT: this happens BEFORE StunnedUntil is written and BEFORE
	-- dizzy FX are created. The old Tree ChildAdded listener could race
	-- this global stun listener, which is why a shielded tower could still
	-- visibly / mechanically become stunned for a moment.
	-- ========================================================
	if hasActiveTowerStunShield(towerModel) then
		consumeTowerStunShields(towerModel, "Stun")

		-- Do NOT destroy the incoming Stunned object synchronously from inside
		-- Config.ChildAdded. Roblox is still completing the Parent assignment at
		-- that moment; trying to set Parent = nil re-entrantly can produce:
		--
		-- "Something unexpectedly tried to set the parent of Stunned to NULL..."
		--
		-- Defer the removal until the current ChildAdded dispatch has finished.
		if stunnedValueObj.Parent == config then
			task_defer(function()
				if stunnedValueObj
					and stunnedValueObj.Parent == config
				then
					pcall(function()
						stunnedValueObj:Destroy()
					end)
				end
			end)
		end

		-- Defensive cleanup: a blocked stun must leave zero server stun state.
		config:SetAttribute("StunnedUntil", nil)

		local staleState = StunState[config]
		if staleState then
			if staleState.head and staleState.head.Parent then
				destroyOurFx(staleState.head)
			end
			StunState[config] = nil
		end

		return
	end

	local duration = math_max(stunnedValueObj.Value / safeGameSpeed(), 0)
	config:SetAttribute("StunnedUntil", os_clock() + duration)
	local state = StunState[config]
	if not state then
		state = { tower=towerModel, head=nil, fx=nil }; StunState[config] = state
	else state.tower = towerModel end
	local head = getHeadPart(towerModel)
	state.head = head
	if head then
		local fx, fxHead = ensureDizzy(towerModel, config)
		state.head = fxHead or head; state.fx = fx
	else state.fx = nil end
end

local function clearStunNow(config, skipMarkerDestroy)
	local state = StunState[config]

	if state
		and state.head
		and state.head.Parent
	then
		destroyOurFx(state.head)
	end

	StunState[config] = nil

	if config and config.Parent then
		config:SetAttribute("StunnedUntil", nil)

		-- If this function was reached FROM Config.ChildRemoved, the Stunned
		-- object's Parent is already being changed by Roblox. Never try to
		-- Destroy()/reparent that same object again from the removal callback.
		if not skipMarkerDestroy then
			local s = config:FindFirstChild("Stunned")

			if s and s:IsA("NumberValue") then
				pcall(function()
					s:Destroy()
				end)
			end
		end
	end
end

local function hookTowerForStun(towerModel)
	if not (towerModel and towerModel:IsA("Model")) then return end
	local config = towerModel:FindFirstChild("Config")
	if not config then return end
	local stunned = config:FindFirstChild("Stunned")
	if stunned and stunned:IsA("NumberValue") then startOrRefreshStun(towerModel, config, stunned) end
	config.ChildAdded:Connect(function(child)
		if child.Name == "Stunned" and child:IsA("NumberValue") then
			startOrRefreshStun(towerModel, config, child)
			child:GetPropertyChangedSignal("Value"):Connect(function()
				if child.Parent == config then startOrRefreshStun(towerModel, config, child) end
			end)
		end
	end)
	config.ChildRemoved:Connect(function(child)
		if child.Name == "Stunned" then
			-- The child is already in the middle of being unparented.
			-- Clear the server stun state without touching the marker again.
			clearStunNow(config, true)
		end
	end)
end

RunService.Heartbeat:Connect(function()
	local now = os_clock()
	for config, state in pairs(StunState) do
		local ok = pcall(function()
			if not (config and config.Parent) then StunState[config] = nil; return end
			local untilT = config:GetAttribute("StunnedUntil")
			if type(untilT) ~= "number" then clearStunNow(config); return end
			local head = state.head; local fx = state.fx
			if head and head.Parent and fx and fx.Parent then moveFxToHead(fx, head) end
			if now >= untilT then clearStunNow(config) end
		end)
		if not ok then
			if config and config.Parent then config:SetAttribute("StunnedUntil", nil) end
			if state and state.head and state.head.Parent then destroyOurFx(state.head) end
			StunState[config] = nil
		end
	end
end)

for _, t in ipairs(TowersFolderWS:GetChildren()) do hookTowerForStun(t) end
TowersFolderWS.ChildAdded:Connect(hookTowerForStun)

-- ============================================================
-- FARM
-- ============================================================
function tower.Farm(newTower, player)
	SupportService.Register('Farm', newTower, function(scope)
		require(TowerSystemFolder.Supports.Farm).Start(scope, {
			Comma = Comma,
			GetGameSpeed = getGameSpeed,
			Tower = tower,
			WaveValue = WaveValue,
			getEcoDebuffMultiplier = getEcoDebuffMultiplier,
		}, newTower, player)
	end)
end

function tower.Tree(newTower, player)
	SupportService.Register('Tree', newTower, function(scope)
		require(TowerSystemFolder.Supports.Tree).Start(scope, {
			GetGameSpeed = getGameSpeed,
			Tower = tower,
			TowerSet = TowerSet,
			consumeTowerStunShields = consumeTowerStunShields,
			isCorruptedTower = isCorruptedTower,
			registerTowerStunShield = registerTowerStunShield,
			unregisterTowerStunShield = unregisterTowerStunShield,
		}, newTower, player)
	end)
end

function tower.MedicFindTarget(newTower, range, _)
	if isCorruptedTower(newTower) then return nil end
	local hrp = newTower:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local best, bestDist = nil, math_huge
	for t in pairs(TowerSet) do
		if t == newTower or isCorruptedTower(t) then continue end
		local cfg = t:FindFirstChild("Config")
		if not cfg or cfg:FindFirstChild("Flying") then continue end
		local health = cfg:FindFirstChild("Health")
		local thrp   = t:FindFirstChild("HumanoidRootPart")
		if health and thrp then
			local hv = health:FindFirstChild("HealthValue")
			local mh = health:FindFirstChild("MaxHealth")
			if hv and mh and hv.Value < mh.Value then
				local d = (thrp.Position - hrp.Position).Magnitude
				if d <= range and d < bestDist then bestDist = d; best = t end
			end
		end
	end
	return best
end

function tower.MedicFaceTarget(newTower, target, duration)
	if not (newTower and newTower.PrimaryPart and target) then return end
	local head = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
	if not head then return end
	local np = newTower.PrimaryPart.Position; local tp = head.Position
	local cf = CFrame.new(np, Vector3.new(tp.X, np.Y, tp.Z))
	TweenService:Create(newTower.PrimaryPart,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{CFrame=cf}):Play()
end

-- ============================================================
-- MEDIC
-- ============================================================
function tower.Medic(newTower, player)
	SupportService.Register('Medic', newTower, function(scope)
		require(TowerSystemFolder.Supports.Medic).Start(scope, {
			GetGameSpeed = getGameSpeed,
			ParticleFolder = ParticleFolder,
			Tower = tower,
			WaveValue = WaveValue,
			animateTowerEvent = animateTowerEvent,
			getMedicBeam = getMedicBeam,
			isCorruptedTower = isCorruptedTower,
		}, newTower, player)
	end)
end

function tower.Shocker(targeted, towerModel, player)
	local config = towerModel:FindFirstChild("Config")
	if not config then return end
	local shocker = config:FindFirstChild("Shocker")
	if not shocker then return end
	local ChainCount = shocker:FindFirstChild("ChainCount")
	local StunTime   = shocker:FindFirstChild("StunTime")
	if not (ChainCount and StunTime) then return end

	local dmg       = config.Damage.Value
	local chainRange = 5
	local tdv       = config:FindFirstChild("TotalDamage")

	local weapon = towerModel:FindFirstChild("Weapon")
	local handle = weapon and weapon:FindFirstChild("Handle")
	local startAtt = handle and handle:FindFirstChild("Lightning")
	if not startAtt then return end

	-- Snapshot mobs once
	local mobs   = MobsFolder:GetChildren()
	local hitMap = {}
	local hitTargets = {}

	local function isValid(mob)
		local s = mob:FindFirstChild("EnemyStats")
		local h = mob:FindFirstChild("Hitbox")
		if not (s and h) then return false end
		if s.Health.Value <= 0 or s:FindFirstChild("Invincible") then return false end
		return true
	end

	local function applyDamage(mob)
		local stats = mob:FindFirstChild("EnemyStats")
		if not stats then return end
		local old   = stats.Health.Value
		if old <= 0 then return end
		local dealt = math_min(dmg, old)
		local shield = stats:FindFirstChild("ShieldHealth")
		if shield and shield.Health.Value > 0 then shield.Health.Value -= dealt
		else stats.Health.Value -= dealt end
		if tdv then tdv.Value += dealt end

		local effects = mob:FindFirstChild("Effects")
		if effects then
			local bt  = effects:FindFirstChild("StunTime")
			local isS = effects:FindFirstChild("IsStunned")

			-- IMPORTANT:
			-- Shocker only supplies stun time. The mob effect system owns
			-- IsStunned, setting it true when the stun starts and false when
			-- the timer expires. Setting IsStunned here caused mob.Stunned()
			-- to think the stun was already running, so it returned early and
			-- the enemy could remain permanently marked as stunned.
			if bt and isS
				and StunTime.Value > 0
				and stats.MaxHealth.Value < 1500
				and not stats:FindFirstChild("NoStun")
				and not isS.Value
			then
				-- Start a fresh stun. Do not stack repeated Shocker hits while
				-- already stunned; once the mob effect system clears IsStunned,
				-- this can be applied again normally.
				bt.Value = StunTime.Value

				local animator = mob:FindFirstChildOfClass("Animator")
					or (mob:FindFirstChild("AnimationController")
						and mob.AnimationController:FindFirstChildOfClass("Animator"))
				if animator then
					for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
						track:Stop(0.1 / GAME_SPEED)
					end
					local anim = Instance.new("Animation")

					if mob.EnemyStats:FindFirstChild("Flying") and mob.Name == "Glider" then
						anim.AnimationId = "rbxassetid://101860625363207"
					elseif mob.EnemyStats:FindFirstChild("Flying") and mob.Name == "Pilot" then
						anim.AnimationId = "rbxassetid://115411855743173"
					else
						anim.AnimationId = "rbxassetid://94145580619770"
					end
					local track = animator:LoadAnimation(anim)
					track.Priority = Enum.AnimationPriority.Action; track.Looped = true; track:Play()
					task_delay(StunTime.Value / GAME_SPEED, function()
						if track then track:Stop(0.2 / GAME_SPEED) end
					end)
				end
			end
		end

		if player and player:FindFirstChild("Cash") and not stats:FindFirstChild("NoCash") then
			player.Cash.Value += math_max(1, math_round(dealt * 0.55))
		end
	end

	local current = targeted
	for i = 1, ChainCount.Value do
		if not current or hitMap[current] then break end
		hitMap[current] = true; table.insert(hitTargets, current)
		applyDamage(current)

		local curHit   = current:FindFirstChild("Hitbox")
		if not curHit then break end

		local closest, closestDist = nil, chainRange
		for _, mob in ipairs(mobs) do
			if not hitMap[mob] and isValid(mob) then
				local h = mob:FindFirstChild("Hitbox")
				if h then
					local d = (h.Position - curHit.Position).Magnitude
					if d <= closestDist then closestDist = d; closest = mob end
				end
			end
		end
		current = closest
	end

	ReplicatedStorage.Events.Shocker.LightningBolt:FireAllClients(towerModel, hitTargets)
end

-- ============================================================
-- SPAWNER
-- ============================================================
-- Upgrade-safe Motor Pool / unit spawner.
--
-- Behavior:
--   • Placement starts each already-unlocked unit on PlacementCooldown.
--   • Existing units KEEP their current countdown through upgrades.
--   • If an existing unit's SpawnCooldown changes, the CURRENT timer is
--     shifted by the exact cooldown difference:
--         40 -> 30 = subtract 10 seconds from the current timer.
--         30 -> 40 = add 10 seconds to the current timer.
--     Upgrade adjustments are clamped to a minimum of 1 second.
--   • If a slot unlocks a NEW unit, or its Unit name changes, that slot's
--     timer resets to the CURRENT PlacementCooldown. After that first spawn,
--     it uses the normal SpawnCooldown for that slot.
--   • HealthMultiplier / SpeedMultiplier are read LIVE at spawn time.
--   • One lightweight loop per spawner tower handles all 3 slots.
--   • No duplicate loops if Spawner is accidentally started twice.
--
-- SpawnerStates is intentionally kept at module scope so the eventual
-- max-level Motor Pool ability can safely interact with the live queue.
-- ============================================================

function tower.Spawner(newTower, player)
	SupportService.Register('Spawner', newTower, function(scope)
		require(TowerSystemFolder.Supports.Spawner).Start(scope, {
			GetGameSpeed = getGameSpeed,
			Tower = tower,
			UnitMod = UnitMod,
		}, newTower, player)
	end)
end

function tower.BootTower(newTower, player)
	if not (newTower and newTower.Parent) then return end
	local cfg = newTower:FindFirstChild("Config")
	if not cfg then return end
	if cfg:FindFirstChild("Commander") then task_spawn(tower.FireRateSupport, newTower, player); return end
	if cfg:FindFirstChild("Farm") then task_spawn(tower.Farm, newTower, player); return end
	if cfg:FindFirstChild("Tree") then task_spawn(tower.Tree, newTower); return end
	if cfg:FindFirstChild("Medic") then task_spawn(tower.Medic, newTower, player); return end
	if cfg:FindFirstChild("SpawnCooldown") or cfg:FindFirstChild("SpawnCooldown2") or cfg:FindFirstChild("SpawnCooldown3") then
		task_spawn(tower.Spawner, newTower, player); return
	end
	if cfg:FindFirstChild("RebuildTime") then task_spawn(tower.Scrambler, newTower, player); return end
	if tower.StartAttackLoop then tower.StartAttackLoop(newTower, player) end
end

-- ============================================================
-- SECONDARY ATTACK
-- ============================================================
function tower.SecondarySplash(targeted, obj)
	local sec = obj.Config:FindFirstChild("Secondary")
	if not sec then return end
	local damage = sec.Damage.Value; local radius = sec.SplashRadius.Value
	local tdv    = obj.Config:FindFirstChild("TotalDamage")

	if targeted and targeted:FindFirstChild("Hitbox") and targeted:FindFirstChild("EnemyStats") then
		local inv = targeted.EnemyStats:FindFirstChild("Invincible")
		if not inv then
			local sh = targeted.EnemyStats:FindFirstChild("ShieldHealth")
			if sh and sh.Health.Value > 0 then sh.Health.Value -= damage
			else targeted.EnemyStats.Health.Value -= damage end
			if tdv then tdv.Value += damage end
		end
	end

	local center = targeted and targeted:FindFirstChild("Hitbox") and targeted.Hitbox.Position
	if not center then return end

	for mob in pairs(MobSet) do
		if mob == targeted then continue end
		local hit   = mob:FindFirstChild("Hitbox")
		local stats = mob:FindFirstChild("EnemyStats")
		if not (hit and stats) then continue end
		if (center - hit.Position).Magnitude > radius then continue end
		if stats:FindFirstChild("Invincible") then
			local sh = mob.Hitbox:FindFirstChild("Shield"); if sh then sh.Attack:Play() end; continue
		end
		local expDef = stats:FindFirstChild("ExplosionDefense")
		local fd     = expDef and math_round(damage / (1 + stats.ExplosionDefense.DefenseValue.Value)) or damage
		local sh2    = stats:FindFirstChild("ShieldHealth")
		if sh2 and sh2.Health.Value > 0 then sh2.Health.Value -= fd
		else stats.Health.Value -= fd end
		if tdv then tdv.Value += damage end
	end
end

tower.DoSecondaryAttackLogic = SecondaryAttack.new({
	Tower = tower, Towers = Towers, IsCorrupted = isCorruptedTower,
	CorruptionAttack = corruptionSecondaryAttack, MobSet = MobSet,
})

-- ============================================================
-- START ATTACK LOOP
-- ============================================================
function tower.StartAttackLoop(newTower, player, carryOver)
	local config = newTower:FindFirstChild("Config")
	if not config or config:FindFirstChild("Commander") or config:FindFirstChild("Tree") or config:FindFirstChild("MineStats") then return end
	local isPhaser = config:FindFirstChild("BeamerSettings") ~= nil
	Towers[newTower] = {
		player       = player,
		config       = config,
		MatchGeneration = Match.Capture(),
		-- Generation zero is preparation for the first match, not an ended match.
		PendingMatch = Match.Capture() == 0 and not Match.IsCurrent(Match.Capture()),
		lastAttack   = (carryOver and carryOver.lastAttack) or 0,
		isBursting   = false,
		burstGen     = 0,
		lastSecondary = 0,
		-- Secondary is checked dynamically because an in-place upgrade can
		-- unlock Config.Secondary after the attack loop has already started.
		secondaryBursting = false,
		heliLast     = 0,
		heliRate     = 1/60,
		nextAttack   = (carryOver and carryOver.nextAttack) or 0,
		nextSecondary = (carryOver and carryOver.nextSecondary) or 0,
		_swaySeed    = math_random() * 1000,
		_offsetIndex = 0,
		_lastPitch   = 0,
		_lastRoll    = 0,
		_attackTarget = nil,
		_owner       = nil,
		isPhaser     = isPhaser,
		phaserPhase  = isPhaser and "StandBy" or nil,
		phaserTarget = nil,

		-- Phaser has TWO damage concepts:
		--
		-- phaserBaseDamage = TowerData's normal/base Damage for the level.
		-- phaserDamage     = current ramped damage during this lock.
		--
		-- Keeping them separate is what lets upgrades change the future base
		-- without touching an already-running LockedOn beam.
		phaserBaseDamage =
			isPhaser
			and (
				config:FindFirstChild("Damage")
				and config.Damage.Value
				or 0
			)
			or nil,

		phaserDamage = nil,
		phaserNextTick = 0,
		phaserPhaseEnd = 0,
	}
end
-- ============================================================
-- BURST
-- ============================================================
tower.Burst = BurstAttack.new({Tower = tower, Towers = Towers})

-- ============================================================
-- HELICOPTER (unchanged logic, data-driven from Heartbeat)
-- ============================================================
local HeliSlotsByOwner = setmetatable({}, { __mode = "k" })
local function getHeliSlot(owner, towerModel)
	local bucket = HeliSlotsByOwner[owner]
	if not bucket then
		bucket = { byTower = setmetatable({}, {__mode="k"}), next = 1 }
		HeliSlotsByOwner[owner] = bucket
	end
	local slot = bucket.byTower[towerModel]
	if not slot then slot = bucket.next; bucket.next += 1; bucket.byTower[towerModel] = slot end
	return slot
end

function tower.Helicopter(newTower, player)
	if not (newTower and newTower.Parent) then return end
	local data   = Towers[newTower]
	if not data then return end
	local config = data.config or newTower:FindFirstChild("Config")
	if not config then return end

	local followMode = (config:FindFirstChild("FlyingMode") and config.FlyingMode.Value) or "Follow"
	if not data._owner then
		local ov = config:FindFirstChild("Owner")
		local on = ov and ov.Value
		data._owner = (on and Players:FindFirstChild(on)) or player
	end
	local owner = data._owner
	if not owner then return end

	local range = config:FindFirstChild("Range") and config.Range.Value
	local mode  = (config:FindFirstChild("TargetMode") and config.TargetMode.Value) or "First"

	local function getHitbox(m)
		if isCorruptedTower(newTower) then return corruptionTargetPart(m) end
		return m and m.Parent and m:FindFirstChild("Hitbox")
	end
	local function isTargetValid(t) local h=getHitbox(t); return h and h:IsDescendantOf(workspace) end
	local function isTargetInRange(t, from, maxR)
		local h=getHitbox(t); return h and (h.Position-from).Magnitude<=maxR
	end
	local function getModelRoot(m)
		if m.PrimaryPart then return m.PrimaryPart end
		if m:IsA("BasePart") then return m end
		return m:FindFirstChildWhichIsA("BasePart",true)
	end

	local function ensureHeliFX(rootPart)
		if not rootPart then return end
		if data._fxRoot == rootPart and data._fxInit then return end
		data._fxRoot = rootPart; data._fxInit = true
		local old = rootPart:FindFirstChild("HeliFX"); if old then old:Destroy() end
		local att = Instance.new("Attachment"); att.Name="HeliFX"; att.Position=Vector3.new(0,0.15,0); att.Parent=rootPart
		local function mkParticle(name, rate, speed, life, size, trans, tex, le, br)
			local p = Instance.new("ParticleEmitter"); p.Name=name; p.Enabled=true
			p.LightInfluence=0; p.LightEmission=le; p.Brightness=br; p.Rate=rate
			p.Speed=speed; p.Lifetime=life; p.Rotation=NumberRange.new(0,360)
			p.RotSpeed=NumberRange.new(-8,8); p.SpreadAngle=Vector2.new(20,20)
			p.Drag=2; p.Size=size; p.Transparency=trans; p.Texture=tex; p.Parent=att
		end
		mkParticle("RotorMist",5,NumberRange.new(0.15,0.45),NumberRange.new(0.55,0.9),
			NumberSequence.new({NumberSequenceKeypoint.new(0,0.18),NumberSequenceKeypoint.new(0.5,0.42),NumberSequenceKeypoint.new(1,0.05)}),
			NumberSequence.new({NumberSequenceKeypoint.new(0,0.72),NumberSequenceKeypoint.new(0.5,0.84),NumberSequenceKeypoint.new(1,1)}),
			"rbxasset://textures/particles/smoke_main.dds",0.35,0.6)
		mkParticle("HeliShimmer",2,NumberRange.new(0,0.08),NumberRange.new(0.35,0.55),
			NumberSequence.new({NumberSequenceKeypoint.new(0,0.08),NumberSequenceKeypoint.new(0.5,0.16),NumberSequenceKeypoint.new(1,0)}),
			NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(1,1)}),
			"rbxasset://textures/particles/sparkles_main.dds",0.8,0.9)
		local light = Instance.new("PointLight"); light.Name="HeliNavLight"
		light.Color=Color3.fromRGB(170,220,255); light.Range=6; light.Brightness=0.2; light.Shadows=false; light.Parent=att
		data._fxAttachment=att; data._fxLight=light
		data._fxMist    = att:FindFirstChild("RotorMist")
		data._fxShimmer = att:FindFirstChild("HeliShimmer")
	end

	local function updateHeliFX(gsValue, movementSpeed)
		if not data._fxInit then return end
		local nowFx = tick()
		if nowFx - (data._fxRefresh or 0) < 0.12 then return end
		data._fxRefresh = nowFx
		local ma = math_clamp(movementSpeed/28,0,1); local ga = math_clamp(gsValue,0.5,3)
		if data._fxMist    then data._fxMist.Rate    = 4 + math.floor(ma*4*ga) end
		if data._fxShimmer then data._fxShimmer.Rate = 1 + math.floor(ma*2)    end
		if data._fxLight   then data._fxLight.Brightness = 0.15 + ma*0.18      end
	end

	local followPart, target
	if followMode == "Follow" then
		local char = owner.Character
		followPart = char and char:FindFirstChild("HumanoidRootPart")
		if followPart then
			local switchedFromPursuit = (data._lastFlyingMode == "Pursuit")
			if data._attackTarget and isTargetValid(data._attackTarget) and isTargetInRange(data._attackTarget, newTower:GetPivot().Position, range) then
				target = data._attackTarget
			else
				data._attackTarget = nil
				target = tower.FindTarget(newTower, range, mode)
				if target and getHitbox(target) then data._attackTarget = target end
			end
			if switchedFromPursuit and data._attackTarget and not isTargetInRange(data._attackTarget, newTower:GetPivot().Position, range) then
				data._attackTarget = nil
				target = tower.FindTarget(newTower, range, mode)
				if target and isTargetValid(target) then data._attackTarget = target else target = nil end
			end
		end
	elseif followMode == "Pursuit" then
		target = tower.FindTarget(newTower, math_huge, mode)
		local pursuitPart = target and getHitbox(target)
		if pursuitPart then followPart = pursuitPart; data._attackTarget = target
		else data._attackTarget = nil end
	end
	data._lastFlyingMode = followMode
	if not followPart then return end

	local gs = GAME_SPEED; if gs == 0 then gs = 1 end
	local now = tick()
	local dt  = math_clamp(now - (data._lastHeliStep or now), 0, 0.25)
	data._lastHeliStep = now

	local basePos = followPart.Position + Vector3.new(0, 5, 0)

	local index = data._offsetIndex
	if index == 0 then index = getHeliSlot(owner, newTower); data._offsetIndex = index end
	local angle = (index-1) * math.pi / 4
	local radius = 4 + (index % 3) * 0.8
	local offset = Vector3.new(math.cos(angle)*radius, 0, math.sin(angle)*radius)
	local targetPos = basePos + offset

	for t, d in pairs(Towers) do
		if d._owner == owner and t ~= newTower and t.Parent then
			local op = t:GetPivot().Position; local diff = targetPos - op; local dist = diff.Magnitude
			if dist < 2.5 and dist > 0.001 then targetPos += diff.Unit * (2.5-dist)*0.5 end
		end
	end

	local currentCFrame = newTower:GetPivot()
	local currentPos    = currentCFrame.Position
	local maxStep = newTower.Config:FindFirstChild("MovementSpeed").Value * gs * dt
	local toTarget = targetPos - currentPos; local distToTarget = toTarget.Magnitude
	local newPos = (distToTarget <= maxStep or distToTarget == 0) and targetPos
		or currentPos + toTarget.Unit * maxStep

	local swayTime = tick() + data._swaySeed
	newPos += followPart.CFrame:VectorToWorldSpace(Vector3.new(
		math.sin(swayTime*1.25)*0.15, math.sin(swayTime*2.2)*0.08, math.cos(swayTime*1.6)*0.16))

	local vel = followPart.AssemblyLinearVelocity; local speed = vel.Magnitude
	local ti   = math_clamp(speed*0.01,0,1); local look = followPart.CFrame.LookVector; local right = followPart.CFrame.RightVector
	local vu   = speed > 0.001 and vel.Unit or Vector3.zero
	local pitch = -look:Dot(vu)*ti*0.18; local roll = right:Dot(vu)*ti*0.18
	if speed < 0.5 then
		data._lastPitch = (data._lastPitch or 0) * 0.9; data._lastRoll = (data._lastRoll or 0) * 0.9
	else
		data._lastPitch = (data._lastPitch or 0)*0.8 + pitch*0.2; data._lastRoll = (data._lastRoll or 0)*0.8 + roll*0.2
	end
	pitch, roll = data._lastPitch, data._lastRoll

	local facingDir
	target = data._attackTarget
	if target and isTargetValid(target) then
		if followMode == "Follow" and not isTargetInRange(target, newPos, range) then
			data._attackTarget = nil; target = nil
		end
	else data._attackTarget = nil; target = nil end

	if followMode == "Follow" and not target then
		local nt = tower.FindTarget(newTower, range, mode)
		if nt and isTargetValid(nt) then data._attackTarget = nt; target = nt end
	end

	if target and target:FindFirstChild("Hitbox") then
		local ep = target.Hitbox.Position
		local flat = Vector3.new(ep.X, newPos.Y, ep.Z); local dir = flat - newPos
		facingDir = dir.Magnitude > 0.001 and dir.Unit or followPart.CFrame.LookVector
	else
		facingDir = followPart.CFrame.LookVector
	end

	local desired  = CFrame.lookAt(newPos, newPos + facingDir)
	local tilted   = desired * CFrame.Angles(pitch, 0, roll)
	local finalCF  = currentCFrame:Lerp(tilted, 0.1)
	newTower:PivotTo(finalCF)

	local rootPart = getModelRoot(newTower)
	ensureHeliFX(rootPart)
	updateHeliFX(gs, (newPos - currentPos).Magnitude / math_max(dt, 1/240))
end

function tower.HeliFaceTarget(newTower, target)
	if not newTower then return end
	local data = Towers[newTower]
	if not data then return end
	data._attackTarget = (target and target:FindFirstChild("Hitbox")) and target or nil
end

-- Spawn positioning update:
-- Each coil template may have Config.SpawnHeight (NumberValue, default 0).
-- SpawnHeight measures the BOTTOM of the coil relative to UnitSpawn.Position.Y.
-- The coil's horizontal facing follows the parent Scrambler's HumanoidRootPart.
--
-- ============================================================
-- SCRAMBLER / COILS
-- Replace the old SCRAMBLER through SCRAMBLER TOWER section
-- (stop immediately before COMMANDER FIRERATE SUPPORT).
--
-- Coil templates:
-- ReplicatedStorage.TowerUnits.Scrambler.Default.<TUnit.Value>
-- ReplicatedStorage.TowerUnits.Scrambler.Necro.<TUnit.Value>
-- Uses placedTower:GetAttribute("AppearanceName").
-- ============================================================

local SharedSlowedEnemies = setmetatable({}, { __mode = "k" })

local function scramblerRoot(unit)
	if not (unit and unit:IsA("Model")) then return nil end
	return unit.PrimaryPart
		or unit:FindFirstChild("Handle")
		or unit:FindFirstChildWhichIsA("BasePart")
end

local function scramblerTargetInfo(unit, enemy, range)
	local root = scramblerRoot(unit)
	local unitConfig = unit and unit:FindFirstChild("Config")
	if not (root and root:IsA("BasePart") and unitConfig) then return nil end
	if not (enemy and enemy.Parent == MobsFolder) then return nil end

	local stats = enemy:FindFirstChild("EnemyStats")
	local hitbox = enemy:FindFirstChild("Hitbox")
	local alpha = enemy:FindFirstChild("Alpha")
	if not (stats and hitbox and hitbox:IsA("BasePart") and alpha) then return nil end

	local health = stats:FindFirstChild("Health")
	if not (health and health.Value > 0) then return nil end
	if stats:FindFirstChild("Invincible") then return nil end

	local hidden = stats:FindFirstChild("Hidden")
	local hiddenDetection = unitConfig:FindFirstChild("HiddenDetection")
	if hidden and hidden.Value and not (hiddenDetection and hiddenDetection.Value) then
		return nil
	end

	local flying = stats:FindFirstChild("Flying")
	local flyingDetection = unitConfig:FindFirstChild("FlyingDetection")
	if flying and flying.Value and not (flyingDetection and flyingDetection.Value) then
		return nil
	end

	local dist = (hitbox.Position - root.Position).Magnitude
	if dist > math_max(0, range) then return nil end

	return stats, hitbox, alpha, dist
end

function tower.FindTargetForScrambler(scramblerUnit, range, mode, ignoreTargets)
	if not scramblerRoot(scramblerUnit) then return nil end
	local ignored = {}
	for _, mob in ipairs(ignoreTargets or {}) do
		ignored[mob] = true
	end

	local best, bestMetric
	mode = mode or "First"

	for mob in pairs(MobSet) do
		if ignored[mob] then continue end

		local stats, _, alpha, dist =
			scramblerTargetInfo(scramblerUnit, mob, range)
		if not stats then continue end

		-- Preserve the previous priority override for aggro enemies.
		if stats:FindFirstChild("Aggro") then
			return mob
		end

		local metric, preferHigher
		if mode == "Near" then
			metric, preferHigher = dist, false
		elseif mode == "Last" then
			metric, preferHigher = alpha.Value, false
		elseif mode == "Strong" then
			metric, preferHigher = stats.Health.Value, true
		elseif mode == "Weak" then
			metric, preferHigher = stats.Health.Value, false
		else -- "First", including any unexpected saved TargetMode.
			metric, preferHigher = alpha.Value, true
		end

		if bestMetric == nil
			or (preferHigher and metric > bestMetric)
			or (not preferHigher and metric < bestMetric)
		then
			best, bestMetric = mob, metric
		end
	end

	return best
end

-- All coils on the same enemy contribute to this one strongest-slow result.
local function refreshScramblerSlow(enemy)
	local scramblers = SharedSlowedEnemies[enemy]
	local stats = enemy and enemy:FindFirstChild("EnemyStats")
	local speed = stats and stats:FindFirstChild("Speed")
	local original = stats and stats:FindFirstChild("OrigSpeedForSlow")

	if not scramblers then return end
	if not (speed and original) then
		if next(scramblers) == nil then
			SharedSlowedEnemies[enemy] = nil
		end
		return
	end

	local strongest = 0
	for _, data in pairs(scramblers) do
		strongest = math_max(strongest, data.slowAmount)
	end

	if next(scramblers) == nil then
		SharedSlowedEnemies[enemy] = nil
	end

	local desired = math_max(0, original.Value * (1 - strongest))
	if speed.Value ~= desired then
		speed.Value = desired
	end
end

local function removeScramblerUnitSlows(unit)
	for enemy, scramblers in pairs(SharedSlowedEnemies) do
		if scramblers[unit] then
			scramblers[unit] = nil
			refreshScramblerSlow(enemy)
		end
	end
end

local function applyScramblerSlow(unit, enemy, stats, slowAmount, duration)
	if slowAmount <= 0 or duration <= 0 then return end

	local speed = stats:FindFirstChild("Speed")
	if not speed then return end

	local original = stats:FindFirstChild("OrigSpeedForSlow")
	if not original then
		local origSpeed = stats:FindFirstChild("OrigSpeed")
		original = Instance.new("NumberValue")
		original.Name = "OrigSpeedForSlow"
		original.Value = math_max(0, origSpeed and origSpeed.Value or speed.Value)
		original.Parent = stats
	end

	local scramblers = SharedSlowedEnemies[enemy]
	if not scramblers then
		scramblers = {}
		SharedSlowedEnemies[enemy] = scramblers
	end

	local entry = scramblers[unit]
	if entry then
		entry.remaining = duration
		entry.slowAmount = math_max(entry.slowAmount, slowAmount)
	else
		scramblers[unit] = {
			remaining = duration,
			slowAmount = slowAmount,
		}
	end

	refreshScramblerSlow(enemy)
end

local function dealScramblerDamage(stats, rawDamage)
	if typeof(rawDamage) ~= "number"
		or rawDamage ~= rawDamage
		or rawDamage <= 0
		or rawDamage == math_huge
	then
		return 0, 0
	end

	local damageRemaining = rawDamage
	local totalDamage, healthDamage = 0, 0

	local shield = stats:FindFirstChild("ShieldHealth")
	local shieldHealth = shield and shield:FindFirstChild("Health")
	if shieldHealth and shieldHealth.Value > 0 then
		local dealtToShield = math_min(damageRemaining, shieldHealth.Value)
		shieldHealth.Value = math_max(0, shieldHealth.Value - dealtToShield)
		totalDamage += dealtToShield
		damageRemaining -= dealtToShield
	end

	local health = stats:FindFirstChild("Health")
	if health and health.Value > 0 and damageRemaining > 0 then
		healthDamage = math_min(damageRemaining, health.Value)
		health.Value = math_max(0, health.Value - healthDamage)
		totalDamage += healthDamage
	end

	return totalDamage, healthDamage
end

function tower.ScramblerUnits(unit, player)
	if not (unit and unit:IsDescendantOf(TowersWorkspace)) then return end
	local unitConfig = unit:FindFirstChild("Config")
	if not unitConfig then
		warn("[Scrambler] Coil is missing Config:", unit:GetFullName())
		return
	end

	local range = unitConfig:FindFirstChild("Range")
	local damage = unitConfig:FindFirstChild("Damage")
	local cooldown = unitConfig:FindFirstChild("Cooldown")
	local targetMode = unitConfig:FindFirstChild("TargetMode")
	local maxTargets = unitConfig:FindFirstChild("MaxTargets")
	local slowConfig = unitConfig:FindFirstChild("SlowdownConfig")
	local bigCoil = unitConfig:FindFirstChild("BigCoil")

	if not (range and damage and cooldown and maxTargets and slowConfig) then
		warn("[Scrambler] Coil missing required Config values:", unit:GetFullName())
		return
	end

	local slowValue = slowConfig:FindFirstChild("SlowdownValue")
	local slowDuration = slowConfig:FindFirstChild("SlowdownDuration")
	local bossSlowValue = slowConfig:FindFirstChild("BossSlowdownValue")
	if not (slowValue and slowDuration) then
		warn("[Scrambler] Coil missing slowdown values:", unit:GetFullName())
		return
	end

	local unitsFolder = unit.Parent
	local parentTower = unitsFolder and unitsFolder.Parent
	local parentConfig = parentTower and parentTower:FindFirstChild("Config")
	local totalDamageValue = parentConfig and parentConfig:FindFirstChild("TotalDamage")
	local currentTargets = {}
	local attackElapsed = 0

	local destroyConnection
	destroyConnection = unit.Destroying:Connect(function()
		removeScramblerUnitSlows(unit)
		if destroyConnection then
			destroyConnection:Disconnect()
			destroyConnection = nil
		end
	end)

	task_spawn(function()
		local last = os_clock()

		while unit:IsDescendantOf(TowersWorkspace)
			and unitConfig.Parent
			and parentTower
			and parentTower:IsDescendantOf(TowersWorkspace)
		do
			local now = os_clock()
			local dt = math_clamp(now - last, 0, 0.5)
			last = now
			local cd = math_max(cooldown.Value, 0.001)
			local targetLimit = math_max(0, math.floor(maxTargets.Value))

			local positionPart = scramblerRoot(unit)
			if not positionPart then break end

			-- Remove targets that died, left range, lost detection, or became invincible.
			for i = #currentTargets, 1, -1 do
				if i > targetLimit
					or not scramblerTargetInfo(unit, currentTargets[i], range.Value)
				then
					table.remove(currentTargets, i)
				end
			end

			while #currentTargets < targetLimit do
				local newTarget = tower.FindTargetForScrambler(
					unit,
					range.Value,
					targetMode and targetMode.Value or "First",
					currentTargets
				)
				if not newTarget then break end
				table.insert(currentTargets, newTarget)
			end

			-- Cap elapsed cooldown so idle coils cannot burst-fire for many
			-- ticks after spending a long time without any targets.
			attackElapsed = math_min(cd, attackElapsed + dt * getGameSpeed())

			if attackElapsed >= cd and #currentTargets > 0 then
				attackElapsed = 0
				animateTowerEvent:FireAllClients(unit, "Attack", table.clone(currentTargets))

				for _, enemy in ipairs(currentTargets) do
					local stats = scramblerTargetInfo(unit, enemy, range.Value)
					if not stats then continue end

					local dealt, dealtToHealth =
						dealScramblerDamage(stats, damage.Value)

					if totalDamageValue and totalDamageValue.Parent and dealt > 0 then
						totalDamageValue.Value += dealt
					end

					if dealtToHealth > 0
						and player and player.Parent == Players
						and not stats:FindFirstChild("NoCash")
					then
						local cash = player:FindFirstChild("Cash")
						if cash then
							cash.Value += math_round(dealtToHealth * 0.55)
						end
					end

					local boss = enemy:FindFirstChild("IsFinalBoss")
					local slow
					if boss and boss.Value then
						slow = (bigCoil and bigCoil.Value and bossSlowValue)
							and bossSlowValue.Value or 0
					else
						slow = slowValue.Value
					end

					local remainingHealth = stats:FindFirstChild("Health")
					if remainingHealth and remainingHealth.Value > 0 then
						applyScramblerSlow(
							unit,
							enemy,
							stats,
							math_clamp(slow, 0, 1),
							math_max(0, slowDuration.Value)
						)
					end
				end
			end

			task_wait(0.06)
		end

		removeScramblerUnitSlows(unit)
		if destroyConnection then
			destroyConnection:Disconnect()
			destroyConnection = nil
		end
	end)
end

-- One shared worker for all Scrambler slow-duration timers.
do
	local slowDecayAccum = 0
	RunService.Heartbeat:Connect(function(dt)
		slowDecayAccum += dt
		if slowDecayAccum < 0.06 then return end

		local scaled = slowDecayAccum * getGameSpeed()
		slowDecayAccum = 0

		for enemy, scramblers in pairs(SharedSlowedEnemies) do
			if not (enemy and enemy.Parent == MobsFolder) then
				SharedSlowedEnemies[enemy] = nil
				continue
			end

			for unit, data in pairs(scramblers) do
				data.remaining -= scaled
				if data.remaining <= 0
					or not unit:IsDescendantOf(TowersWorkspace)
				then
					scramblers[unit] = nil
				end
			end

			refreshScramblerSlow(enemy)
		end
	end)
end

-- ============================================================
-- SCRAMBLER TOWER -- SKIN-SPECIFIC COIL TEMPLATES
-- ============================================================
function tower.Scrambler(newTower, player)
	if not (newTower and newTower:IsDescendantOf(TowersWorkspace)) then return end

	local config = newTower:FindFirstChild("Config")
	local rebuildTime = config and config:FindFirstChild("RebuildTime")
	local unitNameValue = config and config:FindFirstChild("TUnit")
	if not (rebuildTime and unitNameValue) then return end

	local root = ReplicatedStorage:FindFirstChild("TowerUnits")
	local towerName = newTower:GetAttribute("TowerName") or "Scrambler"
	local towerUnitsFolder = root and root:FindFirstChild(towerName)
	if not towerUnitsFolder then
		warn("[Scrambler] Missing TowerUnits/" .. towerName)
		return
	end

	local unitsFolder = newTower:FindFirstChild("Units")
	if not unitsFolder then
		unitsFolder = Instance.new("Folder")
		unitsFolder.Name = "Units"
		unitsFolder.Parent = newTower
	end

	local warnedMissing = {}

	local function currentRebuildTime()
		local value = rebuildTime.Value
		if typeof(value) ~= "number" or value ~= value or value == math_huge then
			return 1
		end
		return math_max(0.05, value)
	end

	local function coilTemplate()
		-- Placement code sets this attribute to the resolved appearance.
		local skinName = newTower:GetAttribute("AppearanceName")
		if typeof(skinName) ~= "string" or skinName == "" then
			skinName = "Default"
		end

		local requestedName = unitNameValue.Value
		if typeof(requestedName) ~= "string" or requestedName == "" then
			return nil
		end

		local skinFolder = towerUnitsFolder:FindFirstChild(skinName)
		local defaultFolder = towerUnitsFolder:FindFirstChild("Default")

		local template = skinFolder and skinFolder:FindFirstChild(requestedName)
		if not (template and template:IsA("Model")) then
			template = defaultFolder and defaultFolder:FindFirstChild(requestedName)
		end

		if template and template:IsA("Model") then
			return template
		end

		local key = skinName .. "/" .. requestedName
		if not warnedMissing[key] then
			warn("[Scrambler] Coil template not found:",
				"TowerUnits/" .. towerName .. "/" .. key,
				"(also checked Default)")
			warnedMissing[key] = true
		end
		return nil
	end

	local function spawnUnit()
		if not newTower:IsDescendantOf(TowersWorkspace) then return end
		local template = coilTemplate()
		if not template then return end

		local unit = template:Clone()
		local unitConfig = unit:FindFirstChild("Config")
		if not unitConfig then
			warn("[Scrambler] Template missing Config:", template:GetFullName())
			unit:Destroy()
			return
		end

		-- Each coil may contain a NumberValue called Config.SpawnHeight.
		-- The value is the desired clearance between the bottom of the
		-- coil's bounding box and UnitSpawn.Position.Y (default: 0 studs).
		-- This automatically accounts for coils of different sizes.
		local spawnPart = newTower:FindFirstChild("UnitSpawn")
		local spawnPos = (spawnPart and spawnPart:IsA("BasePart"))
			and spawnPart.Position or newTower:GetPivot().Position

		local spawnHeightValue = unitConfig:FindFirstChild("SpawnHeight")
		local spawnHeight = 0
		if spawnHeightValue and (
			spawnHeightValue:IsA("NumberValue")
				or spawnHeightValue:IsA("IntValue")
			) then
			local height = spawnHeightValue.Value
			if height == height and math_abs(height) < math_huge then
				spawnHeight = height
			end
		end

		-- Match the parent Scrambler's HumanoidRootPart facing direction,
		-- rather than resetting the coil to an unrotated world CFrame.
		-- Preserve horizontal facing without inheriting unwanted pitch/roll.
		local parentRoot = newTower:FindFirstChild("HumanoidRootPart")
		local look = (parentRoot and parentRoot:IsA("BasePart"))
			and parentRoot.CFrame.LookVector or newTower:GetPivot().LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		local spawnCFrame = CFrame.new(spawnPos)
		if flatLook.Magnitude > 0.001 then
			spawnCFrame = CFrame.lookAt(spawnPos, spawnPos + flatLook.Unit)
		end

		unit.Parent = unitsFolder
		unit:PivotTo(spawnCFrame)

		-- Place the BOTTOM of this actual model at the configured height,
		-- not its pivot/center. This fixes floating coils of varying sizes.
		local boundsCFrame, boundsSize = unit:GetBoundingBox()
		local bottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
		local desiredBottomY = spawnPos.Y + spawnHeight
		unit:PivotTo(unit:GetPivot() + Vector3.new(0, desiredBottomY - bottomY, 0))

		task_spawn(function()
			if newTower:IsDescendantOf(TowersWorkspace) then
				animateTowerEvent:FireAllClients(newTower, "Attack")
				local hrp = newTower:FindFirstChild("HumanoidRootPart")
				local sound = hrp and hrp:FindFirstChild("Attack")
				if sound and sound:IsA("Sound") then sound:Play() end
			end
		end)

		task_defer(function()
			if unit:IsDescendantOf(TowersWorkspace) then
				tower.ScramblerUnits(unit, player)
			end
		end)

		local lifespanValue = unitConfig:FindFirstChild("Lifespan")
		if lifespanValue then
			task_spawn(function()
				local total = lifespanValue.Value
				if total <= 0 then
					if unit.Parent then unit:Destroy() end
					return
				end

				local elapsed = 0
				local handle = unit:FindFirstChild("Handle")
				local lifetime = handle and handle:FindFirstChild("Lifetime")
				local bar = lifetime and lifetime:FindFirstChild("Bar")
				local fill = bar and bar:FindFirstChild("Fill")

				while unit:IsDescendantOf(TowersWorkspace) and elapsed < total do
					local dt = task_wait(0.1)
					elapsed += dt * getGameSpeed()
					if fill and fill.Parent then
						fill.Size = UDim2.new(
							math_clamp(1 - elapsed / total, 0, 1), 0, 1, 0
						)
					end
				end

				if unit.Parent then
					unit:Destroy()
				end
			end)
		end
	end

	-- Preserve initial immediate coil spawn from the previous implementation.
	spawnUnit()

	task_spawn(function()
		local previousRebuild = currentRebuildTime()
		local timeLeft = previousRebuild

		while newTower:IsDescendantOf(TowersWorkspace)
			and config.Parent and rebuildTime.Parent
		do
			local dt = task_wait(0.1)
			local newRebuild = currentRebuildTime()

			if newRebuild ~= previousRebuild then
				-- Maintain the same percentage of rebuild progress through upgrades.
				timeLeft = newRebuild * math_clamp(
					timeLeft / previousRebuild, 0, 1
				)
				previousRebuild = newRebuild
			end

			timeLeft -= dt * getGameSpeed()

			local timeValue = config:FindFirstChild("TimeUntilRebuild")
			if timeValue then
				timeValue.Value = math_max(0, math.ceil(timeLeft))
			end

			if timeLeft <= 0 then
				spawnUnit()
				timeLeft = currentRebuildTime()
				previousRebuild = timeLeft
			end
		end

		local timeValue = config:FindFirstChild("TimeUntilRebuild")
		if timeValue and timeValue.Parent then timeValue.Value = 0 end
	end)
end


-- ============================================================
-- COMMANDER FIRERATE SUPPORT
-- ============================================================
-- ============================================================
-- SHARED BUFF MANAGERS
-- Declare these ONCE at module scope (outside/above both functions),
-- alongside your other module-level locals (RunService, TowersWorkspace, etc).
-- They persist for the life of the script and are shared by every
-- commander instance, which is what lets us compare commanders
-- against each other instead of "first claim wins".
-- ============================================================
FireRateManager = {
	commanders = {}, -- [commanderInstance] = commanderData
	buffed     = {}, -- [towerInstance]     = { commander = commanderInstance, connections = {} }
	towerListenerStarted = false,
}

DamageManager = {
	commanders = {},
	buffed     = {},
	towerListenerStarted = false,
}

applyDeathWishRange = function(towerModel)
	local cfg = towerModel and towerModel:FindFirstChild("Config")
	if not cfg then return end
	local rangeVal  = cfg:FindFirstChild("Range")
	local baseRange = cfg:FindFirstChild("BaseRange")
	if not (rangeVal and baseRange) then return end

	local newBase = baseRange.Value
	if DeathWishModifier.Value == true then
		newBase = math_round(baseRange.Value * DeathWishInfo.RangeReduction.Value)
	end

	local buffOriginalRange = cfg:FindFirstChild("OriginalRange")
	if buffOriginalRange then
		buffOriginalRange.Value = newBase
		local commanderMarker = cfg:FindFirstChild("FirerateBuff")
		local commander = commanderMarker and commanderMarker.Value
		local cData = commander and FireRateManager.commanders[commander]
		rangeVal.Value = cData
			and math_round(newBase * effectiveBuffMultiplier(cData.RangeMultiplier.Value))
			or newBase
	else
		rangeVal.Value = newBase
	end
end

DeathWishModifier:GetPropertyChangedSignal("Value"):Connect(function()
	for towerModel in pairs(TowerSet) do
		applyDeathWishRange(towerModel)
	end
	if FireRateManager.recomputeAll then FireRateManager.recomputeAll() end
	if DamageManager.recomputeAll then DamageManager.recomputeAll() end
end)

DeathWishModifier:GetPropertyChangedSignal("Value"):Connect(function()
	for towerModel in pairs(TowerSet) do
		applyDeathWishRange(towerModel)
	end
end)

-- ============================================================
-- FIRE RATE SUPPORT
-- ============================================================
function tower.FireRateSupport(commander, player)
	SupportService.Register('FireRateSupport', commander, function(scope)
		require(TowerSystemFolder.Supports.FireRateSupport).Start(scope, {
			FireRateManager = FireRateManager,
			GetGameSpeed = getGameSpeed,
			ParticleFolder = ParticleFolder,
			Tower = tower,
			TowersWorkspace = TowersWorkspace,
			effectiveBuffMultiplier = effectiveBuffMultiplier,
			isCorruptedTower = isCorruptedTower,
		}, commander, player)
	end)
end

function tower.DamageSupport(commander, player)
	SupportService.Register('DamageSupport', commander, function(scope)
		require(TowerSystemFolder.Supports.DamageSupport).Start(scope, {
			DamageManager = DamageManager,
			GetGameSpeed = getGameSpeed,
			ParticleFolder = ParticleFolder,
			Tower = tower,
			TowersWorkspace = TowersWorkspace,
			effectiveBuffMultiplier = effectiveBuffMultiplier,
			isCorruptedTower = isCorruptedTower,
		}, commander, player)
	end)
end

local PhaserController = require(TowerSystemFolder.Phaser).new({
	Tower = tower, IsCorrupted = isCorruptedTower, CorruptionAttack = corruptionPrimaryAttack,
	Info = Info, GetGameSpeed = getGameSpeed, GetPlayers = function() return CachedPlayers end,
	corruptionDamage = corruptionDamage, corruptionFace = corruptionFace,
	corruptionTargetPart = corruptionTargetPart, validCorruptionVictim = validCorruptionVictim,
})
tower.PhaserTick = PhaserController.Tick

function tower.Cowboy(config, player, newTower)
	local Killcount = config:FindFirstChild("KillCount")
	local CurrentKills = config:FindFirstChild("Kills")
	local CashReward = config:FindFirstChild("CashReward")
	if not (Killcount and CurrentKills and CashReward) then return end
	if CurrentKills.Value < Killcount.Value then return end  -- fast exit

	if player and player:FindFirstChild("Cash") then player.Cash.Value += CashReward.Value end
	CurrentKills.Value = 0
	local head = newTower:FindFirstChild("Head")
	if head and head:FindFirstChild("Cash") then
		local cashGui   = head.Cash:FindFirstChild("CashCounter")
		local cashSound = head.Cash:FindFirstChild("CashSound")
		if cashSound then cashSound:Play() end
		if cashGui then
			cashGui.Enabled = true
			local cl = cashGui:FindFirstChild("Cash"); local cl2 = cashGui:FindFirstChild("Cash2")
			if cl  then cl.Text  = "$"..CashReward.Value end
			if cl2 then cl2.Text = "$"..CashReward.Value end
			local fxF = ReplicatedStorage.Events:FindFirstChild("TowerEffects")
			local fo  = fxF and fxF:FindFirstChild("FarmOrbs")
			if fo and newTower.HumanoidRootPart then
				fo:FireAllClients("Coin", 0.5, 1, newTower.HumanoidRootPart.Position, player)
			end
			task_delay(0.5, function() if cashGui and cashGui.Parent then cashGui.Enabled=false end end)
		end
	end
end

-- ============================================================
-- SHOTGUNNER
-- ============================================================
function tower.Shotgunner(config, player, newTower)
	local PelletCount = config:FindFirstChild("PelletCount")
	if not PelletCount then return end
	local Damage       = config.Damage.Value
	local Range        = config.Range.Value
	local SpreadAngle  = config:FindFirstChild("SpreadAngle") and math.rad(config.SpreadAngle.Value) or math.rad(10)
	local hiddenDet    = config:FindFirstChild("HiddenDetection") and config.HiddenDetection.Value or false
	local flyingDet    = config:FindFirstChild("FlyingDetection") and config.FlyingDetection.Value or false
	local LeadDet    = config:FindFirstChild("LeadDetection") and config.LeadDetection.Value or false
	local startAtt = newTower:FindFirstChild("Weapon") and newTower.Weapon:FindFirstChild("Handle")
		and newTower.Weapon.Handle:FindFirstChild("Start")
	if not (startAtt and startAtt:IsA("Attachment")) then return end

	local towerPos  = startAtt.WorldPosition
	local towerLook = startAtt.WorldCFrame.LookVector
	local mobs      = MobsFolder:GetChildren()  -- snapshot once per volley
	local shotTotal = 0
	local halfSpread = SpreadAngle / 2

	local pelletsFolder = newTower:FindFirstChild("Pellets")
	if not pelletsFolder then
		pelletsFolder = Instance.new("Folder"); pelletsFolder.Name="Pellets"; pelletsFolder.Parent=newTower
	end

	for i = 1, PelletCount.Value do
		local rH = (math_random()-0.5)*SpreadAngle; local rV = (math_random()-0.5)*SpreadAngle
		local pelletDir = (CFrame.fromAxisAngle(Vector3.new(0,1,0),rH)*CFrame.fromAxisAngle(Vector3.new(1,0,0),rV))
			:VectorToWorldSpace(towerLook)

		local beam = Instance.new("Part")
		beam.CanCollide=false; beam.CanQuery=false; beam.Anchored=true
		beam.BrickColor=BrickColor.new("Gold"); beam.Material=Enum.Material.Neon
		beam.Size=Vector3.new(0.1,0.1,Range)
		beam.CFrame=CFrame.new(towerPos,towerPos+pelletDir)*CFrame.new(0,0,-Range/2)
		beam.Parent=pelletsFolder; Debris:AddItem(beam,0.35)
		TweenService:Create(beam,TweenInfo.new(0.3,Enum.EasingStyle.Linear),{Transparency=1}):Play()

		for _, mob in ipairs(mobs) do
			local hitbox = mob:FindFirstChild("Hitbox"); local stats = mob:FindFirstChild("EnemyStats")
			if not (hitbox and stats) then continue end
			if stats:FindFirstChild("Invincible") then continue end
			if (stats:FindFirstChild("Hidden") and stats.Hidden.Value and not hiddenDet) then continue end
			if (stats:FindFirstChild("Flying") and stats.Flying.Value and not flyingDet) then continue end
			if (stats:FindFirstChild("Lead") and stats.Lead.Value and not LeadDet) then continue end
			local toMob = hitbox.Position - towerPos; local dist = toMob.Magnitude
			if dist > Range then continue end
			local dot = pelletDir:Dot(toMob.Unit)
			if math.acos(math_clamp(dot,-1,1)) <= halfSpread then
				stats.Health.Value -= Damage; shotTotal += Damage
				local sh = stats:FindFirstChild("ShieldHealth")
				if not (sh and sh.Health.Value > 0) then
					if player and player:FindFirstChild("Cash") and not stats:FindFirstChild("NoCash") then
						player.Cash.Value += math_max(1, math_round(Damage*0.55))
					end
				end
			end
		end
	end

	if config:FindFirstChild("TotalDamage") then config.TotalDamage.Value += shotTotal end
end

-- ============================================================
-- COMMANDER BUFF REMOTES
-- ============================================================
-- All player-activated tower abilities use this single server-side gate.
-- A corrupted tower is still allowed to attack towers via the corruption
-- implementation, but it cannot activate abilities until cleansed.
local function canUseTowerAbility(player, model)
	if not Match.IsCurrent(Match.Capture()) then return false end
	if not player or typeof(model) ~= "Instance"
		or not model:IsA("Model") or model.Parent ~= TowersWorkspace then
		return false
	end
	local config = model:FindFirstChild("Config")
	local owner = config and config:FindFirstChild("Owner")
	if not owner or owner.Value ~= player.Name then return false end
	if isCorruptedTower(model) then return false end
	local health = config:FindFirstChild("Health")
	local value = health and health:FindFirstChild("HealthValue")
	if value and value.Value <= 0 then return false end
	return true
end

CommanderBuff.OnServerEvent:Connect(function(player, towerModel)
	if not canUseTowerAbility(player, towerModel) then return end
	SupportService.Register('CommanderAbility', towerModel, function(scope)
		local task_wait = scope.Task.wait
		local config = towerModel:FindFirstChild('Config')
		if not config then return end
		local saved = {}
		for _, path in {'ABILITYACTIVE','CanBuff','Buffs.FirerateBuff','Buffs.FirerateBuffPercentage','DamageBuffs.DamageBuff'} do
			local object = config
			for _, name in string.split(path,'.') do object = object and object:FindFirstChild(name) end
			if object then saved[object] = object.Value end
		end
		scope:OnCancel(function()
			for object, value in pairs(saved) do if object.Parent then object.Value = value end end
			local head = towerModel:FindFirstChild('Head')
			local scream = head and head:FindFirstChild('Scream')
			local emitter = scream and scream:FindFirstChild('Scream')
			if emitter then emitter.Enabled = false end
			local root = towerModel:FindFirstChild('HumanoidRootPart')
			local rootScream = root and root:FindFirstChild('Scream')
			if rootScream then rootScream.Enabled = false end
		end)
	if not canUseTowerAbility(player, towerModel) then return end
	local config = towerModel and towerModel:FindFirstChild("Config")
	local hrp    = towerModel and towerModel:FindFirstChild("HumanoidRootPart")
	if not config then return end
	if hrp then
		local sounds = {}
		for _, s in ipairs(hrp:GetChildren()) do if s:IsA("Sound") then table.insert(sounds,s) end end
		if #sounds > 0 then sounds[math_random(1,#sounds)]:Play() end
	end
	local head = towerModel:FindFirstChild("Head")
	if head and head:FindFirstChild("Scream") and head.Scream:FindFirstChild("Scream") then
		head.Scream.Scream.Enabled = true
	end
	config.Buffs.FirerateBuff.Value          = 1.325
	config.Buffs.FirerateBuffPercentage.Value = 32.5
	config.CanBuff.Value   = "No"
	config.ABILITYACTIVE.Value = true
	task_wait(config.BuffLegnth.Value)
	if head and head:FindFirstChild("Scream") and head.Scream:FindFirstChild("Scream") then
		head.Scream.Scream.Enabled = false
	end
	config.ABILITYACTIVE.Value = false
	config.Buffs.FirerateBuff.Value          = 1.225
	config.Buffs.FirerateBuffPercentage.Value = 22.5
	local cd = (config.BuffCooldown.Value - config.BuffLegnth.Value) * getAbilityCooldownMultiplier()
	if cd > 0 then task_wait(cd) end
	config.CanBuff.Value = "Yes"
	end, true)
end)

events.SergeantBuff.OnServerEvent:Connect(function(player, towerModel)
	if not canUseTowerAbility(player, towerModel) then return end
	SupportService.Register('SergeantAbility', towerModel, function(scope)
		local task_wait = scope.Task.wait
		local config = towerModel:FindFirstChild('Config')
		if not config then return end
		local saved = {}
		for _, path in {'ABILITYACTIVE','CanBuff','Buffs.FirerateBuff','Buffs.FirerateBuffPercentage','DamageBuffs.DamageBuff'} do
			local object = config
			for _, name in string.split(path,'.') do object = object and object:FindFirstChild(name) end
			if object then saved[object] = object.Value end
		end
		scope:OnCancel(function()
			for object, value in pairs(saved) do if object.Parent then object.Value = value end end
			local head = towerModel:FindFirstChild('Head')
			local scream = head and head:FindFirstChild('Scream')
			local emitter = scream and scream:FindFirstChild('Scream')
			if emitter then emitter.Enabled = false end
			local root = towerModel:FindFirstChild('HumanoidRootPart')
			local rootScream = root and root:FindFirstChild('Scream')
			if rootScream then rootScream.Enabled = false end
		end)
	if not canUseTowerAbility(player, towerModel) then return end
	local config = towerModel and towerModel:FindFirstChild("Config")
	local hrp    = towerModel and towerModel:FindFirstChild("HumanoidRootPart")
	if not config then return end
	if hrp then
		local sounds = {}
		for _, s in ipairs(hrp:GetChildren()) do
			if s:IsA("Sound") and s.Name == "Scream1" then table.insert(sounds,s) end
		end
		if #sounds > 0 then sounds[math_random(1,#sounds)]:Play() end
		if hrp:FindFirstChild("Scream") then hrp.Scream.Enabled = true end
	end
	config.DamageBuffs.DamageBuff.Value = 1.1
	config.CanBuff.Value   = "No"
	config.ABILITYACTIVE.Value = true
	task_wait(config.BuffLegnth.Value)
	if hrp and hrp:FindFirstChild("Scream") then hrp.Scream.Enabled = false end
	config.ABILITYACTIVE.Value = false
	config.DamageBuffs.DamageBuff.Value = 1
	local cd = (config.BuffCooldown.Value - config.BuffLegnth.Value) * getAbilityCooldownMultiplier()
	if cd > 0 then task_wait(cd) end
	config.CanBuff.Value = "Yes"
	end, true)
end)

events.TankSpawn.OnServerEvent:Connect(function(player, towerModel)
	if not canUseTowerAbility(player, towerModel) then return end
	if not player
		or not towerModel
	then
		return
	end

	local config = towerModel:FindFirstChild("Config")
	if not config then
		return
	end

	local abilityCost = config:FindFirstChild("AbilityCost")
	local canBuff = config:FindFirstChild("CanBuff")
	local abilityActive = config:FindFirstChild("ABILITYACTIVE")
	local map = workspace.Map:FindFirstChildOfClass("Folder")

	if not abilityCost
		or not canBuff
		or not abilityActive
	then
		return
	end

	-- Make sure this tower actually belongs to the player.
	if config:FindFirstChild("Owner")
		and config.Owner.Value ~= player.Name
	then
		return
	end

	-- Prevent activation while already active.
	if abilityActive.Value then
		return
	end

	-- Make sure the player can afford it.
	if player:FindFirstChild("Cash") == nil
		or player.Cash.Value < abilityCost.Value
	then
		return
	end

	-- ========================================================
	-- ACTIVATE
	-- ========================================================

	player.Cash.Value -= abilityCost.Value

	canBuff.Value = "No"
	abilityActive.Value = true

	-- ========================================================
	-- SPAWN TANK1
	-- ========================================================

	local success, err = pcall(
		UnitMod.Spawn,
		"Tank1",
		1,
		0,
		1,
		1,
		map,
		towerModel
	)

	if not success then
		warn(
			"[TankSpawn] Failed to spawn Tank1 for",
			towerModel:GetFullName(),
			err
		)

		-- Don't leave the ability permanently active if spawning failed.
		abilityActive.Value = false
		canBuff.Value = "Yes"
		return
	end

	-- ========================================================
	-- ABILITY DURATION
	-- ========================================================

	local buffLength = config:FindFirstChild("BuffLegnth")

	if buffLength then
		local duration =
			buffLength.Value / getGameSpeed()

		if duration > 0 then
			task.wait(duration)
		end
	end

	abilityActive.Value = false

	-- ========================================================
	-- COOLDOWN
	-- ========================================================

	local buffCooldown = config:FindFirstChild("BuffCooldown")

	if buffCooldown and buffLength then

		local cd =
			(buffCooldown.Value - buffLength.Value)
			/ getGameSpeed()
			* getAbilityCooldownMultiplier()

		if cd > 0 then
			task.wait(cd)
		end

	end

	canBuff.Value = "Yes"
end)

-- ============================================================
-- REAPER SOUL SUMMONS
-- Remote: Events.ReaperSpawn(player, tower, GUIButtonName, action)
-- action: "Press", "Release", "Cancel", or "Tap" (keyboard/gamepad)
-- A held Press automatically summons MAX after 2 real seconds on SERVER.
-- Release before then summons ONE. All calculations are server-authoritative.
-- ONE: only used tower gets 1 game-second cooldown.
-- MAX: used tower gets full cooldown; others get 10s soft cooldown.
-- ============================================================
local REAPER_HOLD_TIME = 2
local REAPER_SINGLE_COOLDOWN = 1 -- game second, only used tower
local REAPER_FULL_COOLDOWN = 50 -- game seconds, used tower after MAX
local REAPER_SOFT_COOLDOWN = 10 -- game seconds, other owned Reapers after MAX

-- GUI button -> Config.Reaper unlock BoolValue, corresponding unit template,
-- SoulRequirements candidate keys (button name has priority).
-- Unit names are matched to your existing Config.Reaper flag names.
local ReaperTypes = {
	SkeletonHoard = {
		Flag = "Skeleton", Unit = "Skeleton",
		RequirementKeys = {"SkeletonHoard", "Skeleton"},
	},
	GiantSkeletonHoard = {
		Flag = "Giant Skeleton", Unit = "Giant Skeleton",
		RequirementKeys = {"GiantSkeletonHoard", "Giant Skeleton", "GiantSkeleton"},
	},
	SluaghHoard = {
		Flag = "Slaugh", Unit = "Sluagh",
		RequirementKeys = {"SluaghHoard", "Slaugh", "Sluagh"},
	},
	ForgottenKnight = {
		Flag = "ForgottenKnight", Unit = "Forgotten Knight",
		RequirementKeys = {"ForgottenKnight", "Forgotten Knight"},
	},
	HallowGaurd = {
		Flag = "HallowGaurd", Unit = "Hallow Gaurd",
		RequirementKeys = {"HallowGaurd", "HallowGuard", "Hallow Guard"},
	},
}

local ReaperCooldowns = setmetatable({}, {__mode = "k"})
local ReaperPending = {} -- [player] = {Tower, ButtonName, Started}, one hold at a time
-- Lock each tower, not the entire player. Spawns from other ready towers
-- can run independently, as required for single-unit summons.
local ReaperSpawnLocks = setmetatable({}, {__mode = "k"}) -- [towerModel] = true

-- Game-second clock: dynamically follows GameSpeed even if the value changes
-- mid-animation. Only active MAX-summoning towers are kept in this table.
local REAPER_CAST_DURATION = 2
local REAPER_CAST_LIGHTNING_AT = 0.95
local ReaperCastStates = setmetatable({}, {__mode = "k"})

local function finishReaperCast(towerModel)
	if not ReaperCastStates[towerModel] then return end
	ReaperCastStates[towerModel] = nil
	if towerModel.Parent == TowersWorkspace then
		towerModel:SetAttribute("ReaperSummoning", false)
		ReaperSummonFX:FireAllClients("End", towerModel)
	end
end

local function startReaperCast(towerModel)
	if towerModel.Parent ~= TowersWorkspace or ReaperCastStates[towerModel] then return end
	ReaperCastStates[towerModel] = {Elapsed = 0, LightningFired = false}
	towerModel:SetAttribute("ReaperSummoning", true)
	ReaperSummonFX:FireAllClients("Start", towerModel)
end

local function updateReaperCooldownAttributes(model, state)
	if not model or not model.Parent then return end
	model:SetAttribute("ReaperSpawnHardCooldown", math_max(0, math.ceil(state.Hard * 10) / 10))
	model:SetAttribute("ReaperSpawnSoftCooldown", math_max(0, math.ceil(state.Soft * 10) / 10))
end

local function getReaperCooldownState(model)
	local state = ReaperCooldowns[model]
	if not state then
		state = {Hard = 0, Soft = 0}
		ReaperCooldowns[model] = state
	end
	return state
end

-- Count down in game seconds, so timescale changes also affect ACTIVE timers.
local reaperCooldownReplicationTime = 0
RunService.Heartbeat:Connect(function(dt)
	local advance = dt * getGameSpeed()
	reaperCooldownReplicationTime += dt
	local publish = reaperCooldownReplicationTime >= 0.1
	if publish then reaperCooldownReplicationTime = 0 end

	-- Drive active max-summon casts in the SAME timer worker as cooldowns.
	for model, cast in pairs(ReaperCastStates) do
		if model.Parent ~= TowersWorkspace then
			ReaperCastStates[model] = nil
		else
			cast.Elapsed += advance
			if not cast.LightningFired and cast.Elapsed >= REAPER_CAST_LIGHTNING_AT then
				cast.LightningFired = true
				ReaperSummonFX:FireAllClients("Lightning", model)
			end
			if cast.Elapsed >= REAPER_CAST_DURATION then
				finishReaperCast(model)
			end
		end
	end

	for model, state in pairs(ReaperCooldowns) do
		if model.Parent ~= TowersWorkspace then
			ReaperCooldowns[model] = nil
			continue
		end
		state.Hard = math_max(0, state.Hard - advance)
		state.Soft = math_max(0, state.Soft - advance)
		if publish or (state.Hard == 0 and state.Soft == 0) then
			updateReaperCooldownAttributes(model, state)
		end
		if state.Hard == 0 and state.Soft == 0 then
			ReaperCooldowns[model] = nil
		end
	end
end)

local function validSoulNumber(object)
	return object
		and (object:IsA("IntValue") or object:IsA("NumberValue"))
		and typeof(object.Value) == "number"
		and object.Value == object.Value
		and object.Value < math_huge
end

local function getValidReaperRequest(player, towerModel, buttonName)
	if typeof(towerModel) ~= "Instance"
		or not towerModel:IsA("Model")
		or towerModel.Parent ~= TowersWorkspace
		or typeof(buttonName) ~= "string" then
		return nil
	end

	local spec = ReaperTypes[buttonName]
	if not spec then return nil end -- strict allowlist, NOT an arbitrary unit name

	if not canUseTowerAbility(player, towerModel) then return nil end
	if towerModel:GetAttribute("ReaperSummoning") == true then return nil end
	local config = towerModel:FindFirstChild("Config")
	local owner = config and config:FindFirstChild("Owner")
	local reaper = config and config:FindFirstChild("Reaper")
	if not (owner and owner.Value == player.Name and reaper) then return nil end
	if config:FindFirstChild("DISABLED", true) then return nil end

	local healthFolder = config:FindFirstChild("Health")
	local health = healthFolder and healthFolder:FindFirstChild("HealthValue")
	if health and health.Value <= 0 then return nil end

	local unlock = reaper:FindFirstChild(spec.Flag)
	if not (unlock and unlock:IsA("BoolValue") and unlock.Value == true) then
		return nil
	end

	local souls = reaper:FindFirstChild("Souls")
	local requirements = reaper:FindFirstChild("SoulRequirements")
	if not validSoulNumber(souls) or not requirements then return nil end

	local required
	for _, key in ipairs(spec.RequirementKeys) do
		local candidate = requirements:FindFirstChild(key)
		if validSoulNumber(candidate) and candidate.Value > 0 then
			required = candidate.Value
			break
		end
	end
	if not required then return nil end
	return spec, souls, required
end

local function performReaperSummon(player, towerModel, buttonName, summonAll)
	if ReaperSpawnLocks[towerModel] then return end

	local spec, souls, soulCost = getValidReaperRequest(player, towerModel, buttonName)
	if not spec then return end

	local selfState = ReaperCooldowns[towerModel]
	if selfState and math_max(selfState.Hard, selfState.Soft) > 0 then return end

	local count = summonAll and math.floor(souls.Value / soulCost) or 1
	if count < 1 then
		tower.Error(player, "Not enough souls for " .. spec.Unit .. "!")
		return
	end
	local totalCost = count * soulCost
	if souls.Value < totalCost then return end

	local mapFolder = Workspace:FindFirstChild("Map")
	local map = mapFolder and mapFolder:FindFirstChildOfClass("Folder")
	if not map then
		warn("[ReaperSpawn] Map folder not found")
		return
	end

	-- Lock before the spawn function (which can yield), and start the
	-- tower's cooldown immediately. Soft CD only affects this player's
	-- OTHER Reaper towers; teammates keep their own timers.
	ReaperSpawnLocks[towerModel] = true
	local oldStates = {}
	local function saveBeforeChange(model)
		if not oldStates[model] then
			local st = getReaperCooldownState(model)
			oldStates[model] = {Hard = st.Hard, Soft = st.Soft}
		end
		return getReaperCooldownState(model)
	end

	local modifier = math_max(0, getAbilityCooldownMultiplier())
	local config = towerModel:FindFirstChild("Config")
	local reaperConfig = config and config:FindFirstChild("Reaper")
	local configuredCooldown = reaperConfig and (
		reaperConfig:FindFirstChild("SpawnCooldown")
			or reaperConfig:FindFirstChild("SummonCooldown")
	)
	configuredCooldown = configuredCooldown or (config and config:FindFirstChild("BuffCooldown"))
	local fullCooldown = REAPER_FULL_COOLDOWN
	if validSoulNumber(configuredCooldown) and configuredCooldown.Value > 0 then
		fullCooldown = configuredCooldown.Value
	end

	local own = saveBeforeChange(towerModel)
	if summonAll then
		-- MAX summon: full cooldown on this Reaper, 10s soft on other Reapers.
		own.Hard = fullCooldown * modifier
		updateReaperCooldownAttributes(towerModel, own)

		for _, other in ipairs(TowersWorkspace:GetChildren()) do
			if other ~= towerModel then
				local cfg = other:FindFirstChild("Config")
				local otherOwner = cfg and cfg:FindFirstChild("Owner")
				local otherReaper = cfg and cfg:FindFirstChild("Reaper")
				if otherOwner and otherOwner.Value == player.Name and otherReaper then
					local st = saveBeforeChange(other)
					st.Soft = math_max(st.Soft, REAPER_SOFT_COOLDOWN * modifier)
					updateReaperCooldownAttributes(other, st)
				end
			end
		end
	else
		-- ONE summon: exactly 1 game-second cooldown, ONLY this Reaper.
		-- Do not touch any other Reaper's cooldown state.
		own.Hard = REAPER_SINGLE_COOLDOWN
		updateReaperCooldownAttributes(towerModel, own)
	end

	-- Spend once. The count argument spawns the requested number of units.
	souls.Value -= totalCost
	local ok, result = pcall(UnitMod.Spawn, spec.Unit, count, 0, 1, 1, map, towerModel)
	if not ok or result == false then
		warn("[ReaperSpawn] Spawn failed:", spec.Unit, count, result)
		if souls.Parent then souls.Value += totalCost end
		-- Undo the cooldowns only when spawning failed.
		for model, previous in pairs(oldStates) do
			if model.Parent == TowersWorkspace then
				local st = getReaperCooldownState(model)
				st.Hard, st.Soft = previous.Hard, previous.Soft
				updateReaperCooldownAttributes(model, st)
			end
		end
		tower.Error(player, "Failed to summon " .. spec.Unit .. ".")
	elseif summonAll then
		-- Only successful MAX summons enter the 2-game-second casting state.
		-- A single summon never interrupts normal attacks or animations.
		startReaperCast(towerModel)
	end
	ReaperSpawnLocks[towerModel] = nil
end

ReaperSpawn.OnServerEvent:Connect(function(player, towerModel, buttonName, action)
	if typeof(buttonName) ~= "string" or not ReaperTypes[buttonName] then return end
	if action == "Cancel" then
		local pending = ReaperPending[player]
		if pending and pending.Tower == towerModel and pending.ButtonName == buttonName then
			ReaperPending[player] = nil
		end
		return
	end

	if action == "Press" then
		if ReaperPending[player] or ReaperSpawnLocks[towerModel] then return end
		if not getValidReaperRequest(player, towerModel, buttonName) then return end
		local state = ReaperCooldowns[towerModel]
		if state and math_max(state.Hard, state.Soft) > 0 then return end

		local pending = {Tower = towerModel, ButtonName = buttonName, Started = os_clock()}
		ReaperPending[player] = pending
		task_delay(REAPER_HOLD_TIME, function()
			if ReaperPending[player] ~= pending then return end
			ReaperPending[player] = nil
			performReaperSummon(player, towerModel, buttonName, true)
		end)
		return
	end

	if action == "Release" then
		local pending = ReaperPending[player]
		if not pending or pending.Tower ~= towerModel
			or pending.ButtonName ~= buttonName then return end
		ReaperPending[player] = nil
		-- If the release arrives at 2s before task.delay fires, still MAX.
		-- This avoids a race between the timer and an exactly timed release.
		performReaperSummon(player, towerModel, buttonName,
			(os_clock() - pending.Started) >= REAPER_HOLD_TIME)
		return
	end

	if action == "Tap" and not ReaperPending[player] then
		performReaperSummon(player, towerModel, buttonName, false)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	ReaperPending[player] = nil
end)

-- ============================================================
-- BOUNTY / OUTLAW
-- ============================================================
local ActiveBounties = {}

local function getBestBountyTarget(position)
	local best, bestHP = nil, -math_huge
	for mob in pairs(MobSet) do
		local hrp = mob:FindFirstChild("Hitbox"); local hum = mob:FindFirstChild("EnemyStats")
		if hrp and hum and hum.Health.Value > 0 and (hrp.Position-position).Magnitude <= 5 then
			if hum.Health.Value > bestHP then bestHP=hum.Health.Value; best=mob end
		end
	end
	return best
end

events.OutlawBuff.OnServerEvent:Connect(function(player, towerModel, mousePosition)
	if not canUseTowerAbility(player, towerModel) then return end
	local config = towerModel and towerModel:FindFirstChild("Config")
	if not config then return end
	local MaxBounty      = config:FindFirstChild("MaxBounty")
	local BountyPerHP    = config:FindFirstChild("BountyPerHealth")
	local HealthPerBounty = config:FindFirstChild("HealthPerBounty")

	if ActiveBounties[towerModel] then
		if ActiveBounties[towerModel].billboard then ActiveBounties[towerModel].billboard:Destroy() end
		if ActiveBounties[towerModel].connection then ActiveBounties[towerModel].connection:Disconnect() end
		ActiveBounties[towerModel] = nil
	end

	local target = getBestBountyTarget(mousePosition)
	if not target then return end
	local enemyStats = target:FindFirstChild("EnemyStats")
	local head       = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
	if not (enemyStats and head) then return end

	local health      = enemyStats:FindFirstChild("Health")
	local Mhealth     = enemyStats:FindFirstChild("MaxHealth")
	local bountyValue = config:FindFirstChild("BountyTarget")
	if not (health and Mhealth and bountyValue) then return end
	bountyValue.Value = target

	local rawBounty = math_min(
		math.floor((Mhealth.Value / ((HealthPerBounty and HealthPerBounty.Value) or 1))
			* ((BountyPerHP and BountyPerHP.Value) or 1)),
		(MaxBounty and MaxBounty.Value) or 5000
	)
	local bounty = math_round(rawBounty * getEcoDebuffMultiplier())

	local existing = head:FindFirstChild("Bounty"); if existing then existing:Destroy() end
	local billboard = ReplicatedStorage.Particle.Bounty:Clone()
	billboard.Name = "Bounty"; billboard.Parent = head; billboard.Adornee = head
	billboard.Cash.Text = "$"..bounty.." BOUNTY"
	ActiveBounties[towerModel] = { target=target, billboard=billboard }

	local rewarded = false
	local function rewardPlayer()
		if rewarded then return end; rewarded = true
		local Cash = player:FindFirstChild("Cash")
		if Cash then
			local fxF = ReplicatedStorage.Events:FindFirstChild("TowerEffects")
			local fo  = fxF and fxF:FindFirstChild("FarmOrbs")
			if fo and target:FindFirstChild("Hitbox") then
				fo:FireAllClients("Coin",0.5,1,target.Hitbox.Position,player)
			end
			Cash.Value += bounty
		end
		if ActiveBounties[towerModel] then
			if ActiveBounties[towerModel].billboard then ActiveBounties[towerModel].billboard:Destroy() end
			if ActiveBounties[towerModel].connection then ActiveBounties[towerModel].connection:Disconnect() end
			ActiveBounties[towerModel] = nil
		end
	end

	local connection = health:GetPropertyChangedSignal("Value"):Connect(function()
		if health.Value <= 0 then rewardPlayer() end
	end)
	ActiveBounties[towerModel].connection = connection

	local headTower = towerModel:FindFirstChild("Head")
	if headTower and headTower:FindFirstChild("Enraged") and headTower.Enraged:FindFirstChild("Glint") then
		headTower.Enraged.Glint.Enabled = true
	end
	local originalDamage = config.Damage.Value
	config.Damage.Value  = math_round(config.Damage.Value + config.Buffs.DamageIncrease.Value)
	config.CanBuff.Value   = "No"
	config.ABILITYACTIVE.Value = true
	task_wait(config.BuffLegnth.Value / getGameSpeed())
	if headTower and headTower:FindFirstChild("Enraged") and headTower.Enraged:FindFirstChild("Glint") then
		headTower.Enraged.Glint.Enabled = false
	end
	config.Damage.Value = originalDamage
	local cd = (config.BuffCooldown.Value - config.BuffLegnth.Value) / getGameSpeed() * getAbilityCooldownMultiplier()
	if cd > 0 then task_wait(cd) end
	config.CanBuff.Value = "Yes"
end)

events.Missiles.SRBM.OnServerEvent:Connect(function(player, towerModel)
	if not canUseTowerAbility(player, towerModel) then return end
	local config = towerModel and towerModel:FindFirstChild("Config")
	local hrp    = towerModel and towerModel:FindFirstChild("HumanoidRootPart")
	if not config then return end

	config.Settings.Status.Building.Value  = true
	config.Settings.Status.Cooldown.Value  = false
	config.Settings.Status.Standby.Value   = false
	config.Settings.Status.Ready.Value     = false

	local head = towerModel:FindFirstChild("Head")
	local buildUI
	if head and head:FindFirstChild("Attachment") and head.Attachment:FindFirstChild("Build") then
		buildUI = head.Attachment.Build
		buildUI.Ready.Visible = false
		buildUI.OverheatTextArea.Visible = true
		buildUI.Bar.Visible = true
	end

	local Sound     = hrp and hrp:FindFirstChild("Build")
	local BuildTime = config.Settings.Missiles.SRBM.BuildTime.Value
	config.CanBuff.Value = "No"; config.ABILITYACTIVE.Value = true

	if Sound then
		task_spawn(function()
			local elapsed = 0
			while elapsed < BuildTime do
				Sound:Play(); local d = 2/GAME_SPEED; task_wait(d); elapsed += d
			end
		end)
	end

	local missileFolder = towerModel:FindFirstChild("MissileModels")
	local missile = missileFolder and missileFolder:FindFirstChild("SRBM")
	local buildParts = {}
	if missile then
		for i = 1, 5 do
			local pm = missile:FindFirstChild("BuildPart"..i)
			if pm then
				table.insert(buildParts, pm)
				for _, d in ipairs(pm:GetDescendants()) do if d:IsA("BasePart") then d.Transparency=1 end end
			end
		end
	end

	local fill      = buildUI and buildUI.Bar:FindFirstChild("Fill")
	local countText = buildUI and buildUI.Bar:FindFirstChild("Count")
	if fill then fill.Size = UDim2.new(0,0,1,0) end

	task_spawn(function()
		local startTime = os_clock(); local lastSecond = math_huge; local stageTriggered = {}
		while true do
			local elapsed  = (os_clock()-startTime)*GAME_SPEED
			local progress = math_clamp(elapsed/BuildTime, 0, 1)
			if fill then fill.Size = UDim2.new(progress,0,1,0) end
			local remaining = math_max(0, math.ceil(BuildTime-elapsed))
			if countText and remaining ~= lastSecond then countText.Text=remaining.."s"; lastSecond=remaining end
			local stage = math_clamp(math.floor(progress*5)+1, 1, 5)
			if buildParts[stage] and not stageTriggered[stage] then
				stageTriggered[stage] = true
				for _, d in ipairs(buildParts[stage]:GetDescendants()) do
					if d:IsA("BasePart") then d.Transparency=0 end
				end
			end
			if progress >= 1 then break end
			task_wait(0.05)
		end
	end)

	local cd = (BuildTime - config.BuffLegnth.Value) / getGameSpeed() * getAbilityCooldownMultiplier()
	if cd > 0 then task_wait(cd) end
	config.CanBuff.Value = "Yes"
	if buildUI then
		buildUI.Ready.Visible = true; buildUI.ReadyOne.Visible = true
		buildUI.OverheatTextArea.Visible = false; buildUI.OverheatTextArea2.Visible = false
		buildUI.Bar.Visible = false
	end
end)

local heliFolder = events:FindFirstChild("Helicopter")
if heliFolder then
	local function handleHeliMode(mode)
		return function(player, towerModel)
			if not canUseTowerAbility(player, towerModel) then return end
			local config = towerModel and towerModel:FindFirstChild("Config")
			if not config then return end
			config.CanBuff.Value = "No"; config.ABILITYACTIVE.Value = true
			config.FlyingMode.Value = mode
			task_wait(config.BuffLegnth.Value / getGameSpeed())
			local cd = (config.BuffCooldown.Value - config.BuffLegnth.Value) / getGameSpeed() * getAbilityCooldownMultiplier()
			if cd > 0 then task_wait(cd) end
			config.CanBuff.Value = "Yes"
		end
	end
	local Follow  = heliFolder:FindFirstChild("Follow")
	local Pursuit = heliFolder:FindFirstChild("Pursuit")
	if Follow  then Follow.OnServerEvent:Connect(handleHeliMode("Follow")) end
	if Pursuit then Pursuit.OnServerEvent:Connect(handleHeliMode("Pursuit")) end
end

-- ============================================================
-- MAIN HEARTBEAT SCHEDULER
-- Uses os_clock (not time()); Cowboy removed (DoAttackLogic handles it);
-- secondary guarded with secondaryBursting flag.
-- ============================================================
local scheduler = CombatScheduler.new({
	Tower = tower, Towers = Towers, IsCorrupted = isCorruptedTower,
	Projectiles = ProjectileService, Phaser = PhaserController,
})
RunService.Heartbeat:Connect(function(dt) scheduler:Step(dt) end)

return tower
