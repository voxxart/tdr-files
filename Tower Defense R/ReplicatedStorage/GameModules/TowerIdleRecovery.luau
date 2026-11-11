-- Bounded round-robin recovery, independent of attack-request retry slots.
local Recovery={}; Recovery.__index=Recovery
function Recovery.new(ensure,budget)
 return setmetatable({Ensure=ensure,Budget=budget or 16,Active={},ByModel={},Cursor=1,Now=0},Recovery)
end
function Recovery:Add(model)
 if self.ByModel[model] then return end
 local state={Model=model,Next=0,Index=#self.Active+1}
 self.Active[state.Index]=state; self.ByModel[model]=state
end
function Recovery:Remove(model)
 local state=self.ByModel[model]; if not state then return end
 local last=self.Active[#self.Active]; self.Active[state.Index]=last; last.Index=state.Index
 self.Active[#self.Active]=nil; self.ByModel[model]=nil
end
function Recovery:Step(dt)
 self.Now+=dt
 for _=1,math.min(self.Budget,#self.Active) do
  if self.Cursor>#self.Active then self.Cursor=1 end
  local state=self.Active[self.Cursor]; self.Cursor+=1
  if state and self.Now>=state.Next then state.Next=self.Now+0.5; self.Ensure(state.Model) end
 end
end
function Recovery:Clear() table.clear(self.Active); table.clear(self.ByModel); self.Cursor=1 end
return Recovery
