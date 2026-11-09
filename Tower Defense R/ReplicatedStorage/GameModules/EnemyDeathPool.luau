-- Bounded reusable resources, one game-time lifecycle pass, no per-death tasks.
local Pool={}
Pool.__index=Pool
function Pool.new(adapter,maximum,perFrame)
 return setmetatable({Adapter=adapter,Maximum=maximum or 48,PerFrame=perFrame or 6,Tokens=perFrame or 6,Active={},Free={},Created=0,Time=0},Pool)
end
function Pool:Recycle(entry)
 self.Adapter.Reset(entry)
 entry.Index=nil
 local list=self.Free[entry.Key]
 if not list then list={}; self.Free[entry.Key]=list end
 table.insert(list,entry)
end
function Pool:Emit(key,args)
 if self.Tokens<1 or #self.Active>=self.Maximum then return false end
 self.Tokens-=1
 local list=self.Free[key]
 local entry=list and table.remove(list)
 if list and #list==0 then self.Free[key]=nil end
 if not entry then
  if self.Created>=self.Maximum then
   for oldKey,free in pairs(self.Free) do
    local old=table.remove(free)
    self.Adapter.Destroy(old); self.Created-=1
    if #free==0 then self.Free[oldKey]=nil end
    break
   end
  end
  if self.Created>=self.Maximum then return false end
  entry=self.Adapter.Create(key)
  if not entry then return false end
  entry.Key=key; self.Created+=1
 end
 entry.Deadline=self.Time+math.clamp(args.Duration or 2,0.05,15)
 entry.Index=#self.Active+1
 self.Active[entry.Index]=entry
 self.Adapter.Begin(entry,args,self.Time)
 return true
end
function Pool:Step(dt,speed,low)
 self.Time+=math.max(dt,0)*math.max(speed,0)
 self.Tokens=if low then math.max(1,math.floor(self.PerFrame/3)) else self.PerFrame
 for index=#self.Active,1,-1 do
  local entry=self.Active[index]
  if self.Time>=entry.Deadline then
   self.Active[index]=self.Active[#self.Active]; self.Active[index].Index=index
   self.Active[#self.Active]=nil; self:Recycle(entry)
  else self.Adapter.Update(entry,speed,self.Time) end
 end
end
function Pool:Clear()
 for _,entry in self.Active do self:Recycle(entry) end
 table.clear(self.Active); self.Tokens=0
end
function Pool:Destroy()
 self:Clear()
 for _,list in self.Free do for _,entry in list do self.Adapter.Destroy(entry) end end
 table.clear(self.Free); self.Created=0
end
return Pool
