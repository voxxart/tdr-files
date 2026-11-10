-- Client-only picking: shared rays/outlines and one geometry listener per actor folder.
local Players = game:GetService('Players')
local Rep = game:GetService('ReplicatedStorage')
local Interaction = {}
Interaction.MaxSkippedParts = 32
local helperNames = {Border=true,Hitbox=true,EnemyProxyRoot=true}
local function visiblePart(part,model)
 if part.Transparency>=1 or part.LocalTransparencyModifier>=1 then return false end
 if model then
  if helperNames[part.Name] then return false end
  local current=part.Parent
  while current and current~=model do
   if current.Name=='Effects' then return false end
   current=current.Parent
  end
 end
 return true
end
local passiveTooltips = {MobHoverGui=true, UnitHoverGui=true, TowerHoverGui=true}

function Interaction.new(world, playerGui)
	local self = setmetatable({World=world,PlayerGui=playerGui}, {__index=Interaction})
	self.Towers=world:WaitForChild('Towers')
	self.Mobs=world:WaitForChild('Mobs')
	self.Units=world:WaitForChild('Units')
 self.Params=RaycastParams.new()
 self.Params.FilterType=Enum.RaycastFilterType.Exclude; self.Params.IgnoreWater=true
 self.Params.RespectCanCollide=false
 self.Connections={}
 local function prepare(part)
  if not part:IsA('BasePart') then return end
  local owner,kind=self:Owner(part)
  -- Tower placement borders overlap nearby towers. Remove these permanent
  -- helpers from local queries instead of spending recasts on every border.
  if kind=='Tower' and helperNames[part.Name] then part.CanQuery=false; return end
  if part.CanQuery then return end
  -- Correct authored non-queryable body parts locally, without touching physics.
  if owner and visiblePart(part,owner) then part.CanQuery=true end
 end
 for _,folder in {self.Towers,self.Mobs,self.Units} do
  table.insert(self.Connections,folder.DescendantAdded:Connect(prepare))
  for _,part in folder:GetDescendants() do prepare(part) end
 end
	self.Container=Instance.new('Folder')
	self.Container.Name='TowerInteractionVisuals'
	self.Container.Parent=world
	local function outline(name,color)
		local h=Instance.new('Highlight')
		h.Name=name; h.DepthMode=Enum.HighlightDepthMode.Occluded
		h.FillTransparency=1; h.OutlineTransparency=0
		h.OutlineColor=color; h.Enabled=false; h.Parent=self.Container
		return h
	end
	self.Hover=outline('Hover',Color3.fromRGB(255,255,255))
	self.Selected=outline('Selected',Color3.fromRGB(70,210,255))
	return self
end

function Interaction:Owner(instance)
	local current=instance
	while current and current~=self.World do
		if current:IsA('Model') then
			local kind=if current.Parent==self.Towers then 'Tower' elseif current.Parent==self.Mobs then 'Mob' elseif current.Parent==self.Units then 'Unit' else nil
			if kind then return current,kind end
		end
		current=current.Parent
	end
	return nil
end

function Interaction:Resolve(instance)
 local model,kind=self:Owner(instance)
 if not model or model:GetAttribute('Dead')==true then return nil end
 local stats=model:FindFirstChild(if kind=='Tower' then 'Config' else 'EnemyStats')
 local health=stats and stats:FindFirstChild('Health')
 if kind=='Tower' then health=health and health:FindFirstChild('HealthValue') end
 if health and health.Value>0 then return model,kind end
 return nil
end

function Interaction:IsBlocked(position)
	for _,object in self.PlayerGui:GetGuiObjectsAtPosition(position.X,position.Y) do
		local current=object
		local blocks=false
		while current and current~=self.PlayerGui do
			-- Hover cards are presentation, even if an authored child is Active.
			if passiveTooltips[current.Name] then blocks=false; break end
			if current:IsA('GuiButton') or current:IsA('TextBox') or current:IsA('ScrollingFrame') then blocks=true
   elseif current:IsA('GuiObject') and current.Active and current.BackgroundTransparency<1 then blocks=true end
			current=current.Parent
		end
		if blocks then return true end
	end
	return false
end

function Interaction:Pick(position,ignore)
	local camera=self.World.CurrentCamera
	if not camera or self:IsBlocked(position) then return nil,nil,nil end
	-- GetMouseLocation/InputObject.Position use screen coordinates, including inset.
	local ray=camera:ScreenPointToRay(position.X,position.Y)
	local excluded={camera,self.Container}
	if ignore then table.insert(excluded,ignore) end
	local dependencies=self.World:FindFirstChild('GameDependencies')
	local range=dependencies and dependencies:FindFirstChild('Range')
	if range then table.insert(excluded,range) end
	for _,player in Players:GetPlayers() do
		if player.Character then table.insert(excluded,player.Character) end
	end
 local params=self.Params
 params.CollisionGroup=Rep:GetAttribute('InteractionQueryGroup') or 'Default'
 -- Each ray starts at the exact cursor. No nearest-model or radius assistance.
 -- Recasting removes only invisible helpers, effects, and retired models.
 for _=1,self.MaxSkippedParts do
  params.FilterDescendantsInstances=excluded
  local hit=self.World:Raycast(ray.Origin,ray.Direction*1000,params)
  if not hit then return nil,nil,nil end
  local owner=self:Owner(hit.Instance)
  local model,kind=self:Resolve(owner)
  if owner and not model then table.insert(excluded,owner)
  elseif not visiblePart(hit.Instance,owner) then table.insert(excluded,hit.Instance)
  elseif model then return hit,model,kind
  else return hit,nil,nil end -- Solid map geometry occludes everything behind it.
 end
 return nil,nil,nil
end

function Interaction:Update(hovered,selected)
	local function set(highlight,model)
		local valid,kind=self:Resolve(model)
		highlight.Adornee=if kind=='Tower' then valid else nil
		highlight.Enabled=highlight.Adornee~=nil
	end
	set(self.Selected,selected)
	set(self.Hover,if hovered~=selected then hovered else nil)
end

function Interaction:Destroy()
 for _,connection in self.Connections do connection:Disconnect() end
 table.clear(self.Connections)
	self.Container:Destroy()
end
return Interaction
