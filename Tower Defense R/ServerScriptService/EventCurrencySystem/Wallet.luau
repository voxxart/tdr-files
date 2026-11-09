local Config=require(game.ReplicatedStorage.GameModules.EventCurrencyConfig)
local Wallet={}
local getter
local versions={}
local saved={}
local closing={}
function Wallet.Bind(callback) getter=callback end
function Wallet.CanCredit(player)
 local data=getter and getter(player)
 local key=Config.CurrencyKey
 return not closing[player.UserId] and type(key)=='string' and key~='' and data~=nil and (data[key]==nil or type(data[key])=='number')
end
function Wallet.Publish(player)
 local data=getter and getter(player)
 if data and Wallet.CanCredit(player) then
  player:SetAttribute('EventCurrencyKey',Config.CurrencyKey)
  player:SetAttribute('EventCurrencyBalance',data[Config.CurrencyKey] or 0)
 end
end
function Wallet.Credit(player,amount)
 if not Wallet.CanCredit(player) or type(amount)~='number' or amount~=amount or amount<=0 or amount==math.huge then return false end
 local data=getter(player); local key=Config.CurrencyKey
 data[key]=(data[key] or 0)+math.floor(amount)
 versions[player.UserId]=(versions[player.UserId] or 0)+1
 Wallet.Publish(player)
 return true
end
function Wallet.Version(player) return versions[player.UserId] or 0 end
function Wallet.Dirty(player) return Wallet.Version(player)>(saved[player.UserId] or 0) end
function Wallet.MarkSaved(player,version) saved[player.UserId]=math.max(saved[player.UserId] or 0,version or 0) end
function Wallet.Close(player) closing[player.UserId]=true end
function Wallet.Forget(player) versions[player.UserId]=nil; saved[player.UserId]=nil; closing[player.UserId]=nil end
return Wallet
