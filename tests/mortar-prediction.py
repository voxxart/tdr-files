"""Execute real prediction and launch wiring over a curved path fixture."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
base=root/'Tower Defense R/ServerScriptService/TowerSystem'
code='local predictionSource=[====['+(base/'ProjectilePrediction.luau').read_text()+']====]\nlocal serviceSource=[====['+(base/'ProjectileService.luau').read_text()+']====]\n'+r'''
local v; local vm={}
v=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
vm.__index=function(a,key) if key=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
vm.__add=function(a,b) return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vm.__sub=function(a,b) return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
local sampleCount=0
local function sample(_,alpha)
 sampleCount+=1
 local distance=alpha*200
 return {Position=if distance<=100 then v(distance,0,0) else v(100,0,distance-100)}
end
local enemy={Alpha=0.45,Speed=20,PathLength=200,PathData={},Height=3,OffsetX=50,OffsetZ=-25,SpawnDelayRemaining=0,StunUntil=0}
local runtime={State={},Cleanup={Add=function() end}}
local scheduled,emitted,impact={},{},{}
local running,generation=true,1
local dependencies={enemy={Get=function() return enemy end},paths={SampleCFrame=sample},runtime={Get=function() return runtime end},match={Now=function() return 100 end,
 Capture=function() return generation end,IsCurrent=function(g) return running and g==generation end,
 After=function(_,seconds,fn) local item={Seconds=seconds,Callback=fn}; table.insert(scheduled,item); return function() item.Cancelled=true end end}}
local env=setmetatable({Vector3={new=v},workspace={Info={GameSpeed={Value=2}}},game={ServerScriptService={EnemySystem={EnemyRuntime='enemy',EnemyPaths='paths'},Simulation={MatchService='match'}}},
 script={Parent={TowerRuntime='runtime',ProjectilePrediction='prediction'}},require=function(id) return assert(dependencies[id],id) end},{__index=getfenv()})
local init=assert(loadstring(predictionSource)); setfenv(init,env); local Prediction=init(); dependencies.prediction=Prediction
local origin=v(50,3,-20); local fallback=v(-999,0,0)
local aim,time=Prediction.Solve({},origin,fallback,40,0.05,100)
assert(aim.X==100.5 and aim.Z>-0.25,'lead must follow the corner, not extrapolate a straight velocity vector')
local expected=sample(enemy.PathData,enemy.Alpha+enemy.Speed*time/200).Position+v(0.5,3,-0.25)
assert((aim-expected).Magnitude<0.1,'predicted target position must agree with its arrival time')
assert(math.abs(time-(aim-origin).Magnitude/40)<1e-8 and sampleCount<=11,'lead and travel time use bounded path samples')
enemy.Speed=0; aim,time=Prediction.Solve({},origin,fallback,40,0.05,100)
assert((aim-v(90.5,3,-0.25)).Magnitude<1e-6,'stationary targets use authoritative runtime progress, not a stale hitbox')
enemy.Speed=20; enemy.StunUntil=110; aim=Prediction.Solve({},origin,fallback,40,0.05,100)
assert(aim.X==90.5 and aim.Z==-0.25,'known stun time must be subtracted')
enemy.StunUntil=0; enemy.SpawnDelayRemaining=10; aim=Prediction.Solve({},origin,fallback,40,0.05,100); assert(aim.X==90.5)
enemy.SpawnDelayRemaining=0; enemy.Alpha=0.99; aim=Prediction.Solve({},origin,fallback,10,0.05,100); assert(aim.X==100.5 and aim.Z==99.75,'path endpoint must be clamped')
enemy.Alpha=0.45; enemy.Speed=-10; aim=Prediction.Solve({},origin,fallback,40,0.05,100); assert(aim.X<90.5,'reverse movement must lead backward on the same path')
enemy.Dead=true; aim=Prediction.Solve({},origin,fallback,40,0.05,100); assert(aim==fallback); enemy.Dead=false
local oldPath=enemy.PathData; enemy.PathData=nil; aim=Prediction.Solve({},origin,fallback,40,0.05,100); assert(aim==fallback); enemy.PathData=oldPath
enemy.Speed=20
local function node(fields)
 fields=fields or {}; fields.Parent=true
 function fields:FindFirstChild(key) return self[key] end
 function fields:GetAttribute(key) return self.Attributes and self.Attributes[key] end
 return fields
end
local barrel={WorldPosition=origin,IsA=function(_,kind) return kind=='Attachment' end}
local model=node({HumanoidRootPart={Position=v(0,0,0)},Weapon=node({Handle=node({Position=v(5,0,0),Barrel=barrel})})})
local target=node({Hitbox={Position=v(90.5,3,-0.25)}})
local config=node({CliffTower={},ProjectileSpeed={Value=40}})
init=assert(loadstring(serviceSource)); setfenv(init,env); local Service=init()
local function launch()
 Service.Launch(model,target,config,function(_,position,kind,duration) assert(kind=='SplashProjectile'); emitted={Position=position,Duration=duration} end,
 function(position) impact=position end)
end
launch(); assert((emitted.Position-target.Hitbox.Position).Magnitude>1 and math.abs(emitted.Duration*2-scheduled[1].Seconds)<1e-8)
enemy.Speed=0; scheduled[1].Callback(); assert(impact==emitted.Position,'visual and impact use the same immutable launch aim even after speed changes')
config.Attributes={PredictProjectileTarget=false}; launch(); assert(emitted.Position==target.Hitbox.Position,'explicit false restores non-predictive aim')
config.Attributes=nil; config.CliffTower=nil; launch(); assert(emitted.Position==target.Hitbox.Position,'non-mortar splash towers retain their behavior')
config.CliffTower={}; launch(); Service.Cancel(model); assert(scheduled[4].Cancelled)
running=false; local count=#scheduled; launch(); assert(#scheduled==count,'match end prevents new shots')
print('Mortar prediction passed: curved/reversed paths, offsets, authoritative alpha, stop/stun/emergence, endpoints, bounded iterations, barrel origin, shared visual/impact aim, game-time duration, opt-out, non-mortar compatibility and cancellation')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush(); subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
