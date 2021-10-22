local TweenValue = {}
TweenValue.__index = TweenValue

local _keys = {"x","y","z","w"}

function TweenValue.new()
	local t = {}
	t.x = 0
	t.y = 0
	t.z = 0
	t.w = 0
	setmetatable(t, TweenValue)
	return t
end

function TweenValue:get(index)
	return self[_keys[index]]
end

function TweenValue:set(index, value)
	self[_keys[index]] = value
end

function TweenValue:setAll(x, y, z, w)
	self.x = x or 0
	self.y = y or 0
	self.z = z or 0
	self.w = w or 0
end

function TweenValue:getColor()
	return self.x*65536+self.y*256+self.z, self.w
end

function TweenValue:setColor(c)
	self.w = math.floor(c/16777216)
	if self.w>255 then self.w=255 end
	c = c%16777216
	self.x = math.floor(c/65536)
	c = c%65536
	self.y = math.floor(c/256)
	c = c%256
	self.z = c
end

return TweenValue