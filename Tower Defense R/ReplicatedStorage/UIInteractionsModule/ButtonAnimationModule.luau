function Animation (button, x, y)
	coroutine.resume(coroutine.create(function()
		button.ClipsDescendants = false
		
		local size = 0
		if button.AbsoluteSize.X > button.AbsoluteSize.Y then
			size = button.AbsoluteSize.X * 1.5
		elseif button.AbsoluteSize.X < button.AbsoluteSize.Y then
			size = button.AbsoluteSize.Y * 1.5
		elseif button.AbsoluteSize.X == button.AbsoluteSize.Y then
		end
		local Time = 0.5
		
		for i=1, 10 do
			wait(Time/10)
		end
	end))
end

return Animation