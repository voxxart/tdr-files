-- Display metadata is read from this exact level, never from merged combat stats.
local Data = {}
Data.LabelNames={'One','Two','Three','Four','Five','Six','Seven','Eight','Nine'}
function Data.IsKey(key)
	if type(key)~='string' then return false end
	local index=tonumber(string.match(key,'^AdvancedStats(%d+)$'))
	return index~=nil and index>=1 and index<=10 and key=='AdvancedStats'..index
end
function Data.ForLevel(definition,level)
	local result={}
	if type(definition)~='table' then return result end
	local source=if level==0 then definition else definition.Upgrades and definition.Upgrades[level]
	if type(source)~='table' then return result end
	for index=1,10 do
		local group=source['AdvancedStats'..index]
		if type(group)~='table' then continue end
		local items={}
		for order,name in ipairs(Data.LabelNames) do
			local value=group[name]
			if value==nil then value=group[order] end
			if type(value)=='string' and value~='' then table.insert(items,{Name=name,Text=value}) end
		end
		if #items>0 then
			table.insert(result,{Index=index,Title=if type(group.Title)=='string' then group.Title else 'Advanced Stats '..index,Items=items})
		end
	end
	return result
end
return Data
