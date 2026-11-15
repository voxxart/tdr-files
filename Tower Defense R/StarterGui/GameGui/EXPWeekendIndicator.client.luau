local info=workspace:WaitForChild('Info')
local gui=script.Parent
local function update()
 local modifiers=gui:FindFirstChild('Modifiers')
 local indicator=modifiers and modifiers:FindFirstChild('EXPWeekend')
 if indicator and indicator:IsA('GuiObject') then indicator.Visible=info:GetAttribute('EXPWeekendActive')==true end
end
local changed=info:GetAttributeChangedSignal('EXPWeekendActive'):Connect(update)
local added=gui.DescendantAdded:Connect(function(object)
 if object.Name=='Modifiers' or object.Name=='EXPWeekend' then update() end
end)
script.Destroying:Connect(function() changed:Disconnect(); added:Disconnect() end)
update()
