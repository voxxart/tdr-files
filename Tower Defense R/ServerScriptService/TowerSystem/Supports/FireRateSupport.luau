local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Workspace = workspace
local Players = game:GetService('Players')
local Module = {}
function Module.Start(scope, context, commander, player)
local tower = context.Tower
local getGameSpeed = context.GetGameSpeed
local task = scope.Task
local task_spawn, task_wait, task_delay, task_defer = task.spawn, task.wait, task.delay, task.defer
local os_clock = os.clock
local math_max = math.max
local math_min = math.min
local math_round = math.round
local math_sqrt = math.sqrt
local math_random = math.random
local math_floor = math.floor
local math_clamp = math.clamp
local math_abs = math.abs
local math_rad = math.rad
local math_sin = math.sin
local math_cos = math.cos
local math_atan2 = math.atan2
local TowersWorkspace = context.TowersWorkspace
local ParticleFolder = context.ParticleFolder
local FireRateManager = context.FireRateManager
local effectiveBuffMultiplier = context.effectiveBuffMultiplier
local isCorruptedTower = context.isCorruptedTower
local function run(commander)
	local commanderConfig = commander:WaitForChild("Config")
	local fireRateMultiplier        = commanderConfig.Buffs:WaitForChild("FirerateBuff")
	local fireRateMultiplierPercent = commanderConfig.Buffs:WaitForChild("FirerateBuffPercentage")
	local RangeMultiplier           = commanderConfig.Buffs:WaitForChild("RangeBuff")
	local RangeMultiplierPercent    = commanderConfig.Buffs:WaitForChild("RangeBuffPercentage")
	local abilityActive = commanderConfig:FindFirstChild("ABILITYACTIVE")
	local hrpCommander  = commander:WaitForChild("HumanoidRootPart")
	local VisualIndicator      = ParticleFolder:WaitForChild("Buffs")
	local BuffParticleTemplate = ParticleFolder:WaitForChild("FirerateBuff")

	local M = FireRateManager

	local function getTowerHRP(t)    return t and t:FindFirstChild("HumanoidRootPart") end
	local function getTowerConfig(t) return t and t:FindFirstChild("Config") end

	local function isInRangeOf(cData, towerModel)
		local thrp = getTowerHRP(towerModel); if not thrp then return false end
		local r = cData.rangeValue and cData.rangeValue.Value or 0
		local d = thrp.Position - cData.hrp.Position
		return d.X*d.X + d.Y*d.Y + d.Z*d.Z <= r*r
	end

	-- register this commander in the shared manager
	local myData = {
		commander = commander,
		hrp = hrpCommander,
		config = commanderConfig,
		rangeValue = commanderConfig:FindFirstChild("Range"),
		fireRateMultiplier = fireRateMultiplier,
		fireRateMultiplierPercent = fireRateMultiplierPercent,
		RangeMultiplier = RangeMultiplier,
		RangeMultiplierPercent = RangeMultiplierPercent,
		abilityActive = abilityActive,
		VisualIndicator = VisualIndicator,
		BuffParticleTemplate = BuffParticleTemplate,
	}
	M.commanders[commander] = myData

	local function removeBuff(target)
		local entry = M.buffed[target]
		if not entry then return end
		local config = getTowerConfig(target); local hrp = getTowerHRP(target)
		if config then
			if config:FindFirstChild("OriginalCooldown") then
				config.Cooldown.Value = config.OriginalCooldown.Value; scope:Destroy(config.OriginalCooldown)
			end
			if config:FindFirstChild("OriginalRange") then
				config.Range.Value = config.OriginalRange.Value; scope:Destroy(config.OriginalRange)
			end
			for _, fname in ipairs({"OriginalMinRange","OriginalMidRange","OriginalLongRange"}) do
				local backup = config:FindFirstChild(fname)
				if backup and config:FindFirstChild("BehemothStats") then
					local field = fname:gsub("Original",""):gsub("Range","")
					local node  = config.BehemothStats.DamageMultiplierLogic:FindFirstChild(field.."Range")
					if node then node.Range.Value = backup.Value end
					scope:Destroy(backup)
				end
			end
			local marker = config:FindFirstChild("FirerateBuff")
			if marker then scope:Destroy(marker) end
		end
		if hrp then
			local ep = hrp:FindFirstChild("FirerateBuffParticle"); if ep then scope:Destroy(ep) end
			local bg = hrp:FindFirstChild("Buffs"); if bg then scope:Destroy(bg) end
		end
		if entry.connections then
			for _, c in ipairs(entry.connections) do if c.Connected then c:Disconnect() end end
		end
		M.buffed[target] = nil
	end

	local function applyValues(target, cData)
		local config = getTowerConfig(target)
		if not config then return end
		local frMult = effectiveBuffMultiplier(cData.fireRateMultiplier.Value)
		local rgMult = effectiveBuffMultiplier(cData.RangeMultiplier.Value)

		config.Cooldown.Value = math_round((config.OriginalCooldown.Value / frMult)*1000)/1000
		config.Range.Value    = math_round((config.OriginalRange.Value * rgMult)*1000)/1000
		if config:FindFirstChild("BehemothStats") then
			local dml = config.BehemothStats.DamageMultiplierLogic
			dml.MinRange.Range.Value  = math_round((config.OriginalMinRange.Value * rgMult)*1000)/1000
			dml.MidRange.Range.Value  = math_round((config.OriginalMidRange.Value * rgMult)*1000)/1000
			dml.LongRange.Range.Value = math_round((config.OriginalLongRange.Value * rgMult)*1000)/1000
		end

		local hrp = getTowerHRP(target)
		if hrp then
			local frPercent = math_round((frMult-1)*1000)/10
			local rgPercent = math_round((rgMult-1)*1000)/10
			local vb = hrp:FindFirstChild("Buffs")
			if vb then
				vb.Firerate.FirerateBuff.Text = frPercent.."%"
				vb.Range.RangeBuff.Text       = rgPercent.."%"
			elseif not vb then
				local vb = cData.VisualIndicator:Clone(); vb.Parent = hrp
				vb.Firerate.FirerateBuff.Text = frPercent.."%"
				vb.Range.RangeBuff.Text       = rgPercent.."%"
			end
		end
	end

	local function applyBuff(target, cData)
		local config = getTowerConfig(target); local hrp = getTowerHRP(target)
		if not (config and hrp) then return end

		local function ensureBackup(name, getValue)
			if not config:FindFirstChild(name) then
				local b=Instance.new("NumberValue"); b.Name=name; b.Value=getValue(); b.Parent=config
			end
		end
		ensureBackup("OriginalCooldown", function() return config.Cooldown.Value end)
		ensureBackup("OriginalRange",    function() return config.Range.Value end)
		if config:FindFirstChild("BehemothStats") then
			local dml = config.BehemothStats.DamageMultiplierLogic
			ensureBackup("OriginalMinRange",  function() return dml.MinRange.Range.Value end)
			ensureBackup("OriginalMidRange",  function() return dml.MidRange.Range.Value end)
			ensureBackup("OriginalLongRange", function() return dml.LongRange.Range.Value end)
		end

		local marker = config:FindFirstChild("FirerateBuff")
		if not marker then marker=Instance.new("ObjectValue"); marker.Name="FirerateBuff"; marker.Parent=config end
		marker.Value = cData.commander

		local vb = hrp:FindFirstChild("Buffs")
		if vb then vb = cData.VisualIndicator:Clone(); vb.Parent = hrp end

		applyValues(target, cData)

		if cData.abilityActive and cData.abilityActive.Value then
			if not hrp:FindFirstChild("FirerateBuffParticle") then
				local p=cData.BuffParticleTemplate:Clone(); p.Name="FirerateBuffParticle"; p.Parent=hrp
			end
		else
			local ex = hrp:FindFirstChild("FirerateBuffParticle"); if ex then scope:Destroy(ex) end
		end

		local conns = {}
		table.insert(conns, scope:Connect(target.Destroying, function() removeBuff(target) end))
		M.buffed[target] = { commander = cData.commander, connections = conns }
	end

	-- picks the in-range commander with the HIGHEST fire rate buff percentage
	local function bestCandidate(target)
		local config = getTowerConfig(target)
		if not config or isCorruptedTower(target) then return nil end
		if config:FindFirstChild("Flying") then return nil end
		local best, bestPercent = nil, -math.huge
		for cmd, cData in pairs(M.commanders) do
			if cmd ~= target and cmd.Parent == TowersWorkspace
				and not isCorruptedTower(cmd) and isInRangeOf(cData, target) then
				local p = cData.fireRateMultiplierPercent.Value
				if p > bestPercent then best, bestPercent = cData, p end
			end
		end
		return best
	end

	local function recompute(target)
		if target == nil then return end
		local best = bestCandidate(target)
		local entry = M.buffed[target]
		if not best then
			if entry then removeBuff(target) end
			return
		end
		if entry and entry.commander == best.commander then
			applyValues(target, best) -- keep it fresh in case percentages or nerf factor changed
			return
		end
		if entry then removeBuff(target) end
		applyBuff(target, best)
	end

	local function recomputeAll()
		for _, t in ipairs(TowersWorkspace:GetChildren()) do
			recompute(t)
		end
	end
	M.recomputeAll = recomputeAll

	-- initial pass
	recomputeAll()

	-- reactive updates: this commander's stats changing may change who wins nearby towers
	local myConns = {}
	table.insert(myConns, scope:Connect(fireRateMultiplierPercent.Changed, recomputeAll))
	table.insert(myConns, scope:Connect(RangeMultiplierPercent.Changed, recomputeAll))
	table.insert(myConns, scope:Connect(fireRateMultiplier.Changed, function()
		for target, entry in pairs(M.buffed) do
			if entry.commander == commander then applyValues(target, myData) end
		end
	end))
	table.insert(myConns, scope:Connect(RangeMultiplier.Changed, function()
		for target, entry in pairs(M.buffed) do
			if entry.commander == commander then applyValues(target, myData) end
		end
	end))
	if abilityActive then
		table.insert(myConns, scope:Connect(abilityActive.Changed, function()
			for target, entry in pairs(M.buffed) do
				if entry.commander == commander then
					local hrp = getTowerHRP(target)
					if hrp then
						local ex = hrp:FindFirstChild("FirerateBuffParticle")
						if abilityActive.Value and not ex then
							local p = BuffParticleTemplate:Clone(); p.Name = "FirerateBuffParticle"; p.Parent = hrp
						elseif not abilityActive.Value and ex then
							scope:Destroy(ex)
						end
					end
				end
			end
		end))
	end

	if not M.towerListenerStarted then
		M.towerListenerStarted = true
		scope:Connect(TowersWorkspace.ChildAdded, function(newT)
			local aliveConn
			aliveConn = scope:Connect(newT.AncestryChanged, function(_, parent)
				if not parent then if aliveConn then aliveConn:Disconnect() end end
			end)
			repeat
				task_wait()
				if not newT.Parent then
					if aliveConn then aliveConn:Disconnect() end
					return
				end
			until newT:FindFirstChild("Config") and newT:FindFirstChild("HumanoidRootPart")
			if aliveConn then aliveConn:Disconnect() end
			recompute(newT)
		end)
	end

	local accum = 0
	local heartbeatConn
	heartbeatConn = scope:OnHeartbeat(function(dt)
		accum += dt; if accum < 0.25 then return end; accum = 0
		if not (commander.Parent and hrpCommander.Parent) then return end
		recomputeAll()
	end)

	scope:OnCancel(function()
		if heartbeatConn and heartbeatConn.Connected then heartbeatConn:Disconnect() end
		for _, c in ipairs(myConns) do if c.Connected then c:Disconnect() end end
		M.commanders[commander] = nil
		for target, entry in pairs(M.buffed) do
			if entry.commander == commander then removeBuff(target) end
		end
		recomputeAll() -- hand off any towers this commander was buffing to the next-highest bidder
	end)
end

return run(commander, player)
end
return Module
