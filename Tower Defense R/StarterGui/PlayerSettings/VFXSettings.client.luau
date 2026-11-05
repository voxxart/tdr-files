local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local VFXFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("VFX")
local HighRemote = VFXFolder:WaitForChild("High")
local LowRemote = VFXFolder:WaitForChild("Low")

local frame = script.Parent
local highButton = frame.High:WaitForChild("Button")
local lowButton = frame.Low:WaitForChild("Button")
local highOutline = highButton:WaitForChild("UIStroke")
local lowOutline = lowButton:WaitForChild("UIStroke")

-- Default HIGH
local particlesEnabled = true

-- Create indi value to track player's VFX
local IndiPlayerVFX = player:FindFirstChild("VFX")

if not IndiPlayerVFX then
	IndiPlayerVFX = Instance.new("StringValue")
	IndiPlayerVFX.Name = "VFX"
	IndiPlayerVFX.Parent = player
end

IndiPlayerVFX.Value = "High"

-- Cache particles
local particlesCache = {}

local function CheckStatus()
	if IndiPlayerVFX then
		if IndiPlayerVFX.Value == "Low" then
			highOutline.EnabledVFX.Enabled = false
			highOutline.Disabled.Enabled = true
			lowOutline.EnabledVFX.Enabled = true
			lowOutline.Disabled.Enabled = false
		elseif IndiPlayerVFX.Value == "High" then
			highOutline.EnabledVFX.Enabled = true
			highOutline.Disabled.Enabled = false
			lowOutline.EnabledVFX.Enabled = false
			lowOutline.Disabled.Enabled = true
		end
	end
end

-- Update UI

-- Enable / disable functions
-- Initialize cache
for _, p in ipairs(workspace:GetDescendants()) do
	if p:IsA("ParticleEmitter") then
		table.insert(particlesCache, p)
	end
end

-- Buttons
highButton.MouseButton1Click:Connect(function()
	if not particlesEnabled then
		particlesEnabled = true
		IndiPlayerVFX.Value = "High"
		game.Lighting.GlobalShadows = true
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
		IndiPlayerVFX.Value = "Low"
		game.Lighting.GlobalShadows = false
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
		IndiPlayerVFX.Value = "High"
		game.Lighting.GlobalShadows = true
		highOutline.EnabledVFX.Enabled = true
		highOutline.Disabled.Enabled = false
		lowOutline.EnabledVFX.Enabled = false
		lowOutline.Disabled.Enabled = true
	end
end)

LowRemote.OnClientEvent:Connect(function(state)
	if state then
		particlesEnabled = false
		IndiPlayerVFX.Value = "Low"
		game.Lighting.GlobalShadows = false
		highOutline.EnabledVFX.Enabled = false
		highOutline.Disabled.Enabled = true
		lowOutline.EnabledVFX.Enabled = true
		lowOutline.Disabled.Enabled = false
	end
end)

-- Initialize
CheckStatus()
