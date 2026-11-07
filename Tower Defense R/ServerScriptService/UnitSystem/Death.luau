local Rep = game:GetService('ReplicatedStorage')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Definitions = require(Rep.GameModules.UnitDefinitions)
local Runtime = require(script.Parent.Runtime)
local Behaviors = require(script.Parent.Behaviors)
local Damage = require(script.Parent.Damage)
local UnitStopAttackEvent, RotateTorsoEvent = Rep.Events.UnitStopAttack, Rep.Events.RotateTorso
local UnitDeathEvent = Rep.Events:FindFirstChild('UnitDeath')
if not UnitDeathEvent then UnitDeathEvent=Instance.new('RemoteEvent'); UnitDeathEvent.Name='UnitDeath'; UnitDeathEvent.Parent=Rep.Events end
local Presentation = Rep.Events:FindFirstChild('UnitPresentation')
if not Presentation then Presentation=Instance.new('RemoteEvent'); Presentation.Name='UnitPresentation'; Presentation.Parent=Rep.Events end
local unit = {Explode=function(position,radius) Presentation:FireAllClients('Explosion',position,radius) end}
local Spatial = require(game.ServerScriptService.TowerSystem.Targeting)
local AddTowerDamage, DamageEnemy, GiveDamageCash = Damage.Credit, Damage.Apply, Damage.Reward
local math_round = math.round
local Death = {}
local presentations = {}
local FinishedUnits = setmetatable({}, { __mode = "k" })
local RamInProgress = setmetatable({}, { __mode = "k" })

local function deathSplash(newunit, position)
	local maxHealth = newunit.EnemyStats:FindFirstChild("MaxHealth")
	if not maxHealth then return end
	local profile = (Definitions.Units[newunit.Name] or {}).Death or {}
	local damage = math_round(maxHealth.Value * (profile.SplashFraction or 0.15))
	local splashRadius = profile.SplashRadius or 3.5
	local radiusSq = splashRadius * splashRadius
	Spatial.Visit(position,splashRadius,function(enemy)
		local hit = enemy:FindFirstChild("Hitbox")
		local enemyStats = enemy:FindFirstChild("EnemyStats")
		local hp = enemyStats and enemyStats:FindFirstChild("Health")
		if hit and hp and hp.Value > 0 and not enemyStats:FindFirstChild("Invincible") then
			local flying = enemyStats:FindFirstChild("Flying")
			if not (flying and flying.Value) then
				local dx = hit.Position.X - position.X
				local dz = hit.Position.Z - position.Z
				if dx*dx + dz*dz <= radiusSq then
					local actual = DamageEnemy(enemyStats, damage, true)
					AddTowerDamage(newunit, actual)
					GiveDamageCash(actual)
				end
			end
		end
	end)
end

function Death.Finish(newunit, died, ram)
	if not newunit or FinishedUnits[newunit] then return end
	local runtime = Runtime.Get(newunit)
	local definition = Definitions.Units[newunit.Name] or {}
	local profile = definition.Death or {}
	if ram then RamInProgress[newunit] = true end
	FinishedUnits[newunit] = true
	if died then
		local callback = Behaviors.Death[profile.Behavior or 'Default']
		if callback then
			local ok,err = pcall(callback,{Model=newunit,Position=newunit:FindFirstChild('Hitbox') and newunit.Hitbox.Position})
			if not ok then warn('Unit death hook failed:',newunit.Name,err) end
		end
	end

	-- Mark gameplay death before presentation. Service removes the runtime
	-- record after Finish returns, preventing further attacks or movement.
	if newunit.Parent then
		newunit:SetAttribute("Dead", true)
		newunit:SetAttribute("AttackPaused", false)
		UnitStopAttackEvent:FireAllClients(newunit, nil, 0)
		RotateTorsoEvent:FireAllClients(newunit, nil, 0)
	end


	local stats = newunit:FindFirstChild("EnemyStats")
	local hitbox = newunit:FindFirstChild("Hitbox")
	local root = newunit.PrimaryPart or newunit:FindFirstChild("HumanoidRootPart")
	-- Server position is stored on Hitbox. The visible model normally moves
	-- client-side, so its server-side root can still be near the spawn point.
	local deathCF = (hitbox and hitbox.CFrame) or (root and root.CFrame)
	local deathPos = deathCF and deathCF.Position

	local effects = died and profile.Animate ~= false and newunit:FindFirstChild("DeathEffects")
	local holdSeconds = 0

	if died then
		local explodeFlag = stats and stats:FindFirstChild("Explode")
		local shouldExplode = if profile.Explode ~= nil then profile.Explode else (explodeFlag and explodeFlag:IsA("BoolValue") and explodeFlag.Value)
		if shouldExplode and deathPos then
			-- The intended EXPLOSION is the only possible damage at death;
			-- it happens once and only for units with Explode=true.
			if RamInProgress[newunit] or profile.SplashOnRamOnly == false then
				deathSplash(newunit, deathPos)
			end
			local radiusObject = stats:FindFirstChild("ExplosionRadius")
			local radius = tonumber(profile.ExplosionRadius) or (radiusObject and tonumber(radiusObject.Value)) or 3.5
			if radius > 0 then unit.Explode(deathPos, radius) end
		end

		if effects and effects:IsA("Folder") and deathCF then
			-- Default: 4 GAME seconds. Set DeathEffects.Duration on the unit
			-- to match long/short death animations (e.g. Duration=5).
			local configuredDuration = tonumber(profile.Duration) or tonumber(effects:GetAttribute("Duration")) or 4
			holdSeconds = math.clamp(configuredDuration, 0.1, 60)

			-- Put the actual server rig where the client was rendering it.
			-- Without this, its anchored HumanoidRootPart can snap back to
			-- spawn as soon as client-side path animation stops.
			if newunit.PrimaryPart then
				newunit:PivotTo(deathCF)
			end

			-- No physical collision, touch-triggered damage or targetable
			-- hitboxes on a dead unit. The Motor6Ds remain intact for Death.
			for _, obj in ipairs(newunit:GetDescendants()) do
				if obj:IsA("BasePart") then
					obj.CanCollide = false
					obj.CanTouch = false
					obj.CanQuery = false
				elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
					obj.Enabled = false
				end
			end

			-- IMPORTANT: DO NOT reparent the animated rig at the same moment
			-- that Death plays. Moving workspace.Units -> workspace.Visual
			-- can interrupt client animation state/replication, leaving the
			-- original model stuck in its resting pose. It remains in Units,
			-- but Dead=true, Health=0, collisions disabled, and ALL server
			-- combat / movement loops have stopped. Unit counters update now.
			newunit:SetAttribute("UnitDeathAnimation", profile.Animation or "Death")
			newunit:SetAttribute("UnitDeathPresentation", true)

			-- Also trigger the client via event; the client independently
			-- watches UnitDeathPresentation so it survives event ordering.
			UnitDeathEvent:FireAllClients(newunit, deathCF)
		end
	end

	RamInProgress[newunit] = nil
	local count = workspace.Info:FindFirstChild("EnemyInGame")
	if count then count.Value = math.max(0, count.Value - 1) end

	-- Remaining in workspace is VISUAL ONLY: Dead=true and Health<=0 stop
	-- server attack, ram and movement before this delay starts.
	if holdSeconds > 0 then
		presentations[newunit] = {Generation = runtime and runtime.Generation or Match.Capture(), Deadline = Match.Now()+holdSeconds}
	elseif newunit.Parent then
		newunit:Destroy()
	end
end

function Death.Update()
	for model, record in pairs(presentations) do
		if not model.Parent or not Match.IsCurrent(record.Generation) or Match.Now() >= record.Deadline then
			presentations[model] = nil
			if model.Parent then model:Destroy() end
		end
	end
end
function Death.Explode(position,radius) unit.Explode(position,radius) end
return Death
