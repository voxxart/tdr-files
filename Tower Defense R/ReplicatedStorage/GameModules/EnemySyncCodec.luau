-- Bounded unreliable packets: 14-byte header, 8-byte records, <=900 bytes.
local Codec={HeaderSize=14,RecordSize=8,MaxBytes=900}
function Codec.IsNewer(sequence,previous)
 if previous==nil then return true end
 local delta=(sequence-previous)%4294967296
 return delta>0 and delta<2147483648
end
function Codec.Encode(active,sequence,timestamp,speedOf,send,maxBytes)
 local limit=math.clamp(math.floor(maxBytes or Codec.MaxBytes),22,Codec.MaxBytes)
 local capacity=math.floor((limit-Codec.HeaderSize)/Codec.RecordSize)
 local packets=0
 for first=1,#active,capacity do
  local count=math.min(capacity,#active-first+1)
  local packet=buffer.create(Codec.HeaderSize+count*Codec.RecordSize)
  buffer.writeu16(packet,0,count)
  buffer.writeu32(packet,2,sequence)
  buffer.writef64(packet,6,timestamp)
  local offset=Codec.HeaderSize
  for index=first,first+count-1 do
   local runtime=active[index]
   buffer.writeu32(packet,offset,runtime.Id)
   buffer.writeu16(packet,offset+4,math.clamp(math.round(runtime.Alpha*65535),0,65535))
   buffer.writei16(packet,offset+6,math.clamp(math.round(speedOf(runtime)*100),-32768,32767))
   offset+=Codec.RecordSize
  end
  send(packet); packets+=1
 end
 return packets
end
function Codec.Decode(packet,visit)
 if typeof(packet)~='buffer' or buffer.len(packet)<Codec.HeaderSize then return false end
 local count=buffer.readu16(packet,0)
 if buffer.len(packet)~=Codec.HeaderSize+count*Codec.RecordSize or buffer.len(packet)>Codec.MaxBytes then return false end
 local sequence=buffer.readu32(packet,2)
 local timestamp=buffer.readf64(packet,6)
 if timestamp~=timestamp or math.abs(timestamp)==math.huge then return false end
 local offset=Codec.HeaderSize
 for _=1,count do
  visit(buffer.readu32(packet,offset),buffer.readu16(packet,offset+4)/65535,buffer.readi16(packet,offset+6)/100,sequence,timestamp)
  offset+=Codec.RecordSize
 end
 return true
end
return Codec
