"""Execute the purchase controller against the provided UI hierarchy."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'Tower Defense R/StarterGui/GameGui/TimescaleController.client.luau').read_text()
code=r'''
local function signal()
 local s={F={}}
 function s:Connect(fn) local c={Live=true};self.F[c]=fn;function c:Disconnect() self.Live=false end;return c end
 function s:Fire(...) for c,fn in self.F do if c.Live then fn(...) end end end
 return s
end
local function node(children)
 local n={Children=children or {},Parent=true,Visible=true,Activated=signal(),Attributes={},Signals={}}
 function n:FindFirstChild(k) return self.Children[k] end
 function n:WaitForChild(k) return assert(self.Children[k],k) end
 function n:IsA(k) return self.Kind==k end
 function n:FindFirstChildWhichIsA(k) return self.Children.Text end
 function n:GetAttribute(k) return self.Attributes[k] end
 function n:GetAttributeChangedSignal(k) self.Signals[k]=self.Signals[k] or signal();return self.Signals[k] end
 function n:SetAttribute(k,v) self.Attributes[k]=v;if self.Signals[k] then self.Signals[k]:Fire() end end
 return setmetatable(n,{__index=function(self,k) return self.Children[k] end})
end
local player=node()
player:SetAttribute('TimescalePurchaseReady',true)
player:SetAttribute('TimescaleGems',200)
player:SetAttribute('UnlockedTimescale',0)
local main=node();local buy=node();local close=node();local label=node();local message=node({Text=node()}); message.Text.Text='Authored purchase message'
local menu=node({Actions=node({Purchase=node({Button=buy})}),Close=close,Gems=node({Amount=label}),Message=message})
local successSound=node();successSound.Kind='Sound'
local plays=0;function successSound:Play() plays+=1 end
local successTemplate=node()
local shown
function successTemplate:Clone()
 local label=node();label.Kind='TextLabel'
 shown=node({Main=label});function shown:Destroy() self.Parent=nil end
 return shown
end
local speedLabel=node();speedLabel.Kind='TextLabel'
local gui=node({Timescale=node({ButtonNumber=speedLabel}),Sounds=node({PurchasedSuccessful=successSound}),Messages=node({Message=successTemplate}),PurchaseTimescale=menu,Misc=node({Timescale=node({Button=main})})})
local statusCalls,purchases,speedCalls=0,0,0
local remote={InvokeServer=function(_,action)
 if action=='Status' then statusCalls+=1;return {Price=500} end
 purchases+=1
 if player:GetAttribute('TimescaleGems')<500 then return {Success=false,Error='You need 300 gems to purchase this!'} end
 player:SetAttribute('TimescaleGems',player:GetAttribute('TimescaleGems')-500)
 player:SetAttribute('UnlockedTimescale',1)
 return {Success=true,Changed=true}
end}
local functions=node({PurchaseTimescale=remote,RequestTimescale={InvokeServer=function() speedCalls+=1;return {Success=true} end}})
local rep=node({Functions=functions})
local game={GetService=function(_,name) return if name=='Players' then {LocalPlayer=player} else rep end}
local speed=node();speed.Value=1;speed.Changed=signal()
local workspace=node({Info={GameSpeed=speed}})
local script=node();function script:FindFirstAncestorWhichIsA() return gui end
script.Destroying=signal()
local errors={}
local warn=function(s) table.insert(errors,s) end
local task={spawn=function(f) f() end,delay=function() end}
'''+source+r'''
assert(not menu.Visible and label.Text=='200' and speedLabel.Text=='1x')
speed.Value=1.5;speed.Changed:Fire();assert(speedLabel.Text=='1.5x')
speed.Value=1;speed.Changed:Fire()
main.Activated:Fire();assert(menu.Visible and message.Visible)
assert(message.Text.Text=='Authored purchase message')
buy.Activated:Fire();assert(menu.Visible and errors[1]=='You need 300 gems to purchase this!')
close.Activated:Fire();assert(not menu.Visible)
player:SetAttribute('TimescaleGems',800)
main.Activated:Fire();assert(menu.Visible and not message.Visible and label.Text=='800')
buy.Activated:Fire();assert(not menu.Visible and label.Text=='300')
assert(plays==1 and shown.Main.Text=='Successfully purchased Timescale!' and shown.Visible)
main.Activated:Fire();assert(speedCalls==1 and not menu.Visible)
assert(purchases==2)
script.Destroying:Fire()
print('Timescale UI: opening, balance, shortage, close, successful purchase and owner speed control passed')
'''
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau') as f:
 f.write(code);f.flush();subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True)
