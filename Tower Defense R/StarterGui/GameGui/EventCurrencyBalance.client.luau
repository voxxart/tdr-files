-- Read-only HUD binding. Wallet replicates the loaded playerData[CurrencyKey].
local player=game:GetService('Players').LocalPlayer
local Rep=game:GetService('ReplicatedStorage')
local Config=require(Rep:WaitForChild('GameModules'):WaitForChild('EventCurrencyConfig'))
local gui=script:FindFirstAncestorWhichIsA('ScreenGui') or script.Parent
local label,textChanged
local alive=true
local function isText(object)
 return object and (object:IsA('TextLabel') or object:IsA('TextButton') or object:IsA('TextBox'))
end
local function balanceText()
 local value=if player:GetAttribute('EventCurrencyKey')==Config.CurrencyKey then player:GetAttribute('EventCurrencyBalance') else 0
 if type(value)~='number' or value~=value or math.abs(value)==math.huge then value=0 end
 return tostring(math.max(0,math.floor(value))):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
end
local function write()
 if label and label.Parent then
  local text=balanceText()
  if label.Text~=text then label.Text=text end
 end
end
local function update()
 if not alive then return end
 local settings=gui:FindFirstChild('Settings')
 local currency=settings and settings:FindFirstChild('EventCurrency')
 local target=currency and currency:FindFirstChild('Amount')
 if not isText(target) then target=nil end
 if target~=label then
  if textChanged then textChanged:Disconnect(); textChanged=nil end
  label=target
  if label then textChanged=label:GetPropertyChangedSignal('Text'):Connect(write) end
 end
 write()
end
local balance=player:GetAttributeChangedSignal('EventCurrencyBalance'):Connect(update)
local keyChanged=player:GetAttributeChangedSignal('EventCurrencyKey'):Connect(update)
local added=gui.DescendantAdded:Connect(function(object)
 if object.Name=='Amount' or object.Name=='EventCurrency' or object.Name=='Settings' then task.defer(update) end
end)
script.Destroying:Connect(function()
 alive=false; balance:Disconnect(); keyChanged:Disconnect(); added:Disconnect()
 if textChanged then textChanged:Disconnect() end
 label=nil
end)
update()
-- A single startup check replaces silent failures; no polling or data requests.
task.delay(10,function()
 if not alive then return end
 update()
 if not label then
  warn('EventCurrencyBalance: expected a TextLabel, TextButton, or TextBox at '..gui:GetFullName()..'.Settings.EventCurrency.Amount. Check the exact names and parenting.')
 elseif player:GetAttribute('EventCurrencyKey')~=Config.CurrencyKey or type(player:GetAttribute('EventCurrencyBalance'))~='number' then
  warn('EventCurrencyBalance: no server balance for CurrencyKey "'..tostring(Config.CurrencyKey)..'". Update Datastore and EventCurrencySystem.Wallet, and verify the saved field is numeric.')
 end
end)
