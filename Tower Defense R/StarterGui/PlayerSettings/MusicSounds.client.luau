local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Events:WaitForChild("VolumeChangeMusic")

local frame = script.Parent
local buttonsFolder = frame:WaitForChild("Buttons")

local currentPercent = 100
local lastPressed = nil
local pressCount = 0
local MAX_VOLUME = 2 -- music max volume at 100%

-- Colors
local COLOR_ON = Color3.fromRGB(33, 255, 89)
local COLOR_OFF = Color3.fromRGB(30, 30, 30)

-- Update music volume (ONLY music already in workspace.Music)
local function updateMusicVolume(percent)
	currentPercent = percent

	for _, sound in ipairs(workspace.Music:GetChildren()) do
		if sound:IsA("Sound") then
			sound.Volume = MAX_VOLUME * (percent / 100)
		end
	end
end

-- Highlight the correct buttons
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

-- Number button pressed logic
local function setPercentFromButton(n)
	local percent = n * 10

	-- 10% double-press → mute (0%)
	if percent == 10 then
		if lastPressed == 1 then
			pressCount += 1

			if pressCount == 2 then
				percent = 0
			elseif pressCount == 3 then
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

	updateMusicVolume(percent)
	updateButtonColors(percent)
	remote:FireServer(percent)
end

-- Connect all 10 "Upgrade" buttons
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

-- Server sends saved volume
remote.OnClientEvent:Connect(function(savedPercent)
	currentPercent = savedPercent
	updateMusicVolume(savedPercent)
	updateButtonColors(savedPercent)
end)

-- Initial
updateMusicVolume(currentPercent)
updateButtonColors(currentPercent)
