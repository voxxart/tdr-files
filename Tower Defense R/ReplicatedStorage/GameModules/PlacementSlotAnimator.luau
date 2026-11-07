local TweenService = game:GetService('TweenService')
local function border(frame,thickness)
	local overlay=Instance.new('Frame')
	overlay.Name='PlacementBorder'
	overlay.Size=UDim2.fromScale(1,1)
	overlay.BackgroundTransparency=1
	overlay.BorderSizePixel=0
	overlay.Active=false
	overlay.ZIndex=frame.ZIndex+2
	local button=frame:FindFirstChild('Button')
	local corner=frame:FindFirstChildOfClass('UICorner') or (button and button:FindFirstChildOfClass('UICorner'))
	if corner then corner:Clone().Parent=overlay end
	local stroke=Instance.new('UIStroke')
	stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
	stroke.Color=Color3.new(1,1,1)
	stroke.Thickness=thickness
	stroke.Transparency=1
	stroke.Parent=overlay
	overlay.Parent=frame
	return overlay,stroke
end
local Animator = {}
Animator.__index = Animator
Animator.SelectedScale = 1.12

function Animator.new()
	return setmetatable({Slots={},Selected=nil},Animator)
end

function Animator:Register(index,frame)
	local previous=self.Slots[index]
	if previous then
		if previous.Frame==frame then return end
		self:Release(index)
	end
	local scale=frame:FindFirstChildOfClass('UIScale')
	local owned=not scale
	if not scale then scale=Instance.new('UIScale'); scale.Name='PlacementScale'; scale.Parent=frame end
	local layers={}
	for _,spec in {{8,0.96},{5,0.9},{2,0.05}} do
		local overlay,stroke=border(frame,spec[1])
		table.insert(layers,{Overlay=overlay,Stroke=stroke,Transparency=spec[2]})
	end
	self.Slots[index]={Frame=frame,Scale=scale,Base=scale.Scale,Owned=owned,Layers=layers}
	if self.Selected==index then self:Animate(index,true) end
end

function Animator:Animate(index,selected)
	local slot=self.Slots[index]
	if not slot then return end
	if slot.Tween then slot.Tween:Cancel(); slot.Tween=nil end
	if not slot.Frame.Parent or not slot.Scale.Parent then return end
	slot.Tween=TweenService:Create(slot.Scale,
		TweenInfo.new(if selected then 0.24 else 0.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
		{Scale=slot.Base*(if selected then self.SelectedScale else 1)})
	slot.Tween:Play()
	for _,layer in slot.Layers do
		if layer.Tween then layer.Tween:Cancel() end
		layer.Tween=TweenService:Create(layer.Stroke,
			TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
			{Transparency=if selected then layer.Transparency else 1})
		layer.Tween:Play()
	end
end

function Animator:Select(index)
	if self.Selected==index then return end
	local previous=self.Selected
	self.Selected=index
	if previous then self:Animate(previous,false) end
	if index then self:Animate(index,true) end
end

function Animator:Release(index)
	local slot=self.Slots[index]
	if not slot then return end
	if slot.Tween then slot.Tween:Cancel() end
	for _,layer in slot.Layers do
		if layer.Tween then layer.Tween:Cancel() end
		layer.Overlay:Destroy()
	end
	if slot.Scale.Parent then
		if slot.Owned then slot.Scale:Destroy() else slot.Scale.Scale=slot.Base end
	end
	self.Slots[index]=nil
end

function Animator:Destroy()
	self.Selected=nil
	for index in pairs(self.Slots) do self:Release(index) end
end
return Animator
