local ToolSet = {}

function string.trim(s)
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function string.tocolor(str)
	if #str < 7 then return 0 end

	if #str==9 then
		return tonumber(string.sub(str,4,5),16)*65536+tonumber(string.sub(str,6,7),16)*256
			+tonumber(string.sub(str,8,9),16)+tonumber(string.sub(str,2,3),16)*16777216
	else
		return tonumber(string.sub(str,2,3),16)*65536+tonumber(string.sub(str,4,5),16)*256+tonumber(string.sub(str,6,7),16)
	end
end

function math.clamp(v, min, max)  
	if v < min then
		return min
	end
	if( v > max) then
		return max
	end
	return v 
end

function math.clamp01(v)  
	if v < 0 then
		return 0
	end
	if( v > 1) then
		return 1
	end
	return v 
end

function math.lerp(start, ends, percent)
	return (start + percent*(ends - start))
end

function ToolSet.unpackColor(c,a)
	c = c%16777216
	local r = math.floor(c/65536)
	c = c%65536
	local g = math.floor(c/256)
	c = c%256
	local b = c

	if a then
		return r/255,g/255,b/255,a
	else
		return r/255,g/255,b/255
	end
end

function ToolSet.contains(t, v)
	for i=1,#t do
		if t[i]==v then return true end
	end
end

function ToolSet.copy(source, dst)
	dst = dst or {}
	for k,v in pairs( source ) do
		dst[k] = v
	end

	return dst
end

function ToolSet.indexOf(t, v, start)
	start = start or 1
	for i=start,#t do
		if t[i]==v then return i end
	end

	return 0
end

return ToolSet