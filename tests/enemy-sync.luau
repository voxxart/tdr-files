local Codec=require('../Tower Defense R/ReplicatedStorage/GameModules/EnemySyncCodec')
local active={}
for id=1,5000 do active[id]={Id=id,Alpha=id/5001,Speed=id%200-50} end
local packets={}
local count=Codec.Encode(active,7,123.5,function(r) return r.Speed end,function(packet) table.insert(packets,packet) end)
assert(count==46)
local seen,total={},0
for index=#packets,1,-1 do
 local packet=packets[index]
 assert(buffer.len(packet)<=900)
 assert(Codec.Decode(packet,function(id,alpha,speed,seq,time)
  assert(not seen[id]); seen[id]=true; total+=1
  assert(math.abs(alpha-active[id].Alpha)<1/65535 and speed==active[id].Speed and seq==7 and time==123.5)
 end))
end
assert(total==5000)
assert(not Codec.Decode(buffer.create(3),function() error('malformed') end))
local broken=buffer.create(22); buffer.writeu16(broken,0,500)
assert(not Codec.Decode(broken,function() error('truncated') end))
assert(Codec.IsNewer(7,nil) and Codec.IsNewer(8,7) and not Codec.IsNewer(7,7) and not Codec.IsNewer(6,7))
assert(Codec.IsNewer(0,4294967295) and not Codec.IsNewer(4294967295,0))
assert(Codec.Encode({},1,0,function() return 0 end,function() error('empty packet') end)==0)
print('Enemy sync passed: 5000 records in 46 bounded packets, quantization, reordered chunks, malformed data, sequence wrap')
