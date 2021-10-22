local lpack = require("plugin.serialize").lpack

local ByteBuffer = class('ByteBuffer', false)

function ByteBuffer:ctor(data, offset, len)
	self._data = data	
	self._offset = offset or 0
	self.pos = 0
	self.length = len or #data
	self.stringTable = {}
	self.version = 0
end

function ByteBuffer:skip(count)
	self.pos = self.pos + count
end

function ByteBuffer:remain()
	return self.pos<self.length
end

function ByteBuffer:readByte()
	local val = 0
	_, val = lpack.unpack(self._data, 'c', self._offset + self.pos + 1)
	self.pos = self.pos + 1
	if val<0 then val = val+255 end
	return val
end

function ByteBuffer:readBool()
	local val = 0
	_, val = lpack.unpack(self._data, 'c', self._offset + self.pos + 1)
	self.pos = self.pos + 1
	return val==1
end

function ByteBuffer:readShort()
	local val = 0
	_, val = lpack.unpack(self._data, '>h', self._offset + self.pos + 1)
	self.pos = self.pos + 2
	return val
end

function ByteBuffer:readUshort()
	local val = 0
	_, val = lpack.unpack(self._data, '>H', self._offset + self.pos + 1)
	self.pos = self.pos + 2
	return val
end

function ByteBuffer:readInt()
	local val = 0
	_, val = lpack.unpack(self._data, '>i', self._offset + self.pos + 1)
	self.pos = self.pos + 4
	return val
end

function ByteBuffer:readUint()
	local val = 0
	_, val = lpack.unpack(self._data, '>I', self._offset + self.pos + 1)
	self.pos = self.pos + 4
	return val
end

function ByteBuffer:readLong()
	local val = 0
	_, val = lpack.unpack(self._data, '>l', self._offset + self.pos + 1)
	self.pos = self.pos + 8
	return val
end

function ByteBuffer:readUlong()
	local val = 0
	_, val = lpack.unpack(self._data, '>L', self._offset + self.pos + 1)
	self.pos = self.pos + 8
	return val
end

function ByteBuffer:readFloat()
	local val = 0
	_, val = lpack.unpack(self._data, '>f', self._offset + self.pos + 1)
	self.pos = self.pos + 4
	return val
end

function ByteBuffer:readDouble()
	local val = 0
	_, val = lpack.unpack(self._data, '>d', self._offset + self.pos + 1)
	self.pos = self.pos + 8
	return val
end

function ByteBuffer:readString(len)
	if not len then len = self:readUshort() end
	local val
	_, val = lpack.unpack(self._data, 'A' .. len, self._offset + self.pos + 1)
	self.pos = self.pos + len
	return val
end

function ByteBuffer:readS(nilValue)
	local index = self:readUshort()
	if index == 65534 then
		return nilValue
	elseif index == 65533 then
		return ''
	else
		return self.stringTable[index+1]
	end
end

function ByteBuffer:writeS(value)
	local index = self:readUshort()
	if index ~= 65534 and index ~= 65533 then
		self.stringTable[index+1] = value
	end
end

function ByteBuffer:readBuffer()
	local count = self:readInt()
	local ba = ByteBuffer.new(self._data, self._offset+self.pos, count)
	ba.stringTable = self.stringTable
	ba.version = self.version
	self.pos = self.pos + count
	return ba
end

function ByteBuffer:readColor()
	local r = self:readByte()*65536
	local g = self:readByte()*256
	local b = self:readByte()
	local a = self:readByte()/255
	return r+g+b,a
end

function ByteBuffer:readRect(rect)
	rect = rect or {}
	rect.x = self:readInt()
	rect.y = self:readInt()
	rect.width = self:readInt()
	rect.height = self:readInt()
	return rect
end

function ByteBuffer:seek(indexTablePos, blockIndex)
	local tmp = self.pos
	self.pos = indexTablePos
	local segCount = self:readByte()
	if blockIndex < segCount then
		local useShort = self:readBool()
		local newPos
		if useShort then
			self.pos = self.pos + 2 * blockIndex
			newPos = self:readShort()
		else
			self.pos = self.pos + 4 * blockIndex
			newPos = self:readInt()
		end

		if newPos > 0 then
			self.pos = indexTablePos + newPos
			return true
		else
			self.pos = tmp
			return false
		end
	else
		self.pos = tmp
		return false
	end
end

return ByteBuffer