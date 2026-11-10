"""Exercise real landing resolver and read-only balance HUD binding."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'Tower Defense R/ServerScriptService/EventCurrencySystem/Ground.luau').read_text()
hud=(root/'Tower Defense R/StarterGui/GameGui/EventCurrencyBalance.client.luau').read_text()
code='local source=[====['+source+']====]\nlocal hudSource=[====['+hud+']====]\n'+r'''
local vec
vec=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},{__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end}) end
local env=setmetatable({Vector3={new=vec},RaycastParams={new=function() return {} end},Enum={RaycastFilterType={Include=1}}},{__index=getfenv()})
local fn=assert(loadstring(source)); setfenv(fn,env); local Ground=fn()
local map={FindFirstChild=function() return nil end}
local random={NextNumber=function(_,low) return low end}
local config={ScatterMin=2,ScatterMax=6,GroundOffset=0.1,LandingAttempts=3}
local calls=0
local land=Ground.Find({},map,vec(0,3,0),3,random,config,function(start,direction,params)
 calls+=1; assert(params.RespectCanCollide and params.FilterDescendantsInstances[1]==map)
 if calls==1 then return {Position=vec(start.X,1,0),Normal=vec(1,0,0)} end
 return {Position=vec(start.X,0,0),Normal=vec(0,1,0)}
end)
assert(land.Y==0.1 and calls==2,'side face must not become a resting surface')
local fallback=Ground.Find({},map,vec(0,3,0),3,random,config,function(start)
 return {Position=vec(start.X,0,0),Normal=vec(0,1,0)}
end,function(hit) return hit.Position.X==0 end)
assert(fallback.X==0,'blocked scatter positions must retry and fall back to open floor near the enemy')
local none=Ground.Find({},map,vec(0,3,0),3,random,config,function() return nil end)
assert(not none,'missing floor must not create a guessed floating landing')
local dedicated={}; local specified={FindFirstChild=function(_,name) if name=='EventCurrencyFloor' then return dedicated end end}
assert(Ground.Find({},specified,vec(0,3,0),3,random,config,function(start,_,params)
 assert(params.FilterDescendantsInstances[1]==dedicated); return {Position=vec(start.X,0,0),Normal=vec(0,1,0)}
end))
local function signal()
 local s={Entries={}}
 function s:Connect(fn) local c={Connected=true,F=fn}; function c:Disconnect() self.Connected=false end; table.insert(self.Entries,c); return c end
 function s:Fire(...) for _,c in self.Entries do if c.Connected then c.F(...) end end end
 return s
end
local function node(name,class)
 local n={Name=name,Class=class,Parent=true}
 function n:FindFirstChild(key) return self[key] end
 function n:IsA(kind) return self.Class==kind end
 return n
end
local changed,added,destroy=signal(),signal(),signal()
local balance=1234
local player={GetAttribute=function(_,key) assert(key=='EventCurrencyBalance'); return balance end,
 GetAttributeChangedSignal=function(_,key) assert(key=='EventCurrencyBalance'); return changed end}
local gui=node('GameGui','ScreenGui'); gui.DescendantAdded=added
local henv=setmetatable({game={GetService=function(_,key) assert(key=='Players','HUD must not poll RunService or invoke data remotes'); return {LocalPlayer=player} end},script={Parent=gui,Destroying=destroy}},{__index=getfenv()})
local init=assert(loadstring(hudSource)); setfenv(init,henv); init()
gui.Settings=node('Settings','Frame'); gui.Settings.EventCurrency=node('EventCurrency','Frame'); local label=node('Amount','TextLabel'); gui.Settings.EventCurrency.Amount=label
added:Fire(label); assert(label.Text=='1,234')
balance=6500; changed:Fire(); assert(label.Text=='6,500')
balance=0/0; changed:Fire(); assert(label.Text=='0')
assert(#changed.Entries==1 and #added.Entries==1)
destroy:Fire(); assert(not changed.Entries[1].Connected and not added.Entries[1].Connected)
print('Currency ground/HUD passed: floor normals, blocked-position retry, no floating fallback, dedicated floor filter, late UI binding, one read-only balance listener and cleanup')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush(); subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
