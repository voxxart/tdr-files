-- Dense server-only records. IDs never repeat during this server session.
local Store={}
Store.__index=Store
function Store.new(maximum) return setmetatable({Active={},ById={},NextId=0,Maximum=maximum or 128},Store) end
function Store:Add(record)
 if #self.Active>=self.Maximum then return nil end
 self.NextId+=1; record.Id=self.NextId; record.Index=#self.Active+1
 self.Active[record.Index]=record; self.ById[record.Id]=record
 return record
end
function Store:Remove(record)
 if not record or self.ById[record.Id]~=record then return false end
 local last=self.Active[#self.Active]
 self.Active[record.Index]=last; last.Index=record.Index
 self.Active[#self.Active]=nil; self.ById[record.Id]=nil; record.Index=nil
 return true
end
function Store:Clear() table.clear(self.Active); table.clear(self.ById) end
return Store
