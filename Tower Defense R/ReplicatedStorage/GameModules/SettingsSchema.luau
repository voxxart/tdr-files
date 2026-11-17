local Schema={}
Schema.Defaults={Towers=100,Ambience=100,Music=100,Dialogue='On',VFX='High',UIScale='Default'}
Schema.ScaleFactors={Small=0.9,Default=1,Large=1.1}
Schema.Legacy={
 Towers={Store='VolumePreferences',Prefix=''},
 Ambience={Store='AmbientVolumePreferences',Prefix=''},
 Music={Store='MusicVolumePreferences',Prefix=''},
 Dialogue={Store='DialogueSettings',Prefix='Dialogue_MODE_'},
 VFX={Store='VFXSetting',Prefix='VFX_MODE_'},
 UIScale={Store='UiScaleSetting',Prefix='UI_SCALE_'},
}
function Schema.Validate(key,value)
 if key=='Towers' or key=='Ambience' or key=='Music' then
  if type(value)~='number' or value~=value or math.abs(value)==math.huge then return nil end
  return math.round(math.clamp(value,0,100)*10)/10
 elseif key=='Dialogue' then return if value=='On' or value=='Off' then value else nil
 elseif key=='VFX' then return if value=='High' or value=='Low' then value else nil
 elseif key=='UIScale' then return if type(value)=='string' and Schema.ScaleFactors[value] then value else nil end
 return nil
end
function Schema.LegacyValue(key,value)
 if key=='VFX' and type(value)=='boolean' then return if value then 'High' else 'Low' end
 if key=='Dialogue' and type(value)=='boolean' then return if value then 'On' else 'Off' end
 if key=='UIScale' and value=='ExtraLarge' then return 'Large' end
 return Schema.Validate(key,value)
end
function Schema.Normalize(values)
 local result={}
 for key,default in Schema.Defaults do result[key]=Schema.Validate(key,type(values)=='table' and values[key] or nil) or default end
 return result
end
return Schema
