-- StarterPlayerScripts/UnitMovement.client.lua
-- NoStop=true: keep walking and aim with a torso-only Motor6D.
-- NoStop=false: freeze movement while attacking, and face the target.
-- Walk-to-Attack animation crossfades live in TDR_AnimationClient_Updated.lua.
local RepStorage = game:GetService("ReplicatedStorage")
local BezierPath = require(RepStorage.Modules.BezierPath)
local RunService = game:GetService("RunService")
local Events = RepStorage:WaitForChild("Events")

local activeRotations = {}
local frozenAttacks = {} -- [unit] = {targetPart, lastFacing, returning?, elapsed?, from?}
local torsoRotations = {}
local BODY_RETURN_TIME = 0.5 -- game-seconds to turn from target to path after hold
local TORSO_HOLD_TIME = 1.5
local TORSO_RETURN_TIME = 0.4

Events.RotateUnit.OnClientEvent:Connect(function(newUnit, part, duration)
	if not newUnit or not newUnit.PrimaryPart then return end
	if part then
		activeRotations[newUnit] = {part = part, endTime = os.clock() + (duration or 0)}
	else
		activeRotations[newUnit] = nil
	end
end)

Events.UnitStopAttack.OnClientEvent:Connect(function(newUnit, part, _duration, targetPosition)
	if not newUnit then return end
	local state = frozenAttacks[newUnit]
	-- A deleted Hitbox may arrive as nil, but the snapshot survives. Nil
	-- with NO snapshot is the explicit release after the attack hold.
	local isAttack = (typeof(part) == "Instance" and part:IsA("BasePart"))
		or typeof(targetPosition) == "Vector3"
	if isAttack then
		if not state then
			state = {}
			frozenAttacks[newUnit] = state
		end
		state.targetPart = (typeof(part) == "Instance" and part:IsA("BasePart")) and part or nil
		state.targetPosition = typeof(targetPosition) == "Vector3" and targetPosition
			or (state.targetPart and state.targetPart.Position)
		state.returning = false
		state.elapsed = nil
		state.from = nil
	elseif state then
		-- The target can be gone; preserve its last orientation until the
		-- server releases AttackPaused, then blend toward the path heading.
		state.targetPart = nil
		state.returning = true
		state.elapsed = 0
		state.from = state.lastFacing
	end
end)

Events.RotateTorso.OnClientEvent:Connect(function(newUnit, target)
	if not newUnit then return end
	local data = torsoRotations[newUnit]
	if not target then
		if data and data.state == "tracking" then
			data.state = "holding"
			data.holdElapsed = 0
			data.target = nil
		end
		return
	end
	if not data then
		local pivot = newUnit:FindFirstChild("Pivot", true)
		local motor = pivot and pivot:FindFirstChild("Torso")
		if not (motor and motor:IsA("Motor6D")) then
			warn("[RotateTorso] missing Pivot.Torso Motor6D in", newUnit.Name)
			return
		end
		data = {motor = motor, originalC0 = motor.C0, state = "tracking"}
		torsoRotations[newUnit] = data
	end
	data.state = "tracking"
	data.target = target
end)

local function MoveUnit(newUnit, waypointPositions, height, offset)
	if not newUnit then return end
	local root = newUnit.PrimaryPart
	if not root then return end
	if not waypointPositions or #waypointPositions < 2 then
		root.CFrame += Vector3.new(0, height or 0, 0)
		return
	end
	offset = offset or Vector3.zero
	local path = BezierPath.new(waypointPositions, 1.2)
	local pathLength = math.max(path:GetPathLength(), 0.001)
	local alpha = newUnit:WaitForChild("Alpha", 5)
	if not alpha or not newUnit.Parent then return end
	local T = alpha.Value

	while T < 1 do
		if not newUnit.Parent or newUnit:GetAttribute("Dead") == true then break end
		local stats = newUnit:FindFirstChild("EnemyStats")
		local hp = stats and stats:FindFirstChild("Health")
		local speed = stats and stats:FindFirstChild("Speed")
		if not (hp and hp.Value > 0 and speed and newUnit.PrimaryPart) then break end
		local dt = RunService.RenderStepped:Wait()
		if not newUnit.Parent or newUnit:GetAttribute("Dead") == true or hp.Value <= 0 then break end
		local baseCF = path:CalculateUniformCFrame(T) + Vector3.new(0, height or 0, 0) + offset

		-- Full-body stop-to-attack orientation. Preserve the last facing when
		-- the enemy disappears mid-hold. On release, ease towards the path
		-- heading instead of snapping to it as walking resumes.
		local stopState = frozenAttacks[newUnit]
		local paused = newUnit:GetAttribute("AttackPaused") == true
		-- Durable fallback for a face event that reached us before the model
		-- or target instance was fully replicated. Do not use this outside
		-- the active attack pause (it intentionally remains after a kill).
		if paused and not stopState then
			local snapshot = newUnit:GetAttribute("AttackFacePosition")
			if typeof(snapshot) == "Vector3" then
				stopState = {targetPosition = snapshot}
				frozenAttacks[newUnit] = stopState
			end
		end
		-- The remote event can arrive before the paused attribute does.
		if stopState and not stopState.returning then
			paused = true
		end
		local faceCF = baseCF
		local facing = activeRotations[newUnit]

		if stopState then
			local targetPart = stopState.targetPart
			if not stopState.returning then
				local pos = targetPart and targetPart.Parent and targetPart.Position
					or stopState.targetPosition
				if typeof(pos) == "Vector3" then
					local flat = Vector3.new(pos.X, baseCF.Position.Y, pos.Z)
					if (flat - baseCF.Position).Magnitude > 0.01 then
						stopState.lastFacing = CFrame.lookAt(baseCF.Position, flat).Rotation
					end
				end
			end

			if stopState.returning then
				if paused then
					-- A release remote can beat AttackPaused=false to this
					-- client. Keep the attack facing until the attribute
					-- arrives instead of snapping forward for one frame.
					local rotation = stopState.lastFacing or baseCF.Rotation
					faceCF = CFrame.new(baseCF.Position) * rotation
				else
					stopState.elapsed = (stopState.elapsed or 0) + dt * math.max(workspace.Info.GameSpeed.Value, 0.05)
					local t = math.clamp(stopState.elapsed / BODY_RETURN_TIME, 0, 1)
					local smooth = t * t * (3 - 2 * t)
					local from = stopState.from or stopState.lastFacing or baseCF.Rotation
					faceCF = CFrame.new(baseCF.Position) * from:Lerp(baseCF.Rotation, smooth)
					if t >= 1 then
						frozenAttacks[newUnit] = nil
					end
				end
			else
				-- Keep this rotation even if the target got destroyed.
				local rotation = stopState.lastFacing or baseCF.Rotation
				faceCF = CFrame.new(baseCF.Position) * rotation
			end
		elseif facing and facing.part and facing.part.Parent and os.clock() < facing.endTime then
			local pos = facing.part.Position
			local flat = Vector3.new(pos.X, baseCF.Position.Y, pos.Z)
			if (flat - baseCF.Position).Magnitude > 0.01 then
				faceCF = CFrame.lookAt(baseCF.Position, flat)
			end
		else
			activeRotations[newUnit] = nil
		end

		-- If AttackPaused arrives before UnitStopAttack on a slow client,
		-- still freeze position. The full-body target turn follows as soon
		-- as the remote becomes available.
		newUnit.PrimaryPart.CFrame = faceCF

		local torso = torsoRotations[newUnit]
		if torso then
			if not (torso.motor and torso.motor.Parent) then
				torsoRotations[newUnit] = nil
			else
				local gs = workspace.Info.GameSpeed.Value
				if gs == 0 then gs = 1 end
				if torso.state == "tracking" and torso.target and torso.target.Parent then
					local base = newUnit.PrimaryPart.CFrame
					local hitbox = torso.target:FindFirstChild("Hitbox")
					local targetPos = hitbox and hitbox.Position or torso.target:GetPivot().Position
					local dir = targetPos - base.Position
					dir = Vector3.new(dir.X, 0, dir.Z)
					if dir.Magnitude > 0.05 then
						local world = CFrame.lookAt(base.Position, base.Position + dir)
						torso.motor.C0 = torso.originalC0 * base:ToObjectSpace(world).Rotation
					end
				elseif torso.state == "tracking" then
					torso.state = "holding"
					torso.holdElapsed = 0
					torso.target = nil
				elseif torso.state == "holding" then
					torso.holdElapsed = (torso.holdElapsed or 0) + dt * gs
					if torso.holdElapsed >= TORSO_HOLD_TIME then
						torso.state = "returning"
						torso.returnElapsed = 0
						torso.returnStartC0 = torso.motor.C0
					end
				elseif torso.state == "returning" then
					torso.returnElapsed += dt * gs
					local a = math.clamp(torso.returnElapsed / TORSO_RETURN_TIME, 0, 1)
					local ease = a * a * (3 - 2 * a)
					torso.motor.C0 = torso.returnStartC0:Lerp(torso.originalC0, ease)
					if a >= 1 then
						torso.motor.C0 = torso.originalC0
						torsoRotations[newUnit] = nil
					end
				end
			end
		end

		if not paused then
			T += (speed.Value * workspace.Info.GameSpeed.Value * dt) / pathLength
		end
	end
	frozenAttacks[newUnit] = nil
	activeRotations[newUnit] = nil
	local torso = torsoRotations[newUnit]
	if torso and torso.motor and torso.motor.Parent then
		torso.motor.C0 = torso.originalC0
	end
	torsoRotations[newUnit] = nil
end
Events.ReplicateUnit.OnClientEvent:Connect(MoveUnit)
