-- Per-match, per-player ledger. Outstanding piles reserve budget until claimed/expired.
local Quota={}
Quota.__index=Quota
function Quota.new() return setmetatable({Players={},Generation=nil,Target=nil,Finished=false},Quota) end
function Quota:Begin(generation,mode,config)
 self.Generation=generation; self.Mode=mode; self.Finished=false; table.clear(self.Players)
 self.Target=if config.QuotasEnabled==false then nil else math.max(0,math.floor((config.ModeQuotas and config.ModeQuotas[mode]) or 0))
end
function Quota:State(id)
 local state=self.Players[id]
 if not state then state={Collected=0,Reserved=0}; self.Players[id]=state end
 return state
end
function Quota:Available(id)
 local state=self:State(id)
 if self.Finished then return 0 end
 return if self.Target==nil then math.huge else math.max(0,self.Target-state.Collected-state.Reserved)
end
function Quota:Reserve(id,amount)
 local accepted=math.min(math.max(0,amount),self:Available(id))
 self:State(id).Reserved+=accepted
 return accepted
end
function Quota:Release(id,amount)
 local state=self.Players[id]; if state then state.Reserved=math.max(0,state.Reserved-amount) end
end
function Quota:ClaimAmount(id,amount)
 local state=self:State(id)
 return if self.Target==nil then amount else math.min(amount,math.max(0,self.Target-state.Collected))
end
function Quota:Collected(id,amount,reserved)
 local state=self:State(id); state.Reserved=math.max(0,state.Reserved-(reserved or amount)); state.Collected+=amount
end
function Quota:Shortfall(id)
 if self.Target==nil then return 0 end
 return math.max(0,self.Target-self:State(id).Collected)
end
return Quota
