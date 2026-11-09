-- Client-only death presentations: pooled rigs/anchors, bounded effects, game time.
local Rep=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local Visibility=require(Rep.GameModules.ScreenVisibility)
local Pool=require(Rep.GameModules.EnemyDeathPool)
local Settings=require(Rep.GameModules.EnemyData).Settings
local Mobs=Rep:WaitForChild('Mobs')
local Info=workspace:WaitForChild('Info')
local Player=Players.LocalPlayer
local Visual=Instance.new('Folder'); Visual.Name='EnemyDeathVisuals'; Visual.Parent=workspace
local descriptors={}
local function running() return Info.GameRunning.Value and Info.Message.Value~='VICTORY' and Info.Message.Value~='GAME OVER' end
local function collect(folder,class)
 local list={}
 if folder then for _,object in folder:GetDescendants() do if object:IsA(class) then table.insert(list,object) end end end
 table.sort(list,function(a,b) return a.Name<b.Name end)
 while #list>8 do table.remove(list) end
 return list
end
local function describe(template)
 local cached=descriptors[template]
 if cached then return cached end
 local fx=template:FindFirstChild('DeathEffects')
 if not fx then return nil end
 cached={Animations=collect(fx:FindFirstChild('Animations'),'Animation'),Sounds=collect(fx:FindFirstChild('Sounds'),'Sound'),Particles=collect(fx:FindFirstChild('Particles'),'ParticleEmitter'),
  Duration=tonumber(fx:GetAttribute('Duration')) or 2,Radius=math.max(2,template:GetExtentsSize().Magnitude/2)}
 descriptors[template]=cached
 return cached
end
local adapter={}
function adapter.Create(template)
 local def=describe(template)
 local model,root
 if #def.Animations>0 then
  model=template:Clone()
  for _,name in {'EnemyStats','Effects','Alpha','Hitbox'} do local child=model:FindFirstChild(name); if child then child:Destroy() end end
  root=model.PrimaryPart or model:FindFirstChild('HumanoidRootPart') or model:FindFirstChildWhichIsA('BasePart')
  if not root then model:Destroy(); return nil end
  model.PrimaryPart=root
 else
  root=Instance.new('Part'); root.Name='EnemyDeathFX'; root.Size=Vector3.new(0.1,0.1,0.1); root.Transparency=1; model=root
 end
 local entry={Model=model,Root=root,Definition=def,Tracks={},Sounds={},Emitters={},Motors={}}
 for _,object in model:GetDescendants() do
  if object:IsA('Script') or object:IsA('LocalScript') then object:Destroy()
  elseif object:IsA('BasePart') then object.CanCollide=false; object.CanQuery=false; object.CanTouch=false; object.Massless=true
  elseif object:IsA('Motor6D') then entry.Motors[object]=object.Transform
  elseif object:IsA('ParticleEmitter') or object:IsA('BillboardGui') or object:IsA('SurfaceGui') then object.Enabled=false
  elseif object:IsA('Sound') then object:Stop() end
 end
 root.Anchored=true; root.CanCollide=false; root.CanQuery=false; root.CanTouch=false
 local attachment=Instance.new('Attachment'); attachment.Parent=root
 for _,source in def.Particles do
  local emitter=source:Clone(); emitter.Enabled=false; emitter.Parent=attachment
  table.insert(entry.Emitters,{Object=emitter,Count=math.clamp(math.floor(tonumber(source:GetAttribute('EmitCount')) or 20),0,100)})
 end
 for _,source in def.Sounds do
  local sound=source:Clone(); sound.Looped=false; sound.Parent=root
  table.insert(entry.Sounds,{Object=sound,Speed=sound.PlaybackSpeed})
 end
 if #def.Animations>0 then
  local animator=model:FindFirstChildWhichIsA('Animator',true)
  if not animator then
   local controller=model:FindFirstChildWhichIsA('AnimationController',true) or model:FindFirstChildWhichIsA('Humanoid',true)
   if not controller then controller=Instance.new('AnimationController'); controller.Parent=model end
   animator=Instance.new('Animator'); animator.Parent=controller
  end
  for _,animation in def.Animations do
   local ok,track=pcall(function() return animator:LoadAnimation(animation) end)
   if ok then track.Looped=false; track.Priority=Enum.AnimationPriority.Action4; table.insert(entry.Tracks,track) end
  end
 end
 return entry
end
function adapter.Reset(entry)
 for _,track in entry.Tracks do track:Stop(0) end
 for _,sound in entry.Sounds do sound.Object:Stop() end
 for _,emitter in entry.Emitters do emitter.Object:Clear() end
 for motor,transform in entry.Motors do motor.Transform=transform end
 entry.Model.Parent=nil; entry.Track=nil; entry.Sound=nil; entry.Visible=nil; entry.SoundPaused=false
end
function adapter.Begin(entry,args,time)
 adapter.Reset(entry)
 entry.Started=time; entry.Model:PivotTo(args.CFrame); entry.Model.Parent=Visual
 local random=Random.new(tonumber(args.Id) or 0)
 if #entry.Tracks>0 then entry.Track=entry.Tracks[random:NextInteger(1,#entry.Tracks)] end
 if #entry.Sounds>0 then entry.Sound=entry.Sounds[random:NextInteger(1,#entry.Sounds)]; entry.Sound.Object:Play() end
 local remaining=if args.Low then 50 else (Settings.DeathParticlesPerEffect or 200)
 for _,emitter in entry.Emitters do
  local count=math.min(remaining,emitter.Count); remaining-=count
  emitter.Object:Emit(count)
 end
 adapter.Update(entry,math.max(Info.GameSpeed.Value,0),time)
end
function adapter.Update(entry,speed,time)
 speed=math.max(speed,0)
 local visible=Visibility.Test(workspace.CurrentCamera,entry.Root.Position,entry.Definition.Radius,Settings.AnimationScreenMargin or 48)
 local track=entry.Track
 if track then
  if visible then
   local elapsed=time-entry.Started
   if track.Length<=0 or elapsed<track.Length then
    if not track.IsPlaying then track:Play(0); if track.Length>0 then track.TimePosition=math.min(elapsed,track.Length) end end
    track:AdjustSpeed(speed)
   end
  elseif track.IsPlaying then track:Stop(0) end
 end
 local sound=entry.Sound
 if sound then
  if speed==0 then if sound.Object.IsPlaying then sound.Object:Pause(); entry.SoundPaused=true end
  else
   sound.Object.PlaybackSpeed=sound.Speed*speed
   if entry.SoundPaused then sound.Object:Resume(); entry.SoundPaused=false end
  end
 end
 for _,emitter in entry.Emitters do emitter.Object.TimeScale=math.clamp(speed,0,1) end
end
function adapter.Destroy(entry)
 for _,track in entry.Tracks do track:Destroy() end
 entry.Model:Destroy()
end
local pool=Pool.new(adapter,Settings.MaxDeathPresentations or 48,Settings.DeathPresentationsPerFrame or 6)
local connections={}
connections[#connections+1]=Rep.Events:WaitForChild('EnemyDeath').OnClientEvent:Connect(function(name,cframe,id)
 if not running() or typeof(name)~='string' or typeof(cframe)~='CFrame' then return end
 if pool.Tokens<1 or #pool.Active>=pool.Maximum then return end
 local template=Mobs:FindFirstChild(name)
 local def=template and describe(template)
 if not def or not Visibility.Test(workspace.CurrentCamera,cframe.Position,def.Radius,Settings.AnimationScreenMargin or 48) then return end
 local vfx=Player:FindFirstChild('VFX')
 pool:Emit(template,{CFrame=cframe,Id=id,Duration=def.Duration,Low=vfx and vfx.Value=='Low'})
end)
connections[#connections+1]=RunService.RenderStepped:Connect(function(dt)
 if not running() then if #pool.Active>0 then pool:Clear() end; return end
 local vfx=Player:FindFirstChild('VFX')
 pool:Step(dt,Info.GameSpeed.Value,vfx and vfx.Value=='Low')
end)
local function clear() if not running() then pool:Clear() end end
connections[#connections+1]=Info.GameRunning.Changed:Connect(clear)
connections[#connections+1]=Info.Message.Changed:Connect(clear)
script.Destroying:Connect(function()
 for _,connection in connections do connection:Disconnect() end
 pool:Destroy(); Visual:Destroy(); table.clear(descriptors)
end)
