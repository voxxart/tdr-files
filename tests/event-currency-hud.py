"""Exercise read-only balance HUD binding and silent-startup regressions."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
hud=(root/'Tower Defense R/StarterGui/GameGui/EventCurrencyBalance.client.luau').read_text()
code='local hudSource=[====['+hud+']====]\n'+r'''
local function signal()
 local s={Entries={}}
 function s:Connect(fn) local c={Connected=true,F=fn}; function c:Disconnect() self.Connected=false end; table.insert(self.Entries,c); return c end
 function s:Fire(...) for _,c in self.Entries do if c.Connected then c.F(...) end end end
 return s
end
local function node(name,class)
 local n={Name=name,Class=class,Parent=true}
 function n:FindFirstChild(key) return self[key] end
 function n:GetPropertyChangedSignal(key) assert(key=='Text'); self.TextChanged=self.TextChanged or signal(); return self.TextChanged end
 function n:GetFullName() return self.Name end
 function n:IsA(kind) return self.Class==kind end
 return n
end
local changed,added,destroy=signal(),signal(),signal()
local balance=1234
local currencyKey='Pumpkins'
local keySignal=signal()
local player={GetAttribute=function(_,key) if key=='EventCurrencyKey' then return currencyKey end; assert(key=='EventCurrencyBalance'); return balance end,
 GetAttributeChangedSignal=function(_,key) if key=='EventCurrencyKey' then return keySignal end; assert(key=='EventCurrencyBalance'); return changed end}
local gui=node('GameGui','ScreenGui'); gui.DescendantAdded=added
local deferred={}
local warnings={}
local module={EventCurrencyConfig='config',WaitForChild=function(self,key) return self[key] end}
local rep={GameModules=module,WaitForChild=function(self,key) return self[key] end}
local henv=setmetatable({game={GetService=function(_,key) if key=='ReplicatedStorage' then return rep end; assert(key=='Players','HUD must not poll RunService or invoke data remotes'); return {LocalPlayer=player} end},require=function(id) assert(id=='config'); return {CurrencyKey='Pumpkins'} end,warn=function(message) table.insert(warnings,message) end,task={defer=function(fn) fn() end,delay=function(_,fn) table.insert(deferred,fn) end},script={Parent={Name='NestedFolder'},FindFirstAncestorWhichIsA=function(_,kind) assert(kind=='ScreenGui'); return gui end,Destroying=destroy}},{__index=getfenv()})
local init=assert(loadstring(hudSource)); setfenv(init,henv); init()
gui.Settings=node('Settings','Frame'); gui.Settings.EventCurrency=node('EventCurrency','Frame'); local label=node('Amount','TextLabel'); gui.Settings.EventCurrency.Amount=label
added:Fire(label); assert(label.Text=='1,234')
label.Text='initial template text'; label.TextChanged:Fire(); assert(label.Text=='1,234','later UI initialization must not overwrite the balance')
local old=label; label=node('Amount','TextBox'); gui.Settings.EventCurrency.Amount=label; added:Fire(label); assert(label.Text=='1,234' and not old.TextChanged.Entries[1].Connected,'replacement label must rebind without leaking')
balance=6500; changed:Fire(); assert(label.Text=='6,500')
currencyKey='Other'; keySignal:Fire(); assert(label.Text=='0'); currencyKey='Pumpkins'; keySignal:Fire(); assert(label.Text=='6,500')
balance=0/0; changed:Fire(); assert(label.Text=='0')
assert(#changed.Entries==1 and #added.Entries==1)
for _,fn in deferred do fn() end; assert(#warnings==0,'valid binding must not warn')
destroy:Fire(); assert(not label.TextChanged.Entries[1].Connected); for _,fn in deferred do fn() end
 assert(not changed.Entries[1].Connected and not added.Entries[1].Connected and not keySignal.Entries[1].Connected)
-- Diagnose the two silent startup failures independently.
gui.Settings.EventCurrency.Amount=nil; table.clear(deferred); table.clear(warnings)
init(); deferred[1](); assert(#warnings==1 and warnings[1]:find('Settings.EventCurrency.Amount',1,true),'missing target must identify the exact path'); destroy:Fire()
gui.Settings.EventCurrency.Amount=label; currencyKey=nil; table.clear(deferred); table.clear(warnings)
init(); deferred[1](); assert(#warnings==1 and warnings[1]:find('no server balance',1,true),'missing replication must identify the server dependency'); destroy:Fire()
print('Currency HUD passed: configured saved-data key, late UI binding, one read-only balance listener and cleanup')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush(); subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
