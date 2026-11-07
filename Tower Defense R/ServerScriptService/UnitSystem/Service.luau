local Rep = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Match = require(game.ServerScriptService.Simulation.MatchService)
local Motion = require(game.ServerScriptService.Simulation.UnitMotion)
local Definitions = require(Rep.GameModules.UnitDefinitions)
local Runtime = require(script.Parent.Runtime)
local Paths = require(script.Parent.Paths)
local Combat = require(script.Parent.Combat)
local Death = require(script.Parent.Death)
local Behaviors = require(script.Parent.Behaviors)
local Service = {}
function Service.Spawn(...) return require(script.Parent.Spawner).Spawn(...) end
local function finish(model,died,ram)
	if not Runtime.Get(model) then return end
	Death.Finish(model,died,ram)
	Runtime.Remove(model)
end
function Service.Move(model,map,path,length,offset)
	local existing = Runtime.Get(model)
	if existing then return existing end
	local generation = Match.Capture()
	if not model or not model.Parent or model:GetAttribute('Dead') == true or not Match.IsCurrent(generation) then return nil end
	local stats = model:FindFirstChild('EnemyStats')
	local health = stats and stats:FindFirstChild('Health')
	local speed = stats and stats:FindFirstChild('Speed')
	local hitbox = model:FindFirstChild('Hitbox')
	local alpha = model:FindFirstChild('Alpha')
	if not health or not speed or not hitbox or not alpha or not model.PrimaryPart then return nil end
	local definition = Definitions.Units[model.Name] or {}
	local noStop, attacks = stats:FindFirstChild('NoStop'),stats:FindFirstChild('Attacks')
	local config = model:FindFirstChild('Config')
	local secondary = config and config:FindFirstChild('SecondaryAttack')
	local secondaryCd = secondary and secondary:FindFirstChild('Cooldown')
	for key,value in pairs({NoStop=definition.NoStop,Attacks=definition.Attacks}) do
		local flag=stats:FindFirstChild(key)
		if not flag then flag=Instance.new('BoolValue'); flag.Name=key; flag.Parent=stats end
		flag.Value=value
	end
	return Runtime.Add(model,{
		Generation=generation,Stats=stats,Health=health,Speed=speed,Hitbox=hitbox,AlphaValue=alpha,
		Map=map,Path=path,Length=length,Offset=offset or Vector3.zero,Alpha=alpha.Value,
		Height=stats.HipHeight.Value+model.PrimaryPart.Size.Y/2,Config=config,Definition=definition,
		Attacks=if definition.Attacks ~= nil then definition.Attacks else (attacks ~= nil and attacks.Value == true),
		NoStop=if definition.NoStop ~= nil then definition.NoStop else (noStop ~= nil and noStop.Value == true),
		Paused=false,NextPrimary=0,NextSecondary=Match.Now()+(secondaryCd and math.max(secondaryCd.Value,0.05) or 0),
	})
end
function Service.WayPointsLoad(map)
	local path = Paths.Select(map)
	if not path then return nil,nil,nil end
	return path,path.Length,path.Positions
end
function Service.Explode(position,radius)
	if Match.IsCurrent(Match.Capture()) then Death.Explode(position,radius) end
end
local positionElapsed,alphaElapsed = 0,0
RunService.Heartbeat:Connect(function(dt)
	Death.Update()
	local current = Match.Capture()
	local speed = math.max(workspace.Info.GameSpeed.Value,0)
	local gameDt = dt*speed
	positionElapsed += dt; alphaElapsed += dt
	local move = positionElapsed >= 1/math.max(1,Definitions.Settings.PositionHz or 30)
	local mirror = alphaElapsed >= 1/math.max(1,Definitions.Settings.AlphaHz or 10)
	if move then positionElapsed=0 end
	if mirror then alphaElapsed=0 end
	local parts,frames = {},{}
	local active = Runtime.List()
	for i=#active,1,-1 do
		local data = active[i]
		if not data then continue end
		local model = data.Model
		if not model.Parent or not Match.IsCurrent(data.Generation) or data.Generation ~= current then finish(model,false); continue end
		if data.Health.Value <= 0 then finish(model,true); continue end
		if speed <= 0 then continue end
		if not data.Hitbox.Parent or not data.AlphaValue.Parent then finish(model,false); continue end
		local ok,err=pcall(Combat.Step,data,Match.Now())
		if not ok then warn('Unit combat failed:',model.Name,err); finish(model,false); continue end
		if data.Health.Value <= 0 or data.Cleaned then continue end
		if not model.Parent or not data.Hitbox.Parent then finish(model,false); continue end
		data.Alpha=Motion.Advance(data.Alpha,data.Speed.Value,gameDt,data.Length,data.Paused)
		if data.Alpha >= 1 then
			local callback=Behaviors.End[data.Definition.EndBehavior or 'Despawn'] or Behaviors.End.Despawn
			local continued=false
			local ok,err=pcall(callback,{
				Model=model,Map=data.Map,Definition=data.Definition,Position=data.Hitbox.Position,
				Finish=function(died) finish(model,died) end,
				Reset=function(alpha)
					continued=true; data.Alpha=math.clamp(alpha or 0,0,0.9999); data.AlphaValue.Value=data.Alpha
				end,
			})
			if not ok then warn('Unit end behavior failed:',model.Name,err); finish(model,false) end
			if Runtime.Get(model) and not continued then finish(model,false) end
			continue
		end
		if mirror then data.AlphaValue.Value=data.Alpha end
		if move then
			local ok,frame=pcall(function() return Paths.Sample(data.Path,data.Alpha)+Vector3.new(0,data.Height,0)+data.Offset end)
			if not ok then warn('Unit movement failed:',model.Name,frame); finish(model,false); continue end
			table.insert(parts,data.Hitbox); table.insert(frames,frame)
		end
	end
	if #parts>0 then workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged) end
	for i=#active,1,-1 do
		local data=active[i]
		if data and not data.Cleaned and speed>0 and Match.IsCurrent(data.Generation) then
			local ok,err=pcall(Combat.Ram,data,finish)
			if not ok then warn('Unit contact failed:',data.Model.Name,err); finish(data.Model,false) end
		end
	end
end)

local snapshot = Rep.Events:FindFirstChild('UnitSnapshot')
if not snapshot then snapshot=Instance.new('RemoteFunction'); snapshot.Name='UnitSnapshot'; snapshot.Parent=Rep.Events end
assert(snapshot:IsA('RemoteFunction'),'UnitSnapshot must be a RemoteFunction')
local snapshotRequests=setmetatable({}, {__mode='k'})
snapshot.OnServerInvoke = function(player)
	local now=os.clock()
	if snapshotRequests[player] and now-snapshotRequests[player]<1 then return {Paths={},Units={}} end
	snapshotRequests[player]=now
	local result={Paths={},Units={}}
	for _, data in Runtime.List() do
		if not data.Cleaned and data.Model.Parent and Match.IsCurrent(data.Generation) then
			local id=data.Path.Id
			if id then result.Paths[id]=data.Path.Positions end
			table.insert(result.Units,{Model=data.Model,Id=id,Positions=if id then nil else data.Path.Positions,Height=data.Height,Offset=data.Offset})
		end
	end
	return result
end
return Service
