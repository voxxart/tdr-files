-- Single client settings entry point: menu, sliders, preferences and local presentation.
local Players=game:GetService('Players')
local Rep=game:GetService('ReplicatedStorage')
local Input=game:GetService('UserInputService')
local GuiService=game:GetService('GuiService')
local RunService=game:GetService('RunService')
local player=Players.LocalPlayer
local gui=script.Parent
local modules=Rep:WaitForChild('GameModules')
local Schema=require(modules:WaitForChild('SettingsSchema'))
local Math=require(modules:WaitForChild('SettingsMath'))
local Audio=require(modules:WaitForChild('SettingsAudio')).new(workspace)
local Scale=require(modules:WaitForChild('SettingsScale')).new(player:WaitForChild('PlayerGui'))
local Effects=require(modules:WaitForChild('SettingsEffects')).new(workspace,player)
local remote=Rep:WaitForChild('Events'):WaitForChild('PlayerSettingChange')
local values=Schema.Normalize()
local connections,uiConnections={},{}
local sliders,choices={},{}
local sliderDefaults=setmetatable({}, {__mode="k"})
local dragged
local panel
local dirtyCommit={}
local alive=true
local function button(object)
 if not object then return nil end
 if object:IsA('GuiButton') then return object end
 local child=object:FindFirstChild('Button') or object:FindFirstChild('Upgrade')
 if child and child:IsA('GuiButton') then return child end
 return object:FindFirstChildWhichIsA('GuiButton',true)
end
local function ready() return player:GetAttribute('SettingsReady')==true end
local function visible(object)
 while object and object~=gui do
  if object:IsA('GuiObject') and not object.Visible then return false end
  object=object.Parent
 end
 return true
end
local function mark(object,selected)
 object:SetAttribute('Selected',selected)
 local stroke=object:FindFirstChildWhichIsA('UIStroke',true)
 if stroke then
  local on=stroke:FindFirstChild('EnabledVFX'); local off=stroke:FindFirstChild('Disabled')
  if on then on.Enabled=selected end; if off then off.Enabled=not selected end
 end
end
local function pixelScale(object)
 local scale=1
 while object and object~=player do
  if object:IsA('GuiObject') then
   local scaler=object:FindFirstChildWhichIsA('UIScale')
   if scaler then scale*=math.max(0.001,scaler.Scale) end
  end
  object=object.Parent
 end
 return scale
end
local function render()
 for key,slider in sliders do
  local percent=values[key]/100
  slider.Mover.AnchorPoint=Vector2.new(0.5,slider.Mover.AnchorPoint.Y)
  if slider.ParentFill then
   local base=slider.Base
   local width=slider.Track.AbsoluteSize.X/math.max(0.001,pixelScale(slider.Track))
   local fullWidth=width*base.Size.X.Scale+base.Size.X.Offset
   local knobWidth=math.max(1,fullWidth*base.KnobSize.X.Scale+base.KnobSize.X.Offset)
   slider.Mover.Size=UDim2.new(0,knobWidth,base.KnobSize.Y.Scale,base.KnobSize.Y.Offset)
   slider.Fill.AnchorPoint=Vector2.new(0,base.Anchor.Y)
   slider.Fill.Position=UDim2.new(base.Position.X.Scale-base.Anchor.X*base.Size.X.Scale,base.Position.X.Offset-base.Anchor.X*base.Size.X.Offset,base.Position.Y.Scale,base.Position.Y.Offset)
   slider.Fill.Size=UDim2.new(base.Size.X.Scale*percent,base.Size.X.Offset*percent,base.Size.Y.Scale,base.Size.Y.Offset)
   slider.Fill.ClipsDescendants=false
   slider.Mover.Position=UDim2.new(1,(0.5-percent)*knobWidth,base.KnobPosition.Y.Scale,base.KnobPosition.Y.Offset)
  else
   local y=slider.Mover.Position.Y
   local ratio=math.clamp(slider.Mover.AbsoluteSize.X/math.max(1,slider.Track.AbsoluteSize.X),0,1)
   slider.Mover.Position=UDim2.new(ratio*0.5+(1-ratio)*percent,0,y.Scale,y.Offset)
   if slider.Fill then slider.Fill.Size=UDim2.new(percent,0,slider.Fill.Size.Y.Scale,slider.Fill.Size.Y.Offset) end
  end
  if slider.Label then slider.Label.Text=tostring(math.round(values[key]))..'%' end
  slider.Button.Interactable=ready()
 end
 for key,options in choices do
  for name,entry in options do mark(entry.Object,values[key]==name); mark(entry.Button,values[key]==name); entry.Button.Interactable=ready() end
 end
end
local function apply(key,value)
 values[key]=value
 if key=='Towers' or key=='Ambience' or key=='Music' then Audio:Set(key,value)
 elseif key=='UIScale' then Scale:Set(Schema.ScaleFactors[value])
 elseif key=='VFX' then Effects:Set(value) end
 if key=='VFX' or key=='Dialogue' then
  local object=player:FindFirstChild(key)
  if object and object:IsA('StringValue') then object.Value=value end
 end
 render()
end
local function commit(key)
 dirtyCommit[key]=nil
 if ready() then remote:FireServer(key,values[key]) end
end
local function choose(key,value,send)
 local valid=Schema.Validate(key,value); if valid==nil then return end
 if values[key]~=valid then apply(key,valid) end
 if send then commit(key) end
end
local function finishDrag()
 if dragged then local key=dragged.Key; dragged=nil; commit(key) end
end
local function point(slider,x)
 choose(slider.Key,Math.Percent(x,slider.Track.AbsolutePosition.X,slider.Track.AbsoluteSize.X,slider.Mover.AbsoluteSize.X),false)
end
local function connect(target,event,fn) table.insert(uiConnections,target[event]:Connect(fn)) end
local function bindSlider(section,key)
 local bar=section and section:FindFirstChild('VolumeBar')
 local slider=bar and bar:FindFirstChild('Slider')
 local endFrame=slider and slider:FindFirstChild('End')
 local knob=button(endFrame or slider)
 if not bar or not slider or not knob then warn('Settings: missing '..key..'.VolumeBar.Slider.End.Button'); return end
 local override=slider:GetAttribute('SettingsSliderTrack')
 local isTrack=if type(override)=='boolean' then override else slider~=knob and slider.AbsoluteSize.X>=bar.AbsoluteSize.X*0.8
 local record=if endFrame and endFrame:IsA('GuiObject') then {Key=key,Track=bar,Mover=endFrame,Button=knob,ParentFill=true}
  else {Key=key,Track=if isTrack then slider else bar,Mover=if isTrack or slider==knob then knob else slider,Button=knob}
 local label=bar:FindFirstChild('SectionTitle')
 record.Label=if label and (label:IsA('TextLabel') or label:IsA('TextButton')) then label else nil
 if record.ParentFill then
  sliderDefaults[slider]=sliderDefaults[slider] or {Size=slider.Size,Position=slider.Position,Anchor=slider.AnchorPoint,KnobSize=endFrame.Size,KnobPosition=endFrame.Position}
  record.Base=sliderDefaults[slider]; record.Fill=slider
 else
  record.Fill=record.Track:FindFirstChild('Fill'); if record.Fill and not record.Fill:IsA('GuiObject') then record.Fill=nil end
 end
 sliders[key]=record
 knob.NextSelectionLeft=knob; knob.NextSelectionRight=knob
 local targets={}
 for _,target in {bar,slider,record.Track,record.Mover,knob} do
  if not targets[target] then
   targets[target]=true; target.Active=true
   connect(target,'InputBegan',function(input)
    if not ready() or not visible(target) or (dragged and dragged.Input~=input) then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
     dragged={Key=key,Slider=record,Input=input}; point(record,input.Position.X)
    end
   end)
  end
 end
end
local function bindChoice(general,key,sectionName,options)
 local section=general and general:FindFirstChild(sectionName)
 local list=section and section:FindFirstChild('ButtonSection')
 if not list then warn('Settings: missing GeneralSettings.'..sectionName..'.ButtonSection'); return end
 choices[key]={}
 for name,value in options do
  local object=list:FindFirstChild(name); local control=button(object)
  if control then
   choices[key][value]={Object=object,Button=control}
   connect(control,'Activated',function() if ready() then choose(key,value,true) end end)
  else warn('Settings: missing '..sectionName..'.'..name..' button') end
 end
end
local rebindQueued=false
local function bind()
 rebindQueued=false; if not alive then return end
 finishDrag()
 for _,connection in uiConnections do connection:Disconnect() end
 table.clear(uiConnections); table.clear(sliders); table.clear(choices)
 panel=gui:FindFirstChild('FullSettings'); if not panel then return end
 Scale:AddRoot(panel)
 local area=panel:FindFirstChild('SettingsArea')
 local sound=area and area:FindFirstChild('SoundSettings')
 local general=area and area:FindFirstChild('GeneralSettings')
 if sound then sound.Visible=true end; if general then general.Visible=true end
 for _,key in {'Towers','Ambience','Music'} do bindSlider(sound and (sound:FindFirstChild(key) or (key=='Music' and sound:FindFirstChild('Volume'))),key) end
 bindChoice(general,'Dialogue','Dialogue',{Default='On',Off='Off'})
 bindChoice(general,'VFX','VFX',{High='High',Low='Low'})
 bindChoice(general,'UIScale','UIScale',{Small='Small',Default='Default',Large='Large'})
 local settings=gui:FindFirstChild('Settings')
 local misc=gui:FindFirstChild('Misc')
 local open=button(misc and misc:FindFirstChild('Settings')) or button(settings and settings:FindFirstChild('OpenSettings'))
 local close=button(panel:FindFirstChild('Close'))
 if open then connect(open,'Activated',function() panel.Visible=not panel.Visible; if not panel.Visible then finishDrag() end; Scale.Dirty=true end) end
 if close then connect(close,'Activated',function() finishDrag(); panel.Visible=false end) end
 render(); Scale.Dirty=true
end
for key,default in Schema.Defaults do
 apply(key,default)
 table.insert(connections,player:GetAttributeChangedSignal('Setting'..key):Connect(function()
  local value=Schema.Validate(key,player:GetAttribute('Setting'..key))
  if value~=nil and not (dragged and dragged.Key==key) and not dirtyCommit[key] then apply(key,value) end
 end))
end
table.insert(connections,player:GetAttributeChangedSignal('SettingsReady'):Connect(function()
 if ready() then for key in Schema.Defaults do local value=Schema.Validate(key,player:GetAttribute('Setting'..key)); if value~=nil then apply(key,value) end end end
 render()
end))
for key in Schema.Defaults do local value=Schema.Validate(key,player:GetAttribute('Setting'..key)); if value~=nil then apply(key,value) end end
table.insert(connections,Input.InputChanged:Connect(function(input)
 if dragged and (input==dragged.Input or input.UserInputType==Enum.UserInputType.MouseMovement and dragged.Input.UserInputType==Enum.UserInputType.MouseButton1) then point(dragged.Slider,input.Position.X) end
end))
table.insert(connections,Input.InputEnded:Connect(function(input)
 if dragged and (input==dragged.Input or input.UserInputType==Enum.UserInputType.MouseButton1 and dragged.Input.UserInputType==Enum.UserInputType.MouseButton1) then finishDrag() end
end))
table.insert(connections,Input.WindowFocusReleased:Connect(finishDrag))
table.insert(connections,Input.InputBegan:Connect(function(input)
 if not panel or not panel.Visible or not ready() then return end
 if input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB then finishDrag(); panel.Visible=false; return end
 for key,slider in sliders do
  if GuiService.SelectedObject==slider.Button then
   local delta=if input.KeyCode==Enum.KeyCode.Left then -1 elseif input.KeyCode==Enum.KeyCode.Right then 1 elseif input.KeyCode==Enum.KeyCode.DPadLeft then -5 elseif input.KeyCode==Enum.KeyCode.DPadRight then 5 else 0
   if delta~=0 then choose(key,values[key]+delta,false); dirtyCommit[key]=os.clock()+0.2 end
   if input.KeyCode==Enum.KeyCode.Home or input.KeyCode==Enum.KeyCode.End then choose(key,if input.KeyCode==Enum.KeyCode.Home then 0 else 100,false); commit(key) end
  end
 end
end))
local cameraConnection
local function cameraChanged()
 if cameraConnection then cameraConnection:Disconnect() end
 local camera=workspace.CurrentCamera
 if camera then cameraConnection=camera:GetPropertyChangedSignal('ViewportSize'):Connect(function() Scale.Dirty=true end) end
 Scale.Dirty=true
end
table.insert(connections,workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(cameraChanged)); cameraChanged()
table.insert(connections,gui.DescendantAdded:Connect(function(object)
 local current=object; local relevant=false
 while current and current~=gui do
  if current.Name=='FullSettings' or current.Name=='OpenSettings' or (current.Name=='Settings' and current.Parent and current.Parent.Name=='Misc') then relevant=true; break end
  current=current.Parent
 end
 if relevant and (object.Name=='FullSettings' or object.Name=='SettingsArea' or object.Name=='SoundSettings' or object.Name=='GeneralSettings' or object.Name=='ButtonSection' or object.Name=='End' or object.Name=='Button' or object.Name=='Close' or object.Name=='OpenSettings' or object.Name=='Settings') then
  if not rebindQueued then rebindQueued=true; task.defer(bind) end
 end
end))
table.insert(connections,RunService.RenderStepped:Connect(function()
 if dragged and not visible(dragged.Slider.Button) then finishDrag() end
 local fitDirty=Scale.Dirty
 Scale:Step()
 if fitDirty then render() end
 for key,deadline in dirtyCommit do if os.clock()>=deadline then commit(key) end end
end))
script.Destroying:Connect(function()
 alive=false; finishDrag()
 for _,connection in connections do connection:Disconnect() end
 for _,connection in uiConnections do connection:Disconnect() end
 if cameraConnection then cameraConnection:Disconnect() end
 Audio:Destroy(); Effects:Destroy(); Scale:Destroy()
end)
bind()
