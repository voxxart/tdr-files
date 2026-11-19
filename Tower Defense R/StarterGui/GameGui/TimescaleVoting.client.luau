local Rep=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Http=game:GetService('HttpService')
local player=Players.LocalPlayer
local gui=script:FindFirstAncestorWhichIsA('ScreenGui') or script.Parent
local frame=gui:WaitForChild('TimescaleVote')
local area=frame:WaitForChild('ButtonArea')
local yes=area:WaitForChild('Yes'):WaitForChild('Button')
local no=area:WaitForChild('No'):WaitForChild('Button')
local title=frame:WaitForChild('Title')
local info=workspace:WaitForChild('Info')
local remote=Rep:WaitForChild('Functions'):WaitForChild('VoteTimescale')
local current,pendingId
local alive=true
local connections={}
frame.Visible=false
local function render()
 if not alive then return end
 local now=workspace:GetServerTimeNow()
 local active=current and current.Active and now<current.Expires
 frame.Visible=active==true
 if not current then return end
 local voted=current.Choices and current.Choices[tostring(player.UserId)]~=nil
 yes.Active=active==true and not voted and pendingId~=current.Id
 no.Active=yes.Active
 title.Text=(if current.Target==1.5 then 'Increase Timescale to 1.5x' else 'Decrease Timescale to 1x')
  ..' ('..tostring(current.Yes)..'/'..tostring(current.Required)..')'
 frame:SetAttribute('VoteFailed',current.Failed==true)
 local remaining=if active then math.max(0,math.ceil(current.Expires-now)) else 0
 frame:SetAttribute('SecondsRemaining',remaining)
 local timer=frame:FindFirstChild('Timer') or frame:FindFirstChild('Countdown')
 if timer and timer:IsA('TextLabel') then timer.Text=tostring(remaining) end
 local misc=gui:FindFirstChild('Misc')
 local toggle=misc and misc:FindFirstChild('Timescale')
 if toggle then toggle:SetAttribute('CooldownRemaining',math.max(0,math.ceil(current.CooldownUntil-now))) end
end
local function update()
 local encoded=info:GetAttribute('TimescaleState')
 if type(encoded)=='string' then
  local ok,value=pcall(Http.JSONDecode,Http,encoded)
  if ok and type(value)=='table' then
   if not current or current.Id~=value.Id then pendingId=nil end
   current=value
  end
 end
 render()
end
local function cast(choice)
 if not current or not current.Active or pendingId==current.Id then return end
 if current.Choices and current.Choices[tostring(player.UserId)]~=nil then return end
 local id=current.Id;pendingId=id;render()
 local ok,accepted=pcall(remote.InvokeServer,remote,id,choice)
 if (not ok or not accepted) and pendingId==id then pendingId=nil end
 render()
end
connections[#connections+1]=yes.Activated:Connect(function() cast(true) end)
connections[#connections+1]=no.Activated:Connect(function() cast(false) end)
connections[#connections+1]=info:GetAttributeChangedSignal('TimescaleState'):Connect(update)
local elapsed=0
connections[#connections+1]=RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<0.2 then return end;elapsed=0;render()
end)
script.Destroying:Connect(function()
 alive=false
 for _,connection in connections do connection:Disconnect() end
end)
update()
