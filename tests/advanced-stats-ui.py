"""Execute the actual pooled dropdown renderer and metadata reader with engine mocks."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
paths=['Tower Defense R/ReplicatedStorage/GameModules/AdvancedStatsUI.luau','Tower Defense R/ReplicatedStorage/GameModules/AdvancedStatsData.luau','Tower Defense R/ServerScriptService/TowerSystem/TowerStats.luau']
code='\n'.join('local source'+str(i)+'=[====['+(root/p).read_text()+']====]' for i,p in enumerate(paths))+r'''
local function signal()
 local s={Callbacks={}}
 function s:Connect(fn)
  local c={Connected=true}; function c:Disconnect() self.Connected=false end
  table.insert(self.Callbacks,{C=c,F=fn}); return c
 end
 function s:Fire(...) for _,entry in self.Callbacks do if entry.C.Connected then entry.F(...) end end end
 return s
end
local objects=0
local function node(class)
 objects+=1
 local n={Name=class,Class=class,Children={},Signals={},Activated=signal(),Visible=true,AnchorPoint={X=0,Y=0},AbsoluteSize={Y=1000},AbsoluteCanvasSize={Y=1000},AbsoluteContentSize={Y=100},Scale=1}
 local mt={}
 mt.__index=function(self,key)
  if key=='Parent' then return rawget(self,'_Parent') end
  return rawget(self,key) or self.Children[key]
 end
 mt.__newindex=function(self,key,value)
  if key=='Parent' then
   local old=rawget(self,'_Parent'); if old then old.Children[self.Name]=nil end
   rawset(self,'_Parent',value); if value then value.Children[self.Name]=self end
  else rawset(self,key,value) end
 end
 setmetatable(n,mt)
 function n:IsA(kind) return self.Class==kind or kind=='GuiObject' and (self.Class=='Frame' or self.Class=='ScrollingFrame' or self.Class=='TextLabel' or self.Class=='TextButton') end
 function n:GetChildren() local list={} for _,child in self.Children do table.insert(list,child) end return list end
 function n:FindFirstChild(key) return self.Children[key] end
 function n:WaitForChild(key) return assert(self.Children[key],key) end
 function n:FindFirstChildOfClass(kind) for _,c in self.Children do if c.Class==kind then return c end end end
 function n:GetPropertyChangedSignal(key) if not self.Signals[key] then self.Signals[key]=signal() end; return self.Signals[key] end
 function n:Destroy() self.Parent=nil; self.Destroyed=true end
 function n:Clone()
  local copy=node(self.Class)
  for key,value in pairs(self) do
   if type(value)~='function' and key~='Children' and key~='Signals' and key~='Activated' and key~='_Parent' then copy[key]=value end
  end
  for _,child in self.Children do local cloned=child:Clone(); cloned.Parent=copy end
  return copy
 end
 return n
end
local function dim(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end
local tweenService={Create=function(_,target,info,goal)
 local t={Target=target,Goal=goal}
 function t:Play() self.Played=true end
 function t:Cancel() self.Cancelled=true end
 function t:Finish() if not self.Cancelled then for k,v in goal do target[k]=v end end end
 return t
end}
local env=setmetatable({Instance={new=node},script={Parent={AdvancedStatsData='data'}},
 game={GetService=function() return tweenService end},
 UDim2={new=dim,fromOffset=function(x,y) return dim(0,x,0,y) end},UDim={new=function(a,b) return {Scale=a,Offset=b} end},
 Vector2={new=function(x,y) return {X=x,Y=y} end},Color3={fromRGB=function(...) return {...} end},
 Enum={ApplyStrokeMode={Border=1},AutomaticSize={Y=1,None=0},SortOrder={LayoutOrder=1},Font={Gotham=1,GothamBold=2},TextXAlignment={Left=1},TextYAlignment={Top=1},EasingStyle={Quart=1,Quad=2},EasingDirection={Out=1}},
 TweenInfo={new=function(...) return {...} end}},{__index=getfenv()})
local data=assert(loadstring(source1))()
env.require=function(id) assert(id=='data'); return data end
local chunk=assert(loadstring(source0)); setfenv(chunk,env); local UI=chunk()
local host=node('ScrollingFrame'); host.Name='Main'; host.AutomaticCanvasSize=0
local ui=UI.new(host)
assert(ui.Template.Name=='AdvancedStatsTemplate' and not ui.Template.Visible)
local def={Upgrades={[1]={AdvancedStats1={Title='Abilities',One='First',Nine='Last'},AdvancedStats2={Title='Second',Two='Middle'}},[2]={}}}
local identity={}
ui:ShowLevel(def,1,identity)
assert(#ui.Records==2 and ui.Records[1].Frame.Visible)
local record=ui.Records[1]
assert(not record.Frame:FindFirstChildOfClass('UIStroke') and record.Header:FindFirstChildOfClass('UIStroke'),'outline must belong to fixed header')
assert(record.Header.Title.Text=='Abilities' and record.Body.One.Visible and record.Body.Nine.Visible and not record.Body.Two.Visible)
record.Header.Activated:Fire(); assert(record.Open and record.Tween.Goal.Size.Y.Scale==0.095 and record.Tween.Goal.Size.Y.Offset==116)
local headerHeight=record.Header.Size.Y.Offset
record.Tween:Finish(); assert(record.Header.Size.Y.Offset==headerHeight,'opening must not stretch outlined header')
local opening=record.Tween; record.Header.Activated:Fire()
assert(not record.Open and opening.Cancelled and record.Tween.Goal.Size.Y.Scale==0.095 and record.Tween.Goal.Size.Y.Offset==0)
record.Header.Activated:Fire(); record.Tween:Finish()
record.Body:FindFirstChildOfClass('UIListLayout').AbsoluteContentSize={Y=220}
record.Body:FindFirstChildOfClass('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Fire()
assert(record.Tween.Goal.Size.Y.Offset==236,'wrapping/content changes must resize open groups')
local count=objects; ui:ShowLevel(def,1,identity); assert(objects==count and record.Open,'same selection preserves open state')
ui:ShowLevel(def,2,identity); assert(not record.Frame.Visible and not record.Open)
ui:ShowLevel(def,1,{}); assert(objects==count and not record.Open,'records must be pooled')
local template=ui.Template
ui:Destroy(); assert(template.Destroyed and record.Frame.Destroyed and host.AutomaticCanvasSize==0)
for _,c in record.Header.Activated.Callbacks do assert(not c.C.Connected) end
-- An authored template is reused and kept on cleanup.
local custom=template:Clone(); custom.Destroyed=nil; custom.Parent=host
custom.Size=dim(0.924,0,0.095,0)
custom.Toggle.Size=dim(1,0,1,0)
custom.Content.AnchorPoint={X=0.5,Y=0.5}
custom.Content.Position=dim(0.5,0,0.5,0)
custom.Content.Size=dim(1,0,0,0)
local reused=UI.new(host); assert(reused.Template==custom and not reused.OwnTemplate)
assert(host.AutomaticCanvasSize==0,'Main canvas setting must remain authored')
reused:ShowLevel(def,1,{})
local scaled=reused.Records[1]
assert(scaled.Frame.Size.X.Scale==0.924 and scaled.Frame.Size.Y.Scale==0.095 and scaled.Frame.Size.Y.Offset==0 and scaled.Frame.Parent==host)
assert(scaled.Header.Size.Y.Offset==95 and scaled.Body.AnchorPoint.Y==0.5)
assert(scaled.Body.Position.X.Scale==0.5 and scaled.Body.Position.Y.Offset==145)
scaled.Header.Activated:Fire(); assert(scaled.Tween.Goal.Size.Y.Scale==0.095 and scaled.Tween.Goal.Size.Y.Offset==116)
assert(scaled.Header.Size.Y.Offset==95,'header must not expand over the content')
host.AbsoluteCanvasSize={Y=800}; host:GetPropertyChangedSignal('AbsoluteCanvasSize'):Fire()
assert(scaled.Header.Size.Y.Offset==76 and scaled.Frame.Size.Y.Scale==0.095 and scaled.Frame.Size.Y.Offset==116)
assert(custom.Size.Y.Scale==0.095 and custom.Toggle.Size.Y.Scale==1 and custom.Content.Position.Y.Scale==0.5,'template must remain unchanged')
reused:Destroy(); assert(not custom.Destroyed)
-- Server stat merge must ignore level-local display tables.
local gameModules={CombatProfiles='profiles',WaitForChild=function(_,key) return key end}
local serverEnv=setmetatable({game={ReplicatedStorage={GameModules=gameModules},GetService=function() return {GameModules=gameModules} end},
 require=function(id) if id=='TowerData' then return {Towers={Test=def}} end; assert(id=='profiles'); return {Resolve=function() return 'None' end} end},{__index=getfenv()})
local serverChunk=assert(loadstring(source2)); setfenv(serverChunk,serverEnv)
local stats=serverChunk().GetStatsForLevel('Test',1)
assert(stats.AdvancedStats1==nil and stats.AdvancedStats2==nil)
print('Advanced dropdown checks passed: generated/custom template, ordered labels, height, interrupted toggles, reuse, exact level, cleanup, server metadata exclusion')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush()
 subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
