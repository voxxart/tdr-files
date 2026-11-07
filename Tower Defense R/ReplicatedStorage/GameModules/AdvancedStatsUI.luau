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
 local frame=create('Frame',nil,{Name='AdvancedStatsTemplate',Visible=false,Size=UDim2.new(0.924,0,0.095,0),
  BackgroundColor3=Color3.fromRGB(25,31,43),BorderSizePixel=0,ClipsDescendants=true,Active=true})
 create('UICorner',frame,{CornerRadius=UDim.new(0,8)})
 create('UIStroke',frame,{Color=Color3.fromRGB(100,122,155),Transparency=0.65,Thickness=1})
 local header=create('TextButton',frame,{Name='Toggle',Size=UDim2.new(1,0,1,0),
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
  record.Resize(false); record.Arrow.Rotation=0
 end
end

function UI:CreateRecord()
 local frame=self.Template:Clone()
 frame.Parent=self.Host; frame.Visible=false
 local header=frame:WaitForChild('Toggle')
 local arrow=header:WaitForChild('Arrow')
 local body=frame:WaitForChild('Content')
 local layout=assert(body:FindFirstChildOfClass('UIListLayout'),'AdvancedStatsTemplate.Content needs a UIListLayout')
 local record={Frame=frame,Header=header,Arrow=arrow,Body=body,Open=false}
 local closedSize=self.Template.Size
 local headerSize=header.Size
 local bodySize=body.Size
 local bodyPosition=body.Position
 local bodyAnchor=body.AnchorPoint
 body.AutomaticSize=Enum.AutomaticSize.None
 local function scaleFactor(object)
  local factor=1
  while object and object:IsA('GuiObject') do
   local scale=object:FindFirstChildOfClass('UIScale')
   if scale then factor*=scale.Scale end
   object=object.Parent
  end
  return math.max(factor,0.001)
 end
 local function resize(animate)
  if record.Tween then record.Tween:Cancel(); record.Tween=nil end
  -- Frames stay directly in Main, preserving the authored scale dimensions.
  local parentSize=if self.Host:IsA('ScrollingFrame') then self.Host.AbsoluteCanvasSize else self.Host.AbsoluteSize
  local closedHeight=parentSize.Y/scaleFactor(self.Host)*closedSize.Y.Scale+closedSize.Y.Offset
  local headerHeight=closedHeight*headerSize.Y.Scale+headerSize.Y.Offset
  local contentHeight=layout.AbsoluteContentSize.Y/scaleFactor(body)
  -- Keep a full-size Toggle at its collapsed height while its parent expands.
  header.Size=UDim2.new(headerSize.X.Scale,headerSize.X.Offset,0,headerHeight)
  body.Size=UDim2.new(bodySize.X.Scale,bodySize.X.Offset,0,contentHeight)
  body.Position=UDim2.new(bodyPosition.X.Scale,bodyPosition.X.Offset,0,headerHeight+contentHeight*bodyAnchor.Y)
  local extra=if record.Open then contentHeight+16 else 0
  local target=UDim2.new(closedSize.X.Scale,closedSize.X.Offset,closedSize.Y.Scale,closedSize.Y.Offset+extra)
  if animate==false then frame.Size=target; return end
  record.Tween=TweenService:Create(frame,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=target})
  record.Tween:Play()
 end
 record.Resize=resize
 resize(false)
 table.insert(self.Connections,header.Activated:Connect(function()
  record.Open=not record.Open
  if record.ArrowTween then record.ArrowTween:Cancel() end
  record.ArrowTween=TweenService:Create(arrow,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{Rotation=if record.Open then 180 else 0})
  record.ArrowTween:Play(); resize()
 end))
 table.insert(self.Connections,layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
  if frame.Visible then resize(record.Open) end
 end))
 table.insert(self.Connections,self.Host:GetPropertyChangedSignal(if self.Host:IsA('ScrollingFrame') then 'AbsoluteCanvasSize' else 'AbsoluteSize'):Connect(function()
  if frame.Visible then resize(false) end
 end))
 return record
end

function UI:Render(groups)
 self:Clear()
 for order,group in ipairs(groups) do
  local record=self.Records[order]
  if not record then record=self:CreateRecord(); self.Records[order]=record end
  record.Frame.Name='AdvancedStats'..group.Index
  record.Frame.LayoutOrder=1000+order
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
  record.Resize(false)
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
 for _,record in self.Records do record.Frame:Destroy() end
 table.clear(self.Connections); table.clear(self.Records)
 if self.OwnTemplate then self.Template:Destroy() end
 if self.HostLayout then self.HostLayout:Destroy() end
end
return UI
