local RunService = game:GetService('RunService')
local MatchClock = require(script.Parent.MatchClock)
local Info = workspace:WaitForChild('Info')
local Running = Info:WaitForChild('GameRunning')
local Speed = Info:WaitForChild('GameSpeed')
local Message = Info:WaitForChild('Message')
local clock = MatchClock.new()
local MatchService = {}
local observedRunning = false

function MatchService.Begin()
	observedRunning = true
	local generation = clock:Begin()
	Running.Value = true
	return generation
end

function MatchService.Capture()
	return clock.Generation
end

function MatchService.IsCurrent(generation)
	return clock:IsCurrent(generation) and Running.Value
		and Message.Value ~= 'GAME OVER' and Message.Value ~= 'VICTORY'
end

function MatchService.Now()
	return clock.Time
end

function MatchService.Wait(generation, seconds)
	local deadline = clock.Time + math.max(seconds or 0, 0)
	while MatchService.IsCurrent(generation) and clock.Time < deadline do
		RunService.Heartbeat:Wait()
	end
	return clock:IsCurrent(generation) and Running.Value
		and Message.Value ~= 'GAME OVER' and Message.Value ~= 'VICTORY'
end

function MatchService.After(generation, seconds, callback)
	-- Callbacks must not yield. Use Wait in existing yielding workflows instead.
	if not MatchService.IsCurrent(generation) then return nil end
	return clock:After(generation, seconds, function()
		if MatchService.IsCurrent(generation) then callback() end
	end)
end

local function runningChanged()
	if Running.Value and not observedRunning then
		clock:Begin()
	elseif not Running.Value then
		clock:Stop()
	end
	observedRunning = Running.Value
end
local function messageChanged()
	if Message.Value == 'GAME OVER' or Message.Value == 'VICTORY' then
		clock:Stop()
	end
end
Running.Changed:Connect(runningChanged)
Message.Changed:Connect(messageChanged)
runningChanged()
messageChanged()
RunService.Heartbeat:Connect(function(dt)
	-- Inspect values directly as well as signals (Studio can defer signals).
	if not Running.Value or Message.Value == 'GAME OVER' or Message.Value == 'VICTORY' then
		clock:Stop()
		return
	end
	local speed = Speed.Value
	if speed ~= speed or speed < 0 or speed == math.huge then speed = 0 end
	clock:Advance(dt, speed)
end)

return MatchService
