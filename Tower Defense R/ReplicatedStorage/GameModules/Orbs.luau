-- Shared farm/event orb presentation. Play(name,duration,amount,position,player).
local RunService=game:GetService('RunService')
local Rep=game:GetService('ReplicatedStorage')
local Player=game:GetService('Players').LocalPlayer
local Orbs={Settings={MaxActive=256,MaxPerFrame=64,MaxPerCall=8,FadeDuration=0.2}}
local storage=Instance.new('Folder'); storage.Name='OrbsClient'; storage.Parent=workspace
local active,free={},{}
local created,tokens=0,Orbs.Settings.MaxPerFrame
local random=Random.new()
local parts,frames={},{}
local function release(index)
 local entry=active[index]
 entry.Object.Parent=nil
 entry.Root=nil; entry.From=nil; entry.Target=nil; entry.Control=nil
 for _,fx in entry.Effects do fx.Object.Enabled=false; fx.Object:Clear() end
 active[index]=active[#active]; active[#active]=nil
 table.insert(free,entry)
end
local function choose(name)
 local particle=Rep:FindFirstChild('Particle'); local folder=particle and particle:FindFirstChild('Orb')
 local asset=folder and folder:FindFirstChild(name)
 if not asset then return nil end
 if asset:IsA('BasePart') or asset:IsA('Model') then return asset end
 local choices={}
 for _,child in asset:GetChildren() do if child:IsA('BasePart') or child:IsA('Model') then table.insert(choices,child) end end
 if #choices==0 then return nil end
 return choices[random:NextInteger(1,#choices)]
end
local function acquire(asset)
 local entry
 while #free>0 do
  local candidate=table.remove(free)
  if candidate.Asset==asset then entry=candidate; break end
  candidate.Object:Destroy(); created-=1
 end
 if not entry then
  if created>=Orbs.Settings.MaxActive then return nil end
  local object=asset:Clone(); if not object then return nil end
  entry={Object=object,Asset=asset,Parts={},Effects={}}
  local objects=object:GetDescendants(); if object:IsA('BasePart') then table.insert(objects,1,object) end
  for _,child in objects do
   if child:IsA('Script') or child:IsA('LocalScript') then child:Destroy()
   elseif child:IsA('BasePart') then
    child.Anchored=true; child.CanCollide=false; child.CanTouch=false; child.CanQuery=false; child.CastShadow=false
    table.insert(entry.Parts,{Part=child,Transparency=child.Transparency})
   elseif child:IsA('ParticleEmitter') or child:IsA('Trail') then table.insert(entry.Effects,{Object=child,Enabled=child.Enabled})
   elseif child:IsA('Sound') then child:Stop() end
  end
  if #entry.Parts==0 then object:Destroy(); return nil end
  if object:IsA('Model') and not object.PrimaryPart then object.PrimaryPart=entry.Parts[1].Part end
  local pivot=object:GetPivot(); entry.Rotation=pivot.Rotation
  for _,part in entry.Parts do part.Offset=pivot:ToObjectSpace(part.Part.CFrame) end
  created+=1
 end
 for _,part in entry.Parts do part.Part.Transparency=part.Transparency end
 for _,fx in entry.Effects do fx.Object.Enabled=fx.Enabled end
 entry.Object.Parent=storage
 return entry
end
function Orbs.Play(name,duration,amount,position,targetPlayer)
 if targetPlayer~=Player or tokens<1 or #active>=Orbs.Settings.MaxActive then return 0 end
 local character=targetPlayer.Character; local root=character and character:FindFirstChild('HumanoidRootPart')
 if not root then return 0 end
 local asset=choose(name); if not asset then return 0 end
 local count=math.min(math.max(0,math.floor(amount or 1)),Orbs.Settings.MaxPerCall,tokens,Orbs.Settings.MaxActive-#active)
 local accepted=0
 for _=1,count do
  local entry=acquire(asset); if not entry then break end
  entry.From=position; entry.Root=root; entry.Target=root.Position; entry.Age=0; entry.Fade=false
  entry.Duration=math.max(0.01,tonumber(duration) or 0.25)
  local start=CFrame.new(position)*entry.Rotation
  for _,part in entry.Parts do part.Part.CFrame=start*part.Offset end
  entry.Control=(position+root.Position)/2+Vector3.new(random:NextNumber(-3,3),random:NextNumber(3,6),random:NextNumber(-3,3))
  table.insert(active,entry); tokens-=1; accepted+=1
 end
 return accepted
end
RunService.Heartbeat:Connect(function(dt)
 tokens=Orbs.Settings.MaxPerFrame
 table.clear(parts); table.clear(frames)
 for index=#active,1,-1 do
  local entry=active[index]
  if not entry.Root.Parent then release(index); continue end
  entry.Age+=math.max(dt,0)
  local position
  if entry.Fade then
   local alpha=math.clamp(entry.Age/math.max(0.01,Orbs.Settings.FadeDuration),0,1)
   if alpha>=1 then release(index); continue end
   position=entry.Root.Position
   for _,part in entry.Parts do part.Part.Transparency=part.Transparency+(1-part.Transparency)*alpha end
  else
   local t=math.clamp(entry.Age/entry.Duration,0,1)
   entry.Target=entry.Root.Position
   position=(1-t)^2*entry.From+2*(1-t)*t*entry.Control+t^2*entry.Target
   if t>=1 then entry.Fade=true; entry.Age=0 end
  end
  local cf=CFrame.new(position)*entry.Rotation
  for _,part in entry.Parts do table.insert(parts,part.Part); table.insert(frames,cf*part.Offset) end
 end
 if #parts>0 then workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged) end
end)
function Orbs.GetDiagnostics() return {Active=#active,Allocated=created,Maximum=Orbs.Settings.MaxActive} end
return Orbs
