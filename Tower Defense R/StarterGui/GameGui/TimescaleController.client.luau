local Players=game:GetService('Players')
local Rep=game:GetService('ReplicatedStorage')
local player=Players.LocalPlayer
local gui=script:FindFirstAncestorWhichIsA('ScreenGui') or script.Parent
local menu=gui:WaitForChild('PurchaseTimescale')
local toggle=gui:WaitForChild('Misc'):WaitForChild('Timescale'):WaitForChild('Button')
local actions=menu:WaitForChild('Actions')
local action=actions:FindFirstChild('Purchase') or actions:WaitForChild('Puchase')
local purchase=action:WaitForChild('Button')
local close=menu:WaitForChild('Close')
local gems=menu:WaitForChild('Gems'):WaitForChild('Amount')
local message=menu:WaitForChild('Message')
local functions=Rep:WaitForChild('Functions')
local remote=functions:WaitForChild('PurchaseTimescale')
local info=workspace:WaitForChild('Info')
local price=500
local busy=false
local speedBusy=false
local alive=true
local connections={}
menu.Visible=false
message.Visible=false
local function errorMessage(text)
 local area=gui:FindFirstChild('Info')
 area=area and area:FindFirstChild('Errors')
 local template=area and area:FindFirstChild('Error')
 if not template then warn(text);return end
 local copy=template:Clone()
 local label=copy:FindFirstChild('Message')
 if label and label:IsA('TextLabel') then label.Text=text end
 copy.Visible=true;copy.Parent=area
 local sounds=gui:FindFirstChild('Sounds')
 local sound=sounds and sounds:FindFirstChild('Error')
 if sound then sound:Play() end
 task.delay(3,function() copy:Destroy() end)
end
local function purchaseSuccess()
 local sounds=gui:FindFirstChild('Sounds')
 local sound=sounds and sounds:FindFirstChild('PurchasedSuccessful')
 if sound and sound:IsA('Sound') then sound:Play() end
 local area=gui:FindFirstChild('Messages')
 local template=area and area:FindFirstChild('Message')
 if not template then return end
 local copy=template:Clone()
 for _,name in {'Main','Main2','Message'} do
  local label=copy:FindFirstChild(name)
  if label and (label:IsA('TextLabel') or label:IsA('TextButton')) then
   label.Text='Successfully purchased Timescale!'
  end
 end
 copy.Visible=true;copy.Parent=area
 task.delay(3,function() copy:Destroy() end)
end
local function render()
 if not alive then return end
 local ready=player:GetAttribute('TimescalePurchaseReady')==true
 local owned=(player:GetAttribute('UnlockedTimescale') or 0)>=1
 local balance=player:GetAttribute('TimescaleGems') or 0
 gems.Text=if ready then tostring(balance) else '...'
 message.Visible=ready and not owned and balance<price
 purchase.Active=ready and not busy and not owned
 if owned then menu.Visible=false end
end
local function status()
 local ok,result=pcall(remote.InvokeServer,remote,'Status')
 if not alive then return end
 if ok and type(result)=='table' and type(result.Price)=='number' then price=result.Price end
 render()
end
connections[#connections+1]=toggle.Activated:Connect(function()
 if busy or speedBusy then return end
 if (player:GetAttribute('UnlockedTimescale') or 0)<1 then
  menu.Visible=true
  render()
  status()
  return
 end
 local endpoint=functions:WaitForChild('RequestTimescale')
 speedBusy=true
 local ok,result=pcall(endpoint.InvokeServer,endpoint)
 speedBusy=false
 if not alive then return end
 if not ok then errorMessage('Unable to change timescale. Please try again.')
 elseif type(result)=='table' and not result.Success and result.Error then errorMessage(result.Error) end
end)
connections[#connections+1]=purchase.Activated:Connect(function()
 if busy or not menu.Visible then return end
 busy=true;render()
 local ok,result=pcall(remote.InvokeServer,remote,'Purchase')
 busy=false
 if not alive then return end
 if ok and type(result)=='table' then
  if result.Success then
   menu.Visible=false
   if result.Changed then purchaseSuccess() end
  elseif result.Error then errorMessage(result.Error) end
 else errorMessage('Unable to purchase timescale. Please try again.') end
 render()
end)
connections[#connections+1]=close.Activated:Connect(function() menu.Visible=false end)
for _,key in {'TimescaleGems','UnlockedTimescale','TimescalePurchaseReady'} do
 connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(render)
end
script.Destroying:Connect(function()
 alive=false
 for _,connection in connections do connection:Disconnect() end
end)
render()
task.spawn(status)
