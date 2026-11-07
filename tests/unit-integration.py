"""Actual unit modules exercised with deterministic Roblox boundary fixtures."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
def literal(text):
    eq=''
    while ']'+eq+']' in text: eq+='='
    return '['+eq+'['+text+']'+eq+']'
paths={
    'runtime':'ServerScriptService/UnitSystem/Runtime.luau',
    'motion':'ServerScriptService/Simulation/UnitMotion.luau',
    'damage':'ServerScriptService/UnitSystem/Damage.luau',
    'death':'ServerScriptService/UnitSystem/Death.luau',
    'service':'ServerScriptService/UnitSystem/Service.luau',
    'combat':'ServerScriptService/UnitSystem/Combat.luau',
    'behaviors':'ServerScriptService/UnitSystem/Behaviors.luau',
}
code='local sources={'+','.join(k+'='+literal((root/'Tower Defense R'/v).read_text()) for k,v in paths.items())+'}\n'+r'''
local function node(fields)
    fields=fields or {}; fields.Parent=if fields.Parent==nil then true else fields.Parent
    fields.Attributes={}
    function fields:FindFirstChild(key) return self[key] end
    function fields:WaitForChild(key) assert(self[key],key); return self[key] end
    function fields:GetAttribute(key) return self.Attributes[key] end
    function fields:SetAttribute(key,value) self.Attributes[key]=value end
    function fields:IsA(class) return class==self.Class or class=='ValueBase' and self.Value~=nil end
    function fields:Destroy() self.Parent=nil end
    function fields:GetDescendants() return {} end
    function fields:PivotTo(frame) self.PrimaryPart.CFrame=frame end
    function fields:GetChildren() return {} end
    return fields
end
local function vec(x,y,z)
    return setmetatable({X=x,Y=y,Z=z},{
        __add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end,
        __sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end,
        __index=function(a,key)
            if key=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
        end,
    })
end
local events=node({})
local emissions={}
for _,name in {'UnitDeath','UnitStopAttack','RotateTorso','UnitPresentation','AnimateUnit','AnimateUnit2'} do
    events[name]={FireAllClients=function() emissions[name]=(emissions[name] or 0)+1 end}
end
events.UnitSnapshot=node({Class='RemoteFunction'})
local definitions={Settings={PositionHz=30,AlphaHz=10},Units={}}
local now,valid,generation=0,true,1
local Match={Capture=function() return generation end,Now=function() return now end,IsCurrent=function(g) return valid and g==generation end}
local listeners={}
local heartbeat={Connect=function(_,callback) table.insert(listeners,callback) end}
local rep={Events=events,GameModules={UnitDefinitions='definitions'}}
local players={node({Cash=node({Value=0})})}
local chosen,spatialList=nil,{}
local enemyRecords={}
local enemyRuntime={Get=function(model) return enemyRecords[model] end}
local spatial={Visit=function(_,_,callback) for _,model in spatialList do callback(model) end end}
local modules={match=Match,definitions=definitions,enemyRuntime=enemyRuntime,spatial=spatial,
    targeting={Find=function() return chosen end}}
local info=node({GameSpeed={Value=1},EnemyInGame=node({Value=0})})
local workspace={Info=info,Mobs=node({})}
local moved=0
function workspace:WaitForChild(key) return self[key] end
function workspace:BulkMoveTo(parts,frames)
    moved+=#parts
    for i,part in parts do part.CFrame=frames[i] end
end
local warnings=0
local environment=setmetatable({
    warn=function() warnings+=1 end,
    game={ServerScriptService={Simulation={MatchService='match',UnitMotion='motion'},EnemySystem={EnemyRuntime='enemyRuntime'},TowerSystem={Targeting='spatial'}},
        GetService=function(_,name)
            if name=='ReplicatedStorage' then return rep end
            if name=='RunService' then return {Heartbeat=heartbeat} end
            if name=='Players' then return {GetPlayers=function() return players end} end
            error(name)
        end},
    script={Parent={Runtime='runtime',Paths='paths',Combat='combat',Death='death',Behaviors='behaviors',Damage='damage',Targeting='targeting'}},
    workspace=workspace,Vector3={new=vec,zero=vec(0,0,0)},Enum={BulkMoveMode={FireCFrameChanged=1}},
    require=function(id) assert(modules[id],id); return modules[id] end,
},{__index=getfenv()})
local function load(name)
    local fn=assert(loadstring(sources[name],name)); setfenv(fn,environment); return fn()
end
modules.runtime=load('runtime'); modules.motion=load('motion'); modules.damage=load('damage'); modules.behaviors=load('behaviors')
modules.paths={Sample=function(_,alpha) return vec(alpha*100,0,0) end}
modules.death=load('death')
local realCombat=load('combat')
local steps=0
modules.combat={Step=function() steps+=1 end,Ram=function() end}
local service=load('service')
local function unit(name)
    return node({Name=name,PrimaryPart={Size={Y=2},CFrame=vec(0,0,0)},
        EnemyStats=node({Health=node({Value=100}),MaxHealth=node({Value=100}),Speed=node({Value=10}),HipHeight={Value=1}}),
        Hitbox=node({Position=vec(0,0,0),CFrame=vec(0,0,0)}),Alpha=node({Value=0})})
end
local model=unit('Test')
info.EnemyInGame.Value=1
local path={Id='path',Length=100,Positions={vec(0,0,0),vec(100,0,0)}}
local data=service.Move(model,{},path,100,vec(0,0,0))
assert(service.Move(model,{},path,100,vec(0,0,0))==data)
local function tick(dt)
    now+=dt*info.GameSpeed.Value
    for _,callback in listeners do callback(dt) end
end
tick(0.1)
assert(math.abs(data.Alpha-0.01)<0.0001 and moved==1 and steps==1)
info.GameSpeed.Value=0; tick(1)
assert(math.abs(data.Alpha-0.01)<0.0001 and steps==1)
info.GameSpeed.Value=2; tick(0.1)
assert(math.abs(data.Alpha-0.03)<0.0001)
local snapshot=events.UnitSnapshot.OnServerInvoke({})
assert(#snapshot.Units==1 and snapshot.Paths.path==path.Positions)
valid=false; tick(0.1)
assert(modules.runtime.Get(model)==nil and model.Parent==nil and info.EnemyInGame.Value==0)
tick(0.1); assert(info.EnemyInGame.Value==0)
valid=true; generation=2
local second=unit('Second'); info.EnemyInGame.Value=1
service.Move(second,{},path,0.001,vec(0,0,0)); tick(1)
assert(second.Parent==nil and info.EnemyInGame.Value==0, 'Path completion must despawn once')
definitions.Units.Looper={EndBehavior='Loop'}
local looper=unit('Looper'); info.EnemyInGame.Value=1
local loopData=service.Move(looper,{},path,1,vec(0,0,0)); tick(0.1)
assert(modules.runtime.Get(looper)==loopData and loopData.Alpha==0 and info.EnemyInGame.Value==1)
valid=false; tick(0.1); assert(info.EnemyInGame.Value==0); valid=true
-- Animated death keeps only the presentation rig, follows game time and counts once.
local deaths=0
modules.behaviors.Death.Custom=function() deaths+=1 end
definitions.Units.Dying={Death={Behavior='Custom',Animation='Fade',Duration=2,Explode=false}}
local dying=unit('Dying'); dying.DeathEffects=node({Class='Folder'})
info.GameSpeed.Value=1; info.EnemyInGame.Value=1
service.Move(dying,{},path,100,vec(0,0,0))
dying.EnemyStats.Health.Value=0; tick(0.1)
assert(deaths==1 and info.EnemyInGame.Value==0 and dying.Parent~=nil and modules.runtime.Get(dying)==nil)
assert(dying:GetAttribute('UnitDeathAnimation')=='Fade')
info.GameSpeed.Value=0; tick(10)
assert(dying.Parent~=nil, 'Paused death presentation must not expire in real time')
info.GameSpeed.Value=1; tick(2)
assert(dying.Parent==nil and deaths==1 and info.EnemyInGame.Value==0)
local originalStep=modules.combat.Step
modules.combat.Step=function(data)
    if data.Model.Name=='Bad' then error('fixture failure') end
    originalStep(data)
end
local bad,good=unit('Bad'),unit('Good'); info.EnemyInGame.Value=2
service.Move(bad,{},path,100,vec(0,0,0)); service.Move(good,{},path,100,vec(0,0,0))
tick(0.1)
assert(bad.Parent==nil and good.Parent~=nil and info.EnemyInGame.Value==1 and warnings==1)
valid=false; tick(0.1); valid=true
assert(info.EnemyInGame.Value==0)
modules.combat.Step=originalStep
-- Real combat/damage preserves cash, shields, reciprocal ram and facing semantics.
local attacker=unit('Combat'); attacker.Config=node({Range={Value=12},Damage={Value=10},Cooldown={Value=1}})
local credit=node({Value=0}); attacker.OwnerDamageValue={Value=credit}
local enemy=node({EnemyStats=node({Health=node({Value=100}),MaxHealth=node({Value=100})}),Hitbox=node({Position=vec(1,0,0)})})
enemy.EnemyStats.Parent=enemy; enemyRecords[enemy]={}
chosen=enemy; spatialList={enemy}
local combatData={Model=attacker,Health=attacker.EnemyStats.Health,Stats=attacker.EnemyStats,Hitbox=attacker.Hitbox,
    Config=attacker.Config,Definition={DamageType='Bullet'},Attacks=true,NoStop=true,NextPrimary=0,NextSecondary=100,Cleaned=false}
realCombat.Step(combatData,0)
assert(enemy.EnemyStats.Health.Value==90 and credit.Value==10 and players[1].Cash.Value==4)
assert(enemyRecords[enemy].LastDamageType=='Bullet')
realCombat.Step(combatData,0.5); assert(enemy.EnemyStats.Health.Value==90)
enemy.EnemyStats.ShieldHealth=node({Health=node({Value=5})})
realCombat.Step(combatData,1)
assert(enemy.EnemyStats.Health.Value==90 and enemy.EnemyStats.ShieldHealth.Health.Value==0 and credit.Value==15)
local blast=node({EnemyStats=node({Health=node({Value=50}),ExplosionDefense=node({DefenseValue={Value=1}})}),Hitbox=node({Position=vec(1,0,0)})})
blast.EnemyStats.Parent=blast; enemyRecords[blast]={}; chosen=blast; spatialList={blast}
local secondary=unit('Secondary'); secondary.Config=node({SecondaryAttack=node({Range={Value=10},Damage={Value=20},Cooldown={Value=2},SplashRadius={Value=3}})})
local secondaryData={Model=secondary,Health=secondary.EnemyStats.Health,Hitbox=secondary.Hitbox,Config=secondary.Config,
    Definition={},Attacks=false,NextPrimary=0,NextSecondary=0,Cleaned=false}
realCombat.Step(secondaryData,2); realCombat.Step(secondaryData,3)
assert(blast.EnemyStats.Health.Value==40 and enemyRecords[blast].LastDamageType=='Explosion')
chosen=enemy; spatialList={enemy}
local finished=0
realCombat.Ram(combatData,function() finished+=1 end)
assert(enemy.EnemyStats.Health.Value==0 and combatData.Health.Value==10 and finished==0)
local other=node({EnemyStats=node({Health=node({Value=100})}),Hitbox=node({Position=vec(1,0,0)})})
spatialList={other}
realCombat.Ram(combatData,function(_,died,ram) assert(died and ram); finished+=1 end)
assert(combatData.Health.Value==0 and other.EnemyStats.Health.Value==90 and finished==1)
assert(enemy.Parent~=nil, 'Unit combat must leave enemy destruction/counting to EnemyService')
print('Unit integration checks passed: shared movement, pause/speed, snapshot, match cleanup, path end, damage, shields, ram, ownership')
'''
with tempfile.TemporaryDirectory() as directory:
    file=Path(directory)/'unit-integration.luau'; file.write_text(code)
    subprocess.run(['/workspace/tools/luau-0.745/luau',str(file)],check=True,cwd=root)
