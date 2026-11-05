local RunService = game:GetService('RunService')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local info = workspace:WaitForChild('Info')
local generation, elapsed = nil, 0
RunService.Heartbeat:Connect(function(dt)
	local current = Match.Capture()
	if current ~= generation then
		generation, elapsed = current, 0
		info.TotalGameTime.Seconds.Value = 0
		info.TotalGameTime.Minutes.Value = 0
	end
	if not Match.IsCurrent(current) or info.Wave.Value < 1 then return end
	-- Preserve actual elapsed match time, independent of simulation speed.
	elapsed += dt
	if elapsed < 1 then return end
	local seconds = math.floor(elapsed); elapsed -= seconds
	local total = info.TotalGameTime.Minutes.Value * 60 + info.TotalGameTime.Seconds.Value + seconds
	info.TotalGameTime.Minutes.Value = math.floor(total / 60)
	info.TotalGameTime.Seconds.Value = total % 60
end)
