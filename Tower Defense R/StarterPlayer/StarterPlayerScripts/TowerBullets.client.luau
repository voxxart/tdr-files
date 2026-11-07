local Rep=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Profiles=require(Rep.GameModules:WaitForChild('CombatProfiles'))
local Tracers=require(Rep.GameModules:WaitForChild('BulletTracers'))
local pool=Tracers.new(workspace)
local player=Players.LocalPlayer
local info=workspace:WaitForChild('Info')
local towers=workspace:WaitForChild('Towers')
local cache=setmetatable({}, {__mode='k'})
local connections={}
local function running()
 return info.GameRunning.Value and info.Message.Value~='VICTORY' and info.Message.Value~='GAME OVER'
end
local function muzzle(tower)
 local weapon=tower:FindFirstChild('Weapon') or tower:FindFirstChild('weapon')
 local entry=cache[tower]
 if entry and entry.Weapon==weapon and entry.Handle.Parent and entry.Handle:IsDescendantOf(tower) then return entry.Handle end
 local handle=weapon and weapon:FindFirstChild('Handle')
 if not handle or not handle:IsA('BasePart') then cache[tower]=nil; return nil end
 cache[tower]={Weapon=weapon,Handle=handle}
 return handle
end
connections[#connections+1]=Rep.Events:WaitForChild('AnimateTower').OnClientEvent:Connect(function(tower,animation,target)
 if animation~='Attack' or not running() or info.GameSpeed.Value<=0 or pool.Tokens<1 then return end
 if typeof(tower)~='Instance' or tower.Parent~=towers or tower:GetAttribute('Dead')==true then return end
 if typeof(target)~='Instance' or not target.Parent then return end
 local config=tower:FindFirstChild('Config')
 local damageType=config and config:FindFirstChild('DamageType')
 if Profiles.Resolve(tower:GetAttribute('TowerName') or tower.Name,damageType and damageType.Value)~='Bullet' then return end
 local handle=muzzle(tower)
 local aim=target:FindFirstChild('HumanoidRootPart') or target.PrimaryPart or target:FindFirstChild('Hitbox')
 local camera=workspace.CurrentCamera
 if not handle or not aim or not aim:IsA('BasePart') or not camera then return end
 local offset=handle.Position-camera.CFrame.Position
 if offset:Dot(offset)>Tracers.Settings.MaxDistance^2 then return end
 local attachment=handle:FindFirstChild('Barrel')
 local from=if attachment and attachment:IsA('Attachment') then attachment.WorldPosition else handle.Position
 pool:Emit(from,aim.Position)
end)
connections[#connections+1]=RunService.RenderStepped:Connect(function(dt)
 if not running() then
  if #pool.Active>0 then pool:Clear() end
  return
 end
 local vfx=player:FindFirstChild('VFX')
 pool:Step(dt,info.GameSpeed.Value,vfx and vfx.Value=='Low')
end)
connections[#connections+1]=towers.ChildRemoved:Connect(function(tower) cache[tower]=nil end)
local function clear()
 if not running() then pool:Clear(); table.clear(cache) end
end
connections[#connections+1]=info.GameRunning.Changed:Connect(clear)
connections[#connections+1]=info.Message.Changed:Connect(clear)
script.Destroying:Connect(function()
 for _,connection in connections do connection:Disconnect() end
 pool:Destroy(); table.clear(cache)
end)
