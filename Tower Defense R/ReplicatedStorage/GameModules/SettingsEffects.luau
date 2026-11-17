local Lighting=game:GetService('Lighting')
local Effects={}; Effects.__index=Effects
function Effects.new(world,player)
 local self=setmetatable({World=world,Player=player,Quality='High',Shadows=Lighting.GlobalShadows,AppliedShadows=Lighting.GlobalShadows,Emitters=setmetatable({}, {__mode='k'}),Connections={}},Effects)
 local function add(object)
  if object:IsA('ParticleEmitter') then
   local original=object:GetAttribute('SettingsBaseRate')
   self.Emitters[object]={Base=if type(original)=='number' then original else object.Rate,Applied=object.Rate,Original=original}
   self:Apply(object,self.Emitters[object])
  end
 end
 table.insert(self.Connections,world.DescendantAdded:Connect(add))
 table.insert(self.Connections,world.DescendantRemoving:Connect(function(object)
  local record=self.Emitters[object]; if record then object.Rate=record.Base; object:SetAttribute('SettingsBaseRate',record.Original); self.Emitters[object]=nil end
 end))
 for _,object in world:GetDescendants() do add(object) end
 table.insert(self.Connections,Lighting:GetPropertyChangedSignal('GlobalShadows'):Connect(function()
  if Lighting.GlobalShadows~=self.AppliedShadows then
   self.Shadows=Lighting.GlobalShadows; self.AppliedShadows=if self.Quality=='Low' then false else self.Shadows
   Lighting.GlobalShadows=self.AppliedShadows
  end
 end))
 return self
end
function Effects:Apply(object,record)
 if object.Rate~=record.Applied then record.Base=object.Rate end
 record.Applied=record.Base*(if self.Quality=='Low' then 0.25 else 1)
 object:SetAttribute('SettingsBaseRate',record.Base)
 object.Rate=record.Applied -- Preserve Enabled; never turn disabled template emitters on.
end
function Effects:Set(quality)
 self.Quality=quality; self.Player:SetAttribute('LocalVFXQuality',quality)
 self.AppliedShadows=if quality=='Low' then false else self.Shadows
 Lighting.GlobalShadows=self.AppliedShadows
 for object,record in self.Emitters do if object.Parent then self:Apply(object,record) end end
end
function Effects:Destroy()
 for _,connection in self.Connections do connection:Disconnect() end
 for object,record in self.Emitters do if object.Parent and object.Rate==record.Applied then object.Rate=record.Base; object:SetAttribute('SettingsBaseRate',record.Original) end end
 Lighting.GlobalShadows=self.Shadows; self.Player:SetAttribute('LocalVFXQuality',nil)
 table.clear(self.Emitters); table.clear(self.Connections)
end
return Effects
