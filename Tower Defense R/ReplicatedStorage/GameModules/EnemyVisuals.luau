-- Attach a local rig to the replicated proxy so existing client references work.
local Rep=game:GetService('ReplicatedStorage')
local Settings=require(Rep.GameModules.EnemyData).Settings
local Visuals={}
local remaining=Settings.ClientRigBuildsPerFrame or 16
function Visuals.BeginFrame() remaining=Settings.ClientRigBuildsPerFrame or 16 end
local attached=setmetatable({}, {__mode='k'})
local excluded={EnemyStats=true,Effects=true,Alpha=true,Hitbox=true}
function Visuals.Attach(model)
 if model:GetAttribute('LightweightEnemy')~=true then return true end
 local current=attached[model]
 if current and current.Root.Parent==model then return true end
 if current then Visuals.Detach(model) end
 if remaining<=0 then return false,'Budget' end
 local template=Rep.Mobs:FindFirstChild(model.Name)
 local proxyRoot=model:FindFirstChild('HumanoidRootPart') or model:FindFirstChild('EnemyProxyRoot')
 if not template or not proxyRoot then return false end
 remaining-=1
 local clone=template:Clone()
 local root=clone.PrimaryPart or clone:FindFirstChild('HumanoidRootPart')
 if not root then clone:Destroy(); return false end
 clone.PrimaryPart=root; root.Anchored=true
 for _,object in clone:GetDescendants() do
  if object:IsA('Script') or object:IsA('LocalScript') then object:Destroy()
  elseif object:IsA('BasePart') then object.CanCollide=false; object.CanTouch=false; object.CollisionGroup='Mob' end
 end
 clone:PivotTo(proxyRoot.CFrame)
 proxyRoot.Name='EnemyProxyRoot'
 local children={}
 for _,child in clone:GetChildren() do
  if excluded[child.Name] or child:IsA('ValueBase') then child:Destroy()
  else child.Parent=model; table.insert(children,child) end
 end
 clone:Destroy()
 local hitbox=model:FindFirstChild('Hitbox'); if hitbox then hitbox.CanQuery=false end
 model.PrimaryPart=root
 attached[model]={Root=root,ProxyRoot=proxyRoot,Children=children}
 model:SetAttribute('EnemyVisualReady',true)
 return true
end
function Visuals.Detach(model)
 local current=attached[model]
 if not current then return end
 attached[model]=nil
 for _,child in current.Children do child:Destroy() end
 if current.ProxyRoot.Parent then current.ProxyRoot.Name='HumanoidRootPart'; model.PrimaryPart=current.ProxyRoot end
 model:SetAttribute('EnemyVisualReady',nil)
end
return Visuals
