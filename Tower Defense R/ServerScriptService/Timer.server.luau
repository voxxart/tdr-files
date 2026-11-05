local players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local wave = workspace.Info.Wave
local info = workspace.Info
local setTimeText = RS.Events:WaitForChild("SetTextTime")

local Min = workspace.Info.Min
local Sec = workspace.Info.Sec

wave.Changed:Connect(function()
	RS.Events.SkipButton:FireAllClients(true, true)

	local mobsSpawned = false

	repeat
		task.wait(1 / workspace.Info.GameSpeed.Value)

		if #workspace.Mobs:GetChildren() > 0 then
			mobsSpawned = true
		end

		if Sec.Value <= 0 and Min.Value > 0 then
			Sec.Value = 59
			Min.Value -= 1
		elseif Sec.Value > 0 then
			Sec.Value -= 1
		end

		if Min.Value * 100 + Sec.Value == workspace.Info.SkipTime.Value then
			RS.Events.SkipButton:FireAllClients(true, false)
		end

		setTimeText:FireAllClients(Min.Value, Sec.Value)

	until
	(Min.Value == 0 and Sec.Value == 0)
		or (mobsSpawned and #workspace.Mobs:GetChildren() == 0)
end)
