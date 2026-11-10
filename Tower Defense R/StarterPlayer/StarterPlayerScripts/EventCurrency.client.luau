local Rep=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local Config=require(Rep.GameModules.EventCurrencyConfig)
local Assets=require(Rep.GameModules.EventCurrencyAssets)
local Pool=require(Rep.GameModules.EventCurrencyPool)
-- Farm installations commonly place Orbs directly under ReplicatedStorage.
local orbModule=Rep:WaitForChild('Orbs',5) or Rep.GameModules:FindFirstChild('Orbs')
if not orbModule then local modules=Rep:FindFirstChild('Modules'); orbModule=modules and modules:FindFirstChild('Orbs') end
assert(orbModule,'EventCurrency needs the existing Orbs ModuleScript')
local Orbs=require(orbModule)
local player=Players.LocalPlayer
local info=workspace:WaitForChild('Info')
local visual=Instance.new('Folder'); visual.Name='EventCurrencyVisuals'; visual.Parent=workspace
local pool=Pool.new(Config.MaxClientVisuals,visual)
local active,byId={},{}
local parts,frames={},{}
local alive=true
local snapshotPending,snapshotInvalid=false,false
local removedDuringSnapshot={}
local collected,recentIds={},{}
local recentCursor=1
local popup={Total=0,Deadline=0}
local pickupSound, soundSource, soundRoot
local warnedBillboard=false
local warnedOrbs=false
local lastPickupSound=-math.huge
local function running() return info.GameRunning.Value and info.Message.Value~='VICTORY' and info.Message.Value~='GAME OVER' end
local function add(item) item.Index=#active+1; active[item.Index]=item; byId[item.Id]=item end
local function remove(item)
 if not item or not item.Index then return end
 pool:Release(item.Slot); byId[item.Id]=nil
 local last=active[#active]; active[item.Index]=last; last.Index=item.Index; active[#active]=nil; item.Index=nil
end
local function clear()
 for _,item in active do pool:Release(item.Slot); item.Index=nil end
 table.clear(active); table.clear(byId); table.clear(parts); table.clear(frames)
 if snapshotPending then snapshotInvalid=true end
end
local function clearPopup()
 if popup.Gui then popup.Gui:Destroy() end
 popup={Total=0,Deadline=0}
end
local function pickupFeedback(item)
 local character=player.Character; local root=character and character:FindFirstChild('HumanoidRootPart')
 if not root then return end
 local from=item.Position or item.Land
 local ok,err=pcall(Orbs.Play,'EventDrops',Config.CollectionDuration,Config.CollectionOrbs or 1,from,player)
 if not ok and not warnedOrbs then warn('EventCurrency Orbs presentation failed; update the shared Orbs module:',err); warnedOrbs=true end
 local asset=item.Slot and item.Slot.Asset or Assets.Current(Rep)
 local source=asset and asset:FindFirstChild('PickupSound',true)
 if asset and (not source or not source:IsA('Sound')) then source=asset:FindFirstChildWhichIsA('Sound',true) end
 if source and source:IsA('Sound') then
  if not pickupSound or soundSource~=source or soundRoot~=root or not pickupSound.Parent then
   if pickupSound then pickupSound:Destroy() end
   pickupSound=source:Clone(); pickupSound.Name='EventCurrencyPickupSound'; pickupSound.Looped=false; pickupSound.Parent=root
   soundSource=source; soundRoot=root
  end
  if os.clock()-lastPickupSound>=(Config.PickupSoundMinInterval or 0.08) then pickupSound:Stop(); pickupSound:Play(); lastPickupSound=os.clock() end
 end
 local now=os.clock()
 if popup.Root~=root or now>=popup.Deadline or not popup.Gui or not popup.Gui.Parent then
  clearPopup()
  -- Reuse one authored billboard if already present; remove duplicate names.
  local gui
  for _,child in root:GetChildren() do
   if child.Name=='EventCurrencyPickup' then
    if not gui and child:IsA('BillboardGui') then gui=child else child:Destroy() end
   end
  end
  if not gui then
   local particle=Rep:FindFirstChild('Particle'); local template=particle and particle:FindFirstChild('EventCurrencyPickup')
   if template and template:IsA('BillboardGui') then gui=template:Clone(); gui.Name='EventCurrencyPickup'; gui.Parent=root end
  end
  if gui then gui.Adornee=root; gui.Enabled=true; popup={Gui=gui,Root=root,Total=0,Deadline=now+(Config.PickupDisplaySeconds or 5)}
  elseif not warnedBillboard then warn('EventCurrency: missing BillboardGui ReplicatedStorage.Particle.EventCurrencyPickup'); warnedBillboard=true end
 end
 if popup.Gui then
  popup.Total+=item.Amount
  local amount=popup.Gui:FindFirstChild('Amount',true)
  if amount and (amount:IsA('TextLabel') or amount:IsA('TextButton')) then amount.Text='+'..tostring(popup.Total) end
 end
end
local function apply(op)
 if op.Kind=='Spawn' then
  if not running() or byId[op.Id] or (op.Recipients and not (op.Recipients[tostring(player.UserId)] or op.Recipients[player.UserId])) then return end
  if snapshotPending and removedDuringSnapshot[op.Id] then return end
  if #active>=Config.MaxClientVisuals then return end
  add({Id=op.Id,From=op.From,Land=op.Land,Amount=(op.Amounts and (op.Amounts[tostring(player.UserId)] or op.Amounts[player.UserId])) or op.Amount,Age=op.Age or 0,Lifetime=op.Lifetime,Bounces=op.Bounces or (2+op.Id%2)})
 elseif op.Kind=='Collect' then
  if snapshotPending then removedDuringSnapshot[op.Id]=true end
  if collected[op.Id] then return end
  local previous=recentIds[recentCursor]; if previous then collected[previous]=nil end
  recentIds[recentCursor]=op.Id; collected[op.Id]=true; recentCursor=recentCursor%512+1
  local item=byId[op.Id]
  if item then pickupFeedback(item); remove(item)
  else
   local character=player.Character; local root=character and character:FindFirstChild('HumanoidRootPart')
   if root and op.Amount then pickupFeedback({Amount=op.Amount,Land=root.Position}) end
  end
 elseif op.Kind=='Remove' then
  if snapshotPending then removedDuringSnapshot[op.Id]=true end
  remove(byId[op.Id])
 end
end
local connections={}
connections[#connections+1]=Rep.Events:WaitForChild('EventCurrency').OnClientEvent:Connect(function(ops) for _,op in ops do apply(op) end end)
connections[#connections+1]=RunService.RenderStepped:Connect(function(dt)
 local character=player.Character; local root=character and character:FindFirstChild('HumanoidRootPart')
 if popup.Gui and (os.clock()>=popup.Deadline or popup.Root~=root or not popup.Gui.Parent) then clearPopup() end
 if pickupSound and soundRoot~=root then pickupSound:Destroy(); pickupSound=nil; soundRoot=nil; soundSource=nil end
 if not running() or not Config.Enabled then clear(); return end
 local gameDt=dt*math.max(info.GameSpeed.Value,0)
 local buildBudget=Config.ClientBuildsPerFrame
 table.clear(parts); table.clear(frames)
 local currentAsset=Assets.Current(Rep)
 for index=#active,1,-1 do
  local item=active[index]; item.Age+=gameDt
  if item.Age>=item.Lifetime then remove(item); continue end
  if not item.Slot and buildBudget>0 and currentAsset then buildBudget-=1; item.Slot=pool:Acquire(currentAsset,1) end
  local a=math.clamp(item.Age/math.max(0.01,Config.LaunchDuration),0,1)
  local position=item.From:Lerp(item.Land,a)+Vector3.new(0,4*Config.ArcHeight*a*(1-a),0)
  if a>=1 then
   local t=math.clamp((item.Age-Config.LaunchDuration)/math.max(0.01,Config.BounceDuration),0,1)
   local phase=t*item.Bounces
   local bounce=math.floor(phase)
   local height=if t<1 then math.sin((phase-bounce)*math.pi)*Config.BounceHeight*(0.5^bounce) else 0
   position=item.Land+Vector3.new(0,height,0)
  end
  if item.Slot then position+=Vector3.new(0,item.Slot.Height,0) end
  item.Position=position
  if item.Slot then
   -- Keep the asset's authored orientation. No waiting/launch spin.
   local cf=CFrame.new(position)*item.Slot.Rotation
   for _,entry in item.Slot.Parts do table.insert(parts,entry.Part); table.insert(frames,cf*entry.Offset) end
  end
 end
 if #parts>0 then workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged) end
end)
local function ended() if not running() then clear() end end
connections[#connections+1]=info.GameRunning.Changed:Connect(ended)
connections[#connections+1]=info.Message.Changed:Connect(ended)
script.Destroying:Connect(function()
 alive=false
 for _,connection in connections do connection:Disconnect() end
 clear(); clearPopup(); if pickupSound then pickupSound:Destroy() end
 pool:Destroy(); visual:Destroy()
end)
task.spawn(function()
 snapshotPending=true
 local ok,result=pcall(function() return Rep.Events:WaitForChild('EventCurrencySnapshot'):InvokeServer() end)
 if alive and ok and not snapshotInvalid and running() then for _,op in result do apply(op) end end
 snapshotPending=false; table.clear(removedDuringSnapshot)
end)
