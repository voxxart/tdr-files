local Motion = {}
function Motion.Advance(alpha,speed,gameDt,length,paused)
	if paused then return alpha end
	return math.clamp(alpha + speed*gameDt/math.max(length,0.001),0,1)
end
return Motion
