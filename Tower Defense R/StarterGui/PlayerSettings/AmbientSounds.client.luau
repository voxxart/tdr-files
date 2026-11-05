local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Events:WaitForChild("VolumeChangeAmbience")

local frame = script.Parent
local buttonsFolder = frame:WaitForChild("Buttons")
local ambience = workspace:WaitForChild("Ambience")

local currentPercent = 100
local lastPressed = nil
local pressCount = 0
local MAX_VOLUME = 0.5

-- Colors
local COLOR_ON = Color3.fromRGB(33, 255, 89)
local COLOR_OFF = Color3.fromRGB(30, 30, 30)

-- Apply volume to a single sound
local function applyVolumeToSound(sound, percent)
	if sound:IsA("Sound") then
		sound.Volume = MAX_VOLUME * (percent / 100)
	end
end

-- Update all ambience sounds
local function updateAmbienceVolume(percent)
	currentPercent = percent

	for _, sound in ipairs(ambience:GetChildren()) do
		applyVolumeToSound(sound, percent)
	end
end

-- Highlight UI buttons
local function updateButtonColors(percent)
	local count = percent / 10

	for i = 1, 10 do
		local btnFrame = buttonsFolder:FindFirstChild(tostring(i))
		if btnFrame then
			btnFrame.BackgroundColor3 = (i <= count) and COLOR_ON or COLOR_OFF
		end
	end
end

-- Handle button press -> convert 1–10 to 10–100%
local function setPercentFromButton(n)
	local percent = n * 10

	-- Double-press 10 -> mute, triple-press -> restore to 10
	if percent == 10 then
		if lastPressed == 1 then
			pressCount += 1

			if pressCount == 2 then
				percent = 0 -- mute
			elseif pressCount == 3 then
				pressCount = 1
				percent = 10 -- restore to 10%
			end
		else
			pressCount = 1
		end
	else
		pressCount = 1
	end

	lastPressed = n

	updateAmbienceVolume(percent)
	updateButtonColors(percent)
	remote:FireServer(percent)
end

-- Connect each "Upgrade" button
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

-- Apply volume when new ambience sounds appear
ambience.ChildAdded:Connect(function(child)
	if not child:IsA("Sound") then return end

	-- Apply immediately
	applyVolumeToSound(child, currentPercent)

	-- Ensure volume stays correct if the sound starts playing later
	child:GetPropertyChangedSignal("IsPlaying"):Connect(function()
		if child.IsPlaying then
			applyVolumeToSound(child, currentPercent)
		end
	end)
end)

-- Server sends stored volume
remote.OnClientEvent:Connect(function(savedPercent)
	currentPercent = savedPercent
	updateAmbienceVolume(savedPercent)
	updateButtonColors(savedPercent)
end)

-- Initial load
updateAmbienceVolume(currentPercent)
updateButtonColors(currentPercent)
