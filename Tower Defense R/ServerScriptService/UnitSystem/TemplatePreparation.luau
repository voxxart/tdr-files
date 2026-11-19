-- Idempotent template preparation, shared by startup and the spawn boundary.
local Preparation = {}
function Preparation.Prepare(model)
 if not model or not model:IsA('Model') then return false end
 local root=model:FindFirstChild('HumanoidRootPart')
 if not root or not root:IsA('BasePart') then
  warn('Unit template is missing a valid HumanoidRootPart:',model:GetFullName())
  return false
 end
 local hitbox=model:FindFirstChild('Hitbox')
 if hitbox then
  if hitbox:IsA('BasePart') then return true end
  warn('Unit template Hitbox must be a BasePart:',model:GetFullName())
  return false
 end
 hitbox=root:Clone()
 for _,child in hitbox:GetChildren() do child:Destroy() end
 hitbox.Name='Hitbox'; hitbox.Transparency=1
 hitbox.CanCollide=false; hitbox.Anchored=true; hitbox.CanTouch=true
 hitbox.Parent=model
 return true
end
return Preparation
