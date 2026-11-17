local SoundService=game:GetService('SoundService')
local Audio={}; Audio.__index=Audio
function Audio.new(world)
 local self=setmetatable({World=world,Groups={},Sounds=setmetatable({}, {__mode='k'}),Routes={},SourceByRoute={},RouteCount=0,Connections={}},Audio)
 self.Folder=Instance.new('SoundGroup'); self.Folder.Name='LocalSettingsAudio'; self.Folder.Parent=SoundService
 for _,key in {'Towers','Music','Ambience'} do
  local group=Instance.new('SoundGroup'); group.Name=key; group.Parent=self.Folder; self.Groups[key]=group; self.SourceByRoute[group]=false; self.Routes[key]={}
 end
 local function added(object) if object:IsA('Sound') then self:Attach(object) end end
 table.insert(self.Connections,world.DescendantAdded:Connect(added))
 table.insert(self.Connections,world.DescendantRemoving:Connect(function(object)
  local original=self.Sounds[object]
  if original then object.SoundGroup=original.Group; self.Sounds[object]=nil end
 end))
 for _,object in world:GetDescendants() do added(object) end
 return self
end
function Audio:Category(sound)
 local explicit=sound:GetAttribute('SettingsCategory')
 if self.Groups[explicit] then return explicit end
 local current=sound
 while current and current~=self.World do
  if current.Parent==self.World then
   if current.Name=='Music' then return 'Music' end
   if current.Name=='Ambience' then return 'Ambience' end
   if current.Name=='Towers' or current.Name=='Mobs' or current.Name=='Units' or current.Name=='Visual' then return 'Towers' end
  end
  current=current.Parent
 end
 return nil
end
function Audio:Route(original,category)
 if not original then return self.Groups[category] end
 local routes=self.Routes[category]
 if routes[original] then return routes[original] end
 if self.RouteCount>=64 then return self.Groups[category] end
 self.RouteCount+=1
 local route=Instance.new('SoundGroup'); route.Name='AuthoredMix'; route.Volume=original.Volume
 local ancestor=original.Parent
 route.Parent=if ancestor and ancestor:IsA('SoundGroup') then self:Route(ancestor,category) else self.Groups[category]
 for _,effect in original:GetChildren() do if effect:IsA('SoundEffect') then effect:Clone().Parent=route end end
 routes[original]=route; self.SourceByRoute[route]=original
 -- One listener per authored group, not one per sound.
 table.insert(self.Connections,original:GetPropertyChangedSignal('Volume'):Connect(function() route.Volume=original.Volume end))
 return route
end
function Audio:Attach(sound)
 if self.Sounds[sound] then return end
 local category=self:Category(sound); if not category then return end
 local original=sound.SoundGroup
 if self.SourceByRoute[original]~=nil then original=self.SourceByRoute[original] or nil end
 self.Sounds[sound]={Group=original}; sound.SoundGroup=self:Route(original,category)
end
function Audio:Set(category,percent) self.Groups[category].Volume=math.clamp(percent,0,100)/100 end
function Audio:Destroy()
 for _,connection in self.Connections do connection:Disconnect() end
 for sound,original in self.Sounds do if sound.Parent then sound.SoundGroup=original.Group end end
 self.Folder:Destroy(); table.clear(self.Sounds); table.clear(self.Connections); table.clear(self.Routes)
end
return Audio
