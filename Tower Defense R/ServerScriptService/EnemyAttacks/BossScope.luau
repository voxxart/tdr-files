local Match = require(game.ServerScriptService.Simulation.MatchService)
local Runtime = require(game.ServerScriptService.EnemySystem.EnemyRuntime)
local Tasks = require(game.ServerScriptService.Simulation.TaskScope)
local TowerDeath = require(game.ServerScriptService.Main.TowerDeath)
local NativeTask = task
local pendingDeaths = setmetatable({}, {__mode = "k"})
local Scope = {}
Scope.__index = Scope
function Scope.new(enemy)
	local generation = Match.Capture()
	local self = setmetatable({Enemy = enemy, Generation = generation, _owned = {}, _sounds = {}, _properties = {}}, Scope)
	self.Jobs = Tasks.new({
		Active = function()
			local runtime = Runtime.Get(enemy)
			return Match.IsCurrent(generation) and runtime ~= nil and not runtime.Dead and not runtime.Cleaned
				and enemy:IsDescendantOf(workspace) and runtime.HealthValue.Value > 0
		end,
		Start = NativeTask.spawn, Cancel = NativeTask.cancel,
		After = function(seconds, callback) return Match.After(generation, seconds, callback) end,
		Wait = function(seconds, active) return Match.Wait(generation, seconds, active) end,
		Report = function(err) warn('Boss behavior failed:', enemy.Name, err) end,
	})
	self.Task = {
		spawn = function(fn, ...) return self.Jobs:Spawn(fn, ...) end,
		defer = function(fn, ...) return self.Jobs:Delay(0, fn, ...) end,
		delay = function(seconds, fn, ...) return self.Jobs:Delay(seconds, fn, ...) end,
		wait = function(seconds) return self.Jobs:Wait(seconds or 0) end,
	}
	return self
end
function Scope:Active() return self.Jobs:Active() end
function Scope:OnCancel(callback) return self.Jobs:OnCancel(callback) end
function Scope:Play(resource, ...)
	if resource:IsA('Sound') then self._sounds[resource] = true end
	resource:Play(...)
end
function Scope:Set(resource, property, value)
	local saved = self._properties[resource]
	if not saved then saved = {}; self._properties[resource] = saved end
	if saved[property] == nil then saved[property] = {resource[property]} end
	resource[property] = value
end
function Scope:Own(resource)
	self._owned[resource] = true
	return resource
end
function Scope:Destroy(resource)
	self._owned[resource] = nil
	resource:Destroy()
end
function Scope:Connect(signal, callback)
	return self:Own(signal:Connect(function(...)
		self.Jobs:Spawn(callback, ...)
	end))
end
function Scope:Once(signal, callback)
	local connection
	connection = signal:Connect(function(...)
		connection:Disconnect()
		self._owned[connection] = nil
		self.Jobs:Spawn(callback, ...)
	end)
	return self:Own(connection)
end
function Scope:Sweep()
	for resource in pairs(self._owned) do
		if typeof(resource) == 'Instance' then
			if resource:IsA('Tween') then
				local state = resource.PlaybackState
				if state == Enum.PlaybackState.Completed or state == Enum.PlaybackState.Cancelled then self._owned[resource] = nil end
			elseif resource:IsA('AnimationTrack') then
				-- Cached tracks are released with the boss rather than between casts.
			elseif not resource.Parent then self._owned[resource] = nil end
		elseif typeof(resource) == 'RBXScriptConnection' and not resource.Connected then self._owned[resource] = nil end
	end
end
function Scope:KillTower(tower, owner)
	local generation = self.Generation
	if pendingDeaths[tower] == generation then return end
	pendingDeaths[tower] = generation
	-- Committed damage is independent of the caster; teardown still belongs to its match.
	NativeTask.spawn(function()
		if Match.IsCurrent(generation) then
			TowerDeath.KillTower(tower, if typeof(owner) == 'Instance' then owner else nil,
				function() return Match.IsCurrent(generation) end)
		end
		if pendingDeaths[tower] == generation then pendingDeaths[tower] = nil end
	end)
end
function Scope:Cancel()
	self.Jobs:Cancel()
	for sound in pairs(self._sounds) do pcall(function() sound:Stop() end) end
	table.clear(self._sounds)
	for resource, saved in pairs(self._properties) do
		for property, value in pairs(saved) do pcall(function() resource[property] = value[1] end) end
	end
	table.clear(self._properties)
	for resource in pairs(self._owned) do
		pcall(function()
			if typeof(resource) == 'RBXScriptConnection' then resource:Disconnect()
			elseif resource:IsA('Tween') then resource:Cancel(); resource:Destroy()
			elseif resource:IsA('AnimationTrack') then resource:Stop(0); resource:Destroy()
			else resource:Destroy() end
		end)
	end
	table.clear(self._owned)
	local stats = self.Enemy:FindFirstChild('EnemyStats')
	local speed = stats and stats:FindFirstChild('Speed')
	local original = stats and stats:FindFirstChild('OrigSpeed')
	if speed and original and speed.Value == 0 then speed.Value = original.Value end
end
return Scope
