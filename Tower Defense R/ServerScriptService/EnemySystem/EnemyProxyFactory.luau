-- Compatibility-preserving first stage: two server parts + stats, client-owned rig.
local Rep=game:GetService('ReplicatedStorage')
local Collection=game:GetService('CollectionService')
local Settings=require(Rep.GameModules.EnemyData).Settings
local Factory={}
local checked=setmetatable({}, {__mode='k'})
local function eligible(template)
 if not Settings.LightweightEnemies or not Settings.LightweightEnemies[template.Name] then return false end
 local cached=checked[template]
 if cached~=nil then return cached end
 local root=template.PrimaryPart or template:FindFirstChild('HumanoidRootPart')
 local hit=template:FindFirstChild('Hitbox')
 local valid=root and root.Name=='HumanoidRootPart' and root:IsA('BasePart') and hit and hit:IsA('BasePart') and hit~=root and template:FindFirstChild('EnemyStats')~=nil
 if valid and (#Collection:GetTags(template)>0 or template:FindFirstChild('IsFinalBoss')) then valid=false end
 if valid then
  for _,object in template:GetDescendants() do
   if object:IsA('Script') or object:IsA('LocalScript') or object:IsA('ObjectValue') or #Collection:GetTags(object)>0 then valid=false; break end
  end
 end
 checked[template]=not not valid
 return checked[template]
end
local function part(source,name)
 local p=Instance.new('Part'); p.Name=name; p.Size=source.Size; p.CFrame=source.CFrame
 p.Anchored=true; p.Transparency=1; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false; p.CastShadow=false
 return p
end
function Factory.Clone(template)
 if not eligible(template) then return template:Clone() end
 local proxy=Instance.new('Model'); proxy.Name=template.Name
 for key,value in pairs(template:GetAttributes()) do proxy:SetAttribute(key,value) end
 local root=part(template.PrimaryPart or template.HumanoidRootPart,'HumanoidRootPart'); root.Parent=proxy; proxy.PrimaryPart=root
 part(template.Hitbox,'Hitbox').Parent=proxy
 template.EnemyStats:Clone().Parent=proxy
 for _,child in template:GetChildren() do
  if child:IsA('ValueBase') and not child:IsA('ObjectValue') then child:Clone().Parent=proxy end
 end
 proxy:SetAttribute('LightweightEnemy',true)
 return proxy
end
return Factory
