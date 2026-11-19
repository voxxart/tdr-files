local Resolver=require('../Tower Defense R/ServerScriptService/UnitSystem/TemplateResolver')
local function node(kind,name,children)
 local n={Name=name,Children=children or {},Attributes={}}
 function n:IsA(class) return class==kind end
 function n:FindFirstChild(key) return self.Children[key] end
 function n:GetAttribute(key) return self.Attributes[key] end
 return n
end
local golden=node('Model','Tank1')
local default=node('Model','Tank1')
local legacy=node('Model','Tank1')
local units=node('Folder','Units',{Tank1=legacy,['Motor Pool']=node('Folder','Motor Pool',{
 Golden=node('Folder','Golden',{Tank1=golden}),Default=node('Folder','Default',{Tank1=default})})})
local tower=node('Model','Golden Motor Pool')
tower.Attributes.TowerName='Motor Pool';tower.Attributes.AppearanceName='Golden'
assert(Resolver.Resolve(units,'Tank1',tower)==golden)
tower.Attributes.AppearanceName='Missing'
assert(Resolver.Resolve(units,'Tank1',tower)==default)
tower.Attributes.AppearanceName='Golden'
units.Children['Motor Pool'].Children.Golden.Children.Tank1=node('Folder','Tank1')
assert(Resolver.Resolve(units,'Tank1',tower)==default,'non-model must fall back')
units.Children['Motor Pool'].Children.Default.Children.Tank1=nil
assert(Resolver.Resolve(units,'Tank1',tower)==legacy)
assert(Resolver.Resolve(units,'Tank1',nil)==legacy)
assert(Resolver.Resolve(units,'Missing',tower)==nil)
assert(Resolver.Resolve(nil,'Tank1',tower)==nil)
-- Another tower must not accidentally receive Motor Pool's Golden units.
tower.Attributes.TowerName='Reaper'
assert(Resolver.Resolve(units,'Tank1',tower)==legacy)
local reaper=node('Model','Soul')
units.Children.Reaper=node('Folder','Reaper',{Default=node('Folder','Default',{Soul=reaper})})
tower.Attributes.AppearanceName=nil
assert(Resolver.Resolve(units,'Soul',tower)==reaper)
print('Unit templates: canonical tower, selected skin, per-unit Default, legacy, isolation and invalid models passed')
