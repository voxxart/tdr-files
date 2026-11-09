local Rep=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local Config=require(Rep.GameModules.EventCurrencyConfig)
local Assets=require(Rep.GameModules.EventCurrencyAssets)
local Match=require(game.ServerScriptService.Simulation.MatchService)
local Wallet=require(script.Parent.Wallet)
local Store=require(script.Parent.DropStore)
local Service={}
local store=Store.new(Config.MaxActiveDrops)
local random=Random.new()
local events=Rep:WaitForChild('Events')
local function remote(name,class)
 local object=events:FindFirstChild(name)
 if not object then object=Instance.new(class); object.Name=name; object.Parent=events end
 assert(object:IsA(class),name..' has the wrong class')
 return object
end
local event=remote('EventCurrency','RemoteEvent')
local snapshot=remote('EventCurrencySnapshot','RemoteFunction')
local pending={}
local personal={}
local warned=false
local requests=setmetatable({}, {__mode='k'})
local function message(record)
 local recipients={}
 for userId in record.Eligible do recipients[tostring(userId)]=true end
 return {Kind='Spawn',Id=record.Id,From=record.From,Land=record.Land,Amount=record.Amount,Age=math.max(0,Match.Now()-record.Created),Lifetime=record.Lifetime,Recipients=recipients}
end
local function remove(record,kind,player)
 if not store:Remove(record) then return end
 table.insert(pending,{Kind=kind or 'Remove',Id=record.Id,Player=player,Amount=record.Amount})
end
function Service.TryDrop(origin,map,height)
 if not Config.Enabled or not Match.IsCurrent(Match.Capture()) or #store.Active>=store.Maximum then return false end
 if random:NextNumber()>=math.clamp(Config.DropChance,0,1) then return false end
 if not Assets.Current(Rep) then
  if not warned then warn('EventCurrency: missing Model/BasePart at ReplicatedStorage.Particle.EventCurrency.Current'); warned=true end
  return false
 end
 local low=math.max(1,math.floor(Config.MinAmount)); local high=math.max(low,math.floor(Config.MaxAmount))
 local angle=random:NextNumber(0,math.pi*2)
 local radius=random:NextNumber(math.max(0,Config.ScatterMin),math.max(0,Config.ScatterMin,Config.ScatterMax))
 local candidate=origin+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include; params.FilterDescendantsInstances={map}; params.IgnoreWater=true
 local hit=workspace:Raycast(candidate+Vector3.new(0,12,0),Vector3.new(0,-100,0),params)
 local land=Vector3.new(candidate.X,(hit and hit.Position.Y or origin.Y-(height or 0))+Config.GroundOffset,candidate.Z)
 local now=Match.Now()
 local eligible={}
 for _,player in Players:GetPlayers() do eligible[player.UserId]=true end
 if next(eligible)==nil then return false end
 local record=store:Add({From=origin,Land=land,Amount=random:NextInteger(low,high),Created=now,Lifetime=math.max(1,Config.Lifetime),
  Eligible=eligible,Claimed={},Ready=now+Config.LaunchDuration+Config.BounceDuration,Generation=Match.Capture()})
 if record then table.insert(pending,message(record)); return true end
 return false
end
snapshot.OnServerInvoke=function(player)
 local now=os.clock()
 if requests[player] and now-requests[player]<2 then return {} end
 requests[player]=now
 local result={}
 for _,record in store.Active do if Match.IsCurrent(record.Generation) and record.Eligible[player.UserId] and not record.Claimed[player.UserId] then table.insert(result,message(record)) end end
 return result
end
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed<1/math.max(1,Config.PickupHz) then return end
 elapsed=0
 local now=Match.Now()
 if #store.Active>0 then
  local candidates={}
  if Config.Enabled and workspace.Info.GameSpeed.Value>0 then
   for _,player in Players:GetPlayers() do
    local character=player.Character
    local root=character and character:FindFirstChild('HumanoidRootPart')
    local humanoid=character and character:FindFirstChildOfClass('Humanoid')
    if root and humanoid and humanoid.Health>0 and Wallet.CanCredit(player) then table.insert(candidates,{Player=player,Position=root.Position}) end
   end
  end
  for index=#store.Active,1,-1 do
   local record=store.Active[index]
   if not Config.Enabled or not Match.IsCurrent(record.Generation) or now-record.Created>=record.Lifetime then remove(record)
   elseif now>=record.Ready then
    for _,candidate in candidates do
     local player=candidate.Player
     if record.Eligible[player.UserId] and not record.Claimed[player.UserId] then
      local delta=candidate.Position-record.Land
      if delta:Dot(delta)<=Config.PickupRadius^2 and Wallet.Credit(player,record.Amount) then
       record.Claimed[player.UserId]=true
       local queue=personal[player]; if not queue then queue={}; personal[player]=queue end
       table.insert(queue,{Kind='Collect',Id=record.Id,Amount=record.Amount,Player=player})
      end
     end
    end
    local all=true
    for userId in record.Eligible do if not record.Claimed[userId] then all=false; break end end
    if all then store:Remove(record) end
   end
  end
 end
 if #pending>0 then
  -- Spawn age includes time spent in this shared flush queue.
  for _,op in pending do if op.Kind=='Spawn' then local record=store.ById[op.Id]; if record then op.Age=math.max(0,now-record.Created) end end end
  event:FireAllClients(pending); pending={}
 end
 for player,queue in pairs(personal) do
  if player.Parent then event:FireClient(player,queue) end
  personal[player]=nil
 end
end)
Players.PlayerRemoving:Connect(function(player)
 personal[player]=nil; requests[player]=nil
 for index=#store.Active,1,-1 do
  local record=store.Active[index]
  record.Eligible[player.UserId]=nil; record.Claimed[player.UserId]=nil
  local all=true
  for userId in record.Eligible do if not record.Claimed[userId] then all=false; break end end
  if all then remove(record) end
 end
end)
function Service.GetDiagnostics() return {ActiveDrops=#store.Active,Maximum=store.Maximum} end
return Service
