-- Client cosmetic pool. No per-shot tweens, tasks, connections, physics, or remotes.
local Tracers={}
Tracers.__index=Tracers
Tracers.Settings={MaxActive=256,ShotsPerSecond=1200,Burst=64,Speed=500,Length=1.8,Width=0.09,MaxDistance=350}
function Tracers.new(world)
 local folder=Instance.new('Folder'); folder.Name='TowerBulletVisuals'; folder.Parent=world
 return setmetatable({World=world,Folder=folder,Active={},Free={},Created=0,Tokens=Tracers.Settings.Burst,Parts={},Frames={}},Tracers)
end
function Tracers:Emit(from,to)
 local settings=Tracers.Settings
 if self.Tokens<1 or #self.Active>=settings.MaxActive then return false end
 local delta=to-from
 local distance=delta.Magnitude
 if distance~=distance or distance<0.01 or distance==math.huge then return false end
 local record=table.remove(self.Free)
 if not record then
  if self.Created>=settings.MaxActive then return false end
  local part=Instance.new('Part')
  part.Name='BulletTracer'; part.Anchored=true; part.CanCollide=false; part.CanTouch=false; part.CanQuery=false
  part.CastShadow=false; part.Material=Enum.Material.Neon; part.Color=Color3.fromRGB(255,224,145)
  part.Transparency=1; part.Parent=self.Folder
  record={Part=part}; self.Created+=1
 end
 self.Tokens-=1
 record.From=from; record.Direction=delta/distance; record.Distance=distance; record.Elapsed=0
 record.Duration=math.clamp(distance/settings.Speed,0.05,0.5)
 record.Rotation=CFrame.lookAt(Vector3.zero,record.Direction).Rotation
 record.Part.Size=Vector3.new(settings.Width,settings.Width,0.01)
 record.Part.CFrame=record.Rotation+from; record.Part.Transparency=0
 table.insert(self.Active,record)
 return true
end
function Tracers:Step(dt,speed,low)
 local settings=Tracers.Settings
 local rate=if low then settings.ShotsPerSecond/4 else settings.ShotsPerSecond
 self.Tokens=math.min(settings.Burst,self.Tokens+math.max(dt,0)*rate)
 local parts,frames=self.Parts,self.Frames
 table.clear(parts); table.clear(frames)
 for index=#self.Active,1,-1 do
  local record=self.Active[index]
  record.Elapsed+=math.max(dt,0)*math.max(speed,0)
  if record.Elapsed>=record.Duration then
   record.Part.Transparency=1
   self.Active[index]=self.Active[#self.Active]; self.Active[#self.Active]=nil
   table.insert(self.Free,record)
  else
   local travelled=record.Distance*record.Elapsed/record.Duration
   local length=math.min(settings.Length,math.max(0.01,travelled))
   record.Part.Size=Vector3.new(settings.Width,settings.Width,length)
   table.insert(parts,record.Part)
   table.insert(frames,record.Rotation+(record.From+record.Direction*(travelled-length/2)))
  end
 end
 if #parts>0 then self.World:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged) end
end
function Tracers:Clear()
 for _,record in self.Active do record.Part.Transparency=1; table.insert(self.Free,record) end
 table.clear(self.Active); table.clear(self.Parts); table.clear(self.Frames)
 self.Tokens=0
end
function Tracers:Destroy()
 self:Clear(); table.clear(self.Free); self.Folder:Destroy()
end
return Tracers
