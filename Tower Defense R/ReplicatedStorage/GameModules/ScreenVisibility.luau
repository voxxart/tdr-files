-- Conservative sphere/frustum overlap, including a screen-edge margin. No raycasts.
local Visibility={}
function Visibility.Contains(x,y,depth,radius,width,height,fov,margin)
 if width<=0 or height<=0 or depth+radius<=0 then return false end
 local ty=math.tan(math.rad(fov)*0.5)
 local tx=ty*width/height
 tx*=1+2*(margin or 48)/width; ty*=1+2*(margin or 48)/height
 return math.abs(x)<=depth*tx+radius*math.sqrt(1+tx*tx)
  and math.abs(y)<=depth*ty+radius*math.sqrt(1+ty*ty)
end
function Visibility.Test(camera,position,radius,margin)
 if not camera then return true end
 local p=camera.CFrame:PointToObjectSpace(position)
 return Visibility.Contains(p.X,p.Y,-p.Z,radius or 8,camera.ViewportSize.X,camera.ViewportSize.Y,camera.FieldOfView,margin)
end
return Visibility
