local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local VFXFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Dialogue")
local HighRemote = VFXFolder:WaitForChild("On")
local LowRemote = VFXFolder:WaitForChild("Off")

local frame = script.Parent
local highButton = frame.Default:WaitForChild("Button")
local lowButton = frame.Off:WaitForChild("Button")
local highOutline = highButton:WaitForChild("UIStroke")
local lowOutline = lowButton:WaitForChild("UIStroke")

-- Default HIGH
local particlesEnabled = true

-- Create indi value to track player's VFX
local IndiPlayerDialogue = player:FindFirstChild("Dialogue")

if not IndiPlayerDialogue then
	IndiPlayerDialogue = Instance.new("StringValue")
	IndiPlayerDialogue.Name = "Dialogue"
	IndiPlayerDialogue.Parent = player
end

IndiPlayerDialogue.Value = "On"

local function CheckStatus()
	if IndiPlayerDialogue then
		if IndiPlayerDialogue.Value == "Off" then
			highOutline.EnabledVFX.Enabled = false
			highOutline.Disabled.Enabled = true
			lowOutline.EnabledVFX.Enabled = true
			lowOutline.Disabled.Enabled = false
		elseif IndiPlayerDialogue.Value == "On" then
			highOutline.EnabledVFX.Enabled = true
			highOutline.Disabled.Enabled = false
			lowOutline.EnabledVFX.Enabled = false
			lowOutline.Disabled.Enabled = true
		end
	end
end

-- Buttons
highButton.MouseButton1Click:Connect(function()
	if not particlesEnabled then
		particlesEnabled = true
		IndiPlayerDialogue.Value = "On"
		highOutline.EnabledVFX.Enabled = true
		highOutline.Disabled.Enabled = false
		lowOutline.EnabledVFX.Enabled = false
		lowOutline.Disabled.Enabled = true
		HighRemote:FireServer(true)
	end
end)

lowButton.MouseButton1Click:Connect(function()
	if particlesEnabled then
		particlesEnabled = false
		IndiPlayerDialogue.Value = "Off"
		highOutline.EnabledVFX.Enabled = false
		highOutline.Disabled.Enabled = true
		lowOutline.EnabledVFX.Enabled = true
		lowOutline.Disabled.Enabled = false
		LowRemote:FireServer(true)
	end
end)

-- Server → Client sync
HighRemote.OnClientEvent:Connect(function(state)
	if state then
		particlesEnabled = true
		IndiPlayerDialogue.Value = "On"
		highOutline.EnabledVFX.Enabled = true
		highOutline.Disabled.Enabled = false
		lowOutline.EnabledVFX.Enabled = false
		lowOutline.Disabled.Enabled = true
	end
end)

LowRemote.OnClientEvent:Connect(function(state)
	if state then
		particlesEnabled = false
		IndiPlayerDialogue.Value = "Off"
		highOutline.EnabledVFX.Enabled = false
		highOutline.Disabled.Enabled = true
		lowOutline.EnabledVFX.Enabled = true
		lowOutline.Disabled.Enabled = false
	end
end)

-- Initialize
CheckStatus()
