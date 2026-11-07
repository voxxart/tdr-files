local Data=require('../Tower Defense R/ReplicatedStorage/GameModules/AdvancedStatsData')
local def={AdvancedStats1={Title='Base',One='Base only'},Upgrades={
 [1]={AdvancedStats10={Title='Last',Nine='Ninth'},AdvancedStats2={Title='Second',Three='Third',One='First'},AdvancedStats1={Title='Empty'},AdvancedStats11={One='Ignored'}},
 [2]={},[3]={AdvancedStats1={Title='New', 'Array one','Array two',false,'Fourth'}},
}}
local groups=Data.ForLevel(def,1)
assert(#groups==2 and groups[1].Index==2 and groups[2].Index==10)
assert(groups[1].Items[1].Name=='One' and groups[1].Items[2].Name=='Three')
assert(groups[2].Items[1].Name=='Nine')
assert(#Data.ForLevel(def,2)==0,'metadata must not carry forward')
assert(Data.ForLevel(def,0)[1].Title=='Base')
assert(#Data.ForLevel(def,3)[1].Items==3)
assert(#Data.ForLevel(nil,0)==0 and #Data.ForLevel(def,4)==0)
assert(Data.IsKey('AdvancedStats1') and Data.IsKey('AdvancedStats10'))
assert(not Data.IsKey('AdvancedStats11') and not Data.IsKey('AdvancedStats0') and not Data.IsKey('AdvancedStats01') and not Data.IsKey(1))
print('Advanced stats data passed: exact level, group/item order, sparse entries, limits, optional data')
