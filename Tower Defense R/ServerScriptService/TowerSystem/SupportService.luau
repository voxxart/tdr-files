local RunService = game:GetService('RunService')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Tasks = require(game.ServerScriptService.Simulation.TaskScope)
local Runtime = require(script.Parent.TowerRuntime)
local Service = {}
local Scope = {}
Scope.__index = Scope
local registered = {}
function Scope:Active()
	local config = self.Model:FindFirstChild('Config')
	local health = config and config:FindFirstChild('Health')
	return not self.Cancelled and self.Model.Parent ~= nil and Match.IsCurrent(self.Generation)
		and (not health or not health:FindFirstChild('HealthValue') or health.HealthValue.Value > 0)
end
function Scope:OnCancel(callback) return self.Jobs:OnCancel(callback) end
function Scope:Own(resource) self.Owned[resource] = true; return resource end
function Scope:Destroy(resource) self.Owned[resource] = nil; resource:Destroy() end
function Scope:Connect(signal, callback)
	return self:Own(signal:Connect(function(...) self.Jobs:Spawn(callback, ...) end))
end
function Scope:Once(signal, callback)
	local connection
	connection = signal:Connect(function(...)
		connection:Disconnect(); self.Owned[connection] = nil
		self.Jobs:Spawn(callback, ...)
	end)
	return self:Own(connection)
end
function Scope:OnHeartbeat(callback)
	local connection = {Connected = true}
	local updates = self.Updates
	updates[connection] = {Callback = callback, Busy = false}
	function connection:Disconnect() self.Connected = false; updates[self] = nil end
	self:OnCancel(function() connection:Disconnect() end)
	return connection
end
function Scope:Cancel()
	if self.Cancelled then return end
	self.Cancelled = true
	self.Jobs:Cancel()
	for resource in pairs(self.Owned) do
		pcall(function()
			if typeof(resource) == 'RBXScriptConnection' then resource:Disconnect()
			elseif resource:IsA('Tween') then resource:Cancel(); resource:Destroy()
			else resource:Destroy() end
		end)
	end
	table.clear(self.Owned); table.clear(self.Updates)
end
local function sweep(scope)
	for resource in pairs(scope.Owned) do
		if typeof(resource) == 'RBXScriptConnection' then
			if not resource.Connected then scope.Owned[resource] = nil end
		elseif resource:IsA('Tween') then
			if resource.PlaybackState == Enum.PlaybackState.Completed or resource.PlaybackState == Enum.PlaybackState.Cancelled then scope.Owned[resource] = nil end
		elseif not resource.Parent then scope.Owned[resource] = nil end
	end
end
function Service.Register(role, model, start, once)
	if not model or not model.Parent then return end
	local roles = registered[model]
	if not roles then roles = {}; registered[model] = roles end
	if roles[role] then return end
	local scope = setmetatable({Model=model, Generation=Match.Capture(), Owned={}, Updates={}, Cancelled=false}, Scope)
	scope.Jobs = Tasks.new({
		Active = function() return scope:Active() end,
		Start = task.spawn, Cancel = task.cancel,
		After = function(seconds,callback) return Match.After(scope.Generation,seconds,callback) end,
		Wait = function(seconds,active) return Match.Wait(scope.Generation,seconds,active) end,
		Report = function(err) warn('Tower support failed:',role,model.Name,err); scope:Cancel() end,
	})
	scope.Task = {
		spawn=function(fn,...) return scope.Jobs:Spawn(fn,...) end,
		defer=function(fn,...) return scope.Jobs:Delay(0,fn,...) end,
		delay=function(seconds,fn,...) return scope.Jobs:Delay(seconds,fn,...) end,
		wait=function(seconds)
			local before=Match.Now(); scope.Jobs:Wait(seconds or 1/60); return Match.Now()-before
		end,
	}
	scope.Start = start
	scope.AutoComplete = once
	roles[role] = scope
	local runtime = Runtime.Get(model)
	if runtime and runtime.State and not runtime.State.SupportCleanup then
		runtime.State.SupportCleanup = true
		runtime.Cleanup:Add(function()
			for _, current in pairs(registered[model] or {}) do current:Cancel() end
			registered[model] = nil
		end)
	end
end
RunService.Heartbeat:Connect(function(dt)
	for model, roles in pairs(registered) do
		for role, scope in pairs(roles) do
			if scope.Generation == 0 and model.Parent then
				if Match.IsCurrent(Match.Capture()) then scope.Generation = Match.Capture() else continue end
			end
			if not scope:Active() then
				scope:Cancel(); roles[role] = nil
			else
				if scope.Start then
					local start = scope.Start; scope.Start = nil
					scope.Jobs:Spawn(function() start(scope); if scope.AutoComplete then scope:Cancel() end end)
				end
				sweep(scope)
				for _, update in pairs(scope.Updates) do
					if not update.Busy then
						update.Busy = true
						scope.Jobs:Spawn(function()
							local ok, err = pcall(update.Callback,dt)
							update.Busy=false
							if not ok then warn('Tower support update failed:', role, model.Name, err); scope:Cancel() end
						end)
					end
				end
			end
		end
		if next(roles) == nil then registered[model] = nil end
	end
end)
return Service
