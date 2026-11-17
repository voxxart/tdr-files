-- One persistence/validation owner for all personal settings.
local Players=game:GetService('Players')
local Rep=game:GetService('ReplicatedStorage')
local DataStore=game:GetService('DataStoreService')
local RunService=game:GetService('RunService')
local Schema=require(Rep.GameModules.SettingsSchema)
local store=DataStore:GetDataStore('UnifiedPlayerSettingsV1')
local events=Rep:WaitForChild('Events')
local remote=events:FindFirstChild('PlayerSettingChange')
if not remote then remote=Instance.new('RemoteEvent'); remote.Name='PlayerSettingChange'; remote.Parent=events end
assert(remote:IsA('RemoteEvent'),'PlayerSettingChange must be a RemoteEvent')
local states={}
local function publish(player,values)
 for key,value in values do player:SetAttribute('Setting'..key,value) end
 player:SetAttribute('VolumePercent',values.Towers)
 player:SetAttribute('AmbienceVolumePercent',values.Ambience)
 player:SetAttribute('MusicVolumePercent',values.Music)
 player:SetAttribute('UiScale',values.UIScale)
 player:SetAttribute('VFXEnabled',values.VFX=='High')
 player:SetAttribute('DialogueEnabled',values.Dialogue=='On')
 for _,key in {'VFX','Dialogue'} do
  local object=player:FindFirstChild(key)
  if not object then object=Instance.new('StringValue'); object.Name=key; object.Parent=player end
  if object:IsA('StringValue') then object.Value=values[key] end
 end
end
local function read(database,key)
 for attempt=1,3 do
  local ok,value=pcall(database.GetAsync,database,key)
  if ok then return true,value end
  task.wait(attempt)
 end
 return false,nil
end
local function save(player,state)
 if state.Saving or not state.Persistent or not state.Dirty then return end
 state.Saving=true
 local version=state.Version; local snapshot=table.clone(state.Values)
 local ok=false
 for attempt=1,3 do
  ok=pcall(function() store:UpdateAsync(tostring(player.UserId),function() return snapshot end) end)
  if ok then break end
  task.wait(attempt)
 end
 state.Saving=false; state.LastSave=os.clock()
 if ok and state.Version==version then state.Dirty=false end
 if not ok then warn('Settings save failed for',player.UserId) end
end
local function load(player)
 if states[player] then return end
 local state={Values=Schema.Normalize(),Version=0,Dirty=false,Saving=false,Persistent=false,LastSave=-math.huge,LastChange=0,Tokens=12,TokenTime=os.clock()}
 states[player]=state; publish(player,state.Values); player:SetAttribute('SettingsReady',false)
 local ok,data=read(store,tostring(player.UserId))
 if ok and data==nil then
  data={}; local remaining=0; local legacyOK=true
  for key,entry in Schema.Legacy do
   remaining+=1
   task.spawn(function()
    local readOK,value=read(DataStore:GetDataStore(entry.Store),entry.Prefix..player.UserId)
    if not readOK then legacyOK=false end
    data[key]=Schema.LegacyValue(key,value)
    remaining-=1
   end)
  end
  while remaining>0 do task.wait(0.05) end
  ok=legacyOK; state.Dirty=ok -- migrate once; legacy stores remain untouched
 end
 if not player.Parent or states[player]~=state then states[player]=nil; return end
 state.Values=Schema.Normalize(data); state.Persistent=ok
 publish(player,state.Values)
 player:SetAttribute('SettingsPersistent',ok); player:SetAttribute('SettingsReady',true)
 if not ok then warn('Settings load failed; using session settings without overwriting saved preferences for',player.UserId) end
end
remote.OnServerEvent:Connect(function(player,key,value)
 local state=states[player]
 if not state or state.Closing or player:GetAttribute('SettingsReady')~=true then return end
 local now=os.clock(); state.Tokens=math.min(12,state.Tokens+(now-state.TokenTime)*8); state.TokenTime=now
 if state.Tokens<1 then return end
 state.Tokens-=1
 local valid=Schema.Validate(key,value)
 if valid==nil or state.Values[key]==valid then return end
 state.Values[key]=valid; state.Version+=1; state.Dirty=true; state.LastChange=now
 publish(player,state.Values)
end)
Players.PlayerAdded:Connect(function(player) task.spawn(load,player) end)
Players.PlayerRemoving:Connect(function(player)
 local state=states[player]; if not state then return end
 state.Closing=true
 -- Wait for a current autosave before taking the final snapshot.
 while state.Saving do task.wait(0.05) end
 save(player,state); states[player]=nil
end)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt; if elapsed<2 then return end; elapsed=0
 local now=os.clock()
 for player,state in states do
  if player:GetAttribute('SettingsReady') and state.Dirty and not state.Saving and now-state.LastChange>=2 and now-state.LastSave>=30 then task.spawn(save,player,state) end
 end
end)
game:BindToClose(function()
 local pending=0
 for player,state in states do
  state.Closing=true
  pending+=1
  task.spawn(function() while state.Saving do task.wait(0.05) end; save(player,state); pending-=1 end)
 end
 local deadline=os.clock()+25
 while pending>0 and os.clock()<deadline do task.wait(0.05) end
end)
for _,player in Players:GetPlayers() do task.spawn(load,player) end
