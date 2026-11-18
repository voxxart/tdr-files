-- Client-only photon shots. Static core + optional glow, with pooled impacts.
local Rep = game:GetService('ReplicatedStorage')
local Lightning = require(Rep:FindFirstChild('LightningBolt') or Rep.GameModules:WaitForChild('LightningBolt'))
local Photon = {}
Photon.__index = Photon
Photon.DefaultColor = Color3.fromRGB(100, 210, 255)
Photon.MaxActive = 48
local DURATION = 0.18
local IMPACT_DIAMETER = 1.75
-- Immediate full-length strike, then a fast energy decay. No travelling projectile
-- or repeated flashes: opacity only decreases throughout the shot.
local function coreOpacity(_, elapsed)
 return math.clamp((DURATION-elapsed)/0.04,0,1) * (0.2+0.8*math.exp(-elapsed/0.055))
end
local function glowOpacity(_, elapsed)
 return math.clamp((DURATION-elapsed)/0.06,0,1) * (0.08+0.4*math.exp(-elapsed/0.025))
end
local function makeLayer(from,to,direction,color,width,profile)
 local bolt=Lightning.new({WorldPosition=from,WorldAxis=direction},{WorldPosition=to,WorldAxis=direction},1)
 bolt.Static=true; bolt.StaticLifetime=DURATION
 bolt.MaxRadius=0; bolt.MinRadius=0
 bolt.AnimationSpeed=0; bolt.ColorOffsetSpeed=0
 bolt.Thickness=width; bolt.MinThicknessMultiplier=1; bolt.MaxThicknessMultiplier=1
 bolt.ContractFrom=2; bolt.Color=color; bolt.OpacityProfileFunction=profile
 return bolt
end
local function valid(p)
 return p.X==p.X and p.Y==p.Y and p.Z==p.Z
  and math.abs(p.X)<100000 and math.abs(p.Y)<100000 and math.abs(p.Z)<100000
end
function Photon.new(world)
 local folder=Instance.new('Folder'); folder.Name='RailgunnerPhotonVisuals'; folder.Parent=world
 local storage=Instance.new('Folder'); storage.Name='PhotonImpactCache'
 return setmetatable({Folder=folder,Storage=storage,Active={},Free={}},Photon)
end
function Photon:Emit(from,to,color,low)
 if self.Destroyed or #self.Active >= (if low then 16 else Photon.MaxActive) then return false end
 if not valid(from) or not valid(to) then return false end
 local delta=to-from; local distance=delta.Magnitude
 if distance<0.01 or distance>512 then return false end
 local direction=delta.Unit
 local bolt=makeLayer(from,to,direction,if low then color else color:Lerp(Color3.new(1,1,1),0.65),0.075,coreOpacity)
 local glow=if low then nil else makeLayer(from,to,direction,color,0.28,glowOpacity)
 local impact=table.remove(self.Free)
 if not impact then
  impact=Instance.new('Part'); impact.Name='PhotonImpact'
  impact.Shape=Enum.PartType.Ball; impact.Material=Enum.Material.Neon
  impact.Anchored=true; impact.CanCollide=false; impact.CanTouch=false; impact.CanQuery=false; impact.CastShadow=false
 end
 -- Laser hits are instantaneous: the impact appears where the beam terminates.
 impact.Transparency=1; impact.Color=color; impact.Size=Vector3.new(0.18,0.18,0.18)
 impact.CFrame=CFrame.new(to); impact.Parent=self.Folder; impact.Transparency=0.2
 table.insert(self.Active,{Bolt=bolt,Glow=glow,Impact=impact,Elapsed=0})
 return true
end
function Photon:Release(record)
 record.Bolt:Destroy()
 if record.Glow then record.Glow:Destroy() end
 record.Impact.Transparency=1; record.Impact.Parent=self.Storage
 table.insert(self.Free,record.Impact)
end
function Photon:Step(dt)
 for i=#self.Active,1,-1 do
  local record=self.Active[i]; record.Elapsed+=math.max(0,dt)
  if record.Elapsed>=DURATION then
   self:Release(record)
   self.Active[i]=self.Active[#self.Active]; self.Active[#self.Active]=nil
  else
   local alpha=record.Elapsed/DURATION
   local size=0.18+(IMPACT_DIAMETER-0.18)*alpha
   record.Impact.Size=Vector3.new(size,size,size)
   record.Impact.Transparency=0.2+0.8*alpha
  end
 end
end
function Photon:Clear()
 for _,record in self.Active do self:Release(record) end
 table.clear(self.Active)
end
function Photon:Destroy()
 if self.Destroyed then return end
 self.Destroyed=true; self:Clear(); self.Folder:Destroy(); self.Storage:Destroy(); table.clear(self.Free)
end
return Photon
