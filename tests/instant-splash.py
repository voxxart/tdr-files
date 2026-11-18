"""Execute primary attack routing: instant splash versus ordinary projectiles."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
primary=(root/'Tower Defense R/ServerScriptService/TowerSystem/PrimaryAttack.luau').read_text()
data=(root/'Tower Defense R/ReplicatedStorage/GameModules/TowerData.luau').read_text()
code='local Data=(function()\n'+data+'\nend)()\n'+r'''
local function node(children)
 local n={Parent=true}
 for k,v in children or {} do n[k]=v end
 function n:FindFirstChild(k) return self[k] end
 function n:GetAttribute(k) return nil end
 return n
end
local Match={Capture=function() return 1 end,IsCurrent=function() return true end}
local game={ServerScriptService={Simulation={MatchService=Match}}}
local script={Parent={DirectDamage={Apply=function() error('unexpected direct damage') end}}}
local require=function(m) return m end
local task={spawn=function() error('unexpected async task') end}
local Primary=(function()
'''+primary+r'''
end)()
local stats=Data.Towers.Railgunner.Upgrades[4]
assert(stats.Splash and stats.InstantSplash and stats.SplashRadius*2==1.75)
assert(not Data.Towers.Railgunner.Stats.Splash)
for i=1,3 do assert(not Data.Towers.Railgunner.Upgrades[i].Splash) end
local config=node({Damage={Value=400},Splash={Value=true},SplashRadius={Value=stats.SplashRadius},InstantSplash={Value=true},CurrentAmmo={Value=5}})
local model=node();config.Parent=model
local position={X=1,Y=2,Z=3}
local target=node({Hitbox=node({Position=position}),EnemyStats=node({Health={Value=1000}})})
local splash,projectile,animated=0,0,0
local tower={Ammo=function() return true end,FaceTarget=function() end,
 Splash=function(p,m) assert(animated==1,'effect must precede lethal damage'); assert(p==position and m==model);splash+=1 end,
 FireSplashProjectile=function() projectile+=1 end}
local attack=Primary.new({Tower=tower,Towers={},IsCorrupted=function() return false end,Info={},MobsFolder={},
 Effects={},Animate={FireAllClients=function(_,m,kind,t) assert(m==model and kind=='Attack' and t==target);animated+=1 end},GetPlayers=function() error('duplicate cash award') end})
attack(model,nil,config,target)
assert(splash==1 and projectile==0 and animated==1 and config.CurrentAmmo.Value==4)
config.InstantSplash.Value=false;animated=0
attack(model,nil,config,target)
assert(splash==1 and projectile==1 and animated==1)
config.InstantSplash=nil;animated=0
attack(model,nil,config,target)
assert(projectile==2 and animated==1)
print('Instant splash: max-level settings, immediate damage, no projectile, one animation, ammo, legacy routing passed')
'''
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau') as f:
 f.write(code);f.flush();subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True)
