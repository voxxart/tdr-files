local Math={}
function Math.Percent(x,left,width,knobWidth)
 local half=math.min(math.max(0,knobWidth)*0.5,width*0.5)
 return if width-2*half>0 then math.clamp((x-left-half)/(width-2*half),0,1)*100 else 0
end
function Math.Fit(width,height,anchorX,anchorY,x,y,parentWidth,parentHeight,desired,padding)
 padding=padding or 0
 if width<=0 or height<=0 or x<0 or y<0 or x>parentWidth or y>parentHeight then return nil end
 local scale=desired
 local function limit(space,size) if size>0 then scale=math.min(scale,math.max(0,space)/size) end end
 limit(x-padding,width*anchorX); limit(parentWidth-x-padding,width*(1-anchorX))
 limit(y-padding,height*anchorY); limit(parentHeight-y-padding,height*(1-anchorY))
 return math.max(0.01,scale)
end
return Math
