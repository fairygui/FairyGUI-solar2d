GSlider = class('GSlider', GComponent)

local getters = GSlider.getters
local setters = GSlider.setters

function GSlider:ctor()
	GSlider.super.ctor(self)

	self._clickPos = {x=0, y=0}
	self._value = 50
	self._max = 100
	self.changeOnClick = true
	self.canDrag = true
	self._barMaxWidthDelta = 0
	self._barMaxHeightDelta = 0
end

function getters:titleType()
	return self._titleType
end

function setters:titleType(value)
	if self._titleType ~= value then
		self._titleType = value
		self:update(self._value)
	end
end

function getters:max()
	return self._max
end

function setters:max(value)
	if self._max ~= value then
		self._max = value
		self:update(self._value)
	end
end

function getters:value()
	return self._value
end

function setters:value(value)
	if self._value ~= value then
		GTween.kill(self, self.update, false)

		self._value = value
		self:update(self._value)
	end
end

function GSlider:update(newValue)
	local percent = self._max ~= 0 and math.min(newValue / self._max, 1) or 0
	if self._titleObject ~= nil then
		local default = self._titleType
		if default == ProgressTitleType.Percent then
			self._titleObject.text = math.floor(percent * 100) .. "%"
		elseif default == ProgressTitleType.ValueAndMax then
			self._titleObject.text = math.floor(newValue) .. "/" .. math.floor(self._max)
		elseif default == ProgressTitleType.Value then
			self._titleObject.text = "" .. math.floor(newValue)
		elseif default == ProgressTitleType.Max then
			self._titleObject.text = "" .. math.floor(self._max)
		end
	end

	local fullWidth = self.width - self._barMaxWidthDelta
	local fullHeight = self.height - self._barMaxHeightDelta

	if not self._reverse then
		if self._barObjectH ~= nil then
			if self._barObjectH.fillMethod~=0 then
				self._barObjectH.fillAmount = percent
			else
				self._barObjectH.width = math.floor(fullWidth * percent)
			end
		end
		if self._barObjectV ~= nil then
			if self._barObjectV.fillMethod~=0 then
					self._barObjectV.fillAmount = percent
				self._barObjectV.fillAmount = percent
			else
				self._barObjectV.height = math.floor(fullHeight * percent)
			end
		end
	else
		if self._barObjectH ~= nil then
			if self._barObjectH.fillMethod~=0 then
				self._barObjectH.fillAmount = 1 - percent
			else
				self._barObjectH.width = math.floor(fullWidth * percent)
				self._barObjectH.x = self._barStartX + (fullWidth - self._barObjectH.width)
			end
		end
		if self._barObjectV ~= nil then
			if self._barObjectH.fillMethod~=0 then
				self._barObjectV.fillAmount = 1 - percent
			else
				self._barObjectV.height = math.floor(fullHeight * percent)
				self._barObjectV.y = self._barStartY + (fullHeight - self._barObjectV.height)
			end
		end
	end
end

function GSlider:constructExtension(buffer)
	buffer:seek(0, 6)

	self._titleType = buffer:readByte()
	self._reverse = buffer:readBool()

	self._titleObject = self:getChild("title")
	self._barObjectH = self:getChild("bar")
	self._barObjectV = self:getChild("bar_v")
	self._gripObject = self:getChild("grip")

	if self._barObjectH ~= nil then
		self._barMaxWidth = self._barObjectH.width
		self._barMaxWidthDelta = self._width - self._barMaxWidth
		self._barStartX = self._barObjectH.x
	end
	if self._barObjectV ~= nil then
		self._barMaxHeight = self._barObjectV.height
		self._barMaxHeightDelta = self._height - self._barMaxHeight
		self._barStartY = self._barObjectV.y
	end

	if self._gripObject ~= nil then
		self._gripObject:on("touchBegin", self._gripTouchBegin, self)
		self._gripObject:on("touchMove", self._gripTouchMove, self)
		self._gripObject:on("touchEnd", self._gripTouchEnd, self)
	end

	self:on("touchBegin", self._barTouchBegin, self)
end

function GSlider:setup_AfterAdd(buffer, beginPos)
	GSlider.super.setup_AfterAdd(self, buffer, beginPos)

	if not buffer:seek(beginPos, 6) then
		self:update(self._value)
		return
	end

	if buffer:readByte() ~= self.packageItem.objectType then
		self:update(self._value)
		return
	end

	self._value = buffer:readInt()
	self._max = buffer:readInt()

	self:update(self._value)
end

function GSlider:handleSizeChanged()
	GSlider.super.handleSizeChanged(self)

	if self._barObjectH ~= nil then
		self._barMaxWidth = self._width - self._barMaxWidthDelta
	end
	if self._barObjectV ~= nil then
		self._barMaxHeight = self._height - self._barMaxHeightDelta
	end

	if not self._underConstruct then
		self:update(self._value)
	end
end

function GSlider:_gripTouchBegin(context)
	self.canDrag = true

	context:stopPropagation()
	context:captureTouch()

	local x,y = self:globalToLocal(context.inputEvent.x, context.inputEvent.y)
	self._clickPos.x = x
	self._clickPos.y = y
	self._clickPercent = self._value / self._max
end

function GSlider:_gripTouchMove(context)
	if not self.canDrag then
		return
	end

	local x,y = self:globalToLocal(context.inputEvent.x, context.inputEvent.y)
	local deltaX = x - self._clickPos.x
	local deltaY = y - self._clickPos.y
	if self._reverse then
		deltaX = - deltaX
		deltaY = - deltaY
	end

	local percent
	if self._barObjectH ~= nil then
		percent = self._clickPercent + deltaX / self._barMaxWidth
	else
		percent = self._clickPercent + deltaY / self._barMaxHeight
	end
	if percent > 1 then
		percent = 1
	elseif percent < 0 then
		percent = 0
	end

	local newValue = percent * self._max
	if newValue ~= self._value then
		self._value = newValue
		if self:emit("statusChanged") then
			return
		end
	end

	self:update(newValue)
end

function GSlider:_gripTouchEnd(context)
	self:emit("gripTouchEnd")
end

function GSlider:_barTouchBegin(context)
	if not self.changeOnClick then
		return
	end

	local x,y = self._gripObject:globalToLocal(context.inputEvent.x, context.inputEvent.y)
	local percent = self._value / self._max
	local delta = 0
	if self._barObjectH ~= nil then
		delta = (x - self._gripObject.width / 2) / self._barMaxWidth
	end
	if self._barObjectV ~= nil then
		delta = (y - self._gripObject.height / 2) / self._barMaxHeight
	end
	if self._reverse then
		percent = percent - delta
	else
		percent = percent + delta
	end
	if percent > 1 then
		percent = 1
	elseif percent < 0 then
		percent = 0
	end
	local newValue = percent * self._max
	if newValue ~= self._value then
		self._value = newValue
		if self:emit("statusChanged") then
			return
		end
	end
	self:update(newValue)
end