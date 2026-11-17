"""Exercise the actual settings controller/modules with the supplied UI hierarchy."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]; base=root/'Tower Defense R'
paths={key:'ReplicatedStorage/GameModules/'+name+'.luau' for key,name in {'schema':'SettingsSchema','math':'SettingsMath','audio':'SettingsAudio','scale':'SettingsScale','effects':'SettingsEffects','policy':'VFXPolicy'}.items()}
paths['controller']='StarterGui/GameGui/SettingsController.client.luau'
code='local sources={}\n'+''.join(f'sources.{k}=[====['+(base/v).read_text()+']====]\n' for k,v in paths.items())
code+=r'''
local function signal()
 local s={Entries={}}
 function s:Connect(fn) local c={Connected=true,F=fn}; function c:Disconnect() self.Connected=false end; table.insert(self.Entries,c); return c end
 function s:Fire(...) for _,c in table.clone(self.Entries) do if c.Connected then c.F(...) end end end
 return s
end
local function v(x,y) return {X=x,Y=y} end
local function dim(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end
local methods={}; local node
function methods:IsA(kind)
 return self.Class==kind or kind=='GuiObject' and ({Frame=true,TextLabel=true,ImageButton=true,TextButton=true,ScrollingFrame=true})[self.Class] or kind=='GuiButton' and (self.Class=='ImageButton' or self.Class=='TextButton')
end
function methods:IsDescendantOf(other) local current=self.Parent; while current do if current==other then return true end; current=current.Parent end; return false end
function methods:GetChildren() return table.clone(self.Children) end
function methods:GetDescendants() local out={} for _,child in self.Children do table.insert(out,child); for _,d in child:GetDescendants() do table.insert(out,d) end end return out end
function methods:FindFirstChild(name,recursive)
 for _,child in self.Children do if child.Name==name then return child end end
 if recursive then for _,child in self.Children do local found=child:FindFirstChild(name,true); if found then return found end end end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:FindFirstChildWhichIsA(kind,recursive)
 for _,child in self.Children do if child:IsA(kind) then return child end end
 if recursive then for _,child in self.Children do local found=child:FindFirstChildWhichIsA(kind,true); if found then return found end end end
end
function methods:GetAttribute(name) return self.Attributes[name] end
function methods:SetAttribute(name,value) self.Attributes[name]=value; if self.AttributeSignals[name] then self.AttributeSignals[name]:Fire() end end
function methods:GetAttributeChangedSignal(name) self.AttributeSignals[name]=self.AttributeSignals[name] or signal(); return self.AttributeSignals[name] end
function methods:GetPropertyChangedSignal(name) self.PropertySignals[name]=self.PropertySignals[name] or signal(); return self.PropertySignals[name] end
function methods:Emit(count) self.Emitted=(self.Emitted or 0)+count end
function methods:Destroy() self.Destroying:Fire(); self.Parent=nil; self.Destroyed=true end
function methods:Clone()
 local copy=node(self.Class,self.Name)
 for key,value in self.Props do if key~='Parent' then copy.Props[key]=value end end
 copy.Attributes=table.clone(self.Attributes)
 for _,child in self.Children do child:Clone().Parent=copy end
 return copy
end
node=function(class,name,parent)
 local n={Class=class,Children={},Attributes={},AttributeSignals={},PropertySignals={},Props={Name=name or class,Scale=1,Volume=1,Rate=40,Enabled=true,Visible=true,AbsoluteSize=v(100,30),AbsolutePosition=v(0,0),AnchorPoint=v(0.5,0.5),Size=dim(0,100,0,30),Position=dim(0.5,0,0.5,0)},Destroying=signal(),ChildAdded=signal(),DescendantAdded=signal(),DescendantRemoving=signal(),InputBegan=signal(),Activated=signal()}
 setmetatable(n,{__index=function(self,key) return methods[key] or self.Props[key] or self:FindFirstChild(key) end,
 __newindex=function(self,key,value)
  if key=='Parent' then
   local old=self.Props.Parent
   if old then for i,c in old.Children do if c==self then table.remove(old.Children,i); break end end; local a=old; while a do a.DescendantRemoving:Fire(self); a=a.Parent end end
   self.Props.Parent=value
   if value then table.insert(value.Children,self); value.ChildAdded:Fire(self); local a=value; while a do a.DescendantAdded:Fire(self); a=a.Parent end end
  else
   local old=self.Props[key]; self.Props[key]=value
   if key=='AbsoluteSize' and self.Class=='ScreenGui' then
    for _,child in self.Children do if child.BaseSize then child.Props.AbsolutePosition=v(value.X*0.5-child.AbsoluteSize.X*0.5,value.Y*0.5-child.AbsoluteSize.Y*0.5) end end
   end
   if key=='Scale' and self.Class=='UIScale' and self.Parent and self.Parent.BaseSize then
    local root=self.Parent; root.Props.AbsoluteSize=v(root.BaseSize.X*value,root.BaseSize.Y*value)
    root.Props.AbsolutePosition=v(root.Parent.AbsoluteSize.X*0.5-root.AbsoluteSize.X*0.5,root.Parent.AbsoluteSize.Y*0.5-root.AbsoluteSize.Y*0.5)
   end
   if old~=value and self.PropertySignals[key] then self.PropertySignals[key]:Fire() end
  end
 end})
 if parent then n.Parent=parent end
 return n
end
local world=node('Workspace'); local soundService=node('SoundService'); local lighting=node('Lighting'); lighting.GlobalShadows=false
local player=node('Player'); local playerGui=node('PlayerGui','PlayerGui',player)
local gui=node('ScreenGui','GameGui',playerGui); gui.AbsoluteSize=v(800,600); gui.AbsolutePosition=v(0,0)
local panel=node('Frame','FullSettings',gui); panel.Size=dim(0,700,0,500); panel.AbsoluteSize=v(700,500); panel.AbsolutePosition=v(50,50); panel.BaseSize=v(700,500)
local rootScale=node('UIScale','UIScale',panel)
local close=node('ImageButton','Close',panel); node('Frame','Frame',panel)
local area=node('Frame','SettingsArea',panel); local sound=node('Frame','SoundSettings',area); local general=node('Frame','GeneralSettings',area)
local rows={}
for _,name in {'Towers','Ambience','Music'} do
 local row=node('Frame',name,sound); local bar=node('Frame','VolumeBar',row); bar.AbsoluteSize=v(200,20); bar.AbsolutePosition=v(100,0)
 local slider=node('Frame','Slider',bar); slider.AbsoluteSize=v(200,20); slider.AbsolutePosition=v(100,0)
 local endFrame=node('Frame','End',slider); endFrame.AbsoluteSize=v(20,20)
 local knob=node('ImageButton','Button',endFrame); knob.AbsoluteSize=v(16,16)
 local label=node('TextLabel','SectionTitle',bar); rows[name]={Bar=bar,Track=slider,End=endFrame,Knob=knob,Label=label}
end
local options={}
for key,names in {Dialogue={'Default','Off'},VFX={'High','Low'},UIScale={'Small','Default','Large'}} do
 local section=node('Frame',key,general); local buttons=node('Frame','ButtonSection',section); options[key]={}
 for _,name in names do local frame=node('Frame',name,buttons); local control=node('TextButton','Button',frame); options[key][name]=control end
end
local cash=node('Frame','Cash',gui)
local animationScale=node('UIScale','AnimationScale',general); animationScale.Scale=0.83
local settings=node('Frame','Misc',gui); settings:SetAttribute('SettingsScaleIgnore',true); local openFrame=node('Frame','Settings',settings); local open=node('TextButton','Button',openFrame)
local music=node('Folder','Music',world); local ambient=node('Folder','Ambience',world); local towers=node('Folder','Towers',world)
local track=node('Sound','Theme',music); track.Volume=0.7
local background=node('Sound','Rain',ambient); background.Volume=0.3
local attack=node('Sound','Attack',towers); attack.Volume=0.9
local authored=node('SoundGroup','Authored',soundService); authored.Volume=0.8; node('SoundEffect','Reverb',authored); attack.SoundGroup=authored
local emitter=node('ParticleEmitter','Smoke',world); emitter.Rate=100; emitter.Enabled=false
node('StringValue','VFX',player).Value='High'; node('StringValue','Dialogue',player).Value='On'
local camera=node('Camera'); camera.ViewportSize=v(800,600); world.CurrentCamera=camera
local input={InputChanged=signal(),InputEnded=signal(),InputBegan=signal(),WindowFocusReleased=signal()}
local guiService={}; local render=signal(); local destroying=signal(); local now=0; local pending={}; local sent={}
local rep=node('Folder'); local modules=node('Folder','GameModules',rep); local events=node('Folder','Events',rep); local remote=node('RemoteEvent','PlayerSettingChange',events)
function remote:FireServer(...) table.insert(sent,table.pack(...)) end
for key,name in {schema='SettingsSchema',math='SettingsMath',audio='SettingsAudio',scale='SettingsScale',effects='SettingsEffects',policy='VFXPolicy'} do local m=node('ModuleScript',name,modules); m.Key=key end
local loaded={}
local environment=setmetatable({workspace=world,Instance={new=node},Vector2={new=v},UDim2={new=dim},script={Parent=gui,Destroying=destroying},os={clock=function() return now end},
 Enum={UserInputType={MouseButton1='MouseButton1',MouseMovement='MouseMovement',Touch='Touch'},KeyCode={Escape='Escape',ButtonB='ButtonB',Left='Left',Right='Right',DPadLeft='DPadLeft',DPadRight='DPadRight',Home='Home',End='End'}},
 task={defer=function(fn,...) table.insert(pending,{F=fn,Args=table.pack(...)}) end},warn=function(...) error('Unexpected warning: '..tostring(...)) end,
 game={GetService=function(_,name)
 if name=='Players' then return {LocalPlayer=player} elseif name=='ReplicatedStorage' then return rep elseif name=='UserInputService' then return input elseif name=='GuiService' then return guiService elseif name=='RunService' then return {RenderStepped=render} elseif name=='SoundService' then return soundService elseif name=='Lighting' then return lighting end
 error(name)
end}},{__index=getfenv()})
local function load(key)
 if loaded[key] then return loaded[key] end
 local old=environment.script
 environment.script=if key=='controller' then {Parent=gui,Destroying=destroying} else {Parent=modules}
 local fn=assert(loadstring(sources[key])); setfenv(fn,environment); local value=fn(); loaded[key]=value; environment.script=old; return value
end
environment.require=function(module) return load(module.Key) end
local schema=load('schema')
for key,value in schema.Defaults do player:SetAttribute('Setting'..key,value) end
player:SetAttribute('SettingsReady',true)
load('controller')
local function step(dt)
 now+=dt
 local queue=pending; pending={}; for _,item in queue do item.F(table.unpack(item.Args,1,item.Args.n)) end
 render:Fire(dt)
end
step(0.01)
assert(not cash:FindFirstChildWhichIsA('UIScale'),'transient popup templates must not acquire settings scalers')
assert(sound.Visible and general.Visible and animationScale.Scale==0.83,'new layout sections and nested animation scales must be preserved')
assert(track.Volume==0.7 and background.Volume==0.3 and attack.Volume==0.9,'authored sound volumes must not be flattened')
local originalGroup=attack.SoundGroup; assert(originalGroup~=authored and originalGroup.Volume==0.8 and originalGroup:FindFirstChild('Reverb'))
local mouse={UserInputType='MouseButton1',Position=v(170,0)}
rows.Music.Bar.InputBegan:Fire(mouse)
input.InputChanged:Fire({UserInputType='MouseMovement',Position=v(240,0)})
assert(rows.Music.End.Position.X.Offset==0,'knob wrapper positioning must stay scale-independent')
assert(rows.Music.Knob.Position.X.Scale==0.5 and rows.Music.End.Position.X.Scale>0.5,'move End along the track without displacing its inner button')
assert(#sent==0 and rows.Music.Label.Text=='72%' and math.abs(track.SoundGroup.Volume-0.722)<0.001,'drag applies local volume continuously without remote spam')
assert(background.SoundGroup.Volume==1,'music slider must not affect ambience')
local unrelated=node('TextButton','Button',gui); step(0.01); assert(#sent==0,'unrelated UI additions must not end an active settings drag')
input.InputEnded:Fire(mouse); assert(#sent==1 and sent[1][1]=='Music' and sent[1][2]==72.2)
local touch={UserInputType='Touch',Position=v(110,0)}; rows.Ambience.Track.InputBegan:Fire(touch)
input.InputChanged:Fire({UserInputType='Touch',Position=v(290,0)}); assert(rows.Ambience.Label.Text=='0%','second touch must not hijack the drag')
input.InputEnded:Fire(touch); assert(sent[2][1]=='Ambience' and sent[2][2]==0)
options.VFX.Low.Activated:Fire(); assert(player.VFX.Value=='Low' and emitter.Rate==25 and not emitter.Enabled and not lighting.GlobalShadows)
local policy=load('policy'); policy.Emit(emitter,100); assert(emitter.Emitted==24)
for _=1,20 do policy.Emit(emitter,100) end; assert(emitter.Emitted==96,'global burst budget must remain bounded')
local clonedEmitter=emitter:Clone(); clonedEmitter.Parent=world; assert(clonedEmitter.Rate==25,'cloned low-quality emitters must not compound rate reductions')
options.VFX.High.Activated:Fire(); assert(emitter.Rate==100 and clonedEmitter.Rate==100 and not emitter.Enabled and not lighting.GlobalShadows,'High restores authored settings without enabling template emitters or forcing shadows on')
options.Dialogue.Off.Activated:Fire(); assert(player.Dialogue.Value=='Off')
options.UIScale.Large.Activated:Fire(); step(0.01); assert(rootScale.Scale<=1.1 and animationScale.Scale==0.83)
gui.AbsoluteSize=v(320,500); camera.ViewportSize=v(320,500); step(0.01)
assert(panel.AbsoluteSize.X<=304.1 and panel.AbsoluteSize.Y<=484.1,'large preference must fit a small viewport')
gui.AbsoluteSize=v(800,600); camera.ViewportSize=v(800,600); step(0.01); assert(math.abs(rootScale.Scale-1.1)<0.001,'resize must restore the chosen preference instead of compounding shrink')
local late=track:Clone(); late.Parent=music; assert(late.SoundGroup==track.SoundGroup,'cloned already-routed sounds must not get double attenuation')
local newAttack=node('Sound','NewAttack',towers); assert(newAttack.SoundGroup)
guiService.SelectedObject=rows.Towers.Knob
input.InputBegan:Fire({KeyCode='Left'}); step(0.3); assert(sent[#sent][1]=='Towers' and sent[#sent][2]==99,'focused keyboard adjustment commits after debounce')
close.Activated:Fire(); assert(not panel.Visible); open.Activated:Fire(); assert(panel.Visible)
destroying:Fire(); assert(track.SoundGroup==nil and attack.SoundGroup==authored and emitter.Rate==100 and animationScale.Scale==0.83)
for _,entry in render.Entries do assert(not entry.Connected) end
print('Settings client passed: Slider.End.Button hierarchy, full-bar mouse/touch/keyboard sliders, release-only commits, independent audio and late clones, authored mix restoration, VFX budgets/restoration, fitted viewport resize, nested animation scales, open/close and cleanup')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush(); subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
