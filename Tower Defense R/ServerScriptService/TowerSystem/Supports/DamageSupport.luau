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
local DamageManager = context.DamageManager
local effectiveBuffMultiplier = context.effectiveBuffMultiplier
local isCorruptedTower = context.isCorruptedTower
local function run(commander)
	local commanderConfig    = commander:WaitForChild("Config")
	local damageMultiplier   = commanderConfig.DamageBuffs:WaitForChild("DamageBuff")
	local abilityActive      = commanderConfig:FindFirstChild("ABILITYACTIVE")
	local hrpCommander       = commander:WaitForChild("HumanoidRootPart")
	local BuffParticleTemplate = ParticleFolder:WaitForChild("DamageBuff")

	local M = DamageManager

	local function getTowerHRP(t)    return t and t:FindFirstChild("HumanoidRootPart") end
	local function getTowerConfig(t) return t and t:FindFirstChild("Config") end

	local function isInRangeOf(cData, towerModel)
		local thrp = getTowerHRP(towerModel); if not thrp then return false end
		local r = cData.rangeValue and cData.rangeValue.Value or 0
		local d = thrp.Position - cData.hrp.Position
		return d.X*d.X + d.Y*d.Y + d.Z*d.Z <= r*r
	end

	local myData = {
		commander = commander,
		hrp = hrpCommander,
		config = commanderConfig,
		rangeValue = commanderConfig:FindFirstChild("Range"),
		damageMultiplier = damageMultiplier,
		abilityActive = abilityActive,
		BuffParticleTemplate = BuffParticleTemplate,
	}
	M.commanders[commander] = myData

	local function removeBuff(target)
		local entry = M.buffed[target]
		if not entry then return end
		local config = getTowerConfig(target); local hrp = getTowerHRP(target)
		if config then
			local od = config:FindFirstChild("OriginalDamage")
			if od and config:FindFirstChild("Damage") then config.Damage.Value = od.Value; scope:Destroy(od) end
			local marker = config:FindFirstChild("DamageBuff")
			if marker then scope:Destroy(marker) end
		end
		if hrp then
			local p = hrp:FindFirstChild("DamageBuffParticle"); if p then scope:Destroy(p) end
		end
		if entry.connections then
			for _, c in ipairs(entry.connections) do if c.Connected then c:Disconnect() end end
		end
		M.buffed[target] = nil
	end

	local function applyValues(target, cData)
		local config = getTowerConfig(target)
		if not config then return end
		if config:FindFirstChild("BeamerSettings") then	return end
		local damage = config:FindFirstChild("Damage"); if not damage then return end
		local dmgMult = effectiveBuffMultiplier(cData.damageMultiplier.Value)
		damage.Value = math.round(config.OriginalDamage.Value * dmgMult)
	end

	local function applyBuff(target, cData)
		local config = getTowerConfig(target); local hrp = getTowerHRP(target)
		if not (config and hrp) then return end
		local damage = config:FindFirstChild("Damage"); if not damage then return end
		if not config:FindFirstChild("OriginalDamage") then
			local b=Instance.new("NumberValue"); b.Name="OriginalDamage"; b.Value=damage.Value; b.Parent=config
		end
		applyValues(target, cData)

		local marker = config:FindFirstChild("DamageBuff")
		if not marker then marker=Instance.new("ObjectValue"); marker.Name="DamageBuff"; marker.Parent=config end
		marker.Value = cData.commander

		if cData.abilityActive and cData.abilityActive.Value and not hrp:FindFirstChild("DamageBuffParticle") then
			local p=cData.BuffParticleTemplate:Clone(); p.Name="DamageBuffParticle"; p.Parent=hrp
		end

		local conns = {}
		table.insert(conns, scope:Connect(target.Destroying, function() removeBuff(target) end))
		M.buffed[target] = { commander = cData.commander, connections = conns }
	end

	-- picks the in-range commander with the HIGHEST damage multiplier
	local function bestCandidate(target)
		local config = getTowerConfig(target)
		if not config or isCorruptedTower(target) then return nil end
		if config:FindFirstChild("Flying") then return nil end
		local best, bestPercent = nil, -math.huge
		for cmd, cData in pairs(M.commanders) do
			if cmd ~= target and cmd.Parent == TowersWorkspace
				and not isCorruptedTower(cmd) and isInRangeOf(cData, target) then
				local p = cData.damageMultiplier.Value
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
			applyValues(target, best)
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

	recomputeAll()

	local myConns = {}
	table.insert(myConns, scope:Connect(damageMultiplier.Changed, function()
		for target, entry in pairs(M.buffed) do
			if entry.commander == commander then applyValues(target, myData) end
		end
		recomputeAll()
	end))
	if abilityActive then
		table.insert(myConns, scope:Connect(abilityActive.Changed, function()
			for target, entry in pairs(M.buffed) do
				if entry.commander == commander then
					local hrp = getTowerHRP(target)
					if hrp then
						local ex = hrp:FindFirstChild("DamageBuffParticle")
						if abilityActive.Value and not ex then
							local p = BuffParticleTemplate:Clone(); p.Name = "DamageBuffParticle"; p.Parent = hrp
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
		if not commander.Parent then return end
		recomputeAll()
	end)

	scope:OnCancel(function()
		if heartbeatConn and heartbeatConn.Connected then heartbeatConn:Disconnect() end
		for _, c in ipairs(myConns) do if c.Connected then c:Disconnect() end end
		M.commanders[commander] = nil
		for target, entry in pairs(M.buffed) do
			if entry.commander == commander then removeBuff(target) end
		end
		recomputeAll()
	end)
end

return run(commander, player)
end
return Module
