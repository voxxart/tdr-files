"""Execute every real authored wave definition; stubs must not hide missing locals."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'Tower Defense R/ServerScriptService/Main/Round.luau').read_text()
a=source.index('local waveTiming='); b=source.index('local GM',a)
timing=source[a:b]
definitions=source[source.index('function round.GetEasy('):]
code='local timingSource=[====['+timing+'return waveTiming]====]\nlocal definitions=[====['+definitions+']====]\n'+r'''
local loadTiming=assert(loadstring(timingSource)); local timing=loadTiming()
local round={}
local waves,groups,quantity=0,0,0
local function spawn(name,count,cooldown,health,speed,map)
 assert(type(name)=='string' and count>0 and cooldown>=0 and health>0 and speed>0 and map)
 groups+=1; quantity+=count
end
local env=setmetatable({ReplicatedStorage={Events={FinalWave={FireAllClients=function() end}}},Color3={new=function(...) return {...} end},round=round,mob={Spawn=spawn},GM=1,info={Modifiers={NoWaveReward={Value=false}}}}, {__index=getfenv()})
-- No m/s/st or SetTextTime mocks are supplied: old inline timing writes must fail.
local init=assert(loadstring(definitions)); setfenv(init,env); init()
for mode,count in {Easy=20,Normal=26,Hard=32} do
 for wave=1,count do
  local t=assert(timing[mode][wave]); assert(t.Duration>0 and t.SkipRemaining>=0)
  local before=groups
  round['Get'..mode](wave,{})
  assert(groups>before,'authored wave must still spawn groups')
  waves+=1
 end
end
assert(timing.Easy[8].Duration==180 and timing.Easy[8].SkipRemaining==160)
assert(timing.Hard[1].Duration==60 and timing.Hard[1].SkipRemaining==45)
assert(timing.Hard[5].Duration==120 and timing.Hard[5].SkipRemaining==100)
assert(timing.Hard[32].Duration==5999)
-- Scoped spawn dispatch must also work for the actual wave definitions.
local scoped=0
round.GetHard(1,{}, {Spawn=function() scoped+=1 end}); assert(scoped==1)
print('Actual wave definitions passed: '..waves..' waves, '..groups..' enemy groups, '..quantity..' authored enemies, original timing examples and scoped dispatch')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush(); subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
