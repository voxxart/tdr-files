"""Run the shared lightning module with strict cache ownership boundaries."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'Tower Defense R/ReplicatedStorage/GameModules/LightningBolt.luau').read_text()
code=r'''
local function signal()
 local s={}
 function s:Connect(f) self.fn=f; return {Disconnect=function() self.fn=nil end} end
 return s
end
local heartbeat=signal()
local cache={Free={},Owned={}}
function cache:GetPart()
 local p=table.remove(self.Free) or {Transparency=0.25}
 assert(not self.Owned[p]); self.Owned[p]=true; return p
end
function cache:ReturnPart(p)
 assert(self.Owned[p],'double return')
 assert(p.Transparency==1,'visible geometry teleported into distant cache')
 assert(p.Parent and p.Parent.Name=='LightningCacheStorage','cached geometry remains in Workspace')
 self.Owned[p]=nil; table.insert(self.Free,p)
end
function cache:SetCacheParent() end
local game={GetService=function(_,k) return if k=='Workspace' then {Terrain={}} else {Heartbeat=heartbeat} end}
local Instance={new=function() return {} end}
local Enum={Material={Neon=1}}
local Color3={new=function() return {} end}
local CFrame={new=function() return {} end,lookAt=function() return {inverse=function(self) return self end} end}
local vector
vector=function(x,y,z)
 return setmetatable({X=x or 0,Y=y or 0,Z=z or 0}, {__mul=function(a,b) return vector(a.X*b,a.Y*b,a.Z*b) end, __add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end, __sub=function(a,b)
  local x,y,z=a.X-b.X,a.Y-b.Y,a.Z-b.Z
  local v=vector(x,y,z); v.Magnitude=math.sqrt(x*x+y*y+z*z); return v
 end})
end
local Vector3={new=vector}
local script={Parent={PartCache={WaitForChild=function() return {} end}}}
local require=function() return {new=function(_,_,storage) assert(storage.Name=='LightningCacheStorage' and storage.Parent==nil,'cache must be outside Workspace'); return cache end} end
local Lightning=(function()
'''+source+r'''
end)()
local anchor={WorldPosition=vector(0,0,0),WorldAxis=vector(1,0,0)}
local bolts={}
for i=1,8 do table.insert(bolts,Lightning.new(anchor,anchor,2)) end
bolts[2]:Destroy(); bolts[4]:Destroy(); bolts[7]:Destroy()
for i=1,6 do table.insert(bolts,Lightning.new(anchor,anchor,2)) end
local live=0
for _,b in bolts do if not b._Destroyed then live+=1 end end
-- Force all live bolts through the module's expiry branch. Any registry overwrite leaks parts.
for _,b in bolts do b.PulseLength=-1 end
local debug={profilebegin=function() end,profileend=function() end}
-- Module uses Luau's debug library; profiling functions exist only in Roblox.
local env=getfenv(heartbeat.fn)
env.debug=debug
heartbeat.fn()
assert(next(cache.Owned)==nil,'active bolt registry lost a bolt')
for _,b in bolts do b:Destroy() end -- repeat destroy must be harmless
local frozen=Lightning.new(anchor,anchor,6)
frozen.Jagged=true
frozen.Attachment1={WorldPosition=vector(12,0,0),WorldAxis=vector(1,0,0)}
frozen.Static=true; frozen.StaticLifetime=1000
frozen.OpacityProfileFunction=function() return 1 end
local geometryCalls=0
local points={}
function frozen:_UpdateGeometry(part, _, _, _, _, nextPoint) geometryCalls+=1; part.Transparency=0; table.insert(points,nextPoint) end
function frozen:_UpdateColor() end
heartbeat.fn()
assert(geometryCalls==6 and frozen._StaticRendered,'static bolt not built')
assert(points[6].X==12 and points[6].Y==0 and points[6].Z==0,'endpoint moved')
local hasKink=false
for i=1,5 do if math.abs(points[i].Y)>0.001 then hasKink=true end end
assert(hasKink,'jagged bolt has no vertical kinks')
heartbeat.fn(); heartbeat.fn()
assert(geometryCalls==6,'static bolt geometry rebuilt every frame')
frozen._StartT=-100000
heartbeat.fn()
assert(frozen._Destroyed,'static lifetime did not expire')
local bolt=Lightning.new(anchor,anchor,2)
bolt.OpacityProfileFunction=function() return 1 end
local part={Transparency=0}
bolt:_UpdateGeometry(part,0.5,0,1,vector(),vector())
assert(part.Transparency==1,'zero-length segment should be hidden')
bolt.OpacityProfileFunction=function() return 0 end
bolt.ContractFrom=2
part.Transparency=0
bolt:_UpdateGeometry(part,0.5,0,1,vector(),vector(1,0,0))
assert(part.Transparency==1,'fully faded segment should be hidden')
bolt:Destroy()
print('Lightning lifecycle: hidden cache returns, sparse expiry, idempotent cleanup and degenerate segments passed')
'''
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau') as f:
 f.write(code);f.flush()
 subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True)
