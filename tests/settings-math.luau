local Schema=require('../Tower Defense R/ReplicatedStorage/GameModules/SettingsSchema')
local Math=require('../Tower Defense R/ReplicatedStorage/GameModules/SettingsMath')
assert(Schema.Validate('Music',0)==0 and Schema.Validate('Music',100)==100)
assert(Schema.Validate('Ambience',43.21)==43.2 and Schema.Validate('Towers',120)==100)
assert(Schema.Validate('Music',0/0)==nil and Schema.Validate('Music',math.huge)==nil)
assert(Schema.Validate('unknown',100)==nil and Schema.Validate('VFX','wat')==nil)
assert(Schema.LegacyValue('VFX',false)=='Low' and Schema.LegacyValue('Dialogue',false)=='Off')
assert(Schema.LegacyValue('UIScale','ExtraLarge')=='Large')
local prefs=Schema.Normalize({Towers=0,Ambience=35,Music=77,VFX='Low',UIScale='Large'})
assert(prefs.Towers==0 and prefs.Ambience==35 and prefs.Music==77 and prefs.Dialogue=='On')
assert(Math.Percent(0,0,200,20)==0 and Math.Percent(200,0,200,20)==100)
assert(Math.Percent(100,0,200,20)==50 and Math.Percent(50,50,0,0)==0)
for _,viewport in {{1920,1080},{1280,720},{800,600},{390,844},{844,390}} do
 for _,factor in {0.9,1,1.1} do
  local w,h=viewport[1],viewport[2]
  local fitted=Math.Fit(700,500,0.5,0.5,w/2,h/2,w,h,factor,8)
  assert(fitted<=factor and 700*fitted<=w-16+0.001 and 500*fitted<=h-16+0.001,'panel must fit portrait/landscape and desktop at every preference')
 end
end
assert(Math.Fit(700,500,0.5,0.5,-100,100,800,600,1,8)==nil,'offscreen animation positions must not be pulled onto the screen')
print('Settings math passed: continuous values, finite validation, independent channels, migration, knob endpoints and fitted desktop/mobile panel scales')
