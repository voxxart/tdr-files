local ReplicatedStorage = game:GetService("ReplicatedStorage")

local events = ReplicatedStorage:WaitForChild("Events")
local jugEvents = events:WaitForChild("DoombringerEvents")
local MinigunSpray = jugEvents:WaitForChild("Minigun"):WaitForChild("Minigun")
local RAILGUN = jugEvents:WaitForChild("Railgun"):WaitForChild("ShouldRailgun")
local RocketStorm = jugEvents:WaitForChild("Railgun"):WaitForChild("ShouldRailgun")

local ACTIVE = {} -- [enemy] = token
local SPIN_TIME = 1
local FIRE_TIME = 4 -- total firing time after spin

local function setEffectsEnabled(startFolder, enabled)
	local smoke = startFolder:FindFirstChild("Smoke")
	local spark = startFolder:FindFirstChild("Spark")
	local flash = startFolder:FindFirstChild("flash1")

	if smoke then smoke.Enabled = enabled end
	if spark then spark.Enabled = enabled end
	if flash then flash.Enabled = enabled end
end

MinigunSpray.OnClientEvent:Connect(function(enemy)
	if not enemy or not enemy.Parent then return end

	local weaponModel = enemy:FindFirstChild("ArmMinigun")
	if not weaponModel then return end

	local weapon = weaponModel:FindFirstChild("Spin")
	if not weapon then return end

	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local attackSound = hrp:FindFirstChild("MingunSpray")
	local spinSound = hrp:FindFirstChild("Spin")

	local startFolder = weapon:FindFirstChild("Start")
	if not startFolder then return end

	-- cancel/replace any currently running minigun sequence for this enemy
	local token = (ACTIVE[enemy] or 0) + 1
	ACTIVE[enemy] = token

	-- clean start
	setEffectsEnabled(startFolder, false)
	if spinSound and spinSound.IsPlaying then spinSound:Stop() end
	if attackSound and attackSound.IsPlaying then attackSound:Stop() end

	-- startup spin
	if spinSound then
		spinSound:Play()
	end

	task.delay(SPIN_TIME, function()
		if not enemy or not enemy.Parent then return end
		if ACTIVE[enemy] ~= token then return end

		setEffectsEnabled(startFolder, true)

		if attackSound then
			attackSound:Play()
		end
	end)

	task.delay(SPIN_TIME + FIRE_TIME, function()
		if ACTIVE[enemy] ~= token then return end

		setEffectsEnabled(startFolder, false)

		if spinSound and spinSound.IsPlaying then
			spinSound:Stop()
		end
		if attackSound and attackSound.IsPlaying then
			attackSound:Stop()
		end

		ACTIVE[enemy] = nil
	end)
end)

RAILGUN.OnClientEvent:Connect(function(enemy)
	if not enemy or not enemy.Parent then return end

	local weaponModel = enemy:FindFirstChild("Gun")
	if not weaponModel then return end

	local weapon = weaponModel:FindFirstChild("Handle")
	if not weapon then return end

	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local startFolder = weapon:FindFirstChild("Start")
	if not startFolder then return end

	-- cancel/replace any currently running minigun sequence for this enemy
	local token = (ACTIVE[enemy] or 0) + 1
	ACTIVE[enemy] = token

	task.wait(0.75)
	setEffectsEnabled(startFolder, true)
	task.delay(0.22, function()
		setEffectsEnabled(startFolder, false)
	end)
end)