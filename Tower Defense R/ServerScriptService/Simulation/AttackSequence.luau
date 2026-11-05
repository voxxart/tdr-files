-- Shared windup/impact/recovery contract, with cleanup on every exit.
local Sequence = {}
function Sequence.Run(context)
	local ok, result = pcall(function()
		if not context.Active() then return false end
		context.Start()
		if not context.Wait(context.Windup) or not context.Active() or not context.ValidTarget() then return false end
		context.Impact()
		context.Wait(context.Recovery)
		return true
	end)
	context.Cleanup()
	if not ok then error(result, 0) end
	return result
end
return Sequence
