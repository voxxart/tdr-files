"""Execute photon visuals and max-level client dispatch with mocked Roblox boundaries."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
module=(root/'Tower Defense R/ReplicatedStorage/GameModules/PhotonShots.luau').read_text()
client=(root/'Tower Defense R/StarterPlayer/StarterPlayerScripts/Towers/Railgunner.client.luau').read_text()
code=r'''
local function signal()
 local s={Callbacks={}}
 function s:Connect(f) table.insert(self.Callbacks,f); return {Disconnect=function() end} end
 function s:Fire(...) for _,f in self.Callbacks do f(...) end end
 return s
end
local function node(kind,children)
 local n={Kind=kind,Parent=true,Attributes={},Changed=signal()}
 for k,v in children or {} do n[k]=v end
 function n:FindFirstChild(k) return self[k] end
 function n:WaitForChild(k) return assert(self[k],k) end
 function n:IsA(k) return self.Kind==k end
 function n:GetAttribute(k) return self.Attributes[k] end
 function n:Destroy() self.Parent=nil; self.Destroyed=true end
 return n
end
local vec
vec=function(x,y,z)
 return setmetatable({X=x,Y=y,Z=z},{__sub=function(a,b)
  local x,y,z=a.X-b.X,a.Y-b.Y,a.Z-b.Z
  return {Magnitude=math.sqrt(x*x+y*y+z*z),Unit={}}
 end})
end
local Vector3={new=vec}
local CFrame={new=function(p) return {Position=p} end}
local Color3={fromRGB=function(r,g,b) return {R=r,G=g,B=b} end}
local Enum={PartType={Ball=1},Material={Neon=1}}
local created=0
local Instance={new=function(k) if k=='Part' then created+=1 end; return node(k) end}
local function typeof(x) return if type(x)=='table' and x.Kind then 'Instance' else type(x) end
local bolts={}
local Lightning={new=function(a,b,count)
 local bolt={From=a,To=b,Count=count}
 function bolt:Destroy() self.Destroyed=true end
 table.insert(bolts,bolt); return bolt
end}
local quality='High'
local event=signal(); local hb=signal()
local modules=node('Folder',{VFXPolicy={Quality=function() return quality end},TowerData={Towers={Railgunner={Upgrades={[1]={},[2]={},[3]={},[4]={}}}}}})
local rep=node('Folder',{GameModules=modules,LightningBolt=Lightning,Events=node('Folder',{AnimateTower={OnClientEvent=event}})})
local info=node('Folder',{GameRunning=node('BoolValue',{Value=true}),Message=node('StringValue',{Value=''}),GameSpeed={Value=1}})
local towers=node('Folder')
local workspace=node('Workspace',{Info=info,Towers=towers,CurrentCamera={CFrame={Position=vec(0,0,0)}}})
local game={GetService=function(_,name) return if name=='ReplicatedStorage' then rep else {Heartbeat=hb} end}
local require=function(m) return m end
local script={Destroying=signal()}
local Photon=(function()
'''+module+r'''
end)()
local pool=Photon.new(workspace)
local color=Color3.fromRGB(255,80,130)
assert(pool:Emit(vec(0,0,0),vec(10,0,0),color,false))
local b=bolts[#bolts]
assert(b.Count==1 and b.MaxRadius==0 and b.Static and b.Color==color)
assert(pool.Active[1].Impact.Color==color)
assert(not pool:Emit(vec(0,0,0),vec(10000,0,0),color,false))
assert(not pool:Emit(vec(0/0,0,0),vec(10,0,0),color,false))
for i=1,100 do pool:Emit(vec(0,0,0),vec(10,0,0),color,false) end
assert(#pool.Active==48 and created==48,'unbounded geometry')
pool:Step(1)
assert(#pool.Active==0 and #pool.Free==48)
local count=created
pool:Emit(vec(0,0,0),vec(10,0,0),color,false)
assert(created==count,'impact not reused')
pool:Clear()
for i=1,100 do pool:Emit(vec(0,0,0),vec(10,0,0),color,true) end
assert(#pool.Active==16)
pool:Destroy();pool:Destroy()
assert(pool.Folder.Destroyed and pool.Storage.Destroyed)
modules.PhotonShots=Photon
'''+client+r'''
local tower=node('Model',{Name='Skin Name',Config=node('Folder',{PhotonColor=node('Color3Value',{Value=color})}),Weapon=node('Folder',{Handle=node('BasePart',{Position=vec(1,0,0),Barrel=node('Attachment',{WorldPosition=vec(2,0,0)})})})})
tower.Parent=towers;tower.Attributes.TowerName='Railgunner'
local enemy=node('Model',{HumanoidRootPart=node('BasePart',{Position=vec(10,0,0)})})
local count=#bolts
tower.Attributes.TowerLevel=3;event:Fire(tower,'Attack',enemy)
assert(#bolts==count,'lower level fired photon')
tower.Attributes.TowerLevel=4;event:Fire(tower,'Attack',enemy)
assert(#bolts==count+1 and bolts[#bolts].Color==color and bolts[#bolts].From.WorldPosition.X==2)
tower.Attributes.TowerName='Trooper';event:Fire(tower,'Attack',enemy)
assert(#bolts==count+1,'other tower fired photon')
info.GameRunning.Value=false;info.GameRunning.Changed:Fire()
assert(bolts[#bolts].Destroyed,'match end leaked bolt')
script.Destroying:Fire()
print('Photon: level gating, skin color, muzzle, bounded/reused impacts and match cleanup passed')
'''
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau') as f:
 f.write(code);f.flush();subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True)
