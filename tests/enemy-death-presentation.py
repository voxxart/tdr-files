"""Exercise the actual death presentation script, including reusable animated rigs."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
files={'client':'Tower Defense R/StarterPlayer/StarterPlayerScripts/EnemyDeath.client.luau','pool':'Tower Defense R/ReplicatedStorage/GameModules/EnemyDeathPool.luau','visibility':'Tower Defense R/ReplicatedStorage/GameModules/ScreenVisibility.luau'}
code='local sources={}\n'+'\n'.join('sources.'+k+'=[====['+(root/p).read_text()+']====]' for k,p in files.items())+r'''
local function signal()
 local s={Callbacks={}}
 function s:Connect(fn) local c={Connected=true,F=fn}; function c:Disconnect() self.Connected=false end; table.insert(self.Callbacks,c); return c end
 function s:Fire(...) for _,c in self.Callbacks do if c.Connected then c.F(...) end end end
 return s
end
local tracks={}; local emitted=0
local function node(class,name)
 local n={Class=class,Name=name or class,Children={},Attributes={},PlaybackSpeed=1,Length=1,IsPlaying=false,Changed=signal(),Transform={}}
 setmetatable(n,{__index=function(self,key) if key=='Parent' then return rawget(self,'_Parent') end; return rawget(self,key) or self.Children[key] end,
 __newindex=function(self,key,value)
  if key=='Parent' then
   local old=rawget(self,'_Parent'); if old then old.Children[self.Name]=nil end
   rawset(self,'_Parent',value); if value then value.Children[self.Name]=self end
  else rawset(self,key,value) end
 end})
 function n:IsA(kind) return class==kind or kind=='BasePart' and class=='Part' end
 function n:FindFirstChild(key,recursive) if self.Children[key] then return self.Children[key] end; if recursive then for _,c in self.Children do local found=c:FindFirstChild(key,true); if found then return found end end end end
 function n:WaitForChild(key) return assert(self[key],key) end
 function n:FindFirstChildWhichIsA(kind,recursive) for _,c in self.Children do if c:IsA(kind) then return c end; if recursive then local found=c:FindFirstChildWhichIsA(kind,true); if found then return found end end end end
 function n:GetDescendants() local out={} for _,c in self.Children do table.insert(out,c); for _,d in c:GetDescendants() do table.insert(out,d) end end return out end
 function n:GetAttribute(key) return self.Attributes[key] end
 function n:GetExtentsSize() return {Magnitude=4} end
 function n:Destroy() self.Parent=nil; self.Destroyed=true end
 function n:Play() self.IsPlaying=true end
 function n:Stop() self.IsPlaying=false end
 function n:Pause() self.IsPlaying=false; self.Paused=true end
 function n:Resume() self.IsPlaying=true; self.Paused=false end
 function n:AdjustSpeed(value) self.Speed=value end
 function n:Emit(count) emitted+=count end
 function n:Clear() self.Cleared=true end
 function n:LoadAnimation() local track=node('AnimationTrack'); tracks[#tracks+1]=track; return track end
 function n:PivotTo(cf) local root=self.PrimaryPart or self:FindFirstChild('HumanoidRootPart') or self; root.Position=cf.Position end
 function n:Clone()
  local copy=node(self.Class,self.Name)
  for key,value in pairs(self.Attributes) do copy.Attributes[key]=value end
  for _,c in self.Children do local child=c:Clone(); child.Parent=copy end
  if self.PrimaryPart then copy.PrimaryPart=copy:FindFirstChild(self.PrimaryPart.Name) end
  return copy
 end
 return n
end
local function add(parent,class,name) local n=node(class,name); n.Parent=parent; return n end
local world=node('Workspace'); local info=add(world,'Folder','Info')
for key,value in {GameRunning=true,GameSpeed=1,Message=''} do local n=add(info,'Value',key); n.Value=value end
world.CurrentCamera={ViewportSize={X=1920,Y=1080},FieldOfView=70,CFrame={PointToObjectSpace=function(_,p) return p end}}
local rep=node('Folder'); local gm=add(rep,'Folder','GameModules'); gm.ScreenVisibility='visibility'; gm.EnemyDeathPool='pool'; gm.EnemyData='data'
local mobs=add(rep,'Folder','Mobs'); local template=add(mobs,'Model','TestEnemy')
local root=add(template,'Part','HumanoidRootPart'); template.PrimaryPart=root
add(template,'Script','OldScript'); add(template,'Folder','EnemyStats'); add(template,'Part','Hitbox')
local fx=add(template,'Folder','DeathEffects'); fx.Attributes.Duration=2
local animations=add(fx,'Folder','Animations'); add(animations,'Animation','Death')
local sounds=add(fx,'Folder','Sounds'); add(sounds,'Sound','DeathSound')
local particles=add(fx,'Folder','Particles'); local source=add(particles,'ParticleEmitter','Smoke'); source.Attributes.EmitCount=300
local clones={}; local clone=template.Clone
function template:Clone() local copy=clone(self); table.insert(clones,copy); return copy end
local events=add(rep,'Folder','Events'); local remote=add(events,'RemoteEvent','EnemyDeath'); remote.OnClientEvent=signal()
local player=node('Player'); player.VFX={Value='High'}
local render=signal(); local dying=signal()
local modules={data={Settings={MaxDeathPresentations=4,DeathPresentationsPerFrame=2,DeathParticlesPerEffect=200}}}
local env=setmetatable({workspace=world,script={Destroying=dying},Instance={new=node},Vector3={new=function(...) return {...} end},Enum={AnimationPriority={Action4=1}},
 typeof=function(value) return type(value)=='table' and value.IsFrame and 'CFrame' or type(value) end,
 Random={new=function() return {NextInteger=function(_,minimum) return minimum end} end},
 game={GetService=function(_,key) if key=='ReplicatedStorage' then return rep elseif key=='RunService' then return {RenderStepped=render} else return {LocalPlayer=player} end end}}, {__index=getfenv()})
local function load(id) if modules[id] then return modules[id] end; local chunk=assert(loadstring(sources[id])); setfenv(chunk,env); modules[id]=chunk(); return modules[id] end
env.require=load; load('client')
local cf={IsFrame=true,Position={X=0,Y=0,Z=-100}}
for id=1,100 do remote.OnClientEvent:Fire('TestEnemy',cf,id) end
assert(#clones==2 and #tracks==2 and emitted==200,'burst cap must bound rig/particle creation')
for _,corpse in clones do assert(not corpse:FindFirstChild('OldScript') and not corpse:FindFirstChild('EnemyStats')) end
render:Fire(0.1); remote.OnClientEvent:Fire('TestEnemy',cf,101); remote.OnClientEvent:Fire('TestEnemy',cf,102)
assert(#clones==4)
info.GameSpeed.Value=0; render:Fire(5)
for _,track in tracks do assert(track.Speed==0) end
info.GameSpeed.Value=1; render:Fire(2.1)
for _,corpse in clones do assert(not corpse.Parent) end
remote.OnClientEvent:Fire('TestEnemy',cf,103); assert(#clones==4,'expired corpse should be reused')
local off={IsFrame=true,Position={X=1000,Y=0,Z=-100}}
remote.OnClientEvent:Fire('TestEnemy',off,104); assert(#clones==4)
info.GameRunning.Value=false; info.GameRunning.Changed:Fire()
for _,corpse in clones do assert(not corpse.Parent) end
dying:Fire(); for _,corpse in clones do assert(corpse.Destroyed) end
for _,track in tracks do assert(track.Destroyed) end
for _,c in remote.OnClientEvent.Callbacks do assert(not c.Connected) end
print('Enemy death presentation passed: actual rig pooling, burst/particle caps, script stripping, pause, reuse, offscreen skip, end and listener cleanup')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush(); subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
