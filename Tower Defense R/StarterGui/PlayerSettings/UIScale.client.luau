local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local UiScaleFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("UiScale")

local XLRemote = UiScaleFolder:WaitForChild("ExtraLarge")
local LRemote = UiScaleFolder:WaitForChild("Large")
local DefaultRemote = UiScaleFolder:WaitForChild("Default")
local SmallRemote = UiScaleFolder:WaitForChild("Small")

local frame = script.Parent

local Buttons = {
	ExtraLarge = frame.XLarge.Button,
	Large = frame.Large.Button,
	Default = frame.Default.Button,
	Small = frame.Small.Button,
}

local ScaleValues = {
	ExtraLarge = 1.15,
	Large = 1.05,
	Default = 1,
	Small = 0.9,
}

local Outlines = {
	ExtraLarge = Buttons.ExtraLarge:WaitForChild("UIStroke"),
	Large = Buttons.Large:WaitForChild("UIStroke"),
	Default = Buttons.Default:WaitForChild("UIStroke"),
	Small = Buttons.Small:WaitForChild("UIStroke"),
}

local function UpdateOutline(selected)
	for name, outline in pairs(Outlines) do
		local isSelected = (name == selected)

		outline.EnabledVFX.Enabled = isSelected
		outline.Disabled.Enabled = not isSelected
	end
end


local CurrentScale = "Default"


-- Apply scale to every ScreenGui
local function ApplyUIScale(name)
	local scale = ScaleValues[name]

	if not scale then
		return
	end

	CurrentScale = name
	UpdateOutline(name)

	for _, gui in ipairs(PlayerGui:GetChildren()) do
		if gui:IsA("ScreenGui") then
			for _, obj in ipairs(gui:GetDescendants()) do
				if obj:IsA("UIScale") then
					obj.Scale = scale
				end
			end
		end
	end
end


-- New GUIs
PlayerGui.ChildAdded:Connect(function(gui)
	if gui:IsA("ScreenGui") then
		task.wait()
		ApplyUIScale(CurrentScale)
	end
end)


-- Request change
local function SetScale(name)
	if not ScaleValues[name] then
		return
	end

	ApplyUIScale(name)

	if name == "ExtraLarge" then
		XLRemote:FireServer()

	elseif name == "Large" then
		LRemote:FireServer()

	elseif name == "Default" then
		DefaultRemote:FireServer()

	elseif name == "Small" then
		SmallRemote:FireServer()
	end
end


-- Buttons
Buttons.ExtraLarge.MouseButton1Click:Connect(function()
	SetScale("ExtraLarge")
end)

Buttons.Large.MouseButton1Click:Connect(function()
	SetScale("Large")
end)

Buttons.Default.MouseButton1Click:Connect(function()
	SetScale("Default")
end)

Buttons.Small.MouseButton1Click:Connect(function()
	SetScale("Small")
end)


-- Server -> Client sync (DO NOT fire server again)
XLRemote.OnClientEvent:Connect(function()
	ApplyUIScale("ExtraLarge")
end)

LRemote.OnClientEvent:Connect(function()
	ApplyUIScale("Large")
end)

DefaultRemote.OnClientEvent:Connect(function()
	ApplyUIScale("Default")
end)

SmallRemote.OnClientEvent:Connect(function()
	ApplyUIScale("Small")
end)


-- Initial
ApplyUIScale(CurrentScale)