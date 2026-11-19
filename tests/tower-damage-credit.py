"""Execute actual direct damage and primary accounting for blocked and partial hits."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
base=root/'Tower Defense R/ServerScriptService/TowerSystem'
damage=(base/'DirectDamage.luau').read_text();primary=(base/'PrimaryAttack.luau').read_text()
code=r'''
local function node(children)
 local n={Parent=true}
 for k,v in children or {} do n[k]=v end
 function n:FindFirstChild(k) return self[k] end
 function n:GetAttribute() return nil end
 return n
end
local Match={Capture=function() return 1 end,IsCurrent=function() return true end}
local game={ServerScriptService={EnemySystem={EnemyRuntime={Get=function() end}},Simulation={MatchService=Match}},
 ReplicatedStorage={GameModules={CombatProfiles={Resolve=function() return 'Melee' end}}}}
local require=function(m) return m end
local Direct=(function()
'''+damage+r'''
end)()
local script={Parent={DirectDamage=Direct}}
local task={spawn=function() error('unexpected task') end}
local Primary=(function()
'''+primary+r'''
end)()
local cfg=node({Damage={Value=10},TotalDamage={Value=0}})
local tower=node({Config=cfg})
local sounds=0
local stats=node({Health={Value=100},Lead={Value=true},LeadSound={Play=function() sounds+=1 end}})
local enemy=node({EnemyStats=stats})
local animations=0
local attack=Primary.new({Tower={Ammo=function() return true end,FaceTarget=function() end},Towers={},
 IsCorrupted=function() return false end,Info=node(),MobsFolder={},Effects={},
 Animate={FireAllClients=function() animations+=1 end},GetPlayers=function() return {} end})
attack(tower,nil,cfg,enemy)
assert(stats.Health.Value==100 and cfg.TotalDamage.Value==0 and sounds==1 and animations==1)
cfg.LeadDetection={Value=false};attack(tower,nil,cfg,enemy)
assert(stats.Health.Value==100 and cfg.TotalDamage.Value==0 and sounds==2)
cfg.LeadDetection.Value=true;attack(tower,nil,cfg,enemy)
assert(stats.Health.Value==90 and cfg.TotalDamage.Value==10)
stats.Health.Value=5;attack(tower,nil,cfg,enemy)
assert(stats.Health.Value==0 and cfg.TotalDamage.Value==15,'overkill inflated counter')
stats.Health.Value=100;stats.Invincible={};attack(tower,nil,cfg,enemy)
assert(stats.Health.Value==100 and cfg.TotalDamage.Value==15)
stats.Invincible=nil;stats.ShieldHealth=node({Health={Value=4}})
attack(tower,nil,cfg,enemy)
assert(stats.Health.Value==100 and stats.ShieldHealth.Health.Value==0 and cfg.TotalDamage.Value==19)
stats.Defense=node({DefenseValue={Value=1}});attack(tower,nil,cfg,enemy)
assert(stats.Health.Value==95 and cfg.TotalDamage.Value==24,'defense reduction not reflected')
stats.Defense.DefenseValue.Value=10000;attack(tower,nil,cfg,enemy)
assert(stats.Health.Value==95 and cfg.TotalDamage.Value==24,'zero-damage hit credited')
print('Tower damage credit: blocked lead/false detection, animations, invincibility, overkill, shields and reduced/zero damage passed')
'''
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau') as f:
 f.write(code);f.flush();subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True)
