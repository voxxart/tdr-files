local Pool={}
Pool.__index=Pool
function Pool.new(maximum,parent) return setmetatable({Maximum=maximum,Parent=parent,Created=0,Free={},All={}},Pool) end
function Pool:Acquire(asset,scale)
 local slot
 while #self.Free>0 do
  local candidate=table.remove(self.Free)
  if candidate.Asset==asset then slot=candidate; break end
  candidate.Object:Destroy(); self.All[candidate]=nil; self.Created-=1
 end
 if not slot then
  if self.Created>=self.Maximum then return nil end
  local object=asset:Clone()
  if not object then return nil end
  slot={Object=object,Asset=asset,Parts={},Scale=object:IsA('Model') and object:GetScale() or 1}
  local list=object:GetDescendants()
  if object:IsA('BasePart') then table.insert(list,1,object) end
  for _,child in list do
   if child:IsA('Script') or child:IsA('LocalScript') or child:IsA('Highlight') then child:Destroy()
   elseif child:IsA('BasePart') then
    child.Anchored=true; child.CanCollide=false; child.CanQuery=false; child.CanTouch=false; child.CastShadow=false
    table.insert(slot.Parts,{Part=child,Transparency=child.Transparency,Size=child.Size})
   elseif child:IsA('ParticleEmitter') or child:IsA('Trail') or child:IsA('Beam') or child:IsA('Light') or child:IsA('Fire') or child:IsA('Smoke') or child:IsA('Sparkles') then child.Enabled=false
   elseif child:IsA('Sound') then child:Stop() end
  end
  if #slot.Parts==0 then object:Destroy(); return nil end
  if object:IsA('Model') and not object.PrimaryPart then object.PrimaryPart=slot.Parts[1].Part end
  local highlight=Instance.new('Highlight'); highlight.Name='EventCurrencyOutline'; highlight.Adornee=object
  highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; highlight.FillTransparency=1
  highlight.OutlineColor=Color3.new(1,1,1); highlight.OutlineTransparency=0; highlight.Parent=object
  slot.Highlight=highlight
  self.All[slot]=true; self.Created+=1
 end
 scale=scale or 1
 if slot.Object:IsA('Model') then slot.Object:ScaleTo(slot.Scale*scale)
 else slot.Object.Size=slot.Parts[1].Size*scale end
 local pivot=slot.Object:GetPivot()
 slot.Rotation=slot.Rotation or pivot.Rotation
 for _,entry in slot.Parts do entry.Offset=pivot:ToObjectSpace(entry.Part.CFrame); entry.Part.Transparency=entry.Transparency end
 local bottom=math.huge
 for _,entry in slot.Parts do
  local cf,size=entry.Part.CFrame,entry.Part.Size
  local extent=(math.abs(cf.RightVector.Y)*size.X+math.abs(cf.UpVector.Y)*size.Y+math.abs(cf.LookVector.Y)*size.Z)/2
  bottom=math.min(bottom,cf.Position.Y-extent)
 end
 slot.Height=pivot.Position.Y-bottom
 slot.Highlight.Enabled=true
 slot.Object.Parent=self.Parent
 slot.InUse=true
 return slot
end
function Pool:Release(slot)
 if not slot or not slot.InUse then return end
 slot.InUse=false; slot.Object.Parent=nil
 table.insert(self.Free,slot)
end
function Pool:Destroy()
 for slot in self.All do slot.Object:Destroy() end
 table.clear(self.All); table.clear(self.Free); self.Created=0
end
return Pool
