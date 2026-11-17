
local function signal()
 local s={Entries={}}
 function s:Connect(fn) local c={Connected=true,F=fn}; function c:Disconnect() self.Connected=false end; table.insert(self.Entries,c); return c end
 function s:Fire(...) for _,c in table.clone(self.Entries) do if c.Connected then c.F(...) end end end
 return s
end
local function v(x,y) return {X=x,Y=y} end
local function dim(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end
local methods={}; local node
function methods:IsA(kind)
 return self.Class==kind or kind=='GuiObject' and ({Frame=true,TextLabel=true,ImageButton=true,TextButton=true,ScrollingFrame=true})[self.Class] or kind=='GuiButton' and (self.Class=='ImageButton' or self.Class=='TextButton')
end
function methods:IsDescendantOf(other) local current=self.Parent; while current do if current==other then return true end; current=current.Parent end; return false end
function methods:GetChildren() return table.clone(self.Children) end
function methods:GetDescendants() local out={} for _,child in self.Children do table.insert(out,child); for _,d in child:GetDescendants() do table.insert(out,d) end end return out end
function methods:FindFirstChild(name,recursive)
 for _,child in self.Children do if child.Name==name then return child end end
 if recursive then for _,child in self.Children do local found=child:FindFirstChild(name,true); if found then return found end end end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:FindFirstChildWhichIsA(kind,recursive)
 for _,child in self.Children do if child:IsA(kind) then return child end end
 if recursive then for _,child in self.Children do local found=child:FindFirstChildWhichIsA(kind,true); if found then return found end end end
end
function methods:GetAttribute(name) return self.Attributes[name] end
function methods:SetAttribute(name,value) self.Attributes[name]=value; if self.AttributeSignals[name] then self.AttributeSignals[name]:Fire() end end
function methods:GetAttributeChangedSignal(name) self.AttributeSignals[name]=self.AttributeSignals[name] or signal(); return self.AttributeSignals[name] end
function methods:GetPropertyChangedSignal(name) self.PropertySignals[name]=self.PropertySignals[name] or signal(); return self.PropertySignals[name] end
function methods:Play() self.IsPlaying=true; self.PlayCalls=(self.PlayCalls or 0)+1 end
function methods:Stop() self.IsPlaying=false; self.TimePosition=0 end
function methods:Emit(count) self.Emitted=(self.Emitted or 0)+count end
function methods:Destroy() self.Destroying:Fire(); self.Parent=nil; self.Destroyed=true end
function methods:Clone()
 local copy=node(self.Class,self.Name)
 for key,value in self.Props do if key~='Parent' then copy.Props[key]=value end end
 copy.Attributes=table.clone(self.Attributes)
 for _,child in self.Children do child:Clone().Parent=copy end
 return copy
end
node=function(class,name,parent)
 local n={Class=class,Children={},Attributes={},AttributeSignals={},PropertySignals={},Props={Name=name or class,Scale=1,Volume=1,Rate=40,TimeLength=120,TimePosition=0,IsPlaying=false,Looped=false,Enabled=true,Visible=true,AbsoluteSize=v(100,30),AbsolutePosition=v(0,0),AnchorPoint=v(0.5,0.5),Size=dim(0,100,0,30),Position=dim(0.5,0,0.5,0)},Destroying=signal(),AncestryChanged=signal(),Changed=signal(),ChildRemoved=signal(),ChildAdded=signal(),DescendantAdded=signal(),DescendantRemoving=signal(),InputBegan=signal(),Activated=signal()}
 setmetatable(n,{__index=function(self,key) return methods[key] or self.Props[key] or self:FindFirstChild(key) end,
 __newindex=function(self,key,value)
  if key=='Parent' then
   local old=self.Props.Parent
   local common={}; local current=value; while current do common[current]=true; current=current.Parent end
   if old then for i,c in old.Children do if c==self then table.remove(old.Children,i); break end end; local a=old; while a do if not common[a] then a.DescendantRemoving:Fire(self) end; a=a.Parent end end
   self.Props.Parent=value
   if old then old.ChildRemoved:Fire(self) end
   self.AncestryChanged:Fire(self,value)
   if value then table.insert(value.Children,self); value.ChildAdded:Fire(self); local a=value; while a do if not old or (old~=a and not old:IsDescendantOf(a)) then a.DescendantAdded:Fire(self) end; a=a.Parent end end
  else
   local old=self.Props[key]; self.Props[key]=value
   if key=='AbsoluteSize' and self.Class=='ScreenGui' then
    for _,child in self.Children do if child.BaseSize then child.Props.AbsolutePosition=v(value.X*0.5-child.AbsoluteSize.X*0.5,value.Y*0.5-child.AbsoluteSize.Y*0.5) end end
   end
   if key=='Scale' and self.Class=='UIScale' and self.Parent and self.Parent.BaseSize then
    local root=self.Parent; root.Props.AbsoluteSize=v(root.BaseSize.X*value,root.BaseSize.Y*value)
    root.Props.AbsolutePosition=v(root.Parent.AbsoluteSize.X*0.5-root.AbsoluteSize.X*0.5,root.Parent.AbsoluteSize.Y*0.5-root.AbsoluteSize.Y*0.5)
   end
   if old~=value and key=='Value' then self.Changed:Fire(value) end
   if old~=value and self.PropertySignals[key] then self.PropertySignals[key]:Fire() end
  end
 end})
 if parent then n.Parent=parent end
 return n
end

return {Signal=signal,Node=node,Vector=v,Dim=dim}
