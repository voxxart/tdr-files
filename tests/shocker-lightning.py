"""Exercise the actual Shocker client effect against engine/module boundaries."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'Tower Defense R/StarterPlayer/StarterPlayerScripts/Towers/Shocker.client.luau').read_text()
code=r'''
local now=0
local os={clock=function() return now end}
local function signal()
 local s={}
 function s:Connect(fn) self.fn=fn; return {Disconnect=function() self.fn=nil end} end
 function s:Fire(...) if self.fn then self.fn(...) end end
 return s
end
local function node(kind, children)
 local n={Kind=kind,Parent=true}
 for k,v in children or {} do n[k]=v end
 function n:FindFirstChild(k) return self[k] end
 function n:WaitForChild(k) return assert(self[k],k) end
 function n:IsA(k) return k==self.Kind end
 return n
end
local function typeof(n) return if type(n)=='table' and n.Kind then 'Instance' else type(n) end
local function pos(x)
 return setmetatable({X=x},{__sub=function(a,b) return {Magnitude=math.abs(a.X-b.X),Unit={}} end})
end
local bolts={}
local Lightning={new=function(a,b,count)
 local bolt={Start=a,Finish=b,Count=count,Destroyed=false}
 function bolt:Destroy() assert(not self.Destroyed,'double destroy'); self.Destroyed=true end
 table.insert(bolts,bolt); return bolt
end}
local quality='High'
local policy={Quality=function() return quality end}
local event=signal()
local hbSignal=signal()
local script={Destroying=signal()}
local shocker=node('Folder',{LightningBolt={OnClientEvent=event}})
local modules=node('Folder',{VFXPolicy=policy})
local rep=node('Folder',{LightningBolt=Lightning,GameModules=modules,Events={Shocker=shocker}})
local game={GetService=function(_,name) return if name=='ReplicatedStorage' then rep else {Heartbeat=hbSignal} end}
local require=function(m) return m end
local Color3={fromRGB=function(r,g,b) return {R=r,G=g,B=b} end}
'''+source+r'''
local origin=node('Attachment',{WorldPosition=pos(0)})
local tower=node('Model',{Weapon=node('Folder',{Handle=node('Part',{Lightning=origin})})})
local chain={}
for i=1,8 do chain[i]=node('Model',{Hitbox=node('BasePart',{Position=pos(i*10)})}) end
event:Fire(tower,chain)
assert(#bolts==8,'must render all eight links')
for i,b in bolts do
 assert(b.AnimationSpeed==0 and b.ColorOffsetSpeed==0)
 assert(b.MinThicknessMultiplier==b.MaxThicknessMultiplier)
 assert(b.Start.WorldPosition.X==(i-1)*10 and b.Finish.WorldPosition.X==i*10)
 assert(b.OpacityProfileFunction(0.5,0)==1)
 assert(b.OpacityProfileFunction(0.5,0.14)>0 and b.OpacityProfileFunction(0.5,0.14)<1)
end
for i=1,100 do event:Fire(tower,chain) end
local used=0
for _,b in bolts do used+=b.Count end
assert(used<=768,'budget exceeded')
now=1; hbSignal:Fire()
for _,b in bolts do assert(b.Destroyed,'expired bolt leaked') end
local before=#bolts
quality='Low'; event:Fire(tower,chain)
assert(#bolts==before+8,'budget did not recover')
script.Destroying:Fire()
for _,b in bolts do assert(b.Destroyed) end
assert(event.fn==nil and hbSignal.fn==nil,'connections leaked')
print('Shocker: full chain, stable shape, smooth fade, bounded geometry, cleanup passed')
'''
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau') as f:
 f.write(code);f.flush()
 subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True)
