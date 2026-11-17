"""Run the actual message UI block: reward hold, stale callbacks, and end-screen separation."""
from pathlib import Path
import subprocess,tempfile,re
root=Path(__file__).resolve().parents[1]
source=(root/'Tower Defense R/StarterGui/GameGui/GameController.client.luau').read_text()
a=source.index('\tlocal messageFrame =',source.index('local function LoadGui()'))
b=source.index('\n\tSetupVoteGui()',a)
hold=int(re.search(r'task.delay\((\d+)\+tweenTime',source[a:b]).group(1))
code='local hold='+str(hold)+'\nlocal source=[====['+source[a:b]+']====]\n'+r'''
local function signal()
 local s={Entries={}}
 function s:Connect(fn) local c={Connected=true,F=fn}; function c:Disconnect() self.Connected=false end; table.insert(self.Entries,c); return c end
 function s:Once(fn) local c; c=self:Connect(function(...) c:Disconnect(); fn(...) end); return c end
 function s:Fire(...) for _,c in self.Entries do if c.Connected then c.F(...) end end end
 return s
end
local now=0; local tasks={}
local function delay(dt,fn) table.insert(tasks,{At=now+dt,F=fn}) end
local function step(dt)
 now+=dt
 local again=true
 while again do
  again=false
  for i=#tasks,1,-1 do local item=tasks[i]; if item.At<=now then table.remove(tasks,i); item.F(); again=true end end
 end
end
local text={Text='authored text'}
local frame={Position=100,ActualMessage={Message=text},Visible=true}
local info={Message={Value='',Changed=signal()}}
local endCalls={}; local destroying=signal(); local tweens={}
local env=setmetatable({gui={Info={Messages=frame}},info=info,GameWrapUp=false,script={Destroying=destroying},
 UDim2={new=function() return 130 end},TweenInfo={new=function(...) return {...} end},Enum={EasingStyle={Sine=1},EasingDirection={In=1,Out=2},PlaybackState={Completed='Completed'}},
 task={delay=delay},DisplayEndScreen=function(status) table.insert(endCalls,status) end,
 TweenService={Create=function(_,object,_,goal)
  local t={Completed=signal()}; table.insert(tweens,t)
  function t:Play() object.Position=goal.Position end
  function t:Cancel() self.Cancelled=true; self.Completed:Fire('Cancelled') end
  return t
 end}},{__index=getfenv()})
local init=assert(loadstring(source)); setfenv(init,env); init()
local function message(value) info.Message.Value=value; info.Message.Changed:Fire(value) end
assert(not frame.Visible and text.Text=='')
message('Waiting for players'); assert(not frame.Visible)
message('Wave Reward: $100'); message('$100 Other Bonus'); message('+$100 Wave Bonus'); assert(not frame.Visible,'unrelated messages must remain hidden')
message('$100 Wave Bonus'); assert(frame.Visible and text.Text=='$100 Wave Bonus')
step(1); message(''); assert(frame.Visible and text.Text=='$100 Wave Bonus','server clear must not erase the client reward')
message('TRIUMPH'); message('YOU LOSE'); assert(text.Text=='$100 Wave Bonus' and #endCalls==0)
step(hold-0.7); assert(frame.Visible and #tweens==1,'reward must last through the configured hold')
step(0.11); local oldOutro=tweens[#tweens]; assert(#tweens==2)
message('$200 Wave Bonus'); assert(frame.Visible and text.Text=='$200 Wave Bonus')
oldOutro.Completed:Fire('Completed'); assert(frame.Visible,'stale outro must not hide a new reward')
step(2); message('$300 Wave Bonus'); local before=#tweens
step(hold-1.5); assert(#tweens==before and frame.Visible,'stale delayed timeout must not hide a new reward')
step(2); local outro=tweens[#tweens]; outro.Completed:Fire('Completed'); assert(not frame.Visible)
message('VICTORY'); assert(#endCalls==1 and endCalls[1]=='VICTORY' and not frame.Visible and text.Text=='')
env.GameWrapUp=true; message('VICTORY'); message('GAME OVER'); assert(#endCalls==1,'duplicate result updates must not open the end screen again')
env.GameWrapUp=false; message('GAME OVER'); assert(endCalls[2]=='GAME OVER' and not frame.Visible)
message('$1,250 Wave Bonus'); assert(frame.Visible and text.Text=='$1,250 Wave Bonus','formatted amounts must work'); destroying:Fire(); local count=#tweens; step(20); assert(#tweens==count and not info.Message.Changed.Entries[1].Connected)
print('Reward banner passed: reward-only filtering, configured hold, server clears ignored, stale tween/timer protection, end-screen separation and cleanup')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush(); subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
