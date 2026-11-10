local Ground={}
function Ground.Find(world,map,origin,height,random,config,cast,clear)
 if not map then return nil end
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances={map:FindFirstChild('EventCurrencyFloor') or map}
 params.IgnoreWater=true; params.RespectCanCollide=true
 local expectedY=origin.Y-(height or 0)
 local rise=math.max(0,config.MaxFloorRise or 1.5)
 local depth=math.max(1,config.FloorSearchDepth or 32)
 local tries=math.clamp(config.LandingAttempts or 3,1,6)
 for attempt=1,tries+1 do
  local candidate=origin
  if attempt<=tries then
   local angle=random:NextNumber(0,math.pi*2)
   local radius=random:NextNumber(math.max(0,config.ScatterMin),math.max(0,config.ScatterMin,config.ScatterMax))
   candidate=origin+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
  end
  local start=Vector3.new(candidate.X,expectedY+rise+0.25,candidate.Z)
  local bottom=expectedY-depth
  for _=1,4 do
   local hit=cast(start,Vector3.new(0,bottom-start.Y,0),params)
   if not hit then break end
   if hit.Normal.Y>=(config.MinFloorNormalY or 0.75) and hit.Position.Y<=expectedY+rise and hit.Position.Y>=bottom then
    if not clear or clear(hit,map) then return hit.Position+Vector3.new(0,config.GroundOffset,0) end
    break
   end
   start=Vector3.new(candidate.X,math.min(start.Y-0.05,hit.Position.Y-0.05),candidate.Z)
   if start.Y<=bottom then break end
  end
 end
 return nil
end
return Ground
