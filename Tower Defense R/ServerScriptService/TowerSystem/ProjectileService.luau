local Match = require(game.ServerScriptService.Simulation.MatchService)
local Runtime = require(script.Parent.TowerRuntime)
local Prediction = require(script.Parent.ProjectilePrediction)
local Projectiles = {}
function Projectiles.Cancel(model)
	local runtime = Runtime.Get(model)
	local pending = runtime and runtime.State and runtime.State.Projectiles
	if not pending then return end
	for token, cancel in pairs(pending) do cancel(); pending[token] = nil end
end
function Projectiles.Launch(model, target, config, emit, impact)
	local runtime = Runtime.Get(model)
	local generation = Match.Capture()
	local hitbox = target and target:FindFirstChild('Hitbox')
	if not runtime or runtime.Destroyed or not hitbox or not Match.IsCurrent(generation) then return end
	local aim = hitbox.Position
	local root = model:FindFirstChild('HumanoidRootPart')
	local origin = root and root.Position or aim
	local speed = config:FindFirstChild('ProjectileSpeed')
	local authored = config:FindFirstChild('Projectile')
	local minimum = authored and authored:FindFirstChild('MinTravelTime')
	local authoredSpeed = authored and authored:FindFirstChild('Speed')
	local studs = math.max((authoredSpeed and authoredSpeed.Value) or (speed and speed.Value) or 50, 0.001)
	local minTime = math.max((minimum and minimum.Value) or 0.05,0.05)
 local duration = math.max((aim-origin).Magnitude / studs,minTime)
 -- Mortars opt in by default; other splash towers keep their existing aim.
 local predictive = config:GetAttribute('PredictProjectileTarget')
 if predictive==nil then predictive=config:FindFirstChild('CliffTower')~=nil end
 if predictive and Prediction.Enabled then
  local weapon=model:FindFirstChild('Weapon'); local handle=weapon and weapon:FindFirstChild('Handle')
  local barrel=handle and handle:FindFirstChild('Barrel')
  origin=if barrel and barrel:IsA('Attachment') then barrel.WorldPosition elseif handle then handle.Position else origin
  aim,duration=Prediction.Solve(target,origin,aim,studs,minTime,Match.Now())
 end
	runtime.State.Projectiles = runtime.State.Projectiles or {}
	local pending = runtime.State.Projectiles
	if not runtime.State.ProjectileCleanup then
		runtime.State.ProjectileCleanup = true
		runtime.Cleanup:Add(function()
			for token, cancel in pairs(pending) do cancel(); pending[token] = nil end
		end)
	end
	emit(model, aim, 'SplashProjectile', duration / math.max(workspace.Info.GameSpeed.Value, 0.0001))
	local token = {}
	local cancel = Match.After(generation, duration, function()
		pending[token] = nil
		if Runtime.Get(model) == runtime and not runtime.Destroyed and model.Parent and config.Parent then impact(aim, model) end
	end)
	if cancel then pending[token] = cancel end
end
return Projectiles
