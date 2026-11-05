local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local Rep = game:GetService('ReplicatedStorage')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Runtime = require(game.ServerScriptService.EnemySystem.EnemyRuntime)
local Targeting = require(script.Parent.Targeting.NearestTower)
local Ledger = require(game.ServerScriptService.Simulation.ResourceLedger)
local Lifetime = require(game.ServerScriptService.Simulation.WaveLifetime)
local Economy = {}
local orbs, holds = {}, {}
local ledger = Ledger.new()
local generation, cashElapsed = nil, 0
local function release(tower) ledger:Release(tower) end
local function acquire(tower)
	return ledger:Acquire(tower, function()
		local config = tower:FindFirstChild('Config')
		local cash = config and config:FindFirstChild('Cash')
		if not cash or config:FindFirstChild('EcoDebuff') or config:FindFirstChild('OriginalCash') then return nil end
		local original = cash:Clone(); original.Name = 'OriginalCash'; original.Parent = config
		local flag = Instance.new('BoolValue'); flag.Name = 'EcoDebuff'; flag.Value = true; flag.Parent = config
		cash.Value = math.round(original.Value * 0.5)
		return function()
			if cash.Parent and original.Parent then cash.Value = original.Value end
			flag:Destroy(); original:Destroy()
		end
	end)
end
local function restore(enemy, hold)
	if enemy.Parent then
		if hold.Speed and hold.Speed.Parent and hold.Speed.Value == 0 then
			hold.Speed.Value = if hold.Original and hold.Original.Parent then hold.Original.Value else hold.Saved
		end
		enemy:SetAttribute('UsedAbility', false)
	end
	holds[enemy] = nil
end
local function dispose(orb)
	for tower in pairs(orb.Affected) do release(tower) end
	orb.Model:Destroy()
end
local function clear()
	for _, orb in orbs do dispose(orb) end
	table.clear(orbs)
	for enemy, hold in pairs(holds) do restore(enemy, hold) end
	cashElapsed = 0
end
function Economy.Spawn(position, matchGeneration)
	if not Match.IsCurrent(matchGeneration) then return end
	local model = Rep.Particle.EcoDebuff:Clone()
	model.Position = position - Vector3.new(0, 1.18, 0); model.Anchored = true
	local endWave = workspace.Info.Wave.Value + 2
	model.DebuffWave.Value = endWave
	model.Immune.Disappears.Text = 'Despawns: Wave ' .. endWave
	model.Parent = workspace.Visual
	table.insert(orbs, {Model = model, EndWave = endWave, Affected = {}})
end
local function drain()
	local candidates = {}
	for _, mob in workspace.Mobs:GetChildren() do
		local runtime = Runtime.Get(mob)
		local stats = mob:FindFirstChild('EnemyStats')
		local percent = stats and stats:FindFirstChild('DebuffPercent')
		if runtime and runtime.MatchGeneration == generation and not runtime.Dead and runtime.HealthValue.Value > 0
			and not mob:GetAttribute('UsedAbility') and percent and percent.Value > 0 then
			table.insert(candidates, mob)
		end
	end
	local enemy = candidates[1]
	if not enemy then return end
	enemy:SetAttribute('UsedAbility', true)
	local stats = enemy.EnemyStats
	local speed = stats:FindFirstChild('Speed')
	holds[enemy] = {Speed = speed, Saved = speed and speed.Value, Original = stats:FindFirstChild('OrigSpeed'), Until = Match.Now() + 4}
	if speed then speed.Value = 0 end
	Rep.Events.AnimateEnemy:FireAllClients(enemy, 'CoinFlip', nil)
	for _, player in Players:GetPlayers() do
		local cash = player:FindFirstChild('Cash')
		if cash then Rep.Events.MoneyDebuff:FireClient(player); cash.Value -= 1000 end
	end
end
local scanElapsed = 0
RunService.Heartbeat:Connect(function(dt)
	local current = Match.Capture()
	if generation ~= current or not Match.IsCurrent(current) then
		clear(); generation = current; scanElapsed = 0
		if not Match.IsCurrent(current) then return end
	end
	local now = Match.Now()
	for enemy, hold in pairs(holds) do
		local runtime = Runtime.Get(enemy)
		if now >= hold.Until or not runtime or runtime.Dead or runtime.HealthValue.Value <= 0 then restore(enemy, hold) end
	end
	cashElapsed += dt
	if cashElapsed >= 15 then cashElapsed %= 15; drain() end
	scanElapsed += dt
	if scanElapsed < 0.1 then return end
	scanElapsed %= 0.1
	for i = #orbs, 1, -1 do
		local orb = orbs[i]
		for tower in pairs(orb.Affected) do
			if tower.Parent ~= workspace.Towers then release(tower); orb.Affected[tower] = nil end
		end
		local state = Lifetime.State(orb, workspace.Info.Wave.Value, now, orb.Model.Parent ~= nil)
		if state == 'Expired' then
			dispose(orb); table.remove(orbs, i)
		elseif state == 'Linger' then
			orb.Model.Parent = nil
		else
			for _, tower in workspace.Towers:GetChildren() do
				local config = tower:FindFirstChild('Config')
				if Targeting.Valid(tower, workspace.Towers) and config and config:FindFirstChild('Farm') and not config:FindFirstChild('Flying') then
					local delta = tower.PrimaryPart.Position - orb.Model.Position
					if delta.X * delta.X + delta.Z * delta.Z <= 25 and not orb.Affected[tower] and acquire(tower) then
						orb.Affected[tower] = true
					end
				end
			end
		end
	end
end)
return Economy
