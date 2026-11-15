"""Exercise actual Round.StartGame with WaveService using a deterministic game-clock scheduler."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]; base=root/'Tower Defense R'
round_source=(base/'ServerScriptService/Main/Round.luau').read_text()
a=round_source.index('function round.StartGame()'); b=round_source.index('\nfunction round.LoadMap()',a)
# Shorten only the number of waves for the fixture, retaining the actual round controller.
start=round_source[a:b].replace('waves = 20','waves = 2')
code='local sources={}\n'
for key,path in [('state','ServerScriptService/Simulation/WaveState.luau'),('service','ServerScriptService/Simulation/WaveService.luau')]:
 code+=f'sources.{key}=[====['+(base/path).read_text()+']====]\n'
code+='sources.round=[====['+start+']====]\n'+r'''
local function signal()
 local s={Functions={}}; function s:Connect(fn) table.insert(self.Functions,fn) end
 function s:Fire(...) for _,fn in self.Functions do fn(...) end end
 return s
end
local function node(values)
 values=values or {}; values.Attributes={}; values.Parent=true
 function values:FindFirstChild(name) return self[name] end
 function values:WaitForChild(name) return assert(self[name],name) end
 function values:GetAttribute(name) return self.Attributes[name] end
 function values:SetAttribute(name,value) self.Attributes[name]=value end
 function values:IsA(kind) return kind=='NumberValue' end
 return values
end
local now,generation=0,0
local tasks={}; local failures={}
local info=node({})
for key,value in {GameRunning=false,Message='',Wave=0,Timer='',Min=0,Sec=5,SkipTime=90,VoteSkipValue=0,GameSpeed=1,Gamemode='Easy'} do info[key]={Value=value} end
info.Modifiers={['Death Wish']={Value=false},NoWaveReward={Value=false}}
local roster={node({UserId=1,Cash=node({Value=0})}),node({UserId=2,Cash=node({Value=0})}),node({UserId=3,Cash=node({Value=0})})}
local players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return roster end}
local match={}
function match.Begin() generation+=1; info.GameRunning.Value=true; return generation end
function match.Capture() return generation end
function match.IsCurrent(g) return g==generation and info.GameRunning.Value and info.Message.Value~='VICTORY' and info.Message.Value~='GAME OVER' end
function match.Now() return now end
function match.Wait(g,seconds)
 local deadline=now+seconds
 repeat coroutine.yield(deadline) until not match.IsCurrent(g) or now>=deadline
 return match.IsCurrent(g)
end
local world={Info=info,Mobs={GetChildren=function() return {} end,ChildAdded=signal(),ChildRemoved=signal()},Map={FindFirstChildOfClass=function() return nil end}}
function world:WaitForChild(name) return self[name] end
local events={}
for _,name in {'SkipButton','SetTextTime','SkipWaveHide'} do events[name]={FireAllClients=function() end} end
local dependencies={match=match}
local env=setmetatable({workspace=world,game={GetService=function(_,name) if name=='Players' then return players else assert(name=='ReplicatedStorage'); return {Events=events} end end},
 script={Parent={MatchService='match',WaveState='state'}},require=function(key) return assert(dependencies[key],key) end,
 task={spawn=function(fn) table.insert(tasks,{Co=coroutine.create(fn),Deadline=now}) end},warn=function(...) table.insert(failures,{...}) end},{__index=getfenv()})
local function load(key) local fn=assert(loadstring(sources[key])); setfenv(fn,env); return fn() end
dependencies.state=load('state'); local Waves=load('service')
local counts={}; local started={}; local completed=0
local map={}; local round={LoadMap=function() return map end,LoadMode=function() return 'Easy' end}
local mob={ArrowSpawn=function() end}
function mob.Spawn(name,quantity,cooldown)
 local g=generation
 for _=1,quantity do
  if not match.Wait(g,cooldown) then return end
  counts[name]=(counts[name] or 0)+1
 end
end
function round.GetEasy(wave,_,scopedMob)
 started[wave]=now
 -- Multiple sequential groups ensure old tasks cannot accidentally spawn into a new match.
 scopedMob.Spawn('Wave'..wave,2,4)
 scopedMob.Spawn('Wave'..wave,2,4)
end
local starter={GameGui={Sounds={Countdown={Play=function() end}}}}
local roundEnv=setmetatable({round=round,info=info,Match=match,Waves=Waves,Players=players,mob=mob,workspace=world,
 EventCurrency={BeginMatch=function() end,CompleteVictory=function() completed+=1 end},ServerStorage={Modes={FindFirstChild=function() return {WaveReward={Value=100},RewardMultiplier={Value=10}} end}},
 events=events,game={StarterGui=starter,GetService=function(_,name) if name=='Players' then return players end; assert(name=='BadgeService'); return {UserHasBadgeAsync=function() return true end} end}}, {__index=env})
local init=assert(loadstring(sources.round)); setfenv(init,roundEnv); init()
local function tick(dt)
 now+=dt*info.GameSpeed.Value
 Waves.Step()
 local length=#tasks
 for index=1,length do
  local task=tasks[index]
  if coroutine.status(task.Co)~='dead' and now+1e-7>=task.Deadline then
   local ok,deadline=coroutine.resume(task.Co); assert(ok,deadline); task.Deadline=deadline or now
  end
 end
end
local function untilTrue(predicate,limit)
 for _=1,limit or 1000 do if predicate() then return end; tick(0.05) end
 error('scheduler timeout')
end
env.task.spawn(round.StartGame)
untilTrue(function() return info.Wave.Value==1 end)
assert(Waves.Pending==1 and not counts.Wave1)
assert(Waves.Vote(roster[1],1) and not Waves.State.Skipped)
assert(not Waves.Vote(roster[1],1) and not Waves.Vote(roster[2],0))
assert(Waves.Vote(roster[2],1) and Waves.State.Skipped)
untilTrue(function() return info.Wave.Value==2 end,10)
assert(now-started[1]<0.2 and Waves.Pending==2 and not counts.Wave1,'next wave must start immediately while the previous wave has not spawned its enemies')
assert(info.VoteSkipValue.Value==0 and not Waves.Vote(roster[1],1) and not Waves.Vote(roster[1],2),'final-wave and stale votes must be rejected')
for _,p in roster do assert(p.Cash.Value==70,'skipped wave reward is granted once') end
local pausedAt=now; info.GameSpeed.Value=0
for _=1,20 do tick(0.05) end
assert(now==pausedAt and not counts.Wave1 and completed==0,'pause must freeze both overlapping spawn jobs')
info.GameSpeed.Value=1
untilTrue(function() return now>=started[2]+7 end)
assert(info.Min.Value==0 and info.Sec.Value==0 and completed==0,'final timer expiry and empty map must not beat queued spawns')
untilTrue(function() return info.Message.Value=='VICTORY' end)
assert(counts.Wave1==4 and counts.Wave2==4 and completed==1 and Waves.Pending==0 and not Waves.State.Active and #failures==0)
-- Old-generation spawn workers must not alter the new match's pending count.
info.Message.Value=''; generation+=1; info.GameRunning.Value=true
local old=generation; Waves.Begin(1,old,false)
Waves.Spawn(old,function() if match.Wait(old,10) then error('old spawn continued') end end)
tick(0.05); generation+=1; Waves.Begin(1,generation,false)
assert(Waves.Pending==0)
tick(11); assert(Waves.Pending==0 and #failures==0)
print('Wave overlap passed: actual round starts next wave mid-spawn, preserves all groups, per-wave votes, reward once, pause, final-wave completion and old-generation isolation')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush(); subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
