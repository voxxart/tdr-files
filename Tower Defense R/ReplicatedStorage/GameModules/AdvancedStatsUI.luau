local TweenService=game:GetService('TweenService')
local Data=require(script.Parent.AdvancedStatsData)
local UI={}
UI.__index=UI

local function create(class,parent,properties)
 local object=Instance.new(class)
 for key,value in pairs(properties) do object[key]=value end
 object.Parent=parent
 return object
end

local function defaultTemplate(host)
 local frame=create('Frame',nil,{Name='AdvancedStatsTemplate',Visible=false,Size=UDim2.new(1,0,0,55),
  BackgroundColor3=Color3.fromRGB(25,31,43),BorderSizePixel=0,ClipsDescendants=true,Active=true})
 create('UICorner',frame,{CornerRadius=UDim.new(0,8)})
 create('UIStroke',frame,{Color=Color3.fromRGB(100,122,155),Transparency=0.65,Thickness=1})
 local header=create('TextButton',frame,{Name='Toggle',Size=UDim2.new(1,0,0,55),
  BackgroundTransparency=1,Text='',AutoButtonColor=false,Selectable=true})
 create('TextLabel',header,{Name='Title',Position=UDim2.fromOffset(14,0),Size=UDim2.new(1,-58,1,0),
  BackgroundTransparency=1,Text='Advanced Stats',Font=Enum.Font.GothamBold,TextSize=17,
  TextColor3=Color3.fromRGB(245,247,255),TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
 create('TextLabel',header,{Name='Arrow',AnchorPoint=Vector2.new(0.5,0.5),
  Position=UDim2.new(1,-24,0.5,0),Size=UDim2.fromOffset(22,22),BackgroundTransparency=1,
  Text='⌄',Font=Enum.Font.GothamBold,TextSize=22,TextColor3=Color3.fromRGB(225,235,255)})
 local body=create('Frame',frame,{Name='Content',Position=UDim2.fromOffset(14,55),
  Size=UDim2.new(1,-28,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
 create('UIListLayout',body,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)})
 for index,name in ipairs(Data.LabelNames) do
  create('TextLabel',body,{Name=name,LayoutOrder=index,Size=UDim2.new(1,0,0,20),Visible=false,
   AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Text='',RichText=false,TextWrapped=true,
   Font=Enum.Font.Gotham,TextSize=16,TextColor3=Color3.fromRGB(210,220,237),
   TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
 end
 frame.Parent=host
 return frame
end

function UI.new(host)
 local self=setmetatable({Records={},Connections={},Host=host},UI)
 self.Template=host:FindFirstChild('AdvancedStatsTemplate')
 self.OwnTemplate=not self.Template
 if not self.Template then self.Template=defaultTemplate(host) end
 self.Template.Visible=false
 if not host:FindFirstChildOfClass('UIListLayout') then
  self.HostLayout=create('UIListLayout',host,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)})
 end
 if host:IsA('ScrollingFrame') then
  self.PreviousCanvas=host.AutomaticCanvasSize
  host.AutomaticCanvasSize=Enum.AutomaticSize.Y
 end
 self.Root=create('Frame',host,{Name='AdvancedStats',BackgroundTransparency=1,
  Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=1000,Visible=false})
 create('UIListLayout',self.Root,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)})
 return self
end

local function cancel(record)
 if record.Tween then record.Tween:Cancel(); record.Tween=nil end
 if record.ArrowTween then record.ArrowTween:Cancel(); record.ArrowTween=nil end
end
function UI:Clear()
 self.Definition=nil; self.Level=nil; self.Identity=nil
 for _,record in self.Records do
  cancel(record)
  record.Open=false; record.Frame.Visible=false
  record.Frame.Size=UDim2.new(1,0,0,55); record.Arrow.Rotation=0
 end
 self.Root.Visible=false
end

function UI:CreateRecord()
 local frame=self.Template:Clone()
 frame.Parent=self.Root; frame.Visible=false
 local header=frame:WaitForChild('Toggle')
 local arrow=header:WaitForChild('Arrow')
 local body=frame:WaitForChild('Content')
 local layout=assert(body:FindFirstChildOfClass('UIListLayout'),'AdvancedStatsTemplate.Content needs a UIListLayout')
 local record={Frame=frame,Header=header,Arrow=arrow,Body=body,Open=false}
 local function resize()
  if record.Tween then record.Tween:Cancel() end
  -- Absolute layout measurements include ancestor UIScale. Convert back to offsets.
  local factor=1
  local ancestor=body
  while ancestor and ancestor:IsA('GuiObject') do
   local scale=ancestor:FindFirstChildOfClass('UIScale')
   if scale then factor*=scale.Scale end
   ancestor=ancestor.Parent
  end
  local height=55+(if record.Open then layout.AbsoluteContentSize.Y/math.max(factor,0.001)+16 else 0)
  record.Tween=TweenService:Create(frame,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.new(1,0,0,height)})
  record.Tween:Play()
 end
 table.insert(self.Connections,header.Activated:Connect(function()
  record.Open=not record.Open
  if record.ArrowTween then record.ArrowTween:Cancel() end
  record.ArrowTween=TweenService:Create(arrow,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{Rotation=if record.Open then 180 else 0})
  record.ArrowTween:Play(); resize()
 end))
 table.insert(self.Connections,layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
  if record.Open and frame.Visible then resize() end
 end))
 return record
end

function UI:Render(groups)
 self:Clear()
 self.Root.Visible=#groups>0
 for order,group in ipairs(groups) do
  local record=self.Records[order]
  if not record then record=self:CreateRecord(); self.Records[order]=record end
  record.Frame.Name='AdvancedStats'..group.Index
  record.Frame.LayoutOrder=order
  record.Header.Title.Text=group.Title
  for _,name in ipairs(Data.LabelNames) do
   local label=record.Body:WaitForChild(name)
   label.Visible=false; label.Text=''
  end
  for _,item in ipairs(group.Items) do
   local label=record.Body[item.Name]
   label.Text=item.Text; label.Visible=true
  end
  record.Frame.Visible=true
 end
end
function UI:ShowLevel(definition,level,identity)
 if self.Definition==definition and self.Level==level and self.Identity==identity then return end
 self:Render(Data.ForLevel(definition,level))
 self.Definition=definition; self.Level=level; self.Identity=identity
end
function UI:Destroy()
 self:Clear()
 for _,connection in self.Connections do connection:Disconnect() end
 table.clear(self.Connections); table.clear(self.Records)
 self.Root:Destroy()
 if self.OwnTemplate then self.Template:Destroy() end
 if self.HostLayout then self.HostLayout:Destroy() end
 if self.PreviousCanvas then self.Host.AutomaticCanvasSize=self.PreviousCanvas end
end
return UI
