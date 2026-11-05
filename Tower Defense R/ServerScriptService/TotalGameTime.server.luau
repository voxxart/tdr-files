local info = workspace.Info
local totalTimeStats = info.TotalGameTime
local message = info.Message
local wave = info.Wave

-- Wait for wave 1 to start
while wave.Value ~= 1 do
	wait(1)
end

-- Start timer
while true do
	wait(1)
	totalTimeStats.Seconds.Value += 1

	if totalTimeStats.Seconds.Value >= 60 then
		totalTimeStats.Seconds.Value = 0
		totalTimeStats.Minutes.Value += 1
	end

	if message.Value == "GAME OVER" or message.Value == "VICTORY" then
		break
	end
end
