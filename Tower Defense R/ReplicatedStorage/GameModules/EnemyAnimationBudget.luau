local Visibility=require(script.Parent.ScreenVisibility)
local Budget={}
Budget.__index=Budget
function Budget.new(adapter)
 return setmetatable({Adapter=adapter,Records={},ByModel={},GameTime=0,Cursor=1},Budget)
end
local function clock(self,r)
 return self.GameTime-r.PauseTotal-(if r.PauseAt then self.GameTime-r.PauseAt else 0)
end
function Budget:Observe(model)
 local r=self.ByModel[model]
 if r then return r end
 local root=model.PrimaryPart or model:FindFirstChild('HumanoidRootPart')
 if not root then return nil end
 local radius=8
 local ok,size=pcall(function() return model:GetExtentsSize() end)
 if ok then radius=math.max(2,size.Magnitude/2) end
 r={Model=model,Root=root,Radius=radius,Visible=true,Virtual={},PauseTotal=0,Index=#self.Records+1}
 self.Records[r.Index]=r; self.ByModel[model]=r
 self:Check(r)
 return r
end
function Budget:Remove(model)
 local r=self.ByModel[model]
 if not r then return end
 local last=self.Records[#self.Records]
 self.Records[r.Index]=last; last.Index=r.Index; self.Records[#self.Records]=nil
 self.ByModel[model]=nil; table.clear(r.Virtual); r.Seek=nil
end
local function seek(track,position)
 local length=track.Length
 if length<=0 then return false end
 if track.Looped then position%=length
 elseif position>=length then track:Stop(0); return true end
 track.TimePosition=math.max(0,position)
 return true
end
function Budget:Check(r)
 local root=r.Model.PrimaryPart or r.Root
 if not root or not root.Parent then return end
 r.Root=root
 local becameReady=false
 if not r.VisualReady and r.Model:GetAttribute('EnemyVisualReady') then
  r.VisualReady=true
  local ok,size=pcall(function() return r.Model:GetExtentsSize() end)
  if ok then r.Radius=math.max(2,size.Magnitude/2) end
  becameReady=true
 end
 local visible=Visibility.Test(self.Adapter.Camera(),root.Position,r.Radius,self.Adapter.Margin or 48)
 if becameReady and visible and r.Visible then
  local tracks=self.Adapter.Tracks(r.Model)
  if not tracks or next(tracks)==nil then self.Adapter.Fallback(r.Model) end
 end
 if visible==r.Visible then return end
 r.Visible=visible
 local t=clock(self,r)
 if not visible then
  table.clear(r.Virtual)
  for _,track in pairs(self.Adapter.Tracks(r.Model) or {}) do
   if track.IsPlaying then
    table.insert(r.Virtual,{Track=track,Position=track.TimePosition,At=t,Rate=self.Adapter.Rate(r.Model,track.Name)})
    track:Stop(0)
   end
  end
 else
  if r.Pending then
   local pending=r.Pending; r.Pending=nil
   r.Seek=pending
   self.Adapter.Play(r.Model,pending.Name)
  else
   local playing=false
   for _,v in r.Virtual do
    local track=v.Track
    local position=v.Position+(t-v.At)*v.Rate
    if track.Looped or track.Length<=0 or position<track.Length then
     track:Play(0); self.Adapter.Speed(r.Model,track,track.Name); seek(track,position); playing=true
    end
   end
   if not playing then self.Adapter.Fallback(r.Model) end
  end
  table.clear(r.Virtual)
 end
end
function Budget:IsVisible(model)
 if not self.Adapter.IsEnemy(model) then return true end
 local r=self:Observe(model)
 return not r or r.Visible
end
function Budget:Request(model,name)
 if not self.Adapter.IsEnemy(model) then return false end
 local r=self:Observe(model)
 if not r then return false end
 r.LastRequest={Name=name,At=clock(self,r)}
 if not r.Visible then
  r.Pending=r.LastRequest; r.Seek=nil; table.clear(r.Virtual)
  return true
 end
 if r.Seek and r.Seek.Name~=name then r.Seek=nil end
 return false
end
function Budget:Played(model,track,name)
 local r=self.ByModel[model]
 if not r then return end
 if not r.Visible then
  track:Stop(0)
  if r.LastRequest and r.LastRequest.Name==name then r.Pending=r.LastRequest; table.clear(r.Virtual) end
  return
 end
 local pending=r.Seek
 if not pending or pending.Name~=name then return end
 pending.Track=track
 if track.Length>0 then
  local position=(clock(self,r)-pending.At)*self.Adapter.Rate(model,name)
  r.Seek=nil
  if not track.Looped and position>=track.Length then track:Stop(0); self.Adapter.Fallback(model)
  else seek(track,position) end
 end
end
function Budget:Stop(model,name)
 local r=self.ByModel[model]
 if not r then return end
 if not name or (r.Pending and r.Pending.Name==name) then r.Pending=nil end
 if not name or (r.Seek and r.Seek.Name==name) then r.Seek=nil end
 for index=#r.Virtual,1,-1 do if not name or r.Virtual[index].Track.Name==name then table.remove(r.Virtual,index) end end
end
function Budget:Pause(model,paused)
 local r=self.ByModel[model]
 if not r then return end
 if paused and not r.PauseAt then r.PauseAt=self.GameTime
 elseif not paused and r.PauseAt then r.PauseTotal+=self.GameTime-r.PauseAt; r.PauseAt=nil end
end
function Budget:IsPaused(model)
 local r=self.ByModel[model]
 return r and r.PauseAt~=nil
end
function Budget:Step(dt,speed)
 self.GameTime+=math.max(dt,0)*math.max(speed,0)
 for _=1,math.min(#self.Records,self.Adapter.ChecksPerFrame or 1024) do
  if self.Cursor>#self.Records then self.Cursor=1 end
  local r=self.Records[self.Cursor]
  if not r.Model.Parent then self:Remove(r.Model)
  else
   self:Check(r)
   if r.Seek and r.Seek.Track then self:Played(r.Model,r.Seek.Track,r.Seek.Name) end
   self.Cursor+=1
  end
 end
end
function Budget:Clear()
 table.clear(self.Records); table.clear(self.ByModel); self.Cursor=1
end
return Budget
