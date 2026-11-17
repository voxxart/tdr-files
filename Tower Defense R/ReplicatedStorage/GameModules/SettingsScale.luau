local Math=require(script.Parent.SettingsMath)
local Scale={}; Scale.__index=Scale
local transient={Messages=true,Cash=true,MobHoverGui=true,UnitHoverGui=true,TowerHoverGui=true}
function Scale.new(playerGui)
 local self=setmetatable({Gui=playerGui,Roots={},Connections={},Factor=1,Dirty=true},Scale)
 local function addScreen(screen)
  if not screen:IsA('ScreenGui') then return end
  for _,root in screen:GetChildren() do self:AddRoot(root) end
 end
 for _,screen in playerGui:GetChildren() do addScreen(screen) end
 table.insert(self.Connections,playerGui.ChildAdded:Connect(function(screen) task.defer(addScreen,screen) end))
 table.insert(self.Connections,playerGui.DescendantAdded:Connect(function(object)
  if object:IsA('GuiObject') and object:GetAttribute('SettingsScalable')==true then self:Add(object) end
 end))
 return self
end
function Scale:AddRoot(root)
 if self.Destroyed then return end
 if not root:IsA('GuiObject') then return end
 if root.Size.X.Scale>=0.95 and root.Size.Y.Scale>=0.95 then
  for _,panel in root:GetChildren() do if panel:IsA('GuiObject') then self:Add(panel) end end
 else self:Add(root) end
end
function Scale:Add(root)
 if self.Destroyed then return end
 if self.Roots[root] or root:GetAttribute('SettingsScaleIgnore')==true or (transient[root.Name] and root:GetAttribute('SettingsScalable')~=true) then return end
 for managed in self.Roots do if managed:IsDescendantOf(root) then return end end
 local ancestor=root.Parent
 while ancestor and ancestor~=self.Gui do if self.Roots[ancestor] then return end; ancestor=ancestor.Parent end
 local scaler=root:FindFirstChildWhichIsA('UIScale')
 local created=false
 if not scaler then scaler=Instance.new('UIScale'); scaler.Name='SettingsPanelScale'; scaler.Parent=root; created=true end
 local record={Scale=scaler,Base=if scaler.Scale>0 then scaler.Scale else 1,Created=created,Connections={}}
 self.Roots[root]=record
 for _,property in {'AbsoluteSize','Visible'} do
  table.insert(record.Connections,root:GetPropertyChangedSignal(property):Connect(function() self.Dirty=true end))
 end
 table.insert(record.Connections,root.Destroying:Connect(function()
  for _,connection in record.Connections do connection:Disconnect() end
  self.Roots[root]=nil
 end))
 self.Dirty=true
end
function Scale:Set(factor) self.Factor=factor; self.Dirty=true end
function Scale:Step()
 if not self.Dirty then return end
 self.Dirty=false
 for root,record in self.Roots do
  if root.Parent and root.Visible and record.Scale.Parent then
   local parent=root.Parent
   local size=parent.AbsoluteSize; local origin=parent.AbsolutePosition
   local current=record.Scale.Scale
   if current>0 and size.X>0 and size.Y>0 then
    local actual=root.AbsoluteSize; local position=root.AbsolutePosition
    local anchor=root.AnchorPoint
    local padding=if root.Size.X.Scale>=0.95 or root.Size.Y.Scale>=0.95 then 0 else 8
    local fitted=Math.Fit(actual.X/current,actual.Y/current,anchor.X,anchor.Y,
     position.X-origin.X+actual.X*anchor.X,position.Y-origin.Y+actual.Y*anchor.Y,size.X,size.Y,record.Base*self.Factor,padding)
    if fitted and math.abs(fitted-current)>0.001 then record.Scale.Scale=fitted end
   end
  end
 end
end
function Scale:Destroy()
 self.Destroyed=true
 for _,connection in self.Connections do connection:Disconnect() end
 for _,record in self.Roots do
  for _,connection in record.Connections do connection:Disconnect() end
  if record.Scale.Parent then if record.Created then record.Scale:Destroy() else record.Scale.Scale=record.Base end end
 end
 table.clear(self.Roots); table.clear(self.Connections)
end
return Scale
