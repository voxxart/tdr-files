-- Boss markers and one replicated audio snapshot; no shared sound-volume writes.
local Rep=game:GetService('ReplicatedStorage')
local Http=game:GetService('HttpService')
local Config=require(Rep.GameModules.BossMusicConfig)
local mobs=workspace:WaitForChild('Mobs')
local info=workspace:WaitForChild('Info')
local records={}
local serial,revision=0,0
local currentWave=info.Wave.Value
local finalHold,finalStopped=false,false
local hasRun=info.GameRunning.Value
local ended=not hasRun
local terminalHold=false
local lastTrack,lastMuted,lastFinal,lastTerminal,lastWave
local startedAt=0
local function mode() return Config.Modes[info.Gamemode.Value] end
local function exists(path)
 local object=workspace:FindFirstChild('Music')
 for _,part in string.split(path,'.') do object=object and object:FindFirstChild(part) end
 return object and object:IsA('Sound')
end
local warned={}
local function publish()
 local definition=mode()
 local track=''; local newest=0
 if not ended then
  if finalHold then
   if not finalStopped and definition then track=definition.FinalTrack end
  else
   for _,record in records do if record.Serial>newest then track=record.Track; newest=record.Serial end end
  end
 end
 if track~='' and not exists(track) then
  if not warned[track] then warned[track]=true; warn('Boss music Sound not found at Workspace.Music.'..track) end
  track=''
 end
 local muted=terminalHold or finalHold or track~=''
 if track==lastTrack and muted==lastMuted and finalHold==lastFinal and terminalHold==lastTerminal and currentWave==lastWave then return end
 if track~=lastTrack then startedAt=if track~='' then workspace:GetServerTimeNow() else 0 end
 lastTrack,lastMuted,lastFinal,lastTerminal,lastWave=track,muted,finalHold,terminalHold,currentWave
 revision+=1
 info:SetAttribute('BossAudioSnapshot',Http:JSONEncode({Track=track,StartedAt=startedAt,AmbienceMuted=muted,Final=finalHold,Volume=Config.TrackVolumes[track],Terminal=terminalHold,Wave=currentWave,Revision=revision,Fade=Config.FadeSeconds}))
end
local function disconnect(record) for _,connection in record.Connections do connection:Disconnect() end end
local function clear()
 for _,record in records do disconnect(record) end
 table.clear(records)
end
local function remove(model)
 local record=records[model]; if not record then return end
 disconnect(record); records[model]=nil
 if record.Final then
  local remaining=false
  for _,other in records do if other.Final then remaining=true; break end end
  if not remaining then finalStopped=true end
 end
 publish()
end
local function added(model)
 if not model:IsA('Model') then return end
 local definition=mode(); if not definition then return end
 if definition.Bosses[currentWave]==model.Name and not model:FindFirstChild('IsBoss') then
  local marker=Instance.new('BoolValue'); marker.Name='IsBoss'; marker.Value=true; marker.Parent=model
 end
 if ended or info:GetAttribute('WaveActive')==false or records[model] or model:GetAttribute('Dead')==true then return end
 local isFinal=finalHold and model.Name==definition.FinalBoss
 local track=if isFinal then definition.FinalTrack else (definition.Music and definition.Music[model.Name])
 local custom=model:GetAttribute('BossMusicPath')
 if not track and type(custom)=='string' and custom~='' then track=custom end
 if not track then return end
 local stats=model:FindFirstChild('EnemyStats'); local health=stats and stats:FindFirstChild('Health')
 if health and health.Value<=0 then return end
 serial+=1
 local record={Track=track,Serial=serial,Final=isFinal,Connections={}}
 records[model]=record
 if isFinal then finalStopped=false end
 table.insert(record.Connections,model:GetAttributeChangedSignal('Dead'):Connect(function() if model:GetAttribute('Dead')==true then remove(model) end end))
 table.insert(record.Connections,model.AncestryChanged:Connect(function() if model.Parent~=mobs then remove(model) end end))
 table.insert(record.Connections,model.Destroying:Connect(function() remove(model) end))
 if health then table.insert(record.Connections,health.Changed:Connect(function() if health.Value<=0 then remove(model) end end)) end
 publish()
end
local function waveChanged()
 clear(); currentWave=info.Wave.Value
 local definition=mode()
 finalHold=finalHold or (definition~=nil and currentWave>=definition.FinalWave)
 finalStopped=false
 if not ended then publish() end
end
local function terminal()
 local result=info.Message.Value
 if (hasRun and not info.GameRunning.Value) or result=='VICTORY' or result=='GAME OVER' then ended=true; terminalHold=true; clear(); publish() end
end
local connections={}
local function connect(event,fn) table.insert(connections,event:Connect(fn)) end
connect(mobs.ChildAdded,added)
connect(mobs.ChildRemoved,remove)
connect(info.Wave.Changed,waveChanged)
connect(info:GetAttributeChangedSignal('WaveActive'),function()
 if info:GetAttribute('WaveActive')==false then clear(); if finalHold then finalStopped=true end; publish() end
end)
connect(info.Message.Changed,terminal)
connect(info.GameRunning.Changed,function()
 if info.GameRunning.Value then
  clear(); hasRun=true; ended=false; terminalHold=false; finalHold=false; finalStopped=false; currentWave=0; publish()
 else terminal() end
end)
if not ended then waveChanged(); for _,model in mobs:GetChildren() do added(model) end else publish() end
script.Destroying:Connect(function() clear(); for _,connection in connections do connection:Disconnect() end end)
