"""Run real idle recovery, curve math, and shared mortar flights with engine boundaries."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
base=root/'Tower Defense R/ReplicatedStorage/GameModules'
code='local sources={}\n'
for key,name in [('idle','TowerIdleRecovery'),('arc','ProjectileArc'),('flights','MortarFlights')]:
 code+=f'sources.{key}=[====['+(base/(name+'.luau')).read_text()+']====]\n'
animations=(root/'Tower Defense R/StarterPlayer/StarterPlayerScripts/Animations.client.luau').read_text()
a=animations.index('.new(function(object)',animations.index('local towerIdleRecovery='))+len('.new(')
b=animations.index('\nend,16)',a)+len('\nend')
code+='sources.ensure=[====[return '+animations[a:b]+']====]\n'
code+=r'''
local v; local vm={}
v=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
vm.__index=function(a,key)
 if key=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
 if key=='Unit' then return a*(1/a.Magnitude) end
 if key=='Dot' then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
 if key=='Cross' then return function(a,b) return v(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end end
end
vm.__add=function(a,b) return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vm.__sub=function(a,b) return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__mul=function(a,n) return v(a.X*n,a.Y*n,a.Z*n) end
local frame
frame=function(p)
 return setmetatable({Position=p,ToObjectSpace=function(a,b) return frame(b.Position-a.Position) end},{__mul=function(a,b) return frame(a.Position+b.Position) end})
end
local loaded={}
local env=setmetatable({Vector3={new=v,yAxis=v(0,1,0)},script={Parent={ProjectileArc='arc'}},CFrame={new=function() return frame(v(0,0,0)) end,lookAt=function(p,to,up)
 local direction=(to-p).Unit; assert(math.abs(direction:Dot(up))<1e-5,'orientation must avoid vertical roll singularities'); return frame(p)
end},Enum={BulkMoveMode={FireCFrameChanged=1}}},{__index=getfenv()})
local function load(key)
 if loaded[key] then return loaded[key] end
 local fn=assert(loadstring(sources[key])); setfenv(fn,env); loaded[key]=fn(); return loaded[key]
end
env.require=load
local Arc=load('arc')
for _,points in {{v(0,0,0),v(2,0,0)},{v(0,0,0),v(200,0,0)},{v(0,40,0),v(50,-20,0)},{v(0,0,0),v(1,80,0)},{v(0,0,0),v(0,0,0)},{v(0,0,0),v(0,60,0)}} do
 for _,height in {0,6,60} do
  local arc=Arc.new(points[1],points[2],height,v(0,0,-1))
  assert((arc:Sample(0)-points[1]).Magnitude<1e-6 and (arc:Sample(1)-points[2]).Magnitude<1e-6)
  local last=points[1]; local minimum,maximum=math.huge,0
  for i=1,100 do
   local p,d,u=arc:Sample(i/100)
   assert(p.X==p.X and math.abs(d.Magnitude-1)<1e-6 and math.abs(u.Magnitude-1)<1e-6 and math.abs(u:Dot(d))<1e-6)
   local distance=(p-last).Magnitude; minimum=math.min(minimum,distance); maximum=math.max(maximum,distance); last=p
  end
  assert(maximum/minimum<1.5,'arc length mapping must avoid severe speed changes through the apex')
 end
end
assert(Arc.new(v(0,0,0),v(200,0,0),nil,v(0,0,-1)).Height>10,'long mortar arcs must not be clamped flat')
local Recovery=load('idle'); local folder={}; local cast={}; local played=0
local state={Ready=false,Track={IsPlaying=false}}
local object={Parent=folder,GetAttribute=function() return false end}
local ensureEnv=setmetatable({TowersFolder=folder,ActiveReaperTowerCasts=cast,setAnimation=function(_,name) assert(name=='Idle'); if state.Ready then return state.Track end end,
 playLoadedTrack=function(_,name,track) assert(name=='Idle'); track.IsPlaying=true; played+=1 end},{__index=getfenv()})
local init=assert(loadstring(sources.ensure)); setfenv(init,ensureEnv)
local recovery=Recovery.new(init(),1); recovery:Add(object); recovery:Add(object)
for _=1,14 do recovery:Step(0.5) end
state.Ready=true; cast[object]=true; recovery:Step(0.5); assert(played==0)
cast[object]=nil; recovery:Step(0.5); assert(played==1,'idle must recover even after the former five-second timeout and attack requests')
recovery:Step(1); assert(played==1,'playing idle must not restart every check')
state.Track.IsPlaying=false; recovery:Step(0.5); assert(played==2,'interrupted idle must recover')
recovery:Remove(object); assert(#recovery.Active==0 and not recovery.ByModel[object]); recovery:Clear()
local checked=0; local bounded=Recovery.new(function() checked+=1 end,4)
for _=1,100 do bounded:Add({}) end
bounded:Step(0.1); assert(checked==4,'idle checks must respect the per-frame budget'); bounded:Clear()
local objects={}
local function part()
 local n={CFrame=frame(v(0,0,0))}
 function n:IsA(kind) return kind=='BasePart' end
 function n:GetPivot() return self.CFrame end
 function n:GetDescendants() return {} end
 function n:PivotTo(cf) self.CFrame=cf end
 function n:Destroy() self.Parent=nil; self.Destroyed=true end
 return n
end
local template={Clone=function() local n=part(); table.insert(objects,n); return n end}
local batches=0
local world={BulkMoveTo=function(_,parts,frames) batches+=1; for i,p in parts do p.CFrame=frames[i] end end}
local flights=load('flights').new(world,{})
local impacts=0
local function launch() return flights:Launch(template,v(0,0,0),v(100,0,0),1,nil,v(0,0,-1),nil,function() impacts+=1 end) end
assert(launch()); flights:Step(0); assert(impacts==0 and objects[1].CFrame.Position.Magnitude<1e-6,'pause must hold at launch')
flights:Step(0.5); local previous=objects[1].CFrame.Position
flights:Step(0); assert((objects[1].CFrame.Position-previous).Magnitude<1e-6,'pause must hold in flight')
flights:Step(0.5); flights:Step(1); assert(impacts==1 and #flights.Active==0 and objects[1].Destroyed)
for _=1,16 do assert(launch()) end; assert(not launch(),'launch builds must be bounded per frame')
flights:Clear(); assert(impacts==1 and #flights.Parts==0 and #flights.Frames==0,'clearing at match end must not create impacts')
flights.Maximum=2; assert(launch() and launch() and not launch()); flights:Clear()
print('Tower idle/mortar passed: late idle recovery, cast guards, bounded checks, near/far/vertical arc math, endpoint and orientation stability, speed mapping, pause, shared updates, build/active caps, impact once and cleanup')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush(); subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
