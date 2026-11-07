"""Execute real engine-facing modules with a small Luau dependency fixture.
This catches extraction/wiring errors; it does not emulate Roblox gameplay.
"""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
def literal(source):
    for level in range(10):
        eq = '=' * level
        if ']' + eq + ']' not in source:
            return '[' + eq + '[' + source + ']' + eq + ']'
    raise ValueError('No long-string delimiter')
modules = {name: (root / path).read_text() for name, path in {
    'scheduler': 'Tower Defense R/ServerScriptService/TowerSystem/CombatScheduler.luau',
    'damage': 'Tower Defense R/ServerScriptService/TowerSystem/DirectDamage.luau',
    'primary': 'Tower Defense R/ServerScriptService/TowerSystem/PrimaryAttack.luau',
    'projectiles': 'Tower Defense R/ServerScriptService/TowerSystem/ProjectileService.luau',
    'profiles': 'Tower Defense R/ReplicatedStorage/GameModules/CombatProfiles.luau',
    'secondary': 'Tower Defense R/ServerScriptService/TowerSystem/SecondaryAttack.luau',
    'burst': 'Tower Defense R/ServerScriptService/TowerSystem/BurstAttack.luau',
}.items()}
prefix = 'local sources = {\n' + ''.join(f'{name} = {literal(text)},\n' for name,text in modules.items()) + '}\n'
fixture = r'''
local function node(fields)
    fields = fields or {}
    function fields:FindFirstChild(name) return self[name] end
    function fields:GetAttribute() return nil end
    return fields
end
local now, valid = 0, true
local queued, delayed, cleanup = {}, {}, {}
local Match = {
    Now = function() return now end,
    Capture = function() return 1 end,
    IsCurrent = function(g) return valid and g == 1 end,
    Wait = function(_, _, active) return valid and (not active or active()) end,
    After = function(_, seconds, callback)
        local record = {Seconds=seconds,Callback=callback}
        table.insert(delayed,record)
        return function() record.Cancelled = true end
    end,
}
local runtime = {State={},Cleanup={Add=function(_,fn) table.insert(cleanup,fn) end}}
local Runtime = {Get=function() return runtime end}
local dependency = {match=Match, runtime=Runtime}
local workspace = {Info={GameSpeed={Value=1}}}
local environment = setmetatable({
    game={ServerScriptService={Simulation={MatchService='match'},EnemySystem={EnemyRuntime='runtime'}},
        ReplicatedStorage={GameModules={CombatProfiles='profiles'}}},
    workspace=workspace,
    script={Parent={DirectDamage='damage',TowerRuntime='runtime'}},
    task={spawn=function(fn) table.insert(queued,fn) end,wait=function() end},
    require=function(id) assert(dependency[id], id); return dependency[id] end,
}, {__index=getfenv()})
local function load(name)
    local fn=assert(loadstring(sources[name], name))
    setfenv(fn,environment)
    return fn()
end
dependency.profiles=load('profiles')
dependency.damage=load('damage')
local config=node({Parent=true,Damage={Value=10},DamageType={Value='Bullet'},Range={Value=12},Cooldown={Value=1}})
local model=node({Parent=true,Config=config})
local stats=node({Health={Value=100},MaxHealth={Value=100}})
local target=node({Parent=true,EnemyStats=stats})
local data={config=config,MatchGeneration=1}
local towers={[model]=data}
local cash={Value=0}
local player=node({Cash=cash})
local animations=0
local tower={Ammo=function() return true end,FaceTarget=function() end}
tower.DoAttackLogic=load('primary').new({
    Tower=tower,Towers=towers,IsCorrupted=function() return false end,
    Info=node({}),MobsFolder={},Effects={},
    Animate={FireAllClients=function() animations+=1 end},
    GetPlayers=function() return {player} end,
})
tower.DoAttackLogic(model,player,config,target)
assert(stats.Health.Value==90 and cash.Value==6 and animations==1)
assert(runtime.LastDamageType=='Bullet')
stats.ShieldHealth=node({Health={Value=5}})
tower.DoAttackLogic(model,player,config,target)
assert(stats.ShieldHealth.Health.Value==0 and stats.Health.Value==90 and cash.Value==6)
stats.Health.Value=0
tower.DoAttackLogic(model,player,config,target)
assert(cash.Value==6 and animations==2, 'Dead targets must not consume shots or reward cash')
stats.Health.Value=100
local attacks,cancelled=0,0
tower.FindTarget=function() return target end
tower.DoAttackLogic=function() attacks+=1 end
local scheduler=load('scheduler').new({Tower=tower,Towers=towers,Projectiles={Cancel=function() cancelled+=1 end}})
scheduler:Step(); scheduler:Step()
assert(#queued==1, 'Yielding primary work must not overlap')
queued[1](); table.clear(queued)
assert(attacks==1)
now=0.5; scheduler:Step(); assert(#queued==0)
config.Health=node({HealthValue={Value=0},MaxHealth={Value=100}})
now=1; scheduler:Step(); assert(#queued==0, 'Zero-health templates must not attack until placement initializes health')
config.Health.HealthValue.Value=config.Health.MaxHealth.Value

now=1; workspace.Info.GameSpeed.Value=0; scheduler:Step(); assert(#queued==0)
workspace.Info.GameSpeed.Value=1; scheduler:Step(); assert(#queued==1)
queued[1](); table.clear(queued)
valid=false; scheduler:Step()
assert(towers[model]==nil and cancelled==2)
valid=true
local position=setmetatable({}, {__sub=function() return {Magnitude=10} end})
target.Hitbox={Position=position}
model.HumanoidRootPart={Position=position}
local laserCount = 0
local presentation = {IsA=function(_, kind) return kind == 'RemoteEvent' end,
    FireAllClients=function(_, kind) assert(kind == 'Laser'); laserCount += 1 end}
local rep = {Events=node({TowerPresentation=presentation}),Particle={}}
function environment.game:GetService(name)
    if name == 'ReplicatedStorage' then return rep end
    if name == 'Debris' then return {} end
    error(name)
end
model.Head={Position=position}
towers[model]=data
local secondary=node({Type={Value='Laser'},Range={Value=20},Damage={Value=5}})
load('secondary').new({Tower=tower,Towers=towers,IsCorrupted=function() return false end,MobSet={}})(model,player,config,secondary)
assert(stats.Health.Value == 95 and laserCount == 1, 'Secondary laser must damage on server and emit client presentation')
local burst=load('burst').new({Tower=tower,Towers=towers})
config.MaxBurst={Value=3}
burst(model,target); burst(model,target)
assert(#queued==1 and data.isBursting, 'Burst registration must prevent overlapping work')
local before=attacks
queued[1](); table.clear(queued)
assert(attacks==before+3 and not data.isBursting)
burst(model,target)
valid=false
queued[1](); table.clear(queued)
assert(attacks==before+3 and not data.isBursting, 'Cancelled burst must release busy state without shots')
valid=true
local projectiles=load('projectiles')
local emitted,impacts=0,0
local function launch()
    projectiles.Launch(model,target,config,function() emitted+=1 end,function() impacts+=1 end)
end
launch(); launch()
assert(emitted==2 and #cleanup==1 and #delayed==2, 'Projectile cleanup registration must be bounded')
assert(delayed[1].Seconds==0.2)
projectiles.Cancel(model)
assert(delayed[1].Cancelled and delayed[2].Cancelled and next(runtime.State.Projectiles)==nil)
launch(); delayed[3].Callback()
assert(impacts==1 and next(runtime.State.Projectiles)==nil)
launch(); cleanup[1]()
assert(delayed[4].Cancelled)
print('Tower integration checks passed: primary damage/cash/shields, scheduling, pause, match end, projectile ownership')
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / 'tower-integration.luau'
    path.write_text(prefix + fixture)
    subprocess.run(['/workspace/tools/luau-0.745/luau',str(path)],check=True,cwd=root)
