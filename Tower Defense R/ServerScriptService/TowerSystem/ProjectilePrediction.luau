local EnemyRuntime=require(game.ServerScriptService.EnemySystem.EnemyRuntime)
local Paths=require(game.ServerScriptService.EnemySystem.EnemyPaths)
local Prediction={Enabled=true} -- easy global mortar-prediction toggle
function Prediction.Solve(target,origin,fallback,projectileSpeed,minimum,now)
 local runtime=EnemyRuntime.Get(target)
 local fallbackTime=math.max((fallback-origin).Magnitude/projectileSpeed,minimum)
 if not runtime or runtime.Dead or runtime.Cleaned or not runtime.PathData or (runtime.PathLength or 0)<=0 then return fallback,fallbackTime end
 -- Snapshot the authoritative path state once. Prediction never scans enemies.
 local alpha,speed=runtime.Alpha,runtime.Speed
 local delay=math.max(runtime.SpawnDelayRemaining or 0,(runtime.StunUntil or 0)-now,0)
 local offset=Vector3.new((runtime.OffsetX or 0)/100,runtime.Height or 0,(runtime.OffsetZ or 0)/100)
 local function future(seconds)
  local progress=math.clamp(alpha+speed*math.max(0,seconds-delay)/runtime.PathLength,0,1)
  return Paths.SampleCFrame(runtime.PathData,progress).Position+offset
 end
 local aim=future(0)
 local duration=math.max((aim-origin).Magnitude/projectileSpeed,minimum)
 -- A fixed, small number of path lookups accounts for the lead changing flight time.
 for _=1,8 do
  aim=future(duration)
  local nextDuration=math.max((aim-origin).Magnitude/projectileSpeed,minimum)
  if math.abs(nextDuration-duration)<=0.002 then return aim,nextDuration end
  duration=nextDuration
 end
 aim=future(duration)
 return aim,math.max((aim-origin).Magnitude/projectileSpeed,minimum)
end
return Prediction
