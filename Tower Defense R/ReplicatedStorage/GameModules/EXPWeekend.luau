-- Eastern local time, using US daylight-saving rules (2007 onward).
local Weekend={Multiplier=1.5}
local function weekday(timestamp) return (math.floor(timestamp/86400)+4)%7 end -- Sunday=0
local function firstSunday(year,month)
 local first=DateTime.fromUniversalTime(year,month,1).UnixTimestamp
 return 1+(7-weekday(first))%7
end
function Weekend.IsActive(timestamp)
 local year=DateTime.fromUnixTimestamp(timestamp):ToUniversalTime().Year
 local spring=DateTime.fromUniversalTime(year,3,firstSunday(year,3)+7,7).UnixTimestamp
 local autumn=DateTime.fromUniversalTime(year,11,firstSunday(year,11),6).UnixTimestamp
 local offset=if timestamp>=spring and timestamp<autumn then -4*3600 else -5*3600
 local eastern=timestamp+offset
 local day=weekday(eastern); local seconds=eastern%86400
 return (day==5 and seconds>=12*3600) or day==6 or (day==0 and seconds<20*3600)
end
function Weekend.ApplyXP(amount,active)
 return math.round(amount*(if active then Weekend.Multiplier else 1))
end
return Weekend
