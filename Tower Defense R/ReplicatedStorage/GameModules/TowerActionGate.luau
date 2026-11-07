-- Keep one outstanding mutation per tower, even across different UI actions.
local Gate = {}
function Gate.new()
	return setmetatable({Pending=setmetatable({}, {__mode='k'})}, {__index=Gate})
end
function Gate:Run(tower,callback)
	if not tower or self.Pending[tower] then return false,nil end
	self.Pending[tower]=true
	local ok,result=pcall(callback,tower)
	self.Pending[tower]=nil
	return ok,result
end
return Gate
