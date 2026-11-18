local Rep=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local modules=Rep:WaitForChild('GameModules')
local Photon=require(modules:WaitForChild('PhotonShots'))
local Policy=require(modules:WaitForChild('VFXPolicy'))
local data=require(modules:WaitForChild('TowerData')).Towers.Railgunner
local maxLevel=0
for level in data.Upgrades do if type(level)=='number' then maxLevel=math.max(maxLevel,level) end end
local info=workspace:WaitForChild('Info')
local towers=workspace:WaitForChild('Towers')
local effects=Photon.new(workspace)
local function running()
 return info.GameRunning.Value and info.Message.Value~='VICTORY' and info.Message.Value~='GAME OVER'
end
local connections={}
connections[#connections+1]=Rep.Events:WaitForChild('AnimateTower').OnClientEvent:Connect(function(tower,animation,target)
 if animation~='Attack' or not running() or info.GameSpeed.Value<=0 then return end
 if typeof(tower)~='Instance' or tower.Parent~=towers or tower:GetAttribute('Dead') then return end
 if (tower:GetAttribute('TowerName') or tower.Name)~='Railgunner' then return end
 local config=tower:FindFirstChild('Config')
 if not config then return end
 local level=tower:GetAttribute('TowerLevel')
 if type(level)~='number' then local value=config:FindFirstChild('Level'); level=value and value.Value end
 if level~=maxLevel or maxLevel==0 then return end
 if typeof(target)~='Instance' or not target.Parent then return end
 local weapon=tower:FindFirstChild('Weapon') or tower:FindFirstChild('weapon')
 local handle=weapon and weapon:FindFirstChild('Handle')
 local aim=target:FindFirstChild('HumanoidRootPart') or target.PrimaryPart or target:FindFirstChild('Hitbox')
 if not handle or not handle:IsA('BasePart') or not aim or not aim:IsA('BasePart') then return end
 local barrel=handle:FindFirstChild('Barrel')
 local from=if barrel and barrel:IsA('Attachment') then barrel.WorldPosition else handle.Position
 local camera=workspace.CurrentCamera
 if not camera or (from-camera.CFrame.Position).Magnitude>350 then return end
 local color=config:FindFirstChild('PhotonColor')
 effects:Emit(from,aim.Position,if color and color:IsA('Color3Value') then color.Value else Photon.DefaultColor,Policy.Quality()=='Low')
end)
connections[#connections+1]=RunService.Heartbeat:Connect(function(dt)
 if running() then effects:Step(dt) else effects:Clear() end
end)
connections[#connections+1]=info.GameRunning.Changed:Connect(function() if not running() then effects:Clear() end end)
connections[#connections+1]=info.Message.Changed:Connect(function() if not running() then effects:Clear() end end)
script.Destroying:Connect(function()
 for _,connection in connections do connection:Disconnect() end
 effects:Destroy()
end)
