local Players = game:GetService("Players")

local health = {}

function health.Setup(model, screengui)
	local newHealthBar = script.HealthGui:Clone()
	newHealthBar.Parent = model:WaitForChild("Head")

	if model.Name == "Base" then
		newHealthBar.MaxDistance = 1
		newHealthBar.Size = UDim2.new(0, 649, 0, 26)
	else 
		newHealthBar.MaxDistance = 30
		newHealthBar.Size = UDim2.new(0, 100, 0, 20)
	end

	health.UpdateHealth(newHealthBar, model)
	if screengui then
		health.UpdateHealth(screengui, model)
	end

	model.EnemyStats.Health.Changed:Connect(function()
		health.UpdateHealth(newHealthBar, model)

		if screengui then
			health.UpdateHealth(screengui, model)
		end
	end)
	health.UpdateHealth(newHealthBar, model)
	if screengui then
		health.UpdateHealth(screengui, model)
	end

	model.EnemyStats.Health.Changed:Connect(function()
		health.UpdateHealth(newHealthBar, model)

		if screengui then
			health.UpdateHealth(screengui, model)
		end
	end)
end

function health.UpdateHealth(gui, model)
	local humanoid = model:WaitForChild("EnemyStats")

	if humanoid and gui then
		local healthValue = humanoid.Health.Value
		local maxHealth = humanoid.MaxHealth.Value
		local percent = math.clamp(healthValue / maxHealth, 0, 1)
		if model.EnemyStats.Health.Value > model.EnemyStats.MaxHealth.Value then
			model.EnemyStats.OverHeal.Value = true
		else
			model.EnemyStats.OverHeal.Value = false
		end

		-- Smooth tween for normal HP
		gui.CurrentHealth:TweenSize(
			UDim2.new(percent, 0, 1, 0),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Linear,
			0.5,
			true
		)

		-- Handle OverHeal bar if it exists
		if humanoid:FindFirstChild("OverHeal") and humanoid:FindFirstChild("OverHealMaxHealth") then
			if humanoid.OverHeal.Value then
				local overPercent = math.clamp(
					humanoid.Health.Value / humanoid.OverHealMaxHealth.Value,
					0,
					1
				)

				-- Fill the overheal bar based on total HP beyond 100%
				gui.MedicHealth:TweenSize(
					UDim2.new(overPercent, 0, 1, 0),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Linear,
					0.5,
					true
				)
			else
				-- Reset overheal bar if not active
				gui.MedicHealth:TweenSize(
					UDim2.new(0, 0, 1, 0),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Linear,
					0.5,
					true
				)
			end
		end

		-- Update health text
		if healthValue <= 0 then
			if model.Name == "Base" then
				gui.Count.Text = "0"
			else
				gui.Count.Text = model.Name .. " 0"
				task.wait(0.5)
				gui:Destroy()
			end
		else
			gui.Count.Text = healthValue .. " HP"
		end
	end
end



return health
