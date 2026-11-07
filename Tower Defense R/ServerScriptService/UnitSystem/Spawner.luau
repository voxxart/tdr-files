local RepStorage = game:GetService('ReplicatedStorage')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Paths = require(script.Parent.Paths)
local Service = require(script.Parent.Service)

local Spawner = {}
function Spawner.Spawn(name, quantity, cooldown, healthMultiplier, speedMultiplier, map, ownerTower, canContinue)
	local generation = Match.Capture()
	if not Match.IsCurrent(generation) then return end
	local unitExists = RepStorage.Units:FindFirstChild(name)
	if not unitExists then
		warn("No unit found with name:", name)
		return
	end

	local info = workspace:WaitForChild("Info")

	for i = 1, quantity do
		if not Match.Wait(generation,cooldown or 0,canContinue) then return end
		if canContinue and not canContinue() then return end

		if not Match.IsCurrent(generation) then
			return
		end

		local path, pathLength, positions = Service.WayPointsLoad(map)
		if not path then warn('No valid unit path:', map.Name); return end
		local newunit = unitExists:Clone()

		newunit.EnemyStats.MaxHealth.Value = math.round(newunit.EnemyStats.MaxHealth.Value * healthMultiplier)
		newunit.EnemyStats.Health.Value = math.round(newunit.EnemyStats.Health.Value * healthMultiplier)

		if newunit:FindFirstChild("IsFinalBoss") and info.EnemyMultiplier.Value > 1 then
			newunit.EnemyStats.MaxHealth.Value = math.round(newunit.EnemyStats.MaxHealth.Value * healthMultiplier) * 2
			newunit.EnemyStats.Health.Value = math.round(newunit.EnemyStats.Health.Value * healthMultiplier) * 2
		end

		newunit.EnemyStats.Speed.Value *= speedMultiplier
		newunit.EnemyStats.OrigSpeed.Value *= speedMultiplier

		if ownerTower then
			local ownerValue = Instance.new("ObjectValue")
			ownerValue.Name = "OwnerTower"
			ownerValue.Value = ownerTower
			ownerValue.Parent = newunit

			-- Keep a direct reference to the exact damage counter this unit should
			-- credit. ObjectValues do not create event connections, and this object
			-- is destroyed automatically with the unit, so there is no cleanup leak.
			local ownerConfig = ownerTower:FindFirstChild("Config")
			local totalDamage =
				ownerConfig
				and ownerConfig:FindFirstChild("TotalDamage")

			if totalDamage and totalDamage:IsA("ValueBase") then
				local damageValue = Instance.new("ObjectValue")
				damageValue.Name = "OwnerDamageValue"
				damageValue.Value = totalDamage
				damageValue.Parent = newunit
			end

			local linkedVal = Instance.new("BoolValue")
			linkedVal.Name = "LinkedToTower"
			linkedVal.Value = true
			linkedVal.Parent = newunit
		end

		local height = newunit.EnemyStats.HipHeight.Value + (newunit.PrimaryPart.Size.Y / 1.75)
		newunit.HumanoidRootPart.CFrame = Paths.Sample(path,0) + Vector3.new(0, height, 0)
		newunit.Parent = workspace.Units
		newunit.HumanoidRootPart.Anchored = true

		local alpha = newunit:FindFirstChild('Alpha')
		if not alpha then alpha=Instance.new('NumberValue'); alpha.Name='Alpha'; alpha.Parent=newunit end
		alpha.Value=0

		for _, object in ipairs(newunit:GetDescendants()) do
			if object:IsA("BasePart") then
				object.CollisionGroup = "Unit"
			end
		end

		info.EnemyInGame.Value += 1
		newunit:SetAttribute("Dead", false)
		newunit:SetAttribute("AttackPaused", false)
		local offset = Vector3.new(math.random(-35,35)/100,0,math.random(-35,35)/100)
		local data = Service.Move(newunit,map,path,pathLength,offset)
		if not data then
			info.EnemyInGame.Value = math.max(0,info.EnemyInGame.Value-1)
			newunit:Destroy()
		else
			newunit.Hitbox.Anchored = true
			newunit.Hitbox.CFrame=Paths.Sample(path,0)+Vector3.new(0,data.Height,0)+offset
			RepStorage.Events.ReplicateUnit:FireAllClients(newunit,positions,data.Height,offset,path.Id)
		end
	end
end
return Spawner
