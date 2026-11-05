local Rep = game:GetService('ReplicatedStorage')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Mob = require(game.ServerScriptService.Main.Mob)
local Economy = require(script.Parent.Parent.MerchantEconomy)
local Targeting = require(script.Parent.Parent.Targeting.NearestTower)
local Merchant = {}
function Merchant.new(enemy)
	local rng = Random.new()
	local cleanup = function() end
	return {
		InitialCooldown = function() return rng:NextNumber(10, 14) end,
		Cooldown = function() return rng:NextNumber(8, 9) end,
		Finished = function() return enemy:GetAttribute('OrbUsed') == true and not enemy:GetAttribute('UsedAbility') end,
		Cancel = function() cleanup() end,
		Run = function(active)
			if not active() or enemy:GetAttribute('UsedAbility') or enemy:GetAttribute('OrbUsed') then return end
			local best, squared = nil, 10000
			local hitbox = enemy:FindFirstChild('Hitbox')
			if not hitbox then return end
			for _, tower in workspace.Towers:GetChildren() do
				if Targeting.Valid(tower, workspace.Towers) and tower.Config:FindFirstChild('Farm')
					and not tower.Config:FindFirstChild('Flying') and not tower.Config:FindFirstChild('EcoDebuff') then
					local d = tower.PrimaryPart.Position - hitbox.Position
					local distance = d.X * d.X + d.Z * d.Z
					if distance < squared then best, squared = tower, distance end
				end
			end
			if not best then return end
			local generation = Match.Capture()
			local stats = enemy.EnemyStats
			local speed, orig = stats:FindFirstChild('Speed'), stats:FindFirstChild('OrigSpeed')
			local saved = speed and speed.Value
			local cleaned = false
			cleanup = function()
				if cleaned then return end
				cleaned = true
				if enemy.Parent then
					enemy:SetAttribute('UsedAbility', false)
					if speed and speed.Parent and speed.Value == 0 then speed.Value = if orig and orig.Parent then orig.Value else saved end
				end
			end
			enemy:SetAttribute('UsedAbility', true); enemy:SetAttribute('OrbUsed', true)
			local ok, err = pcall(function()
				if speed then speed.Value = 0 end
				Mob.FacePart(enemy, best.PrimaryPart, 3.5 / math.max(workspace.Info.GameSpeed.Value, 0.0001))
				Rep.Events.AnimateEnemy:FireAllClients(enemy, 'Throw', best)
				if not Match.Wait(generation, 1, active) then return end
				if not Targeting.Valid(best, workspace.Towers) then return end
				local root = enemy:FindFirstChild('HumanoidRootPart')
				local sound = root and root:FindFirstChild('Attack')
				if sound and sound:IsA('Sound') then sound:Play() end
				Rep.Events.HardmodeEvents.Merchant.Orb:FireAllClients(enemy, best)
				if not Match.Wait(generation, 2, active) then return end
				if not Targeting.Valid(best, workspace.Towers) then return end
				Economy.Spawn(best.PrimaryPart.Position, generation)
				local cube = enemy:FindFirstChild('EcogodCube')
				if cube then
					for _, name in {'Main', 'MeshPart'} do
						local part = cube:FindFirstChild(name)
						if part then part.Transparency = 1 end
					end
				end
				Match.Wait(generation, 0.5, active)
			end)
			cleanup()
			if not ok then error(err, 0) end
		end,
	}
end
return Merchant
