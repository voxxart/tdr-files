local State={};State.__index=State
function State.new() return setmetatable({Id=0,Active=false,Failed=false,CooldownUntil=0,Votes={}},State) end
local function count(roster) local n=0;for _ in roster do n+=1 end;return n end
function State:Counts(roster)
 local yes=0
 for id,vote in self.Votes do if roster[id] and vote then yes+=1 end end
 return yes,count(roster)
end
function State:Fail(now)
 if not self.Failed then self.Failed=true;self.CooldownUntil=now+60 end
end
function State:Request(now,speed,roster)
 if self.Active then return false,'A timescale vote is already running.' end
 if now<self.CooldownUntil then return false,'Timescale is on cooldown for '..math.ceil(self.CooldownUntil-now)..' seconds.' end
 if speed~=1 and speed~=1.5 then return false,'Timescale cannot be changed right now.' end
 local total=count(roster)
 if total<1 then return false,'No players are available.' end
 self.Id+=1;self.Target=if speed==1 then 1.5 else 1
 self.Failed=false;table.clear(self.Votes)
 if total==1 then self.CooldownUntil=now+15;return true,nil,self.Target end
 self.Active=true;self.Expires=now+15
 return true
end
function State:Step(now,roster,speed)
 if not self.Active then return nil end
 if speed and speed~=1 and speed~=1.5 then self:Fail(now) end
 if speed and speed==self.Target then self:Fail(now) end
 if now>=self.Expires then self:Fail(self.Expires);self.Active=false;return nil end
 local yes,total=self:Counts(roster)
 if total==0 then self.Active=false;return nil end
 if not self.Failed and yes==total then
  self.Active=false;self.CooldownUntil=now+60
  return self.Target
 end
 return nil
end
function State:Vote(now,id,voteId,yes,roster,speed)
 if not self.Active or now>=self.Expires or voteId~=self.Id or not roster[id]
  or type(yes)~='boolean' or self.Votes[id]~=nil then return false end
 self.Votes[id]=yes
 if not yes then self:Fail(now) end
 return true,self:Step(now,roster,speed)
end
function State:Cancel() self.Active=false end
return State
