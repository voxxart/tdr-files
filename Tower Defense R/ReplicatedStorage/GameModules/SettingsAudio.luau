local SoundService=game:GetService('SoundService')
local Audio={}; Audio.__index=Audio
function Audio.new(world)
 local self=setmetatable({World=world,Groups={},Sounds=setmetatable({}, {__mode='k'}),Routes={},SourceByRoute={},RouteCount=0,Roots={},Connections={}},Audio)
 self.Folder=Instance.new('SoundGroup'); self.Folder.Name='LocalSettingsAudio'; self.Folder.Parent=SoundService
 for _,key in {'Towers','Music','Ambience'} do
  local group=Instance.new('SoundGroup'); group.Name=key; group.Parent=self.Folder; self.Groups[key]=group; self.SourceByRoute[group]=false; self.Routes[key]={}
 end
 local function added(object)
  if object:IsA('Sound') then self:Attach(object)
  elseif ({Towers=true,Mobs=true,Units=true,Visual=true,Music=true,Ambience=true,Ambient=true})[object.Name] then self:WatchRoot(object) end
 end
 table.insert(self.Connections,world.DescendantAdded:Connect(added))
 table.insert(self.Connections,world.DescendantRemoving:Connect(function(object) self:UnwatchRoot(object); self:Release(object) end))
 for _,object in world:GetDescendants() do added(object) end
 return self
end
function Audio:Release(sound)
 local record=self.Sounds[sound]; if not record then return end
 self.Sounds[sound]=nil
 if record.Connection then record.Connection:Disconnect() end
 sound.SoundGroup=record.Group
end
function Audio:UnwatchRoot(root)
 local connections=self.Roots[root]; if not connections then return end
 self.Roots[root]=nil
 for _,connection in connections do connection:Disconnect() end
end
function Audio:WatchRoot(root)
 if self.Destroyed then return end
 if self.Roots[root] then return end
 local connections={}; self.Roots[root]=connections
 -- Workspace.DescendantAdded need not fire when an existing map sound moves
 -- into another folder inside Workspace. Observe the category folder itself.
 table.insert(connections,root.DescendantAdded:Connect(function(object) if object:IsA('Sound') then self:Attach(object) end end))
 table.insert(connections,root.DescendantRemoving:Connect(function(object)
  if not object:IsA('Sound') then return end
  task.defer(function()
   if self.Destroyed then return end
   if object:IsDescendantOf(self.World) then self:Attach(object) else self:Release(object) end
  end)
 end))
 table.insert(connections,root.Destroying:Connect(function() self:UnwatchRoot(root) end))
 for _,object in root:GetDescendants() do if object:IsA('Sound') then self:Attach(object) end end
end
function Audio:Category(sound)
 local explicit=sound:GetAttribute('SettingsCategory')
 if self.Groups[explicit] then return explicit end
 local current=sound
 while current and current~=self.World do
  if current~=sound and (current:IsA('Folder') or current:IsA('Model')) then
   if current.Name=='Ambience' or current.Name=='Ambient' then return 'Ambience' end
   if current.Name=='Music' then return 'Music' end
  end
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
 if self.Destroyed then return end
 if not sound:IsDescendantOf(self.World) then self:Release(sound); return end
 local category=self:Category(sound)
 local record=self.Sounds[sound]
 if not category then if record then self:Release(sound) end; return end
 if record and record.Category==category and sound.SoundGroup==record.Route then return end
 local original=sound.SoundGroup
 if record and original==record.Route then original=record.Group end
 if self.SourceByRoute[original]~=nil then original=self.SourceByRoute[original] or nil end
 if record and record.Connection then record.Connection:Disconnect() end
 record={Group=original,Category=category,Route=self:Route(original,category)}
 self.Sounds[sound]=record
 sound.SoundGroup=record.Route
 if category=='Ambience' or category=='Music' then
  record.Connection=sound:GetPropertyChangedSignal('SoundGroup'):Connect(function()
   if sound.SoundGroup~=record.Route then self:Attach(sound) end
  end)
 end
end
function Audio:Set(category,percent) self.Groups[category].Volume=math.clamp(percent,0,100)/100 end
function Audio:Destroy()
 self.Destroyed=true
 for _,connections in self.Roots do for _,connection in connections do connection:Disconnect() end end
 table.clear(self.Roots)
 for _,connection in self.Connections do connection:Disconnect() end
 for sound,original in self.Sounds do
  if original.Connection then original.Connection:Disconnect() end
  if sound.Parent then sound.SoundGroup=original.Group end
 end
 self.Folder:Destroy(); table.clear(self.Sounds); table.clear(self.Connections); table.clear(self.Routes)
end
return Audio
