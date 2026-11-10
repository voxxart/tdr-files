local Rep=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local Config=require(Rep.GameModules.EventCurrencyConfig)
local Assets=require(Rep.GameModules.EventCurrencyAssets)
local Match=require(game.ServerScriptService.Simulation.MatchService)
local Wallet=require(script.Parent.Wallet)
local Store=require(script.Parent.DropStore)
local Quota=require(script.Parent.Quota)
local Service={}
local store=Store.new(Config.MaxActiveDrops)
local quota=Quota.new()
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
local pending,personal={},{}
local warned=false
local requests=setmetatable({}, {__mode='k'})
local raysLeft=Config.LandingChecksPerFrame or 24
local function message(record)
 local recipients,amounts={},{}
 for id in record.Eligible do recipients[tostring(id)]=true; amounts[tostring(id)]=record.Amounts[id] end
 return {Kind='Spawn',Id=record.Id,From=record.From,Land=record.Land,Amount=record.Amount,Amounts=amounts,Age=math.max(0,Match.Now()-record.Created),Lifetime=record.Lifetime,Bounces=record.Bounces,Recipients=recipients}
end
local function collectMessage(player,id,amount,reason)
 local queue=personal[player]; if not queue then queue={}; personal[player]=queue end
 table.insert(queue,{Kind='Collect',Id=id,Amount=amount,Player=player,Reason=reason})
end
local function remove(record)
 if not store:Remove(record) then return end
 if record.Generation==quota.Generation then
  for id in record.Eligible do if not record.Claimed[id] then quota:Release(id,record.Amounts[id]) end end
 end
 table.insert(pending,{Kind='Remove',Id=record.Id})
end
local function flush()
 local now=Match.Now()
 if #pending>0 then
  for _,op in pending do if op.Kind=='Spawn' then local record=store.ById[op.Id]; if record then op.Age=math.max(0,now-record.Created) end end end
  event:FireAllClients(pending); pending={}
 end
 for player,queue in pairs(personal) do
  if player.Parent then event:FireClient(player,queue) end
  personal[player]=nil
 end
end
function Service.BeginMatch(mode,generation)
 generation=generation or Match.Capture()
 if quota.Generation==generation then return end
 for index=#store.Active,1,-1 do remove(store.Active[index]) end
 quota:Begin(generation,mode,Config)
end
local function ensureMatch()
 if quota.Generation~=Match.Capture() then
  local info=workspace:FindFirstChild('Info')
  local mode=info and (info:FindFirstChild('Gamemode') or info:FindFirstChild('GameMode'))
  Service.BeginMatch(mode and mode.Value or '',Match.Capture())
 end
end
local function cast(origin,direction,params)
 if raysLeft<=0 then return nil end
 raysLeft-=1
 return workspace:Raycast(origin,direction,params)
end
function Service.TryDrop(origin,map,height)
 if not Config.Enabled or not Match.IsCurrent(Match.Capture()) then return false end
 ensureMatch()
 if #store.Active>=store.Maximum or raysLeft<=0 then return false end
 local eligible={}
 for _,player in Players:GetPlayers() do if quota:Available(player.UserId)>0 then eligible[player.UserId]=true end end
 if next(eligible)==nil or random:NextNumber()>=math.clamp(Config.DropChance,0,1) then return false end
 if not Assets.Current(Rep) then
  if not warned then warn('EventCurrency: missing Model/BasePart at ReplicatedStorage.Particle.EventCurrency.Current'); warned=true end
  return false
 end
 local angle=random:NextNumber(0,math.pi*2)
 local radius=random:NextNumber(math.max(0,Config.ScatterMin),math.max(0,Config.ScatterMin,Config.ScatterMax))
 local candidate=origin+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances={map}; params.IgnoreWater=true
 local hit=cast(candidate+Vector3.new(0,12,0),Vector3.new(0,-100,0),params)
 local land=Vector3.new(candidate.X,(hit and hit.Position.Y or origin.Y-(height or 0))+Config.GroundOffset,candidate.Z)
 local low=math.max(1,math.floor(Config.MinAmount)); local high=math.max(low,math.floor(Config.MaxAmount))
 local amount=random:NextInteger(low,high)
 local amounts={}
 for id in eligible do
  local accepted=quota:Reserve(id,amount)
  if accepted>0 then amounts[id]=accepted else eligible[id]=nil end
 end
 if next(eligible)==nil then return false end
 local now=Match.Now()
 local record=store:Add({From=origin,Land=land,Amount=amount,Amounts=amounts,Created=now,Lifetime=math.max(1,Config.Lifetime),Eligible=eligible,Claimed={},
  Bounces=random:NextInteger(math.clamp(Config.MinBounces or 2,1,6),math.clamp(math.max(Config.MinBounces or 2,Config.MaxBounces or 3),1,6)),
  Ready=now+Config.LaunchDuration+Config.BounceDuration,Generation=Match.Capture()})
 if record then table.insert(pending,message(record)); return true end
 for id,value in amounts do quota:Release(id,value) end
 return false
end
-- Called before the round publishes VICTORY, so the final award is in the normal save.
function Service.CompleteVictory(generation)
 if not Config.Enabled or not Match.IsCurrent(generation) then return 0 end
 ensureMatch()
 if quota.Generation~=generation or quota.Finished then return 0 end
 quota.Finished=true
 for index=#store.Active,1,-1 do remove(store.Active[index]) end
 local total=0
 if Config.CompleteQuotaOnVictory then
  for _,player in Players:GetPlayers() do
   local amount=quota:Shortfall(player.UserId)
   if amount>0 and Wallet.Credit(player,amount) then
    quota:Collected(player.UserId,amount,0); total+=amount
    store.NextId+=1; collectMessage(player,store.NextId,amount,'QuotaCompletion')
   end
  end
 end
 flush()
 return total
end
snapshot.OnServerInvoke=function(player)
 local now=os.clock()
 if requests[player] and now-requests[player]<2 then return {} end
 requests[player]=now
 local result={}
 for _,record in store.Active do
  if Match.IsCurrent(record.Generation) and record.Eligible[player.UserId] and not record.Claimed[player.UserId] then table.insert(result,message(record)) end
 end
 return result
end
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 raysLeft=Config.LandingChecksPerFrame or 24
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
     local player=candidate.Player; local id=player.UserId
     if record.Eligible[id] and not record.Claimed[id] then
      local delta=candidate.Position-record.Land
      if delta:Dot(delta)<=Config.PickupRadius^2 then
       local amount=quota:ClaimAmount(id,record.Amounts[id])
       if amount>0 and Wallet.Credit(player,amount) then
        record.Claimed[id]=true; quota:Collected(id,amount,record.Amounts[id]); collectMessage(player,record.Id,amount)
       end
      end
     end
    end
    local all=true
    for id in record.Eligible do if not record.Claimed[id] then all=false; break end end
    if all then store:Remove(record) end
   end
  end
 end
 flush()
end)
Players.PlayerRemoving:Connect(function(player)
 personal[player]=nil; requests[player]=nil
 for index=#store.Active,1,-1 do
  local record=store.Active[index]
  if record.Eligible[player.UserId] and not record.Claimed[player.UserId] then quota:Release(player.UserId,record.Amounts[player.UserId]) end
  record.Eligible[player.UserId]=nil; record.Claimed[player.UserId]=nil; record.Amounts[player.UserId]=nil
  local all=true
  for id in record.Eligible do if not record.Claimed[id] then all=false; break end end
  if all then remove(record) end
 end
end)
function Service.GetDiagnostics()
 return {ActiveDrops=#store.Active,Maximum=store.Maximum,Mode=quota.Mode,Quota=quota.Target,Finished=quota.Finished}
end
function Service.GetProgress(player)
 local state=quota:State(player.UserId)
 return {Collected=state.Collected,Outstanding=state.Reserved,Quota=quota.Target}
end
return Service
