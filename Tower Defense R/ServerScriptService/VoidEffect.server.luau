local mobs = workspace:FindFirstChild("Mobs")
local map = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChildOfClass("Folder")
local lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local function applyVoidEffect()

	if mobs:FindFirstChild("Void") then
		-- Tween lighting to fade smoothly
		local tweenInfo = TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		local goal = {ClockTime = 0} -- Smooth transition to midnight
		local tween = TweenService:Create(lighting, tweenInfo, goal)
		tween:Play()
	end
end



mobs.ChildAdded:Connect(function(child)
	if child.Name == "Void" then
		applyVoidEffect()
	end
end)

applyVoidEffect()
