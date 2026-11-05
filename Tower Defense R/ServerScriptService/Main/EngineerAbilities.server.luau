local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildServer = ReplicatedStorage.Events.NoobEngineerEvents.Build.BuildServer

-- Known animation length BEFORE speed adjustment
local BASE_BUILD_ANIM_LENGTH = 1.25

BuildServer.OnServerEvent:Connect(function(player, enemy)

	-- Freeze movement for the entire animation
	enemy.EnemyStats.Speed.Value = 0
	local Wrench = enemy:FindFirstChild("GoldWrench")

	local gameSpeed = workspace.Info.GameSpeed.Value
	local finalLength = (BASE_BUILD_ANIM_LENGTH) / gameSpeed

	-- Build sound
	local BuildSound = enemy:FindFirstChild("HumanoidRootPart") 
		and enemy.HumanoidRootPart:FindFirstChild("Build")

	if BuildSound then
		local count = 2
		local spacing = finalLength / count

		task.spawn(function()
			for i = 1, count do
				BuildSound:Play()
				Wrench.Top.Build:Emit(25)
				task.wait(spacing)
			end
		end)
	end

	-- Wait full animation length before spawning
	task.wait(finalLength)
	
	ReplicatedStorage.Events.SummonEnemy:Fire(enemy)

	-- Restore movement
	enemy.EnemyStats.Speed.Value = enemy.EnemyStats.OrigSpeed.Value
end)
