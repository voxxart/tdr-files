local Players=game:GetService('Players')
local Policy={Used=0,Slice=-1}
function Policy.Quality()
 local player=Players.LocalPlayer
 return (player and (player:GetAttribute('LocalVFXQuality') or player:GetAttribute('SettingVFX'))) or 'High'
end
function Policy.Count(count,quality,essential)
 if type(count)~='number' or count~=count or math.abs(count)==math.huge then return 0 end
 count=math.max(0,math.floor(count))
 if quality=='Low' then return math.min(24,if count>0 then math.max(if essential then 1 else 0,math.floor(count*0.25)) else 0) end
 return math.min(count,120)
end
function Policy.Emit(emitter,count)
 if not emitter or not emitter:IsA('ParticleEmitter') then return end
 local quality=Policy.Quality(); local slice=math.floor(os.clock()*60)
 if slice~=Policy.Slice then Policy.Slice=slice; Policy.Used=0 end
 local limit=if quality=='Low' then 96 else 512
 local amount=math.min(Policy.Count(count,quality,emitter:GetAttribute('VFXEssential')==true),math.max(0,limit-Policy.Used))
 if amount>0 then Policy.Used+=amount; emitter:Emit(amount) end
end
return Policy
