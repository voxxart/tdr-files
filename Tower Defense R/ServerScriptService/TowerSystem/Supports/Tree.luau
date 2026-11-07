local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Workspace = workspace
local Players = game:GetService('Players')
local Module = {}
function Module.Start(scope, context, newTower, player)
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
local TowerSet = context.TowerSet
local isCorruptedTower = context.isCorruptedTower
local registerTowerStunShield = context.registerTowerStunShield
local unregisterTowerStunShield = context.unregisterTowerStunShield
local consumeTowerStunShields = context.consumeTowerStunShields
local function run(newTower)
	local config = newTower:FindFirstChild("Config")
	if not config then return end
	local stats   = config:FindFirstChild("AOEHeal")
	if not stats then return end
	local rangeVal   = stats:FindFirstChild("HealRange")
	local healAmount = stats:FindFirstChild("HealAmount")
	local cooldown   = stats:FindFirstChild("HealCooldown")
	if not (rangeVal and healAmount and cooldown) then return end
	local root = newTower.PrimaryPart or newTower:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Declared up-front so the heal loop (defined below) can see them
	-- as upvalues once the StunShields block populates them.
	local shieldedTowers = {} -- [tower] = { shield = instance, conns = {...}, lastHP = number }
	local ShieldName = nil    -- set later if this tree grants shields

	task_spawn(function()
		while newTower.Parent do
			if isCorruptedTower(newTower) then
				task_wait(0.1)
				continue
			end
			local origin  = root.Position
			local rangeSq = rangeVal.Value * rangeVal.Value
			for t in pairs(TowerSet) do
				if t == newTower or isCorruptedTower(t) then continue end
				local c = t:FindFirstChild("Config")
				if not c then continue end
				local hf = c:FindFirstChild("Health")
				local hp = hf and hf:FindFirstChild("HealthValue")
				local mx = hf and hf:FindFirstChild("MaxHealth")
				if not (hp and mx) then continue end

				-- Shielded towers ignore AOE heal entirely
				if ShieldName and t:FindFirstChild(ShieldName) then continue end

				local v = hp.Value
				if v <= 0 or v >= mx.Value then continue end
				local p = t.PrimaryPart or t:FindFirstChild("HumanoidRootPart")
				if not p then continue end
				local d = p.Position - origin
				if d:Dot(d) <= rangeSq then
					hp.Value = math_min(v + healAmount.Value, mx.Value)
				end
			end
			task_wait(cooldown.Value)
		end
	end)

	local stunShieldConfig = config:FindFirstChild("StunShields")
	if stunShieldConfig then
		local Shields          = ReplicatedStorage.Particle.Shields
		local ShieldTemplate   = Shields.Default
		local ShieldRegenTime  = stunShieldConfig.ShieldRegenTime.Value
		local Countdown        = stunShieldConfig:FindFirstChild("Countdown")
		-- Optional per-tower override; falls back to the heal range if not set
		local shieldRangeVal   = stunShieldConfig:FindFirstChild("ShieldRange") or rangeVal

		ShieldName = ShieldTemplate.Name

		if Countdown then
			Countdown.Value = ShieldRegenTime
		end

		local BreakSound = ShieldTemplate:FindFirstChild("Break")

		local function playBreakSound(atPart)
			if not BreakSound then return end

			local soundClone = scope:Own(BreakSound:Clone())
			soundClone.Parent = atPart or workspace.GameDependencies.Debris
			soundClone:Play()
			game:GetService("Debris"):AddItem(soundClone, soundClone.TimeLength + 0.5)
		end

		local function removeShield(t)
			local data = shieldedTowers[t]
			if not data then return end

			-- Stop the global stun system from considering this shield active
			-- before any visual cleanup happens.
			if data.consumeCallback then
				unregisterTowerStunShield(t, data.consumeCallback)
			end

			shieldedTowers[t] = nil

			for _, conn in ipairs(data.conns) do
				conn:Disconnect()
			end

			if data.shield and data.shield.Parent then
				local p = t.PrimaryPart or t:FindFirstChild("HumanoidRootPart")
				playBreakSound(p or data.shield)
				scope:Destroy(data.shield)
			end
		end

		local function positionShield(shieldClone, targetPart)
			if shieldClone:IsA("BasePart") then
				shieldClone.CFrame = targetPart.CFrame - Vector3.new(0, 0.5, 0)
			elseif shieldClone:IsA("Model") then
				if shieldClone.PrimaryPart then
					shieldClone:SetPrimaryPartCFrame(targetPart.CFrame)
				else
					local anyPart = shieldClone:FindFirstChildWhichIsA("BasePart")
					if anyPart then
						anyPart.CFrame = targetPart.CFrame
					end
				end
			end
		end

		local function applyShield(t)
			if shieldedTowers[t] then return end -- already shielded, leave it alone

			local c = t:FindFirstChild("Config")
			if not c then return end
			local hf = c:FindFirstChild("Health")
			local hp = hf and hf:FindFirstChild("HealthValue")
			local mx = hf and hf:FindFirstChild("MaxHealth")
			if not (hp and mx) then return end
			local p = t.PrimaryPart or t:FindFirstChild("HumanoidRootPart")
			if not p then return end

			local shieldClone = scope:Own(ShieldTemplate:Clone())
			shieldClone.Parent = t
			positionShield(shieldClone, p)

			local data = {
				shield = shieldClone,
				conns  = {},
				lastHP = hp.Value,
				restoringHP = false,
				consumeCallback = nil,
			}
			shieldedTowers[t] = data

			-- The global stun system calls this BEFORE a stun is applied.
			data.consumeCallback = function(_reason)
				if shieldedTowers[t] ~= data then
					return
				end

				removeShield(t)
			end

			registerTowerStunShield(t, data.consumeCallback)

			-- ====================================================
			-- DAMAGE SHIELD — SERVER AUTHORITATIVE
			--
			-- Any HealthValue decrease while this shield is active is restored
			-- immediately to the pre-hit value, then the shield is consumed.
			--
			-- Keep the shield registered DURING the restore write so every
			-- server-side observer still sees this as protected damage.
			-- ====================================================
			table.insert(data.conns, scope:Connect(hp:GetPropertyChangedSignal("Value"), function()
				local d = shieldedTowers[t]
				if not d then
					return
				end

				if d.restoringHP then
					d.lastHP = hp.Value
					return
				end

				if hp.Value < d.lastHP then
					local restoreTo =
						math_min(
							d.lastHP,
							mx.Value
						)

					d.restoringHP = true
					hp.Value = restoreTo
					d.restoringHP = false
					d.lastHP = restoreTo

					-- Damage is fully absorbed; consuming the shield happens
					-- only AFTER HP has been restored.
					consumeTowerStunShields(t, "Damage")
				else
					d.lastHP = hp.Value
				end
			end))

			-- No Config.ChildAdded stun listener is needed here anymore.
			-- Stun blocking now happens inside the global stun system BEFORE
			-- StunnedUntil / FX / attack suppression can ever be applied.
		end

		local function regenPass()
			if isCorruptedTower(newTower) then return end
			local origin  = root.Position
			local rangeSq = shieldRangeVal.Value * shieldRangeVal.Value
			for t in pairs(TowerSet) do
				if t == newTower or isCorruptedTower(t) then continue end
				local c = t:FindFirstChild("Config")
				if not c then continue end
				local p = t.PrimaryPart or t:FindFirstChild("HumanoidRootPart")
				if not p then continue end
				local d = p.Position - origin
				if d:Dot(d) <= rangeSq then
					applyShield(t) -- no-ops if it already has a shield
				end
			end
		end

		task_spawn(function()
			local TICK = 0.1 -- countdown resolution in seconds
			local timeLeft = ShieldRegenTime -- internal float tracker, immune to IntValue rounding

			while newTower.Parent do
				task_wait(TICK)
				if not newTower.Parent then break end

				if isCorruptedTower(newTower) then
					-- Existing shields must also disappear, not just stop regenerating.
					for t in pairs(shieldedTowers) do removeShield(t) end
					timeLeft = ShieldRegenTime
					if Countdown then Countdown.Value = timeLeft end
					continue
				end

				-- A friendly Tree must not keep shielding towers that turn hostile.
				for t in pairs(shieldedTowers) do
					if isCorruptedTower(t) then removeShield(t) end
				end

				timeLeft = math_max(timeLeft - TICK, 0)
				if Countdown then
					Countdown.Value = timeLeft -- purely cosmetic; safe even if this rounds
				end

				if timeLeft <= 0 then
					regenPass()
					timeLeft = ShieldRegenTime
					if Countdown then
						Countdown.Value = timeLeft
					end
				end
			end
		end)

		local function cleanupAllShields()
			for t in pairs(shieldedTowers) do
				removeShield(t)
			end
		end

		scope:OnCancel(cleanupAllShields)
		scope:Connect(newTower.AncestryChanged, function(_, parent)
			if not parent then
				cleanupAllShields()
			end
		end)
	end
end

return run(newTower, player)
end
return Module
