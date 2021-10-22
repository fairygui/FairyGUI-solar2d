GScrollBar = class('GScrollBar', GComponent)

local getters = GScrollBar.getters
local setters = GScrollBar.setters

function GScrollBar:ctor()
	GScrollBar.super.ctor(self)

	self._scrollPerc = 0
end

function GScrollBar:setScrollPane(target, vertical)
	self._target = target
	self._vertical = vertical
end

function setters:displayPerc(value)
	if self._vertical then
		if not self._fixedGripSize then
			self._grip.height = math.floor(value * self._bar.height)
		end
		self._grip.y = math.floor(self._bar.y + (self._bar.height - self._grip.height) * self._scrollPerc)
	else
		if not self._fixedGripSize then
			self._grip.width = math.floor(value * self._bar.width)
		end
		self._grip.x = math.floor(self._bar.x + (self._bar.width - self._grip.width) * self._scrollPerc)
	end
end

function setters:scrollPerc(value)
	self._scrollPerc = value
	if self._vertical then
		self._grip.y = math.floor(self._bar.y + (self._bar.height - self._grip.height) * self._scrollPerc)
	else
		self._grip.x = math.floor(self._bar.x + (self._bar.width - self._grip.width) * self._scrollPerc)
	end
end

function getters:minSize()
	if self._vertical then
		return (self._arrowButton1 ~= nil and self._arrowButton1.height or 0) + (self._arrowButton2 ~= nil and self._arrowButton2.height or 0)
	else
		return (self._arrowButton1 ~= nil and self._arrowButton1.width or 0) + (self._arrowButton2 ~= nil and self._arrowButton2.width or 0)
	end
end

function GScrollBar:constructExtension(buffer)
	buffer:seek(0, 6)

	self._fixedGripSize = buffer:readBool()

	self._grip = self:getChild("grip")
	assert(self._grip, "FairyGUI: " .. self.resourceURL .. " should define grip")

	self._bar = self:getChild("bar")
	assert(self._bar, "FairyGUI: " .. self.resourceURL .. " should define bar")

	self._arrowButton1 = self:getChild("arrow1")
	self._arrowButton2 = self:getChild("arrow2")

	self._grip:on("touchBegin", self._gripTouchBegin, self)
	self._grip:on("touchMove", self._gripTouchMove, self)

	self:on("touchBegin", self._touchBegin, self)
	if self._arrowButton1 ~= nil then
		self._arrowButton1:on("touchBegin", self._arrowButton1Click, self)
	end
	if self._arrowButton2 ~= nil then
		self._arrowButton2:on("touchBegin", self._arrowButton2Click, self)
	end
end

function GScrollBar:_gripTouchBegin(context)
	if self._bar == nil then return end

	context:stopPropagation()
	context:captureTouch()

	self._dragOffsetX, self._dragOffsetY = self:globalToLocal(context.inputEvent.x, context.inputEvent.y)

	self._dragOffsetX = self._dragOffsetX - self._grip.x
	self._dragOffsetY = self._dragOffsetY - self._grip.y
end

function GScrollBar:_gripTouchMove(context)
	local x,y = self:globalToLocal(context.inputEvent.x, context.inputEvent.y)

	if self._vertical then
		local curY = y - self._dragOffsetY
		local diff = self._bar.height - self._grip.height
		if diff == 0 then
			self._target.percY = 0
		else
			self._target.percY = (curY - self._bar.y) / diff
		end
	else
		local curX = x - self._dragOffsetX
		local diff = self._bar.width - self._grip.width
		if diff == 0 then
			self._target.percX = 0
		else
			self._target.percX = (curX - self._bar.x) / diff
		end
	end
end

function GScrollBar:_arrowButton1Click(context)
	context:stopPropagation()

	if self._vertical then
		self._target:scrollUp()
	else
		self._target:scrollLeft()
	end
end

function GScrollBar:_arrowButton2Click(context)
	context:stopPropagation()

	if self._vertical then
		self._target:scrollDown()
	else
		self._target:scrollRight()
	end
end

function GScrollBar:_touchBegin(context)
	context:stopPropagation()

	local x,y = self._grip:globalToLocal(context.inputEvent.x, context.inputEvent.y)
	if self._vertical then
		if y < 0 then
			self._target:scrollUp(4, false)
		else
			self._target:scrollDown(4, false)
		end
	else
		if x < 0 then
			self._target:scrollLeft(4, false)
		else
			self._target:scrollRight(4, false)
		end
	end
end