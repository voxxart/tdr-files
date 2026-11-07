"""Run the actual tracer pool under deterministic vector/renderer mocks."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'Tower Defense R/ReplicatedStorage/GameModules/BulletTracers.luau').read_text()
code='local source=[====['+source+']====]\n'+r'''
local vec
local mt={}
vec=function(x,y,z) return setmetatable({X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)},mt) end
mt.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
mt.__div=function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
mt.__mul=function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end
local partsCreated=0
local batches=0
local world={BulkMoveTo=function(_,parts,frames)
 batches+=1; assert(#parts==#frames)
 for index,part in parts do part.CFrame=frames[index] end
end}
local rot={}
setmetatable(rot,{__add=function(_,p) return {Position=p} end})
local environment=setmetatable({
 Instance={new=function(kind)
  if kind=='Part' then partsCreated+=1 end
  return {Destroy=function(self) self.Destroyed=true end}
 end},Vector3={new=vec,zero=vec(0,0,0)},CFrame={lookAt=function() return {Rotation=rot} end},
 Enum={Material={Neon=1},BulkMoveMode={FireCFrameChanged=1}},Color3={fromRGB=function(...) return {...} end}
},{__index=getfenv()})
local chunk=assert(loadstring(source)); setfenv(chunk,environment)
local Tracers=chunk(); local pool=Tracers.new(world)
local from,to=vec(0,0,0),vec(100,0,0)
assert(not pool:Emit(from,from) and partsCreated==0)
for i=1,64 do assert(pool:Emit(from,to)) end
assert(not pool:Emit(from,to) and partsCreated==64)
pool:Step(0.01,1,false)
assert(batches==1 and #pool.Active==64)
local part=pool.Active[1].Part
local x=part.CFrame.Position.X
assert(x>0 and x<100 and not part.CanCollide and not part.CanTouch and not part.CanQuery)
pool:Step(0.1,0,false); assert(part.CFrame.Position.X==x,'pause must freeze flight')
pool:Step(0.2,1,false); assert(#pool.Active==0 and #pool.Free==64)
assert(pool:Emit(from,to) and partsCreated==64,'expired parts must be reused')
pool:Clear(); assert(#pool.Active==0 and #pool.Free==64 and part.Transparency==1)
pool:Step(0.01,1,true); assert(pool.Tokens==3,'low VFX reduces emission rate')
pool:Clear()
-- Sustain a large event burst while respecting both the allocation and token bounds.
local attempts,accepted=0,0
for frame=1,240 do
 pool:Step(1/60,1,false)
 for shot=1,200 do attempts+=1; if pool:Emit(from,to) then accepted+=1 end end
 assert(#pool.Active<=Tracers.Settings.MaxActive and pool.Created<=Tracers.Settings.MaxActive)
end
assert(attempts==48000 and accepted<attempts and partsCreated<=256)
pool:Clear()
for _,r in pool.Free do assert(r.Part.Transparency==1) end
pool:Destroy(); assert(pool.Folder.Destroyed and #pool.Free==0)
print('Bullet tracer checks passed: bounded burst/allocation, reuse, batched movement, pause, low VFX, match cleanup; 48000 synthetic emissions (not a Studio benchmark)')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush()
 subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
client=(root/'Tower Defense R/StarterPlayer/StarterPlayerScripts/TowerBullets.client.luau').read_text()
code='local source=[====['+client+']====]\n'+r'''
local function signal()
 local s={Callbacks={}}
 function s:Connect(fn) local c={Connected=true,Fn=fn}; function c:Disconnect() self.Connected=false end; table.insert(self.Callbacks,c); return c end
 function s:Fire(...) for _,c in self.Callbacks do if c.Connected then c.Fn(...) end end end
 return s
end
local function node(class)
 local n={Class=class,Parent=true,Instance=true}
 function n:IsA(k) return self.Class==k end
 function n:FindFirstChild(k) return self[k] end
 function n:WaitForChild(k) return assert(self[k],k) end
 function n:GetAttribute(k) return self[k] end
 function n:IsDescendantOf(parent) return self.Tower==parent end
 return n
end
local vmt={__sub=function(a,b) return setmetatable({X=a.X-b.X},{__index={Dot=function(self,other) return self.X*other.X end}}) end}
local function pos(x) return setmetatable({X=x},vmt) end
local events={AnimateTower={OnClientEvent=signal()}}
local render=signal(); local destroyed=signal()
local info={GameRunning={Value=true,Changed=signal()},Message={Value='',Changed=signal()},GameSpeed={Value=1}}
local towers={ChildRemoved=signal()}
local world=node('Workspace'); world.Info=info; world.Towers=towers; world.CurrentCamera={CFrame={Position=pos(0)}}
local pool={Tokens=64,Active={},Emissions=0,ClearCount=0}
function pool:Emit(from,to) self.Emissions+=1; self.LastFrom=from; self.LastTo=to end
function pool:Step(_,_,low) self.Low=low end
function pool:Clear() self.ClearCount+=1; table.clear(self.Active) end
function pool:Destroy() self.Destroyed=true end
local player=node('Player'); player.VFX={Value='Low'}
local modules=node('Folder'); modules.CombatProfiles='profiles'; modules.BulletTracers='pool'
local rep={GameModules=modules,Events=node('Folder')}; rep.Events.AnimateTower=events.AnimateTower
local env=setmetatable({workspace=world,script={Destroying=destroyed},typeof=function(v) return type(v)=='table' and v.Instance and 'Instance' or type(v) end,
 game={GetService=function(_,name) if name=='ReplicatedStorage' then return rep elseif name=='Players' then return {LocalPlayer=player} else return {RenderStepped=render} end end},
 require=function(id) if id=='profiles' then return {Resolve=function(_,kind) return kind end} end; return {new=function() return pool end,Settings={MaxDistance=350}} end
},{__index=getfenv()})
local chunk=assert(loadstring(source)); setfenv(chunk,env); chunk()
local tower=node('Model'); tower.Parent=towers; tower.Config=node('Folder'); tower.Config.DamageType={Value='Bullet'}
local weapon=node('Model'); local handle=node('BasePart'); handle.Tower=tower; handle.Position=pos(5); weapon.Handle=handle; tower.Weapon=weapon
local target=node('Model'); target.HumanoidRootPart=node('BasePart'); target.HumanoidRootPart.Position=pos(50)
local event=events.AnimateTower.OnClientEvent
local barrel=node('Attachment'); barrel.WorldPosition=pos(6); handle.Barrel=barrel
local oldMuzzle=node('Attachment'); oldMuzzle.WorldPosition=pos(7); handle.Muzzle=oldMuzzle
event:Fire(tower,'Attack',target); assert(pool.Emissions==1 and pool.LastFrom==barrel.WorldPosition,'Barrel attachment must be the origin')
tower.Config.DamageType.Value='Fire'; event:Fire(tower,'Attack',target); assert(pool.Emissions==1)
tower.Config.DamageType.Value='Bullet'; local replacement=node('Model'); local newHandle=node('BasePart'); newHandle.Tower=tower; newHandle.Position=pos(10); replacement.Handle=newHandle; tower.Weapon=replacement
event:Fire(tower,'Attack',target); assert(pool.Emissions==2 and pool.LastFrom==newHandle.Position,'upgrade must replace cached muzzle')
newHandle.Position=pos(500); event:Fire(tower,'Attack',target); assert(pool.Emissions==2)
newHandle.Position=pos(5); info.GameSpeed.Value=0; event:Fire(tower,'Attack',target); assert(pool.Emissions==2)
info.GameSpeed.Value=1; render:Fire(0.01); assert(pool.Low)
info.GameRunning.Value=false; info.GameRunning.Changed:Fire(); assert(pool.ClearCount==1)
event:Fire(tower,'Attack',target); assert(pool.Emissions==2)
destroyed:Fire(); assert(pool.Destroyed)
for _,c in event.Callbacks do assert(not c.Connected) end
print('Bullet client checks passed: Bullet-only, weapon replacement, distance culling, pause, low VFX, match end, listener cleanup')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush()
 subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
