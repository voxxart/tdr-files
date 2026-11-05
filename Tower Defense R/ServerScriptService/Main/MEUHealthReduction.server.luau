local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event = ReplicatedStorage.Events.MEU.Server

Event.OnServerEvent:Connect(function(plr, enemy)
	if enemy.EnemyStats.Health.Value <= 25 then
		task.wait(2 / workspace.Info.GameSpeed.Value)
		enemy:Destroy()
	else
		enemy.EnemyStats.Health.Value -= 25
	end
	enemy.EnemyStats.Speed.Value -= math.round(enemy.EnemyStats.OrigSpeed.Value * 0.125)
end)
