local Runtime = require(game.ServerScriptService.EnemySystem.EnemyRuntime)
local Index = require(game.ServerScriptService.Simulation.SpatialIndex)
local Policy = require(game.ServerScriptService.Simulation.TargetPolicy)
local Mobs = workspace:WaitForChild("Mobs")
local grid = Index.new(24)
local candidates = {}
local seen = {}
local lastFrame = -1
local RunService = game:GetService('RunService')
local frame = 0
RunService.Heartbeat:Connect(function() frame += 1 end)
local Targeting = {}
-- Reclaim index references immediately, even if no tower queries after match end.
Mobs.ChildRemoved:Connect(function(model)
	candidates[model] = nil; seen[model] = nil; grid:Remove(model)
end)
local function refresh()
	-- Rebuild once per Heartbeat on demand, shared by every tower query.
	if lastFrame == frame then return end
	lastFrame = frame
	table.clear(seen)
	for _, runtime in Runtime.GetActiveList() do
		local model = runtime.Model
		if model and model.Parent == Mobs and not runtime.Dead and not runtime.Cleaned
			and runtime.HealthValue.Value > 0 and runtime.Hitbox.Parent then
			local position = runtime.Hitbox.Position
			grid:Set(model, position.X, position.Z)
			candidates[model] = runtime; seen[model] = true
		end
	end
	for model in pairs(candidates) do
		if not seen[model] then candidates[model] = nil; grid:Remove(model) end
	end
end
function Targeting.Find(model, range, mode)
	local config = model:FindFirstChild('Config')
	local root = model:FindFirstChild('HumanoidRootPart')
	if not config or not root or not range then return nil end
	local origin = root.Position
	local aviator = config:FindFirstChild('Aviator') ~= nil
	if aviator then
		local upgrades = model:FindFirstChild('UpgradeModels')
		local zero = upgrades and upgrades:FindFirstChild('0')
		local plane = zero and zero:FindFirstChild('Plane')
		local rotate = plane and plane:FindFirstChild('RotatePart')
		local follow = rotate and rotate:FindFirstChild('RangeFollow')
		if follow then origin = follow.WorldPosition end
	end
	local hidden = config:FindFirstChild('HiddenDetection')
	local flying = config:FindFirstChild('FlyingDetection')
	local beamer = config:FindFirstChild('BeamerSettings') ~= nil
	refresh()
	local best, target
	local record = {}
	grid:Visit(origin.X, origin.Z, range, function(mob)
		local runtime = candidates[mob]
		if not runtime or runtime.Dead or runtime.Cleaned or mob.Parent ~= Mobs or runtime.HealthValue.Value <= 0 then return end
		local stats = runtime.Stats
		local hiddenFlag = stats:FindFirstChild('Hidden')
		local flyingFlag = stats:FindFirstChild('Flying')
		if hiddenFlag and hiddenFlag.Value and not (hidden and hidden.Value) then return end
		if flyingFlag and flyingFlag.Value and not (flying and flying.Value) then return end
		local aggro = stats:FindFirstChild('Aggro') ~= nil
		if beamer and not aggro and runtime.MaxHealth < 500 then return end
		local p = runtime.Hitbox.Position
		local dx, dz = p.X-origin.X, p.Z-origin.Z
		local distance = dx*dx + dz*dz
		if distance > range*range then return end
		record.Aggro = aggro; record.Flying = flyingFlag ~= nil and flyingFlag.Value == true
		record.Distance = distance; record.Alpha = runtime.Alpha; record.Health = runtime.HealthValue.Value
		if Policy.Better(record, best, mode, aviator) then
			best = best or {}
			for key, value in pairs(record) do best[key] = value end
			target = mob
		end
	end)
	return target
end
function Targeting.Visit(position, range, callback)
	refresh()
	grid:Visit(position.X,position.Z,range,function(model)
		local runtime = candidates[model]
		if runtime and not runtime.Dead and not runtime.Cleaned and model.Parent == Mobs
			and runtime.HealthValue.Value > 0 then callback(model) end
	end)
end
return Targeting
