-- Called by the existing SettingsAudio controller; no extra render connection.
local Mixer={}; Mixer.__index=Mixer
local function fade(state,target,duration)
 if state.Target==target and state.Duration==duration then return end
 state.From=state.Gain; state.Target=target; state.Time=0; state.Duration=math.max(0,duration)
end
local function advance(state,dt)
 state.Time+=dt
 local t=if state.Duration>0 then math.clamp(state.Time/state.Duration,0,1) else 1
 local eased=t*t*(3-2*t)
 state.Gain=state.From+(state.Target-state.From)*eased
end
function Mixer.new(audio,world,info)
 local self=setmetatable({Audio=audio,World=world,Info=info,Tracks={},Desired='',StartedAt=0,Pending=0,Fade=4,Ambience={Gain=1,From=1,Target=1,Time=0,Duration=0}},Mixer)
 self.Http=game:GetService('HttpService')
 self.Connection=info:GetAttributeChangedSignal('BossAudioSnapshot'):Connect(function() self:Read() end)
 self:Read()
 return self
end
function Mixer:Read()
 local raw=self.Info:GetAttribute('BossAudioSnapshot'); if type(raw)~='string' then return end
 local ok,data=pcall(self.Http.JSONDecode,self.Http,raw)
 if not ok or type(data)~='table' then return end
 self.Fade=math.clamp(tonumber(data.Fade) or 4,0,15)
 self.Desired=if type(data.Track)=='string' then data.Track else ''
 self.StartedAt=tonumber(data.StartedAt) or 0
 self.BaseVolume=if type(data.Volume)=='number' and data.Volume==data.Volume then math.clamp(data.Volume,0,10) else nil
 self.Terminal=data.Terminal==true
 self.Final=data.Final==true
 self.Pending=0
 fade(self.Ambience,if data.AmbienceMuted then 0 else 1,self.Fade)
 -- Late clients must not briefly play ambience during an already-active lock.
 if not self.Initialized or self.Terminal then
  self.Ambience.Gain=if data.AmbienceMuted then 0 else 1; self.Ambience.From=self.Ambience.Gain
  self.Audio:SetSceneGain('Ambience',self.Ambience.Gain)
 end
 self.Initialized=true
 self:Select()
end
function Mixer:Resolve()
 if self.Desired=='' then return nil end
 local object=self.World:FindFirstChild('Music')
 for _,part in string.split(self.Desired,'.') do object=object and object:FindFirstChild(part) end
 return if object and object:IsA('Sound') then object else nil
end
function Mixer:Select()
 local sound=self:Resolve()
 for object,state in self.Tracks do fade(state,if object==sound then 1 else 0,if self.Terminal then 0.5 else self.Fade) end
 if not sound then return end
 local state=self.Tracks[sound]
 if not state then
  local group=self.Audio:SoundFader(sound)
  if not group then return end
  group.Volume=0
  state={OriginalVolume=sound.Volume,OriginalLooped=sound.Looped,Gain=0,From=0,Target=0,Time=0,Duration=0,Group=group,Seek=true,StartedAt=self.StartedAt}
  self.Tracks[sound]=state
 end
 if state.StartedAt~=self.StartedAt then state.StartedAt=self.StartedAt; state.Seek=true end
 if self.BaseVolume~=nil then sound.Volume=self.BaseVolume end
 sound.Looped=true
 if not sound.IsPlaying then state.Seek=true; state.StartedAt=self.StartedAt; sound:Play() end
 fade(state,1,self.Fade)
end
function Mixer:Step(dt)
 dt=math.max(0,dt)
 local running=self.Info:FindFirstChild('GameRunning')
 local message=self.Info:FindFirstChild('Message')
 if running and running.Value then self.SeenRunning=true end
 if not self.Terminal and ((self.SeenRunning and running and not running.Value) or (message and (message.Value=='VICTORY' or message.Value=='GAME OVER'))) then
  self.Terminal=true; self.Desired=''; fade(self.Ambience,0,0); self:Select()
 end
 self.Pending-=dt
 if self.Desired~='' and self.Pending<=0 then self.Pending=0.25; self:Select() end
 advance(self.Ambience,dt); self.Audio:SetSceneGain('Ambience',self.Ambience.Gain)
 for sound,state in self.Tracks do
  if not sound.Parent or not state.Group.Parent then
   if sound.Parent then sound:Stop(); sound.Looped=state.OriginalLooped; sound.Volume=state.OriginalVolume end
   self.Tracks[sound]=nil
  else
   advance(state,dt); state.Group.Volume=state.Gain
   if state.Seek and sound.TimeLength>0 then
    local age=math.max(0,self.World:GetServerTimeNow()-state.StartedAt)
    sound.TimePosition=if sound.Looped then age%sound.TimeLength else math.min(age,math.max(0,sound.TimeLength-0.01))
    state.Seek=false
   end
   if state.Target==0 and state.Gain<=0.0001 then if sound.IsPlaying then sound:Stop() end; sound.Looped=state.OriginalLooped; sound.Volume=state.OriginalVolume; state.Seek=false end
  end
 end
end
function Mixer:Destroy()
 self.Connection:Disconnect()
 for sound,state in self.Tracks do if sound.Parent then sound:Stop(); sound.Looped=state.OriginalLooped; sound.Volume=state.OriginalVolume end end
 table.clear(self.Tracks)
end
return Mixer
