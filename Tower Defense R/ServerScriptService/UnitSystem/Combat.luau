local Rep = game:GetService('ReplicatedStorage')
local Targeting = require(script.Parent.Targeting)
local Spatial = require(game.ServerScriptService.TowerSystem.Targeting)
local Damage = require(script.Parent.Damage)
local Combat = {}
local function alive(data)
	return not data.Cleaned and data.Model.Parent ~= nil and data.Health.Value > 0 and data.Model:GetAttribute('Dead') ~= true
end
local function eligible(mob, config)
	local stats = mob and mob:FindFirstChild('EnemyStats')
	local hp = stats and stats:FindFirstChild('Health')
	local flying = stats and stats:FindFirstChild('Flying')
	return hp ~= nil and hp.Value > 0 and not stats:FindFirstChild('Invincible')
		and not (flying and flying.Value) and (not stats:FindFirstChild('Lead') or config:FindFirstChild('LeadDetection') ~= nil)
end
local function hit(data,mob,amount,explosion)
	if not alive(data) then return end
	local stats = mob:FindFirstChild('EnemyStats')
	if not stats then return end
	local damageType = data.Config and data.Config:FindFirstChild('DamageType')
	local kind = if explosion then data.Definition.SecondaryDamageType or 'Explosion' else data.Definition.DamageType or (damageType and damageType.Value) or 'None'
	local actual = Damage.Apply(stats,amount,explosion,kind)
	Damage.Credit(data.Model,actual); Damage.Reward(actual)
end
local function pause(data, value)
	if data.NoStop or data.Paused == value then return end
	data.Paused = value; data.Model:SetAttribute('AttackPaused',value)
	if not value then Rep.Events.UnitStopAttack:FireAllClients(data.Model,nil,0) end
end
local function clearFacing(data)
	if data.Faced then
		data.Faced = nil
		if data.NoStop then Rep.Events.RotateTorso:FireAllClients(data.Model,nil,0) end
	end
end
function Combat.Step(data, now)
	if not alive(data) then return end
	local config = data.Config
	local primary = data.Definition.Primary or {}
	if data.Attacks and config and now >= data.NextPrimary then
		local range = config:FindFirstChild('Range')
		local damage = config:FindFirstChild('Damage')
		local cooldown = config:FindFirstChild('Cooldown')
		if range and damage and cooldown then
			local target = Targeting.Find(data.Model,data.Hitbox.Position,primary.Range or range.Value)
			if target and eligible(target,config) then
				local interval = math.max(primary.Cooldown or cooldown.Value,0.05)
				local duration = interval / math.max(workspace.Info.GameSpeed.Value,0.05)
				if data.NoStop then
					if data.Faced ~= target then Rep.Events.RotateTorso:FireAllClients(data.Model,target,duration) end
				else
					pause(data,true)
					local part = target:FindFirstChild('Hitbox')
					local position = part and part.Position or target:GetPivot().Position
					data.Model:SetAttribute('AttackFacePosition',position)
					Rep.Events.UnitStopAttack:FireAllClients(data.Model,part,duration,position)
				end
				data.Faced = target; data.LastAttack = now; data.NextPrimary = now + interval
				Rep.Events.AnimateUnit:FireAllClients(data.Model,'Attack',target)
				local function damageTarget(mob)
					if not eligible(mob,config) then return end
					local stats = mob.EnemyStats
					local defense = stats:FindFirstChild('Defense')
					local reduction = defense and defense:FindFirstChild('DefenseValue')
					local amount = primary.Damage or damage.Value
					if reduction then amount = math.round(amount/(1+reduction.Value)) end
					hit(data,mob,amount,false)
				end
				local aoe = config:FindFirstChild('AOE')
				local part = target:FindFirstChild('Hitbox')
				local center = part and part.Position
				damageTarget(target)
				if center and aoe and aoe.Value then
					local radius = primary.AOERadius or 3
					Spatial.Visit(center,radius,function(mob)
						local box = mob:FindFirstChild('Hitbox')
						if mob ~= target and box and (box.Position-center).Magnitude <= radius then damageTarget(mob) end
					end)
				end
			else
				data.NextPrimary = now + 0.05
				if data.NoStop then clearFacing(data)
				elseif data.Paused and (not data.LastAttack or now-data.LastAttack >= (primary.PostAttackHold or 1.5)) then
					pause(data,false); clearFacing(data)
				end
			end
		end
	end
	local secondary = config and config:FindFirstChild('SecondaryAttack')
	if secondary and now >= data.NextSecondary then
		local range, damage = secondary:FindFirstChild('Range'),secondary:FindFirstChild('Damage')
		local cooldown, radius = secondary:FindFirstChild('Cooldown'),secondary:FindFirstChild('SplashRadius')
		if range and damage and cooldown and radius then
			data.NextSecondary = now + math.max(cooldown.Value,0.05)
			local target = Targeting.Find(data.Model,data.Hitbox.Position,range.Value)
			local box = target and target:FindFirstChild('Hitbox')
			if box then
				local position = box.Position
				Rep.Events.AnimateUnit2:FireAllClients(data.Model,'Attack',position)
				Spatial.Visit(position,radius.Value,function(mob)
					local stats = mob:FindFirstChild('EnemyStats')
					local flying = stats and stats:FindFirstChild('Flying')
					if stats and not stats:FindFirstChild('Invincible') and not (flying and flying.Value) then hit(data,mob,damage.Value,true) end
				end)
			end
		end
	end
end
function Combat.Ram(data,finish)
	if not alive(data) then return end
	local selected
	local range = data.Definition.RamRange or (data.Stats:FindFirstChild('RamRange') and data.Stats.RamRange.Value) or 5
	Spatial.Visit(data.Hitbox.Position,range,function(mob)
		if selected then return end
		local stats = mob:FindFirstChild('EnemyStats')
		local hp = stats and stats:FindFirstChild('Health')
		local flying = stats and stats:FindFirstChild('Flying')
		if hp and hp.Value > 0 and not (flying and flying.Value) then selected = mob end
	end)
	if not selected then return end
	local stats = selected.EnemyStats
	local enemyHP, unitHP = stats.Health.Value, data.Health.Value
	local invincible = stats:FindFirstChild('Invincible') ~= nil
	local actual = if invincible then 0 else Damage.Apply(stats,unitHP,false,data.Definition.RamDamageType or 'Melee')
	Damage.Credit(data.Model,actual); Damage.Reward(actual)
	data.Health.Value = math.max(0,unitHP-(if invincible then 5000 else enemyHP))
	if data.Health.Value <= 0 then finish(data.Model,true,true) end
end
return Combat
