"""Validate Eastern scheduling against Python zoneinfo and match-locked reward/UI state."""
from pathlib import Path
from datetime import datetime,timezone,timedelta
from zoneinfo import ZoneInfo
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
base=root/'Tower Defense R'
sources={'schedule':'ReplicatedStorage/GameModules/EXPWeekend.luau','rewards':'ServerScriptService/Simulation/MatchRewards.luau','indicator':'StarterGui/GameGui/EXPWeekendIndicator.client.luau'}
code='local sources={}\n'+''.join(f'sources.{k}=[====['+(base/v).read_text()+']====]\n' for k,v in sources.items())
eastern=ZoneInfo('America/New_York')
stamps=set()
for year in range(2025,2031):
 t=datetime(year,1,1,tzinfo=timezone.utc)
 while t.year==year:
  stamps.add(int(t.timestamp())); t+=timedelta(hours=6)
 # Check exact weekly window boundaries, and DST boundary instants.
 for month in range(1,13):
  for day in range(1,29):
   for hour in (12,20):
    local=datetime(year,month,day,hour,tzinfo=eastern)
    if (local.weekday(),hour) in ((4,12),(6,20)):
     ts=int(local.timestamp()); stamps.update((ts-1,ts,ts+1))
 for month,days,hour in ((3,range(8,15),7),(11,range(1,8),6)):
  for day in days:
   dt=datetime(year,month,day,hour,tzinfo=timezone.utc)
   if dt.weekday()==6: stamps.update((int(dt.timestamp())-1,int(dt.timestamp()),int(dt.timestamp())+1))
# Explicit match-start instants for lock tests.
start=int(datetime(2026,7,10,12,tzinfo=eastern).timestamp())
end=int(datetime(2026,7,12,20,tzinfo=eastern).timestamp())
stamps.update((start-1,start,end-1,end))
code+='local cases={\n'
for ts in sorted(stamps):
 local=datetime.fromtimestamp(ts,eastern)
 active=local.weekday()==5 or (local.weekday()==4 and local.hour>=12) or (local.weekday()==6 and local.hour<20)
 code+=f'{{{ts},{datetime.fromtimestamp(ts,timezone.utc).year},{str(active).lower()}}},\n'
code+='}\nlocal calendar={}\n'
for year in range(2025,2031):
 for month,days,hours in [(3,range(1,15),(0,7)),(11,range(1,8),(0,6))]:
  for day in days:
   for hour in hours:
    ts=int(datetime(year,month,day,hour,tzinfo=timezone.utc).timestamp())
    code+=f'calendar["{year}/{month}/{day}/{hour}"]={ts}\n'
code+=f'local windowStart,windowEnd={start},{end}\n'
code+=r'''
local years={}; for _,case in cases do years[case[1]]=case[2] end
local now=windowStart-1
local function signal()
 local s={Listeners={}}
 function s:Connect(fn) local c={Connected=true,Fn=fn}; function c:Disconnect() self.Connected=false end; table.insert(self.Listeners,c); return c end
 function s:Fire(...) for _,c in self.Listeners do if c.Connected then c.Fn(...) end end end
 return s
end
local info={Attributes={},Changed=signal()}
function info:GetAttribute(key) return self.Attributes[key] end
function info:SetAttribute(key,value) self.Attributes[key]=value; if key=='EXPWeekendActive' then self.Changed:Fire() end end
function info:GetAttributeChangedSignal(key) assert(key=='EXPWeekendActive'); return self.Changed end
local env=setmetatable({DateTime={fromUnixTimestamp=function(ts) return {ToUniversalTime=function() return {Year=assert(years[ts])} end} end,
 fromUniversalTime=function(y,m,d,h) return {UnixTimestamp=assert(calendar[y..'/'..m..'/'..d..'/'..(h or 0)])} end,
 now=function() return {UnixTimestamp=now} end},workspace={WaitForChild=function(_,name) assert(name=='Info'); return info end},
 game={ReplicatedStorage={GameModules={EXPWeekend='schedule'}}}},{__index=getfenv()})
local function execute(key) local fn=assert(loadstring(sources[key])); setfenv(fn,env); return fn() end
local Schedule=execute('schedule'); env.require=function(id) assert(id=='schedule'); return Schedule end
for _,case in cases do assert(Schedule.IsActive(case[1])==case[3],'Eastern/DST boundary mismatch at '..case[1]) end
local Rewards=execute('rewards')
Rewards.Begin(1); assert(info.Attributes.EXPWeekendActive==false and Rewards.ApplyXP(100)==100)
now=windowStart; Rewards.Begin(1); assert(Rewards.ApplyXP(100)==100,'Friday boundary or duplicate Begin cannot enable an existing match')
Rewards.Begin(2); assert(info.Attributes.EXPWeekendActive and Rewards.ApplyXP(100)==150 and Rewards.ApplyXP(3)==5)
now=windowEnd; assert(Rewards.ApplyXP(100)==150,'Sunday boundary cannot disable an eligible match')
info:SetAttribute('EXPWeekendActive',false); assert(Rewards.ApplyXP(100)==150,'reward multiplier must use private server state, not replicated presentation attributes')
Rewards.Begin(3); assert(Rewards.ApplyXP(100)==100 and not info.Attributes.EXPWeekendActive)
local gui={DescendantAdded=signal(),FindFirstChild=function(self,name) return self[name] end}
local destroying=signal(); env.script={Parent=gui,Destroying=destroying}; execute('indicator')
local indicator={Visible=true,IsA=function(_,kind) return kind=='GuiObject' end}
gui.Modifiers={FindFirstChild=function(_,name) if name=='EXPWeekend' then return indicator end end}
gui.DescendantAdded:Fire({Name='EXPWeekend'}); assert(not indicator.Visible,'authored visible badge must hide outside an eligible match')
now=windowStart; Rewards.Begin(4); assert(indicator.Visible,'late UI and future matches must follow server snapshot')
now=windowEnd; assert(indicator.Visible,'badge must remain enabled across the Sunday cutoff')
destroying:Fire(); assert(not info.Changed.Listeners[1].Connected and not gui.DescendantAdded.Listeners[1].Connected)
print('EXP weekend passed: '..#cases..' Eastern calendar/oracle checks, DST and inclusive/exclusive cutoffs, immutable match snapshots, private server multiplier, rounding, badge state and cleanup')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush(); subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
