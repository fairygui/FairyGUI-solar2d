GLabel = class('GLabel', GComponent)

local getters = GLabel.getters
local setters = GLabel.setters

function GLabel:ctor()
	GComponent.ctor(self)
end

function getters:icon()
	return self._icon
end

function setters:icon(value)
	self._icon = value
	if self._selected and self._selectedIcon~=nil then
		value = self._selectedIcon
	else
		value = self._icon
	end
	
	if self._iconObject then self._iconObject.icon = value end
	self:updateGear(7)
end

function getters:title()
	return self._title
end

function setters:title(value)
	self._title = value
	if self._selected and self._selectedIcon~=nil then
		value = self._selectedTitle
	else
		value = self._title
	end

	if self._titleObject then self._titleObject.text = value end
	self:updateGear(8)
end

function getters:text()
	return self._title
end

function setters:text(value)
	self.title = value
end

function getters:editable()
	local tf = self:getTextField()
	if tf then
		return tf.editable
	end
end

function setters:editable(value)
	local tf = self:getTextField()
	if tf then 
		return tf.editable
	end
end

function getters:titleColor()
	local tf = self:getTextField()
	if tf~=nil then
		return tf.color
	else
		return 0
	end
end

function setters:titleColor(value)
	local tf = self:getTextField()
	if tf~=nil then
		tf.color = value
	end
	self:updateGear(4)
end


function getters:color()
	return self.titleColor
end

function setters:color(value)
	self.titleColor = value
end

function getters:titleFontSize()
	local tf = self:getTextField()
	if tf~=nil then
		return tf.size
	else
		return 0
	end
end

function setters:titleFontSize(value)
	local tf = self:getTextField()
	if tf~=nil then
		tf.size = value
	end
	self:updateGear(4)
end

function GLabel:getTextField()
	if self._titleObject.getTextField then
		 return self._titleObject:getTextField()
	else
		return self._titleObject
	end
end

function GLabel:constructExtension(buffer)
	self._titleObject = self:getChild("title")
	self._iconObject = self:getChild("icon")
end

function GLabel:setup_AfterAdd(buffer, beginPos)
	GImage.super.setup_AfterAdd(self, buffer, beginPos)

	if not buffer:seek(beginPos, 6) then
		return
	end

	if buffer:readByte() ~= self.packageItem.objectType then
		return
	end

	local str
	str = buffer:readS()
	if str ~= nil then
		self.title = str
	end
	str = buffer:readS()
	if str ~= nil then
		self.icon = str
	end
	if buffer:readBool() then
		self.titleColor = buffer:readColor()
	end
	local iv = buffer:readInt()
	if iv ~= 0 then
		self.titleFontSize = iv
	end

	if buffer:readBool() then
		local input = typeof(self:getTextField(), GTextInput)
		if input ~= nil then
			str = buffer:readS()
			if str ~= nil then
				input.prompText = str
			end

			str = buffer:readS()
			if str ~= nil then
				input.restrict = str
			end

			iv = buffer:readInt()
			if iv ~= 0 then
				input.maxLength = iv
			end
			iv = buffer:readInt()
			if iv ~= 0 then
				input.keyboardType = iv
			end
			if buffer:readBool() then
				input.displayAsPassword = true
			end
		else
			buffer:skip(13)
		end
	end
end