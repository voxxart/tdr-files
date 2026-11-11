-- Arc-length lookup keeps travel smooth over steep and shallow trajectories.
local Arc={}; Arc.__index=Arc
function Arc:Point(t)
 return self.From+self.Delta*t+Vector3.new(0,4*self.Height*t*(1-t),0)+self.Side*(4*t*(1-t)*(1-2*t))
end
function Arc:Tangent(t)
 return self.Delta+Vector3.new(0,4*self.Height*(1-2*t),0)+self.Side*(4-24*t+24*t*t)
end
function Arc.new(from,to,height,forward)
 local delta=to-from
 local flat=Vector3.new(delta.X,0,delta.Z)
 local horizontal=flat.Magnitude
 local heading=if horizontal>0.001 then flat.Unit else Vector3.new(forward.X,0,forward.Z)
 if heading.Magnitude<0.001 then heading=Vector3.new(0,0,-1) else heading=heading.Unit end
 local arcHeight=math.max(0,height or math.max(3,horizontal*0.28,math.abs(delta.Y)*0.55+1))
 local self=setmetatable({From=from,Delta=delta,Height=arcHeight,
  Side=heading*(math.max(0,2-horizontal)*math.max(1,arcHeight*0.08,math.abs(delta.Y)*0.08)),Normal=heading:Cross(Vector3.yAxis),Lengths={0},Length=0},Arc)
 local previous=from
 for i=1,64 do local p=self:Point(i/64); self.Length+=(p-previous).Magnitude; self.Lengths[i+1]=self.Length; previous=p end
 return self
end
function Arc:Sample(progress)
 progress=math.clamp(progress,0,1)
 local distance=progress*self.Length
 local low,high=1,65
 while low<high do local mid=math.floor((low+high)/2); if self.Lengths[mid]<distance then low=mid+1 else high=mid end end
 local upper=math.max(2,low); local a,b=self.Lengths[upper-1],self.Lengths[upper]
 local fraction=if b-a>1e-8 then (distance-a)/(b-a) else 0
 local t=if progress>=1 then 1 else (upper-2+fraction)/64
 local position=self:Point(t); local tangent=self:Tangent(t)
 if tangent.Magnitude<1e-6 then tangent=self:Tangent(math.clamp(t+0.001,0,1)) end
 if tangent.Magnitude<1e-6 then tangent=Vector3.yAxis end
 local direction=tangent.Unit
 local up=self.Normal:Cross(direction).Unit
 return position,direction,up
end
return Arc
