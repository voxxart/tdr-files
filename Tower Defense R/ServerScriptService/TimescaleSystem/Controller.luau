local Players=game:GetService('Players')
local Rep=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Purchase=require(script.Parent.Purchase)
local State=require(script.Parent.VoteState)
local info=workspace:WaitForChild('Info')
local speed=info:WaitForChild('GameSpeed')
local Controller={State=State.new()}
local function now() return workspace:GetServerTimeNow() end
local function roster(exclude)
 local result={};for _,p in Players:GetPlayers() do if p~=exclude then result[p.UserId]=true end end;return result
end
local function publish(exclude)
 local state=Controller.State
 local yes,total=state:Counts(roster(exclude))
 local choices={};for id,vote in state.Votes do choices[tostring(id)]=vote end
 info:SetAttribute('TimescaleState',Http:JSONEncode({Id=state.Id,Active=state.Active,Failed=state.Failed,
  Target=state.Target or 1.5,Expires=state.Expires or 0,CooldownUntil=state.CooldownUntil,
  Yes=yes,Required=total,Choices=choices}))
end
local function apply(value)
 if value then
  speed.Value=value
  local event=Rep.Events:FindFirstChild('SpeedupCooldown')
  if event then event:FireAllClients() end
 end
end
function Controller.Request(player,expected)
 if not player or not roster()[player.UserId] or not Purchase.Status(player).Owned then
  return {Success=false,Error='Unlock timescale before requesting a change.'}
 end
 if expected and expected~=speed.Value then return {Success=false,Error='Timescale has already changed.'} end
 local wasActive,wasFailed=Controller.State.Active,Controller.State.Failed
 apply(Controller.State:Step(now(),roster(),speed.Value))
 local accepted,err,value=Controller.State:Request(now(),speed.Value,roster())
 apply(value);if accepted or wasActive~=Controller.State.Active or wasFailed~=Controller.State.Failed then publish() end
 return {Success=accepted,Error=err}
end
function Controller.Vote(player,id,yes)
 local accepted,value=Controller.State:Vote(now(),player.UserId,id,yes,roster(),speed.Value)
 if accepted then apply(value);publish() end
 return accepted
end
local functions=Rep:WaitForChild('Functions')
local request=functions:FindFirstChild('RequestTimescale')
if not request then request=Instance.new('RemoteFunction');request.Name='RequestTimescale';request.Parent=functions end
request.OnServerInvoke=Controller.Request
local vote=functions:FindFirstChild('VoteTimescale')
if not vote then vote=Instance.new('RemoteFunction');vote.Name='VoteTimescale';vote.Parent=functions end
vote.OnServerInvoke=Controller.Vote
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 if not Controller.State.Active then return end
 elapsed+=dt;if elapsed<0.1 then return end;elapsed=0
 local wasActive,wasFailed=Controller.State.Active,Controller.State.Failed
 apply(Controller.State:Step(now(),roster(),speed.Value))
 if wasActive~=Controller.State.Active or wasFailed~=Controller.State.Failed then publish() end
end)
Players.PlayerAdded:Connect(function() publish() end)
Players.PlayerRemoving:Connect(function(player)
 apply(Controller.State:Step(now(),roster(player),speed.Value));publish(player)
end)
info.GameRunning.Changed:Connect(function()
 if not info.GameRunning.Value then Controller.State:Cancel();publish() end
end)
publish()
return Controller
