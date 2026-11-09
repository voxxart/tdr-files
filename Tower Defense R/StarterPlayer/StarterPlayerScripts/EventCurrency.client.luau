local Rep=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local Config=require(Rep.GameModules.EventCurrencyConfig)
local Assets=require(Rep.GameModules.EventCurrencyAssets)
local Pool=require(Rep.GameModules.EventCurrencyPool)
local player=Players.LocalPlayer
local info=workspace:WaitForChild('Info')
local visual=Instance.new('Folder'); visual.Name='EventCurrencyVisuals'; visual.Parent=workspace
local pool=Pool.new(Config.MaxClientVisuals,visual)
local active,byId={},{}
local alive=true
local parts,frames={},{}
local snapshotPending,snapshotInvalid=false,false
local removedDuringSnapshot={}
local burstBudget=0
local function running() return info.GameRunning.Value and info.Message.Value~='VICTORY' and info.Message.Value~='GAME OVER' end
local function add(item) item.Index=#active+1; active[item.Index]=item; if item.Id then byId[item.Id]=item end end
local function remove(item)
 if not item or not item.Index then return end
 pool:Release(item.Slot)
 if item.Id then byId[item.Id]=nil end
 local last=active[#active]; active[item.Index]=last; last.Index=item.Index; active[#active]=nil; item.Index=nil
end
local function clear()
 for _,item in active do pool:Release(item.Slot); item.Index=nil end
 table.clear(active); table.clear(byId); table.clear(parts); table.clear(frames)
 if snapshotPending then snapshotInvalid=true end
end
local function apply(op)
 if op.Kind=='Spawn' then
  if not running() or byId[op.Id] or (op.Recipients and not (op.Recipients[tostring(player.UserId)] or op.Recipients[player.UserId])) then return end
  if snapshotPending and removedDuringSnapshot[op.Id] then return end
  if #active>=Config.MaxClientVisuals then return end
  add({Id=op.Id,From=op.From,Land=op.Land,Amount=op.Amount,Age=op.Age or 0,Lifetime=op.Lifetime,Stage='Ground',Angle=op.Id*2.399963})
 elseif op.Kind=='Collect' then
  if snapshotPending then removedDuringSnapshot[op.Id]=true end
  local item=byId[op.Id]
  if not item then return end
  item.Stage='Collect'; item.Age=0; item.From=item.Position or item.Land; item.Player=op.Player or player
  if item.Slot then item.Slot.Highlight.Enabled=false; item.Slot.Label.Text='+'..tostring(item.Amount) end
 elseif op.Kind=='Remove' then
  if snapshotPending then removedDuringSnapshot[op.Id]=true end
  local item=byId[op.Id]; if item and item.Stage=='Ground' then remove(item) end
 end
end
local connections={}
connections[#connections+1]=Rep.Events:WaitForChild('EventCurrency').OnClientEvent:Connect(function(ops)
 for _,op in ops do apply(op) end
end)
local function collectBurst(item,position)
 if burstBudget<=0 or not item.Slot then return end
 burstBudget-=1
 local count=math.clamp(Config.CollectionBurst,0,6)
 for index=1,count do
  if #active>=Config.MaxClientVisuals then break end
  add({Stage='Burst',Age=0,From=position,Asset=item.Slot.Asset,Angle=index*math.pi*2/math.max(count,1)+item.Angle})
 end
end
connections[#connections+1]=RunService.RenderStepped:Connect(function(dt)
 if not running() or not Config.Enabled then clear(); return end
 local gameDt=dt*math.max(info.GameSpeed.Value,0)
 local buildBudget=Config.ClientBuildsPerFrame
 burstBudget=Config.MaxCollectionBurstsPerFrame
 table.clear(parts); table.clear(frames)
 local currentAsset=Assets.Current(Rep)
 for index=#active,1,-1 do
  local item=active[index]
  item.Age+=gameDt
  if not item.Slot and buildBudget>0 then
   buildBudget-=1
   local asset=item.Asset or currentAsset
   if asset then
    item.Slot=pool:Acquire(asset,if item.Stage=='Burst' then 0.4 else 1)
    if item.Slot then
     item.Slot.Label.Text=(item.Stage=='Collect' and '+' or '')..tostring(item.Amount or '')
     item.Slot.Highlight.Enabled=item.Stage=='Ground'; item.Slot.Billboard.Enabled=item.Stage~='Burst'
    end
   end
  end
  local position,fade
  if item.Stage=='Ground' then
   if item.Age>=item.Lifetime then remove(item); continue end
   local a=math.clamp(item.Age/math.max(0.01,Config.LaunchDuration),0,1)
   position=item.From:Lerp(item.Land,a)+Vector3.new(0,4*Config.ArcHeight*a*(1-a),0)
   if a>=1 then
    local b=math.clamp((item.Age-Config.LaunchDuration)/math.max(0.01,Config.BounceDuration),0,1)
    position+=Vector3.new(0,math.abs(math.sin(b*math.pi*2))*Config.BounceHeight*(1-b),0)
   end
   if item.Slot then position+=Vector3.new(0,item.Slot.Height,0) end
  elseif item.Stage=='Collect' then
   local character=item.Player and item.Player.Character
   local root=character and character:FindFirstChild('HumanoidRootPart')
   if not root then remove(item); continue end
   local a=math.clamp(item.Age/math.max(0.05,Config.CollectionDuration),0,1)
   position=item.From:Lerp(root.Position+Vector3.new(0,1,0),1-(1-a)^3)+Vector3.new(0,math.sin(a*math.pi)*2,0)
   if a>=1 then collectBurst(item,root.Position); remove(item); continue end
  else
   local a=item.Age/0.55
   if a>=1 then remove(item); continue end
   position=item.From+Vector3.new(math.cos(item.Angle)*a*2.5,1+3*math.sin(a*math.pi),math.sin(item.Angle)*a*2.5)
   fade=a
  end
  item.Position=position
  if item.Slot then
   local frame=CFrame.new(position)*CFrame.Angles(0,item.Angle+item.Age*2,0)
   for _,entry in item.Slot.Parts do
    if fade then entry.Part.Transparency=entry.Transparency+(1-entry.Transparency)*fade end
    table.insert(parts,entry.Part); table.insert(frames,frame*entry.Offset)
   end
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
 clear(); pool:Destroy(); visual:Destroy()
end)
task.spawn(function()
 snapshotPending=true
 local ok,result=pcall(function() return Rep.Events:WaitForChild('EventCurrencySnapshot'):InvokeServer() end)
 if alive and ok and not snapshotInvalid and running() then for _,op in result do apply(op) end end
 snapshotPending=false; table.clear(removedDuringSnapshot)
end)
