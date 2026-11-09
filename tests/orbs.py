"""Run actual shared Orbs module for farm Parts and event Folder/Model assets."""
from pathlib import Path
import tempfile,subprocess
root=Path(__file__).resolve().parents[1]
source=(root/'Tower Defense R/ReplicatedStorage/GameModules/Orbs.luau').read_text()
code='local source=[====['+source+']====]\n'+r'''
local function signal()
 local s={Callbacks={}}; function s:Connect(fn) table.insert(self.Callbacks,fn) end
 function s:Fire(dt) for _,fn in self.Callbacks do fn(dt) end end
 return s
end
local vec; local mt={}
vec=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
mt.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
mt.__mul=function(a,b) if type(a)=='number' then return vec(a*b.X,a*b.Y,a*b.Z) end; return vec(a.X*b,a.Y*b,a.Z*b) end
mt.__div=function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
local frame
local rotation={Position=vec(0,0,0)}
frame=function(p) return setmetatable({Position=p,Rotation=rotation,ToObjectSpace=function(self,b) return frame(b.Position-self.Position) end},{__mul=function(a,b) return frame(a.Position+b.Position) end}) end
local cloneCount=0
local function node(class,name)
 local n={Class=class,Name=name or class,Children={},Position=vec(0,0,0),CFrame=frame(vec(0,0,0)),Transparency=0}
 setmetatable(n,{__index=function(self,key) local raw=rawget(self,key); if raw~=nil then return raw end; for _,child in self.Children do if child.Name==key then return child end end end,
 __newindex=function(self,key,value) if key=='Parent' then rawset(self,key,value); if value then value.Children[self]=self end else rawset(self,key,value) end end})
 function n:IsA(kind) return self.Class==kind or kind=='BasePart' and (self.Class=='Part' or self.Class=='MeshPart') end
 function n:FindFirstChild(key) return self[key] end
 function n:GetChildren() local out={} for _,child in self.Children do table.insert(out,child) end return out end
 function n:GetDescendants() local out={} for _,child in self.Children do table.insert(out,child); for _,d in child:GetDescendants() do table.insert(out,d) end end return out end
 function n:GetPivot() return self.PrimaryPart and self.PrimaryPart.CFrame or self.CFrame end
 function n:Destroy() self.Destroyed=true; self.Parent=nil end
 function n:Stop() end
 function n:Clear() self.Cleared=true end
 function n:Clone()
  cloneCount+=1
  local clone=node(self.Class,self.Name); clone.Transparency=self.Transparency
  for _,child in self.Children do local copy=child:Clone(); copy.Parent=clone end
  return clone
 end
 return n
end
local function add(parent,class,name) local n=node(class,name); n.Parent=parent; return n end
local rep=node('Folder'); local particle=add(rep,'Folder','Particle'); local orb=add(particle,'Folder','Orb')
local money=add(orb,'Part','Money'); local eventFolder=add(orb,'Folder','EventDrops'); local event=add(eventFolder,'Model','Token')
add(event,'MeshPart','TokenBody'); add(event,'Part','Detail')
local player={Character=node('Model')}; local rootPart=add(player.Character,'Part','HumanoidRootPart'); rootPart.Parent=player.Character; rootPart.Position=vec(10,1,0)
local beat=signal(); local world=node('Workspace'); local moves=0; local lastCount=0
function world:BulkMoveTo(parts,frames) moves+=1; lastCount=#parts; for i,part in parts do assert(not part.CanCollide and not part.CanTouch and not part.CanQuery); part.CFrame=frames[i]; part.Position=frames[i].Position end end
local env=setmetatable({workspace=world,Instance={new=node},Vector3={new=vec},CFrame={new=frame},Enum={BulkMoveMode={FireCFrameChanged=1}},
 Random={new=function() return {NextInteger=function(_,a) return a end,NextNumber=function(_,a) return a end} end},
 game={GetService=function(_,key) if key=='ReplicatedStorage' then return rep elseif key=='Players' then return {LocalPlayer=player} else return {Heartbeat=beat} end end}},{__index=getfenv()})
local chunk=assert(loadstring(source)); setfenv(chunk,env); local Orbs=chunk()
assert(Orbs.Play('EventDrops',0.4,2,vec(0,0,0),player)==2)
assert(Orbs.Play('Money',0.25,1,vec(0,0,0),player)==1)
assert(Orbs.Play('Money',0.25,1,vec(0,0,0),{})==0)
beat:Fire(0.1); assert(lastCount==5 and moves==1)
rootPart.Position=vec(20,1,0); beat:Fire(0.4); beat:Fire(0.3)
assert(Orbs.GetDiagnostics().Active==0 and Orbs.GetDiagnostics().Allocated==3)
local before=cloneCount
assert(Orbs.Play('EventDrops',0.4,2,vec(0,0,0),player)==2)
assert(Orbs.Play('Money',0.25,1,vec(0,0,0),player)==1)
assert(cloneCount==before,'both existing farm and folder event resources must reuse their pool')
beat:Fire(1); beat:Fire(1)
assert(Orbs.Play('Missing',0.25,1,vec(0,0,0),player)==0)
for frameIndex=1,10 do
 beat:Fire(0.01)
 for _=1,100 do Orbs.Play('EventDrops',1,1000,vec(0,0,0),player) end
 assert(Orbs.GetDiagnostics().Allocated<=256 and Orbs.GetDiagnostics().Active<=256)
end
rootPart.Parent=nil; beat:Fire(0.01); assert(Orbs.GetDiagnostics().Active==0)
print('Orbs passed: unchanged farm API, EventDrops folder/model assets, shared batched movement, moving target, fade/reuse, budgets and removed-character cleanup')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush(); subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
