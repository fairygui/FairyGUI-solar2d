GProgressBar = class('GProgressBar', GComponent)

local getters = GProgressBar.getters
local setters = GProgressBar.setters

function GProgressBar:ctor()
	GProgressBar.super.ctor(self)

	self._value = 50
	self._max = 100
	self._barMaxWidthDelta = 0
	self._barMaxHeightDelta = 0
	self._titleType = 0
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

function getters:reverse()
	return self._reverse
end

function setters:reverse(value)
	self._reverse = value
end

function GProgressBar:tweenValue(value, duration)
	local oldValule

	local tweener = GTween.getTween(self, self.update)
	if twener ~= nil then
		oldValule = twener.value.x
		tweener:kill(false)
	else
		oldValule = self._value
	end

	self._value = value
	return GTween.to(oldValule, self._value, duration)
		:setEase(EaseType.Linear)
		:setTarget(self, self.update)
end

function GProgressBar:update(newValue)
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

	local fullWidth = self._width - self._barMaxWidthDelta
	local fullHeight = self._height - self._barMaxHeightDelta

	if not self._reverse then
		if self._barObjectH ~= nil then
			if self._barObjectH.fillMethod and self._barObjectH.fillMethod~=0 then
				self._barObjectH.fillAmount = percent
			else
				self._barObjectH.width = math.floor(fullWidth * percent)
			end
		end
		if self._barObjectV ~= nil then
			if self._barObjectV.fillMethod and self._barObjectV.fillMethod~=0 then
				self._barObjectV.fillAmount = percent
				self._barObjectV.fillAmount = percent
			else
				self._barObjectV.height = math.floor(fullHeight * percent)
			end
		end
	else
		if self._barObjectH ~= nil then
			if self._barObjectH.fillMethod and self._barObjectH.fillMethod~=0 then
				self._barObjectH.fillAmount = 1 - percent
			else
				self._barObjectH.width = math.floor(fullWidth * percent)
				self._barObjectH.x = self._barStartX + (fullWidth - self._barObjectH.width)
			end
		end
		if self._barObjectV ~= nil then
			if self._barObjectV.fillMethod and self._barObjectH.fillMethod~=0 then
				self._barObjectV.fillAmount = 1 - percent
			else
				self._barObjectV.height = math.floor(fullHeight * percent)
				self._barObjectV.y = self._barStartY + (fullHeight - self._barObjectV.height)
			end
		end
	end
	if self._aniObject ~= nil then
		self._aniObject.frame = math.floor(percent * 100)
	end
end

function GProgressBar:constructExtension(buffer)
	buffer:seek(0, 6)

	self._titleType = buffer:readByte()
	self._reverse = buffer:readBool()

	self._titleObject = self:getChild("title")
	self._barObjectH = self:getChild("bar")
	self._barObjectV = self:getChild("bar_v")
	self._aniObject = typeof(self:getChild("ani"), GMovieClip)

	if self._barObjectH ~= nil then
		self._barMaxWidth = self._barObjectH.width
		self._barMaxWidthDelta = self.width - self._barMaxWidth
		self._barStartX = self._barObjectH.x
	end
	if self._barObjectV ~= nil then
		self._barMaxHeight = self._barObjectV.height
		self._barMaxHeightDelta = self.height - self._barMaxHeight
		self._barStartY = self._barObjectV.y
	end
end

function GProgressBar:setup_AfterAdd (buffer, beginPos)
	GProgressBar.super.setup_AfterAdd(self, buffer, beginPos)

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

function GProgressBar:handleSizeChanged()
	GProgressBar.super.handleSizeChanged(self)

	if self._barObjectH ~= nil then
		self._barMaxWidth = self.width - self._barMaxWidthDelta
	end
	if self._barObjectV ~= nil then
		self._barMaxHeight = self.height - self._barMaxHeightDelta
	end

	if not self._underConstruct then
		self:update(self._value)
	end
end