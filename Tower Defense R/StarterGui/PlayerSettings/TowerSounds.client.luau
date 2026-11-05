local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Events:WaitForChild("VolumeChange")
local frame = script.Parent
local buttonsFolder = frame:WaitForChild("Buttons")

local currentPercent = 100
local lastPressed = nil
local pressCount = 0
local MAX_VOLUME = 0.1

-- Colors
local COLOR_ON = Color3.fromRGB(33, 255, 89)
local COLOR_OFF = Color3.fromRGB(30, 30, 30)

-- Update tower volumes
local function updateLocalVolume(percent)
	currentPercent = percent

	for _, tower in ipairs(workspace.Towers:GetChildren()) do
		local hrp = tower and tower:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, sound in ipairs(hrp:GetChildren()) do
				if sound:IsA("Sound") then
					sound.Volume = MAX_VOLUME * (percent / 100)
				end
			end
		end
	end
end

-- UI highlight logic
local function updateButtonColors(percent)
	local count = percent / 10

	for i = 1, 10 do
		local btnFrame = buttonsFolder:FindFirstChild(tostring(i))
		if btnFrame then
			if i <= count then
				btnFrame.BackgroundColor3 = COLOR_ON
			else
				btnFrame.BackgroundColor3 = COLOR_OFF
			end
		end
	end
end

-- Change % based on button press
local function setPercentFromButton(n)
	-- Convert 1–10 → 10–100
	local percent = n * 10

	-- Double-tap logic on button 1 (10%)
	if percent == 10 then
		if lastPressed == 1 then
			pressCount += 1

			if pressCount == 2 then
				-- Double press → mute (0%)
				percent = 0
			elseif pressCount == 3 then
				-- Triple press → restore 10%
				pressCount = 1
				percent = 10
			end
		else
			pressCount = 1
		end
	else
		pressCount = 1
	end

	lastPressed = n

	updateLocalVolume(percent)
	updateButtonColors(percent)
	remote:FireServer(percent)
end

-- Connect all 10 buttons
for i = 1, 10 do
	local btnFrame = buttonsFolder:FindFirstChild(tostring(i))
	if btnFrame then
		local btn = btnFrame:FindFirstChild("Upgrade")
		if btn and btn:IsA("TextButton") then
			btn.MouseButton1Click:Connect(function()
				setPercentFromButton(i)
			end)
		end
	end
end

-- Server sends saved value
remote.OnClientEvent:Connect(function(savedPercent)
	currentPercent = savedPercent
	updateLocalVolume(savedPercent)
	updateButtonColors(savedPercent)
end)

-- New towers get correct volume
workspace.Towers.ChildAdded:Connect(function(tower)
	task.wait(0.1)
	local hrp = tower:FindFirstChild("HumanoidRootPart")
	if hrp then
		for _, sound in ipairs(hrp:GetChildren()) do
			if sound:IsA("Sound") and sound.Name == "Attack" then
				sound.Volume = MAX_VOLUME * (currentPercent / 100)
			end
		end
	end
end)

-- Initial update
updateLocalVolume(currentPercent)
updateButtonColors(currentPercent)
