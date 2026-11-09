-- Client-only picking and two reusable outlines. No connections or per-tower objects.
local Players = game:GetService('Players')
local Interaction = {}
Interaction.UnitAssistRadius = 0.75
local passiveTooltips = {MobHoverGui=true, UnitHoverGui=true, TowerHoverGui=true}

function Interaction.new(world, playerGui)
	local self = setmetatable({World=world,PlayerGui=playerGui}, {__index=Interaction})
	self.Towers=world:WaitForChild('Towers')
	self.Mobs=world:WaitForChild('Mobs')
	self.Units=world:WaitForChild('Units')
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

function Interaction:Resolve(instance)
	local current=instance
	while current and current~=self.World do
		if current:IsA('Model') then
			local kind=if current.Parent==self.Towers then 'Tower' elseif current.Parent==self.Mobs then 'Mob' elseif current.Parent==self.Units then 'Unit' else nil
			if kind then
				if current:GetAttribute('Dead')==true then return nil end
				local stats=current:FindFirstChild(if kind=='Tower' then 'Config' else 'EnemyStats')
				local health=stats and stats:FindFirstChild('Health')
				if kind=='Tower' then health=health and health:FindFirstChild('HealthValue') end
				if stats and health and health.Value>0 then return current,kind end
				return nil
			end
		end
		current=current.Parent
	end
	return nil
end

function Interaction:IsBlocked(position)
	for _,object in self.PlayerGui:GetGuiObjectsAtPosition(position.X,position.Y) do
		local current=object
		local blocks=false
		while current and current~=self.PlayerGui do
			-- Hover cards are presentation, even if an authored child is Active.
			if passiveTooltips[current.Name] then blocks=false; break end
			if current:IsA('GuiObject') and (current.Active or current:IsA('GuiButton') or current:IsA('TextBox')) then blocks=true end
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
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude; params.IgnoreWater=true
	params.FilterDescendantsInstances=excluded
	local exact,model,kind
	-- Borders and invisible tower helpers are not the tower's visible body.
	-- Recast through them locally without changing placement/collision properties.
	for _=1,16 do
		exact=self.World:Raycast(ray.Origin,ray.Direction*1000,params)
		model,kind=self:Resolve(exact and exact.Instance)
		if kind~='Tower' or (exact.Instance.Name~='Border' and exact.Instance.Transparency~=1) then break end
		table.insert(excluded,exact.Instance); params.FilterDescendantsInstances=excluded
		exact,model,kind=nil,nil,nil
	end
	if model then return exact,model,kind end
	local assist=RaycastParams.new()
	assist.FilterType=Enum.RaycastFilterType.Include; assist.IgnoreWater=true
	local function assisted(radius,folders)
		if radius<=0 then return nil end
		assist.FilterDescendantsInstances=folders
		local distance=if exact then math.min(1000,exact.Distance+radius) else 1000
		local hit=self.World:Spherecast(ray.Origin,radius,ray.Direction*distance,assist)
		local target,targetKind=self:Resolve(hit and hit.Instance)
		if target and targetKind=="Unit" then
			local sight=self.World:Raycast(ray.Origin,hit.Position-ray.Origin,params)
			local visible=self:Resolve(sight and sight.Instance)
			if not sight or visible==target then return hit,target,targetKind end
		end
		return nil
	end
	local hit,target,targetKind=assisted(self.UnitAssistRadius,{self.Units})
	if target and targetKind=="Unit" then return hit,target,targetKind end

	return exact,nil,nil
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
	self.Container:Destroy()
end
return Interaction
