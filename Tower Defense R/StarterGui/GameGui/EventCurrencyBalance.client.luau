-- Read-only HUD binding: server-owned balance attribute, no polling or reward RPC.
local player=game:GetService('Players').LocalPlayer
local gui=script.Parent
local label
local function update()
 if not label or not label.Parent then
  local settings=gui:FindFirstChild('Settings')
  local currency=settings and settings:FindFirstChild('EventCurrency')
  label=currency and currency:FindFirstChild('Amount')
 end
 if not label or not (label:IsA('TextLabel') or label:IsA('TextButton')) then return end
 local value=player:GetAttribute('EventCurrencyBalance')
 if type(value)~='number' or value~=value or math.abs(value)==math.huge then value=0 end
 local text=tostring(math.max(0,math.floor(value)))
 label.Text=text:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
end
local balance=player:GetAttributeChangedSignal('EventCurrencyBalance'):Connect(update)
local added=gui.DescendantAdded:Connect(function(object)
 if object.Name=='Amount' or object.Name=='EventCurrency' or object.Name=='Settings' then label=nil; update() end
end)
script.Destroying:Connect(function() balance:Disconnect(); added:Disconnect(); label=nil end)
update()
