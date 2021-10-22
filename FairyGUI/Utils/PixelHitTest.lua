local bitLib = require("plugin.bit" )
local band = bitLib.band
local rshift = bitLib.rshift

local PixelHitTest = class('PixelHitTest', false)

function PixelHitTest.parse(ba)
	local t = {}
	ba:readInt()
	t.pixelWidth = ba:readInt()
	t.scale = 1.0 / ba:readByte()
	t.pixels = ba:readBuffer()
	return t
end

function PixelHitTest:ctor(data, offsetX, offsetY, sourceWidth, sourceHeight)
	self.data = data
	self.offsetX = offsetX
	self.offsetY = offsetY
	self.sourceWidth = sourceWidth
	self.sourceHeight = sourceHeight
end

function PixelHitTest:hitTest(x, y, width, height)
	if x<0 or y<0 or x>width or y>height then
		return false
	end

	local x = math.floor((x * self.sourceWidth / width - self.offsetX) * self.data.scale)
	local y = math.floor((y * self.sourceHeight / height - self.offsetY) * self.data.scale)
	if x >= self.data.pixelWidth then
		return false
	end

	local pos = y * self.data.pixelWidth + x
	local pos2 = pos / 8
	local pos3 = pos % 8

	if pos2 >= 0 and pos2 < self.data.pixels.length then
		self.data.pixels.pos = pos2
		local t = self.data.pixels:readByte()
		return band(rshift(t, pos3), 1) > 0
	else
		return false
	end
end

return PixelHitTest