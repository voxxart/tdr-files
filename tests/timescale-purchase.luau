local Purchase=require('../Tower Defense R/ServerScriptService/TimescaleSystem/Purchase')
local profiles={}
local function player(id)
 local p={UserId=id,Attributes={}}
 function p:SetAttribute(k,v) self.Attributes[k]=v end
 return p
end
Purchase.Bind(function(p) return profiles[p.UserId] end)
local p=player(1)
assert(not Purchase.Buy(p).Success)
profiles[1]={Gems=499,UnlockedTimescale=0}
local rejected=Purchase.Buy(p)
assert(rejected.Error=='You need 1 gems to purchase this!' and profiles[1].Gems==499)
profiles[1].Gems=200
assert(Purchase.Buy(p).Error=='You need 300 gems to purchase this!')
profiles[1].Gems=500
local result=Purchase.Buy(p)
assert(result.Success and result.Changed and result.Gems==0 and result.Owned)
assert(profiles[1].Gems==0 and profiles[1].UnlockedTimescale==1)
assert(p.Attributes.UnlockedTimescale==1 and p.Attributes.TimescaleGems==0)
assert(Purchase.Dirty(p))
local version=Purchase.Version(p)
local duplicate=Purchase.Buy(p)
assert(duplicate.Success and not duplicate.Changed and profiles[1].Gems==0)
assert(Purchase.Version(p)==version)
Purchase.MarkSaved(p,version)
assert(not Purchase.Dirty(p))
local rich=player(2);profiles[2]={Gems=900,UnlockedTimescale=0}
for i=1,10 do assert(Purchase.Buy(rich).Success) end
assert(profiles[2].Gems==400)
local invalid=player(3);profiles[3]={Gems=0/0}
assert(not Purchase.Buy(invalid).Success)
profiles[3]={Gems=1000};Purchase.Close(invalid)
assert(not Purchase.Buy(invalid).Success and profiles[3].Gems==1000)
Purchase.Forget(invalid)
print('Timescale purchase: loaded data, fixed price, shortages, exact balance, duplicate safety, dirty versions and closing guards passed')
