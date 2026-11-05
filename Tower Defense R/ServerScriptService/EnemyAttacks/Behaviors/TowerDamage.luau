local Rep = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local TowerDeath = require(game.ServerScriptService.Main.TowerDeath)
local Towers = workspace:WaitForChild('Towers')
local Damage = {}
function Damage.Apply(target, amount, generation)
	if not Match.IsCurrent(generation) or target.Parent ~= Towers then return end
	local config = target:FindFirstChild('Config')
	local folder = config and config:FindFirstChild('Health')
	local health = folder and folder:FindFirstChild('HealthValue')
	if not health or health.Value <= 0 or target:GetAttribute('Dying') then return end
	health.Value = math.max(0, health.Value - amount)
	if health.Value > 0 then return end
	target:SetAttribute('Dying', true)
	Rep.Events.AnimateTowerDeath:FireAllClients(target, 'TowerDeath', target)
	local owner = config:FindFirstChild('Owner')
	local player = owner and Players:FindFirstChild(owner.Value)
	task.spawn(function()
		if Match.Wait(generation, 0.5) and target.Parent == Towers then
			TowerDeath.KillTower(target, player, function() return Match.IsCurrent(generation) end)
		end
	end)
end
return Damage
