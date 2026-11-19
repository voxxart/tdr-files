local Rep = game:GetService('ReplicatedStorage')
local Preparation = require(script.Parent.UnitSystem.TemplatePreparation)
local units = Rep:WaitForChild('Units')

-- Only descend through organizational folders, not nested rig/accessory Models.
local function prepareFolder(folder)
 for _,child in folder:GetChildren() do
  if child:IsA('Folder') then
   prepareFolder(child)
  elseif child:IsA('Model') then
   Preparation.Prepare(child)
  end
 end
end
prepareFolder(units)
