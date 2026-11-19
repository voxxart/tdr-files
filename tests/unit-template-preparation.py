"""Run startup traversal and idempotent preparation against nested skin templates."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
base=root/'Tower Defense R/ServerScriptService'
preparation=(base/'UnitSystem/TemplatePreparation.luau').read_text()
startup=(base/'AntiLagUnits.server.luau').read_text()
code=r'''
local warnings=0
local warn=function() warnings+=1 end
local function node(kind,name,children)
 local n={Name=name,Children=children or {}}
 function n:IsA(k) return kind==k end
 function n:FindFirstChild(k) return self.Children[k] end
 function n:WaitForChild(k) return assert(self.Children[k],k) end
 function n:GetChildren() local r={} for _,v in self.Children do table.insert(r,v) end return r end
 function n:GetFullName() return self.Name end
 function n:Destroy() self.Destroyed=true end
 function n:Clone()
  local copy=node(kind,self.Name)
  for k,v in self.Children do copy.Children[k]=node('Folder',k) end
  return copy
 end
 setmetatable(n,{__newindex=function(self,k,v)
  rawset(self,k,v)
  if k=='Parent' then v.Children[self.Name]=self end
 end})
 return n
end
local Preparation=(function()
'''+preparation+r'''
end)()
local rootPart=node('BasePart','HumanoidRootPart',{Weld=node('Folder','Weld')})
local skin=node('Model','Tank1',{HumanoidRootPart=rootPart})
local authored=node('BasePart','Hitbox')
local default=node('Model','Tank1',{HumanoidRootPart=node('BasePart','HumanoidRootPart'),Hitbox=authored})
local nested=node('Model','NestedRig')
skin.Children.NestedRig=nested
local units=node('Folder','Units',{['Motor Pool']=node('Folder','Motor Pool',{
 Golden=node('Folder','Golden',{Tank1=skin}),Default=node('Folder','Default',{Tank1=default})})})
local rep=node('Folder','ReplicatedStorage',{Units=units})
local game={GetService=function() return rep end}
local script={Parent={UnitSystem={TemplatePreparation=Preparation}}}
local require=function(m) return m end
'''+startup+r'''
assert(warnings==0,'startup incorrectly prepared folders or nested rigs')
local hitbox=skin.Children.Hitbox
assert(hitbox and hitbox.Transparency==1 and hitbox.CanCollide==false and hitbox.Anchored and hitbox.CanTouch)
assert(hitbox.Children.Weld.Destroyed,'cloned constraints not stripped')
assert(default.Children.Hitbox==authored,'authored hitbox replaced')
assert(Preparation.Prepare(skin) and skin.Children.Hitbox==hitbox,'duplicate hitbox')
local late=node('Model','NewSkin',{HumanoidRootPart=node('BasePart','HumanoidRootPart')})
assert(Preparation.Prepare(late) and late.Children.Hitbox,'on-demand preparation failed')
assert(not Preparation.Prepare(node('Model','Broken')))
assert(not Preparation.Prepare(node('Model','WrongHitbox',{HumanoidRootPart=rootPart,Hitbox=node('Folder','Hitbox')})))
print('Unit preparation: nested skins, preserved hitboxes, no duplicate preparation, late templates and validation passed')
'''
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau') as f:
 f.write(code);f.flush();subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True)
