local Assets={}
local function usable(object)
 if object and object.Archivable~=false and (object:IsA('BasePart') or (object:IsA('Model') and object:FindFirstChildWhichIsA('BasePart',true))) then return object end
 return nil
end
function Assets.Current(rep)
 local particle=rep:FindFirstChild('Particle')
 local folder=particle and particle:FindFirstChild('EventCurrency')
 local current=folder and folder:FindFirstChild('Current')
 if not current then return nil end
 if current:IsA('ObjectValue') then current=current.Value end
 if not current then return nil end
 if current:IsA('Model') or current:IsA('BasePart') then return usable(current) end
 return usable(current:FindFirstChildWhichIsA('Model')) or usable(current:FindFirstChildWhichIsA('BasePart'))
end
return Assets
