"""Run actual client picking/outline code against deterministic Roblox boundaries."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'Tower Defense R/ReplicatedStorage/GameModules/TowerInteraction.luau').read_text()
code='local source=[====['+source+']====]\n'+r'''
local function node(class,parent)
 local n={Class=class,Parent=parent,Attributes={}}
 function n:IsA(kind) return self.Class==kind or kind=='GuiObject' and self.Class=='GuiButton' end
 function n:FindFirstChild(key) return self[key] end
 function n:WaitForChild(key) return assert(self[key],key) end
 function n:GetAttribute(key) return self.Attributes[key] end
 function n:Destroy() self.Parent=nil; self.Destroyed=true end
 return n
end
local function vector(x)
 return setmetatable({X=x,Y=0},{__mul=function(a,b) return vector(a.X*b) end,__sub=function(a,b) return vector(a.X-b.X) end})
end
local world=node('Workspace')
world.Towers=node('Folder',world); world.Mobs=node('Folder',world); world.Units=node('Folder',world)
local origin,direction=vector(0),vector(1)
world.CurrentCamera={ScreenPointToRay=function(_,x,y) assert(x==100 and y==50); return {Origin=origin,Direction=direction} end}
local gui=node('PlayerGui'); local guiObjects={}
function gui:GetGuiObjectsAtPosition() return guiObjects end
local hits={}; local assistHit; local enemyHit; local radiusUsed; local rayCalls=0; local sphereCalls=0
function world:Raycast() rayCalls+=1; return table.remove(hits,1) end
function world:Spherecast(_,radius,distance,params) sphereCalls+=1; radiusUsed=radius; assert(distance.X<=1000); return assistHit end
local environment=setmetatable({game={GetService=function() return {GetPlayers=function() return {} end} end},
 Instance={new=function(kind) return node(kind) end},
 Enum={HighlightDepthMode={Occluded=1},RaycastFilterType={Exclude=1,Include=2}},
 Color3={fromRGB=function(...) return {...} end},RaycastParams={new=function() return {} end}}, {__index=getfenv()})
local chunk=assert(loadstring(source)); setfenv(chunk,environment)
local Interaction=chunk()
local picker=Interaction.new(world,gui)
local tower=node('Model',world.Towers); tower.Config=node('Folder',tower); tower.Config.Health=node('Folder',tower.Config); tower.Config.Health.HealthValue={Value=100}
local nested=node('Model',tower); local part=node('Part',nested)
local hit={Instance=part,Distance=20,Position=vector(20)}
assert(picker:Resolve(part)==tower)
hits={hit}
local result,model,kind=picker:Pick({X=100,Y=50})
assert(result==hit and model==tower and kind=='Tower' and sphereCalls==0)
picker:Update(tower,tower)
assert(picker.Selected.Enabled and picker.Selected.Adornee==tower and not picker.Hover.Enabled)
picker:Update(tower,nil); assert(picker.Hover.Enabled and not picker.Selected.Enabled)
local wall={Instance=node('Part',world),Distance=10,Position=vector(10)}
hits={wall,wall}; assistHit=hit
local _,blocked=picker:Pick({X=100,Y=50}); assert(not blocked,'wall must block assisted hit')
hits={wall}; assistHit=hit
local _,assisted=picker:Pick({X=100,Y=50}); assert(not assisted,'tower hover must not use assistance')
local border=node('Part',tower); border.Name='Border'; border.Transparency=1
local borderHit={Instance=border,Distance=19,Position=vector(19)}
local hidden=node('Part',tower); hidden.Transparency=1
local hiddenHit={Instance=hidden,Distance=19.5,Position=vector(19.5)}
hits={borderHit,hiddenHit,hit}; local before=sphereCalls
assert(select(2,picker:Pick({X=100,Y=50}))==tower and sphereCalls==before,'visible body must be picked through invisible tower helpers')
local unit=node('Model',world.Units); unit.EnemyStats=node('Folder',unit); unit.EnemyStats.Health={Value=100}
local unitHit={Instance=node('Part',unit),Distance=10,Position=vector(10)}
hits={wall,unitHit}; assistHit=unitHit
assert(select(2,picker:Pick({X=100,Y=50}))==unit,'existing unit assist must still work')
local enemy=node('Model',world.Mobs); enemy.EnemyStats=node('Folder',enemy); enemy.EnemyStats.Health={Value=100}
local enemyPart=node('Part',enemy); enemyHit={Instance=enemyPart,Distance=10,Position=vector(10)}
picker.UnitAssistRadius=0.75
assistHit=nil; hits={enemyHit}
local beforeSphere=sphereCalls
local _,exactEnemy,exactKind=picker:Pick({X=100,Y=50})
assert(exactEnemy==enemy and exactKind=='Mob' and sphereCalls==beforeSphere,'visible enemy geometry must resolve without assistance')
hits={wall}; assistHit=enemyHit
local _,outside=picker:Pick({X=100,Y=50})
assert(not outside,'a nearby enemy must not be accepted through an assist cast')
assistHit=nil
local card=node('Frame',gui); card.Name='MobHoverGui'; card.Active=true
local activeChild=node('GuiButton',card); guiObjects={activeChild}; hits={enemyHit}
assert(select(2,picker:Pick({X=100,Y=50}))==enemy,'tooltip must not block its own hover')
guiObjects={}; enemy.Attributes.Dead=true; hits={enemyHit}
assert(select(2,picker:Pick({X=100,Y=50}))==nil)
enemy.Attributes.Dead=false; enemyHit=nil
local button=node('GuiButton',gui); guiObjects={button}; local count=rayCalls
assert(picker:Pick({X=100,Y=50})==nil and rayCalls==count)
guiObjects={}; tower.Attributes.Dead=true
assert(picker:Resolve(part)==nil)
picker:Update(tower,tower); assert(not picker.Hover.Enabled and not picker.Selected.Enabled)
tower.Attributes.Dead=false; tower.Config.Health.HealthValue.Value=0
assert(picker:Resolve(part)==nil)
tower.Config.Health.HealthValue.Value=100; tower.Parent=nil
assert(picker:Resolve(part)==nil)
picker:Destroy(); assert(picker.Container.Destroyed)
print('Tower interaction checks passed: nested models, screen pointer, exact/assisted hit, occlusion, UI blocking, outline priority, death/removal, cleanup')
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau') as f:
 f.write(code); f.flush()
 subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True,cwd=root)
