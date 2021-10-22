GGroup = class('GGroup', GObject)

local getters = GGroup.getters
local setters = GGroup.setters

function GGroup:ctor()
	GGroup.super.ctor(self)

	self._layout = 0
	self._lineGap = 0
	self._columnGap = 0
	self._percentReady = false
	self._boundsChanged = false
	self._updating = 0
end

function getters:layout()
	return self._layout
end

function setters:layout(value)
	if self._layout ~= value then
		self._layout = value
		self:setBoundsChangedFlag(true)
	end
end

function getters:lineGap()
	return self._lineGap
end

function setters:lineGap(value)
	if self._lineGap ~= value then
		self._lineGap = value
		self:setBoundsChangedFlag()
	end
end

function getters:columnGap()
	return self._columnGap
end

function setters:columnGap(value)
	if self._columnGap ~= value then
		self._columnGap = value
		self:setBoundsChangedFlag()
	end
end

function GGroup:setBoundsChangedFlag(childSizeChanged)
	if not self._updating1 and not self._updating2 and self.parent then
		if childSizeChanged then self._percentReady = false end

		if not self._boundsChanged then
			self._boundsChanged = true

			if self._layout ~= GroupLayoutType.None then
				self:delayedCall(self.ensureBoundsCorrect, self)
			end
		end
	end
end

function GGroup:ensureBoundsCorrect()
	if not self._boundsChanged or not self.parent then return end

	self:handleLayout()
	self:updateBounds()
end

function GGroup:ensureSizeCorrect()
	GGroup.super.ensureSizeCorrect(self)
	
	if not self._boundsChanged or not self.parent or self._layout==0 then return end

	self:handleLayout()
	self:updateBounds()
end

function GGroup:updateBounds()
	self._boundsChanged = false

	local cnt = self.parent.numChildren
	local i
	local child
	local ax = 100000000000
	local ay = 100000000000
	local ar = -100000000000
	local ab = -100000000000
	local tmp
	local empty = true

	for i=0,cnt-1 do
		child = self.parent:getChildAt(i)
		if child.group == self then
			tmp = child.xMin
			if tmp < ax then
				ax = tmp
			end
			tmp = child.yMin
			if tmp < ay then
				ay = tmp
			end
			tmp = child.xMin + child.width
			if tmp > ar then
				ar = tmp
			end
			tmp = child.yMin + child.height
			if tmp > ab then
				ab = tmp
			end

			empty = false
		end
	end

	if not empty then
		self._updating1 = true
		self:setPosition(ax, ay)
		self._updating2 = true
		self:setSize(ar - ax, ab - ay)
	else
		self._updating2 = true
		self:setSize(0, 0)
	end

	self._updating1 = nil
	self._updating2 = nil
end

function GGroup:handleLayout()
	self._updating1 = true

	if self._layout == GroupLayoutType.Horizontal then
		local curX
		local cnt = self.parent.numChildren
		for i=0,cnt-1 do
			local child = self.parent:getChildAt(i)
			if child.group == self then
				if not curX then
					curX = child.xMin
				else
					child.xMin = curX
				end
				if child.width ~= 0 then
					curX = curX + child.width + _columnGap
				end
			end
		end
		if not self._percentReady then
			self:updatePercent()
		end
	elseif self._layout == GroupLayoutType.Vertical then
		local curY
		local cnt = self.parent.numChildren
		for i=0,cnt-1 do
			local child = self.parent:getChildAt(i)
			if child.group == self then
				if not curY then
					curY = child.yMin
				else
					child.yMin = curY
				end
				if child.height ~= 0 then
					curY = curY + child.height + _lineGap
				end
			end
		end
		if not self._percentReady then
			self:updatePercent()
		end
	end

	self._updating1 = nil
end

function GGroup:updatePercent()
	self._percentReady = true

	local cnt = self.parent.numChildren
	local i
	local child
	local size = 0
	if self._layout == GroupLayoutType.Horizontal then
		for i=0,cnt-1 do
			local child = self.parent:getChildAt(i)
			if child.group == self then
				size = size + child.width
			end
		end

		for i=0,cnt-1 do
			local child = self.parent:getChildAt(i)
			if child.group == self then
				if size > 0 then
					child._sizePercentInGroup = child.width / size
				else
					child._sizePercentInGroup = 0
				end
			end
		end
	else
		for i=0,cnt-1 do
			local child = self.parent:getChildAt(i)
			if child.group == self then
				size = size + child.height
			end
		end

		for i=0,cnt-1 do
			local child = self.parent:getChildAt(i)
			if child.group == self then
				if size > 0 then
					child._sizePercentInGroup = child.height / size
				else
					child._sizePercentInGroup = 0
				end
			end
		end
	end
end

function GGroup:moveChildren(dx, dy)
	if self._updating1 or not self.parent then return end

	self._updating1 = true

	local cnt = self.parent.numChildren
	local i
	local child
	for i=0,cnt-1 do
		local child = self.parent:getChildAt(i)
		if child.group == self then
			child:setPosition(child.x + dx, child.y + dy)
		end
	end

	self._updating1 = nil
end

function GGroup:resizeChildren(dw, dh)
	if self._layout == GroupLayoutType.None or self._updating2 or not self.parent then return end

	if not self._percentReady then
		self:updatePercent()
	end

	local cnt = self.parent.numChildren
	local i
	local child
	local numChildren = 0
	local remainSize = 0
	local remainPercent = 1

	for i=0,cnt-1 do
		local child = self.parent:getChildAt(i)
		if child.group == self then		
			numChildren = numChildren+1
		end
	end

	if self._layout == GroupLayoutType.Horizontal then
		self._updating2 = true
		remainSize = this.width - (numChildren - 1) * _columnGap
		local curX
		for i=0,cnt-1 do
			local child = self.parent:getChildAt(i)
			if child.group == self then
				if not curX then
					curX = child.xMin
				else
					child.xMin = curX
				end
				child:setSize(math.round(child._sizePercentInGroup / remainPercent * remainSize), child._rawHeight + dh, true)
				remainSize = remainSize - child.width
				remainPercent = remainPercent - child._sizePercentInGroup
				curX = curX + child.width + _columnGap
			end
		end
		self._updating2 = nil
		self:updateBounds()
	elseif self._layout == GroupLayoutType.Vertical then
		self._updating2 = true
		remainSize = this.height - (numChildren - 1) * _lineGap
		local curY
		for i=0,cnt-1 do
			local child = self.parent:getChildAt(i)
			if child.group == self then
				if not curY then
					curY = child.yMin
				else
					child.yMin = curY
				end
				child:setSize(child._rawWidth + dw, math.round(child._sizePercentInGroup / remainPercent * remainSize), true)
				remainSize = remainSize - child.height
				remainPercent = remainPercent - child._sizePercentInGroup
				curY = curY + child.height + _lineGap
			end
		end
		self._updating2 = nil
		self:updateBounds()
	end
end

function GGroup:handleAlphaChanged()
	GGroup.super.handleAlphaChanged(self)

	if self._underConstruct or not self.parent then return end

	local cnt = self.parent.numChildren
	local a = self.alpha
	for i=0,cnt-1 do
		local child = self.parent:getChildAt(i)
		if child.group == self then
			child.alpha = a
		end
	end
end

function GGroup:handleVisibleChanged()
	if not self.parent then return end

	local cnt = self.parent.numChildren
	for i=0,cnt-1 do
		local child = self.parent:getChildAt(i)
		if child.group == self then
			child:handleVisibleChanged()
		end
	end
end

function GGroup:setup_BeforeAdd(buffer, beginPos)
	GGroup.super.setup_BeforeAdd(self, buffer, beginPos)

	buffer:seek(beginPos, 5)

	self._layout = buffer:readByte()
	self._lineGap = buffer:readInt()
	self._columnGap = buffer:readInt()
end

function GGroup:setup_AfterAdd(buffer, beginPos)
	GGroup.super.setup_AfterAdd(self, buffer, beginPos)

	if not self.visible then
		self:handleVisibleChanged()
	end
end
