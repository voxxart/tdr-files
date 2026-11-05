-- Reconcile a global aura without per-target event connections.
local Aura = {}
Aura.__index = Aura
function Aura.new(apply, report)
	return setmetatable({_apply = apply, _report = report, _owned = {}, _caster = nil}, Aura)
end
function Aura:_remove(target)
	local cleanup = self._owned[target]
	self._owned[target] = nil
	if cleanup then
		local ok, err = pcall(cleanup)
		if not ok then self._report(err) end
	end
end
function Aura:Clear()
	for target in pairs(self._owned) do self:_remove(target) end
	self._caster = nil
end
function Aura:Step(caster, targets)
	if caster ~= self._caster then self:Clear(); self._caster = caster end
	if not caster then return end
	local wanted = {}
	for _, target in targets do wanted[target] = true end
	for target in pairs(self._owned) do
		if not wanted[target] then self:_remove(target) end
	end
	for target in pairs(wanted) do
		if not self._owned[target] then
			local ok, cleanup = pcall(self._apply, caster, target)
			if ok then self._owned[target] = cleanup else self._report(cleanup) end
		end
	end
end
return Aura
