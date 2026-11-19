-- Only the server's loaded playerData is authoritative. Purchase never yields.
local Purchase={Price=500}
local getter
local versions,saved,closing={},{},{}
function Purchase.Bind(callback) getter=callback end
local function snapshot(data)
 local gems=data and data.Gems
 if gems==nil and data then gems=0 end
 local valid=type(gems)=='number' and gems==gems and math.abs(gems)~=math.huge and gems>=0
 return {Ready=data~=nil and valid,Gems=if valid then gems else 0,
  Owned=data~=nil and (tonumber(data.UnlockedTimescale) or 0)>=1,Price=Purchase.Price}
end
function Purchase.Status(player)
 return snapshot(getter and getter(player))
end
function Purchase.Publish(player)
 local status=Purchase.Status(player)
 player:SetAttribute('TimescaleGems',status.Gems)
 player:SetAttribute('UnlockedTimescale',if status.Owned then 1 else 0)
 player:SetAttribute('TimescalePurchaseReady',status.Ready and not closing[player.UserId])
 return status
end
function Purchase.Buy(player)
 local data=getter and getter(player)
 local result=snapshot(data)
 result.Success=false
 if closing[player.UserId] or not result.Ready then result.Error='Your data is not ready. Please try again.';return result end
 if result.Owned then result.Success=true;return result end
 if result.Gems<Purchase.Price then
  result.Error='You need '..tostring(math.ceil(Purchase.Price-result.Gems))..' gems to purchase this!'
  return result
 end
 -- No datastore call or other yield between checking ownership and both mutations.
 data.Gems=result.Gems-Purchase.Price
 data.UnlockedTimescale=1
 versions[player.UserId]=(versions[player.UserId] or 0)+1
 result=Purchase.Publish(player)
 result.Success=true;result.Changed=true
 return result
end
function Purchase.Version(player) return versions[player.UserId] or 0 end
function Purchase.Dirty(player) return Purchase.Version(player)>(saved[player.UserId] or 0) end
function Purchase.MarkSaved(player,version) saved[player.UserId]=math.max(saved[player.UserId] or 0,version or 0) end
function Purchase.Close(player) closing[player.UserId]=true end
function Purchase.Forget(player) versions[player.UserId]=nil;saved[player.UserId]=nil;closing[player.UserId]=nil end
return Purchase
