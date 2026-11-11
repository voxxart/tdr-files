local Arc=require(script.Parent.ProjectileArc)
local Flights={}; Flights.__index=Flights
function Flights.new(world,parent)
 return setmetatable({World=world,Parent=parent,Active={},Parts={},Frames={},Builds=0,Maximum=128},Flights)
end
function Flights:Launch(template,from,to,duration,height,forward,offset,impact)
 if #self.Active>=self.Maximum or self.Builds>=16 then return false end
 self.Builds+=1
 local object=template:Clone(); local pivot=object:GetPivot(); local parts={}
 local function prepare(part)
  part.Anchored=true; part.CanCollide=false; part.CanQuery=false; part.CanTouch=false
  table.insert(parts,{Part=part,Offset=pivot:ToObjectSpace(part.CFrame)})
 end
 if object:IsA('BasePart') then prepare(object) end
 for _,child in object:GetDescendants() do
  if child:IsA('Script') or child:IsA('LocalScript') then child:Destroy()
  elseif child:IsA('BasePart') then prepare(child) end
 end
 if #parts==0 then object:Destroy(); return false end
 local arc=Arc.new(from,to,height,forward)
 local p,d,u=arc:Sample(0); object:PivotTo(CFrame.lookAt(p,p+d,u)*(offset or CFrame.new())); object.Parent=self.Parent
 table.insert(self.Active,{Object=object,Parts=parts,Arc=arc,Time=0,Duration=math.max(0.05,duration),Offset=offset or CFrame.new(),Impact=impact})
 return true
end
function Flights:Step(dt)
 self.Builds=0; table.clear(self.Parts); table.clear(self.Frames)
 local completed={}
 for index=#self.Active,1,-1 do
  local flight=self.Active[index]
  if not flight.Object.Parent then
   self.Active[index]=self.Active[#self.Active]; self.Active[#self.Active]=nil; flight.Object:Destroy()
  else
   flight.Time+=math.max(0,dt)
   local progress=math.min(1,flight.Time/flight.Duration)
   local p,d,u=flight.Arc:Sample(progress); local cf=CFrame.lookAt(p,p+d,u)*flight.Offset
   for _,entry in flight.Parts do table.insert(self.Parts,entry.Part); table.insert(self.Frames,cf*entry.Offset) end
   if progress>=1 then
    table.insert(completed,flight); self.Active[index]=self.Active[#self.Active]; self.Active[#self.Active]=nil
   end
  end
 end
 if #self.Parts>0 then self.World:BulkMoveTo(self.Parts,self.Frames,Enum.BulkMoveMode.FireCFrameChanged) end
 table.clear(self.Parts); table.clear(self.Frames)
 for _,flight in completed do flight.Object:Destroy(); local ok,err=pcall(flight.Impact); if not ok then warn('Mortar impact presentation failed:',err) end end
end
function Flights:Clear()
 for _,flight in self.Active do flight.Object:Destroy() end
 table.clear(self.Active); table.clear(self.Parts); table.clear(self.Frames); self.Builds=0
end
return Flights
