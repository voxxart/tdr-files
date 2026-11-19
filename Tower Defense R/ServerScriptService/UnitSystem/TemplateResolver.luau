-- Shared lookup for every path unit spawned by a tower or tower ability.
local Resolver = {}
local function modelIn(folder, name)
 local model = folder and folder:FindFirstChild(name)
 return if model and model:IsA('Model') then model else nil
end
function Resolver.Resolve(units, name, ownerTower)
 if not units or type(name)~='string' or name=='' then return nil end
 if ownerTower then
  local towerName=ownerTower:GetAttribute('TowerName') or ownerTower.Name
  local skin=ownerTower:GetAttribute('AppearanceName')
  if type(skin)~='string' or skin=='' then skin='Default' end
  local towerFolder=units:FindFirstChild(towerName)
  if towerFolder and towerFolder:IsA('Folder') then
   local selected=modelIn(towerFolder:FindFirstChild(skin),name)
   if selected then return selected end
   local fallback=modelIn(towerFolder:FindFirstChild('Default'),name)
   if fallback then return fallback end
  end
 end
 -- Migration compatibility and non-tower spawns retain the old flat layout.
 return modelIn(units,name)
end
return Resolver
