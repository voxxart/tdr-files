-- Poll legacy duration requests in the existing simulation pass, without connections.
local Effects=require(script.Parent.EnemyEffects)
local Bridge={}
function Bridge.Bind(runtime,folder)
 runtime.LegacyBurn=folder:FindFirstChild('BurnTime')
 runtime.LegacyBurnDamage=folder:FindFirstChild('FireDamage')
 runtime.LegacyBleed=folder:FindFirstChild('BleedTime')
 runtime.LegacyBleedDamage=folder:FindFirstChild('BleedDamage')
 runtime.LegacyBleedMultiplier=folder:FindFirstChild('BleedMultiplier')
 runtime.LegacyStun=folder:FindFirstChild('StunTime')
end
function Bridge.Poll(runtime,now)
 local burn,bleed,stun=runtime.LegacyBurn,runtime.LegacyBleed,runtime.LegacyStun
 if burn and burn.Parent and burn.Value>0 and runtime.LegacyBurnDamage then
  Effects.ApplyBurn(runtime,burn.Value,runtime.LegacyBurnDamage.Value,now); burn.Value=0
 end
 if bleed and bleed.Parent and bleed.Value>0 and runtime.LegacyBleedDamage and runtime.LegacyBleedMultiplier then
  Effects.ApplyBleed(runtime,bleed.Value,runtime.LegacyBleedDamage.Value,runtime.LegacyBleedMultiplier.Value,now); bleed.Value=0
 end
 if stun and stun.Parent and stun.Value>0 then Effects.ApplyStun(runtime,stun.Value,now); stun.Value=0 end
end
return Bridge
