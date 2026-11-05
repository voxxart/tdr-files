local Rep = game:GetService('ReplicatedStorage')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local info = workspace:WaitForChild('Info')
local epoch = 0
info.Wave.Changed:Connect(function()
	epoch += 1
	local thisEpoch = epoch
	local generation = Match.Capture()
	local function current() return epoch == thisEpoch end
	if not Match.IsCurrent(generation) then return end
	Rep.Events.SkipButton:FireAllClients(true, true)
	local seenMobs = false
	repeat
		if not Match.Wait(generation, 1, current) then return end
		local count = #workspace.Mobs:GetChildren()
		seenMobs = seenMobs or count > 0
		if info.Sec.Value <= 0 and info.Min.Value > 0 then
			info.Sec.Value = 59; info.Min.Value -= 1
		elseif info.Sec.Value > 0 then info.Sec.Value -= 1 end
		if info.Min.Value * 100 + info.Sec.Value == info.SkipTime.Value then
			Rep.Events.SkipButton:FireAllClients(true, false)
		end
		Rep.Events.SetTextTime:FireAllClients(info.Min.Value, info.Sec.Value)
	until (info.Min.Value == 0 and info.Sec.Value == 0) or (seenMobs and count == 0)
end)
