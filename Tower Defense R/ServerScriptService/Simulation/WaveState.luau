local State={}; State.__index=State
function State.new() return setmetatable({Wave=0,Open=false,Active=false,Votes={}},State) end
function State:Begin(wave,now,duration,skipRemaining,final)
 self.Wave=wave; self.Deadline=now+duration; self.SkipRemaining=skipRemaining
 self.Final=final; self.Active=true; self.Skipped=false; table.clear(self.Votes)
 self:Update(now)
end
function State:Update(now)
 if not self.Active then self.Open=false; return end
 self.Remaining=math.max(0,math.ceil(self.Deadline-now))
 self.Open=not self.Final and not self.Skipped and self.Remaining>0 and self.Remaining<=self.SkipRemaining
end
function State:Count(roster)
 local count=0; for id in self.Votes do if roster[id] then count+=1 else self.Votes[id]=nil end end
 return count
end
function State:Required(total) return math.max(1,total-1) end -- preserve existing all-but-one rule
function State:Vote(id,wave,roster)
 if not self.Active or not self.Open or wave~=self.Wave or not roster[id] or self.Votes[id] then return false end
 self.Votes[id]=true; self:Recheck(roster); return true
end
function State:Recheck(roster)
 local total=0; for _ in roster do total+=1 end
 local count=self:Count(roster)
 if self.Open and count>0 and count>=self:Required(total) then self.Skipped=true; self.Open=false end
end
function State:CanAdvance(spawning,enemies)
 if not self.Active then return false end
 if self.Final then return not spawning and enemies==0 end
 return self.Skipped or self.Remaining<=0 or (not spawning and enemies==0)
end
function State:Close() self.Active=false; self.Open=false; table.clear(self.Votes) end
return State
