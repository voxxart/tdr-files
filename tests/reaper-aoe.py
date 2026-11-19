"""Execute real Reaper accounting and tower AOE filtering with deterministic fixtures."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'Tower Defense R/ServerScriptService/Main/TowerServer.luau').read_text()
tracking=source[source.index('local ReaperSoulTracking ='):source.index('-- LIVE TOWER SET')]
# Trim the separator immediately before the next section.
tracking=tracking[:tracking.rfind('-- ============================================================')]
aoe=source[source.index('function tower.AOE('):source.index('-- CORE ATTACK LOGIC')]
aoe=aoe[:aoe.rfind('-- ============================================================')]
damage=(root/'Tower Defense R/ServerScriptService/UnitSystem/Damage.luau').read_text()
code=r'''
local function signal()
 local s={Callbacks={}}
 function s:Connect(f) local c={Connected=true,F=f};table.insert(self.Callbacks,c);function c:Disconnect() self.Connected=false end;return c end
 function s:Fire() for _,c in self.Callbacks do if c.Connected then c.F() end end end
 return s
end
local function node(children,value)
 local n={Children=children or {},Attributes={},Signal=signal(),Parent=true,_Value=value}
 function n:FindFirstChild(k) return self.Children[k] end
 function n:IsA(k) return k=='Model' or ((k=='NumberValue' or k=='ValueBase') and self._Value~=nil) end
 function n:GetPropertyChangedSignal() return self.Signal end
 function n:GetAttribute(k) return self.Attributes[k] end
 function n:SetAttribute(k,v) self.Attributes[k]=v end
 return setmetatable(n,{__index=function(self,k) if k=='Value' then return rawget(self,'_Value') end;return self.Children[k] end,
 __newindex=function(self,k,v) if k=='Value' then rawset(self,'_Value',v);self.Signal:Fire() else rawset(self,k,v) end end})
end
local math_max,math_min,math_clamp,math_huge=math.max,math.min,math.clamp,math.huge
local TowersWorkspace={}
'''+tracking+r'''
local total=node({},0)
local souls=node({},0)
local reaper=node({Souls=souls,SoulCollectionRate=node({},100),MaxSouls=node({},10)})
local model=node({Config=node({TotalDamage=total,Reaper=reaper})});model.Parent=TowersWorkspace
registerReaperSoulTracking(model)
local game={ServerScriptService={EnemySystem={EnemyRuntime={Get=function() end}}},GetService=function() return {GetPlayers=function() return {} end} end}
local require=function(x) return x end
local Damage=(function()
'''+damage+r'''
end)()
local unit=node({OwnerDamageValue=node({},total)})
total.Value+=60
Damage.Credit(unit,250)
assert(total.Value==310 and souls.Value==0,'summon damage earned souls')
total.Value+=40
assert(souls.Value==1,'unit damage disturbed direct remainder')
Damage.Credit(unit,1000)
assert(souls.Value==1 and total.Value==1350)
souls.Value=0
total.Value+=100
assert(souls.Value==1,'spent souls received old unit credit')
local legacy=node({OwnerTower=node({},model)})
Damage.Credit(legacy,300)
assert(total.Value==1750 and souls.Value==1,'fallback credit earned souls')
total.Value=0
total.Value+=100
assert(souls.Value==2,'reset counter stopped future direct souls')
unregisterReaperSoulTracking(model)
local vec
vec=function(x) return setmetatable({X=x},{__sub=function(a,b) return {Magnitude=math.abs(a.X-b.X)} end}) end
local tower={};local MobSet={}
'''+aoe+r'''
local function mob(flag)
 local stats=node({Health=node({},100)})
 if flag then stats.Children[flag]=node({},true) end
 return node({EnemyStats=stats,Hitbox={Position=vec(1)}})
end
local ordinary=mob();local lead=mob('Lead');local flying=mob('Flying');local hidden=mob('Hidden');local invincible=mob('Invincible')
for _,m in {ordinary,lead,flying,hidden,invincible} do MobSet[m]=true end
local cfg=node({Range=node({},10),Damage=node({},10)})
local obj=node({Config=cfg,HumanoidRootPart={Position=vec(0)}})
tower.AOE(nil,obj,10)
assert(ordinary.EnemyStats.Health.Value==90)
for _,m in {lead,flying,hidden,invincible} do assert(m.EnemyStats.Health.Value==100,'undetected AOE target damaged') end
for _,name in {'LeadDetection','FlyingDetection','HiddenDetection'} do cfg.Children[name]=node({},false) end
tower.AOE(nil,obj,10)
for _,m in {lead,flying,hidden} do assert(m.EnemyStats.Health.Value==100) end
for _,name in {'LeadDetection','FlyingDetection','HiddenDetection'} do cfg.Children[name].Value=true end
tower.AOE(nil,obj,10)
for _,m in {lead,flying,hidden} do assert(m.EnemyStats.Health.Value==90) end
assert(invincible.EnemyStats.Health.Value==100)
print('Reaper/AOE: summon credit excluded from souls, direct remainder/reset, lead/flying/hidden/invincible filtering passed')
'''
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau') as f:
 f.write(code);f.flush();subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True)
