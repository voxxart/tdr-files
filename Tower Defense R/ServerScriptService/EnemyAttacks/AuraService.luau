local RunService = game:GetService('RunService')
local Collection = game:GetService('CollectionService')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Runtime = require(game.ServerScriptService.EnemySystem.EnemyRuntime)
local Controller = require(game.ServerScriptService.Simulation.AuraController)
local Service = {}
local groups = {}
function Service.Register(definition)
	if groups[definition.Tag] then return end
	groups[definition.Tag] = {
		Definition = definition,
		Controller = Controller.new(definition.Apply, function(err) warn('Enemy aura failed:', err) end),
	}
end
local elapsed = 0
local generation
RunService.Heartbeat:Connect(function(dt)
	local current = Match.Capture()
	if generation ~= current or not Match.IsCurrent(current) then
		for _, group in pairs(groups) do group.Controller:Clear() end
		generation = current
		elapsed = 0
		if not Match.IsCurrent(current) then return end
	end
	elapsed += dt
	if elapsed < 0.2 then return end
	elapsed %= 0.2
	for _, group in pairs(groups) do
		local definition = group.Definition
		local caster
		for _, candidate in Collection:GetTagged(definition.Tag) do
			local runtime = Runtime.Get(candidate)
			if runtime and runtime.MatchGeneration == current and not runtime.Dead and not runtime.Cleaned
				and candidate:IsDescendantOf(workspace) and runtime.HealthValue.Value > definition.Threshold then
				caster = candidate; break
			end
		end
		group.Controller:Step(caster, if caster then definition.Targets() else {})
	end
end)
return Service
