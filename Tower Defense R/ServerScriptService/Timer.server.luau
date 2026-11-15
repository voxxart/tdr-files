-- One match-clock-driven timer. No competing Wave.Changed countdown workers.
local RunService=game:GetService('RunService')
local Waves=require(game.ServerScriptService.Simulation.WaveService)
RunService.Heartbeat:Connect(function() Waves.Step() end)
