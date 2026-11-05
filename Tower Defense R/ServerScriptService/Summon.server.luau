local SummonEnemyEvent = game:GetService("ReplicatedStorage").Events.SummonEnemy
local enemy = require(game:GetService("ServerScriptService").Main.Mob)

SummonEnemyEvent.Event:Connect(function(Enemy)
	local map = workspace.Map:FindFirstChildOfClass("Folder")
	if not map then
		warn("Map not found")
		return
	end

	-- Get closest path to summoner
	local path, pathLength, positions = enemy.GetClosestWaypointPath(map, Enemy.Hitbox.CFrame)
	if not path then
		warn("No path found for summoning")
		return
	end

	if Enemy.Name == "Necromancer" then
		enemy.Summon("Zombie", math.random(8,12), 0.15, 1 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Speedy", math.random(6,10), 0.12, 1 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Armored Zombie", math.random(5,8), 0.15, 1 ,1.2, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
	elseif Enemy.Name == "General Noobicus" then
		enemy.Summon("Noob Gaurdian", 1, 0.15, 0.28 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Shadow Noob", math.random(8,12), 0.08, 1 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Ripped Noob", math.random(3,4), 0.1, 0.5 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
	elseif Enemy.Name == "Doombringer" then
		enemy.Summon("Endbringer", math.random(1,1), 0.15, 0.45 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Brute", math.random(3,3), 0.5, 0.5 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Pilot", math.random(4,4), 0.1, 0.5 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
	elseif Enemy.Name == "Honorary" then
		enemy.Summon("Dark Knight", math.random(1,2), 1, 0.65 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Wizard", math.random(2,3), 0.5, 1.5 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Glider", math.random(5,6), 0.1, 1 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Assassin", math.random(6,7), 1, 1.25 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Enforcer", math.random(1,1), 1, 0.45 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
	elseif Enemy.Name == "Swordmaster" then
		enemy.Summon("Enforcer", math.random(1,1), 1, 0.4 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Volent", math.random(1,2), 0.5, 0.4 ,2, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Dark Knight", math.random(5,6), 1, 0.4 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Whispering Elm", math.random(1,2), 0.5, 0.5 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
		enemy.Summon("Marksman", math.random(7,8), 0.5, 0.65 ,1.5, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
	elseif Enemy.Name == "Noob Engineer" then
		enemy.Summon("Spawner", 1, 0.1, 1 ,1, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
	elseif Enemy.name == "Rift" then
		enemy.Summon("Voidling", 69, 0.05, 1 ,0.2, map, Enemy.Alpha.Value, Enemy.Hitbox.CFrame, path, pathLength, positions)
	end
end)

