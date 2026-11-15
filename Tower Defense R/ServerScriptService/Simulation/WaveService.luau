local Players=game:GetService('Players')
local Rep=game:GetService('ReplicatedStorage')
local Match=require(script.Parent.MatchService)
local State=require(script.Parent.WaveState)
local info=workspace:WaitForChild('Info')
local mobs=workspace:WaitForChild('Mobs')
local enemyCount=#mobs:GetChildren()
mobs.ChildAdded:Connect(function() enemyCount+=1 end)
mobs.ChildRemoved:Connect(function() enemyCount=math.max(0,enemyCount-1) end)
local Service={State=State.new(),Pending=0}
local configuredDuration=math.max(0,info.Min.Value*60+info.Sec.Value)
if configuredDuration==0 then configuredDuration=90 end
local lastSecond,lastOpen,lastVotes,lastRequired,lastSpawning
local function roster(exclude)
 local result={}; for _,player in Players:GetPlayers() do if player~=exclude then result[player.UserId]=true end end; return result
end
local function publish(exclude)
 local state=Service.State; local players=roster(exclude); local total=0; for _ in players do total+=1 end
 local votes=state:Count(players); local required=state:Required(total)
 if votes~=lastVotes then info.VoteSkipValue.Value=votes; lastVotes=votes end
 if required~=lastRequired then info:SetAttribute('SkipRequired',required); lastRequired=required end
 local open=state.Active and state.Open
 if open~=lastOpen then
  info:SetAttribute('SkipOpen',open); Rep.Events.SkipButton:FireAllClients(true,not open); lastOpen=open
 end
 if state.Active and state.Remaining~=lastSecond then
  local remaining=state.Remaining
  info.Min.Value=math.floor(remaining/60); info.Sec.Value=remaining%60
  Rep.Events.SetTextTime:FireAllClients(info.Min.Value,info.Sec.Value); lastSecond=remaining
 end
 local spawning=Service.Pending>0
 if spawning~=lastSpawning then info:SetAttribute('WaveSpawning',spawning); lastSpawning=spawning end
end
function Service.Begin(wave,generation,final,timing)
 if Service.Generation~=generation then Service.Generation=generation; Service.Pending=0; Service.Failed=nil end
 local duration=info:GetAttribute('WaveDurationSeconds') or (timing and timing.Duration) or configuredDuration
 duration=math.max(1,duration)
 local encoded=math.max(0,info.SkipTime.Value)
 local skipRemaining=if timing then timing.SkipRemaining else math.floor(encoded/100)*60+encoded%100
 info.SkipTime.Value=math.floor(skipRemaining/60)*100+skipRemaining%60
 Service.State:Begin(wave,Match.Now(),duration,skipRemaining,final)
 lastSecond=nil; publish()
end
function Service.Spawn(generation,callback)
 Service.Pending+=1; publish()
 task.spawn(function()
  if Match.IsCurrent(generation) then
   local ok,err=xpcall(callback,debug.traceback)
   if not ok then warn('Wave spawning failed:',err); Service.Failed=generation end
  end
  if Service.Generation==generation then Service.Pending=math.max(0,Service.Pending-1); publish() end
 end)
end
function Service.CanAdvance()
 if Service.Failed==Service.Generation then return false end
 Service.State:Update(Match.Now())
 return Service.State:CanAdvance(Service.Pending>0,enemyCount)
end
function Service.Vote(player,wave)
 if not Match.IsCurrent(Service.Generation) or workspace.Info.GameSpeed.Value<=0 then return false end
 Service.State:Update(Match.Now())
 local accepted=Service.State:Vote(player.UserId,wave,roster())
 publish(); return accepted
end
function Service.Close() Service.State:Close(); publish() end
function Service.Step()
 if not Service.State.Active then return end
 if not Match.IsCurrent(Service.Generation) then Service.Close(); return end
 Service.State:Update(Match.Now()); Service.State:Recheck(roster()); publish()
end
Players.PlayerRemoving:Connect(function(player) Service.State:Recheck(roster(player)); publish(player) end)
Players.PlayerAdded:Connect(function() publish() end)
Service.Close()
return Service
