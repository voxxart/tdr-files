local Cleanup = require(script.Parent.Cleanup)

local TowerRuntime = {}
local Active = setmetatable({}, { __mode = "k" })

function TowerRuntime.Create(model, player, name, level, totalSpent)
	local existing = Active[model]
	if existing then return existing end

	local runtime = {
		Model = model,
		Player = player,
		Name = name,
		Level = level or 0,
		TotalSpent = totalSpent or 0,
		TotalDamage = 0,
		Destroyed = false,
		State = {},
		Modifiers = {},
		Cleanup = Cleanup.new(),
	}

	Active[model] = runtime
	runtime.Cleanup:Add(model.Destroying:Connect(function()
		TowerRuntime.Remove(model)
	end))
	return runtime
end

function TowerRuntime.Get(model)
	return Active[model]
end

function TowerRuntime.GetAll()
	return Active
end

function TowerRuntime.Remove(model)
	local runtime = Active[model]
	if not runtime then return end
	Active[model] = nil
	if not runtime.Destroyed then
		runtime.Destroyed = true
		runtime.Cleanup:Destroy()
	end
	runtime.Model = nil
	runtime.Player = nil
	runtime.State = nil
	runtime.Modifiers = nil
end

return TowerRuntime
