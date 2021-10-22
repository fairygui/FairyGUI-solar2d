local bitLib = require("plugin.bit" )
local band = bitLib.band
local tools = require("Utils.ToolSet")
local InputProcessor = require("Event.InputProcessor")

local ScrollPane = class('ScrollPane')

local TWEEN_TIME_GO = 0.5 --调用SetPos(ani)时使用的缓动时间
local TWEEN_TIME_DEFAULT = 0.3 --惯性滚动的最小缓动时间
local PULL_RATIO = 0.5 --下拉过顶或者上拉过底时允许超过的距离占显示区域的比例

local getters = ScrollPane.getters
local setters = ScrollPane.setters

local _gestureFlagX = false
local _gestureFlagY = false

local Vector2 = class('Vector2', false)

function Vector2:ctor(x, y)
	self.x = x or 0
	self.y = y or 0
end

function Vector2:copy(source)
	self.x = source.x or 0
	self.y = source.y or 0
end

function Vector2:set(x, y)
	self.x = x or 0
	self.y = y or 0
end

local function easeFunc(t, d)
	t = t / d - 1
	return t * t * t + 1
end

function ScrollPane:ctor(owner)
	self._scrollBarMargin = {left=0,right=0,top=0,bottom=0}
	self._pageSize = Vector2.new()
	self._viewSize = Vector2.new()
	self._contentSize = Vector2.new()
	self._overlapSize = Vector2.new()
	self._containerPos = Vector2.new()
	self._beginTouchPos = Vector2.new()
	self._lastTouchPos = Vector2.new()
	self._lastTouchGlobalPos = Vector2.new()
	self._velocity = Vector2.new()
	self._tweenStart = Vector2.new()
	self._tweenChange = Vector2.new()
	self._tweenTime = Vector2.new()
	self._tweenDuration = Vector2.new()
	self._xPos = 0
	self._yPos = 0
	self._headerLockedSize = 0
	self._footerLockedSize = 0
	self._tweening = 0

	self._scrollStep = UIConfig.defaultScrollStep
	self._mouseWheelStep = self._scrollStep * 2
	self._softnessOnTopOrLeftSide = UIConfig.allowSoftnessOnTopOrLeftSide
	self._decelerationRate = UIConfig.defaultScrollDecelerationRate
	self._touchEffect = UIConfig.defaultScrollTouchEffect
	self._bouncebackEffect = UIConfig.defaultScrollBounceEffect
	self._scrollBarVisible = true
	self._mouseWheelEnabled = true
	self._pageSize = Vector2.new(1, 1)

	self._owner = owner

	self._owner:on("touchBegin", self._touchBegin, self)
	self._owner:on("touchMove", self._touchMove, self)
	self._owner:on("touchEnd", self._touchEnd, self)
end

 function ScrollPane:setup(buffer)
	self._scrollType = buffer:readByte()
	local scrollBarDisplay = buffer:readByte()
	local flags = buffer:readInt()

	if buffer:readBool() then
		self._scrollBarMargin.top = buffer:readInt()
		self._scrollBarMargin.bottom = buffer:readInt()
		self._scrollBarMargin.left = buffer:readInt()
		self._scrollBarMargin.right = buffer:readInt()
	end

	local vtScrollBarRes = buffer:readS()
	local hzScrollBarRes = buffer:readS()
	local headerRes = buffer:readS()
	local footerRes = buffer:readS()

	self._displayOnLeft = (band(flags, 1)) ~= 0
	self._snapToItem = (band(flags, 2)) ~= 0
	self._displayInDemand = (band(flags, 4)) ~= 0
	self._pageMode = (band(flags, 8)) ~= 0
	if (band(flags, 16)) ~= 0 then
		self._touchEffect = true
	elseif (band(flags, 32)) ~= 0 then
		self._touchEffect = false
	end
	if (band(flags, 64)) ~= 0 then
		self._bouncebackEffect = true
	elseif (band(flags, 128)) ~= 0 then
		self._bouncebackEffect = false
	end
	self._inertiaDisabled = (band(flags, 256)) ~= 0
	self._maskDisabled = (band(flags, 512)) ~= 0

	if self._maskDisabled then
		self._maskContainer = display.newGroup()
	else
		self._maskContainer = display.newContainer(0,0,10,10)
		self._maskContainer.anchorChildren = false
	end

	self._maskContainer.anchorX = 0
	self._maskContainer.anchorY = 0
	self._owner.displayObject:insert(self._maskContainer)

	self._container = self._owner._container
	self._container.x = 0
	self._container.y = 0
	self._maskContainer:insert(self._container)

	if scrollBarDisplay == ScrollBarDisplayType.Default then
		scrollBarDisplay = UIConfig.defaultScrollBarDisplay
		if scrollBarDisplay == ScrollBarDisplayType.Default then
			scrollBarDisplay = ScrollBarDisplayType.Visible
		end
	end

	if scrollBarDisplay ~= ScrollBarDisplayType.Hidden then
		if self._scrollType == ScrollType.Both or self._scrollType == ScrollType.Vertical then
			local res
			if vtScrollBarRes ~= nil then
				res = vtScrollBarRes
			else
				res = UIConfig.verticalScrollBar
			end
			if res and #res>0 then
				self._vtScrollBar = UIPackage.createObjectFromURL(res)
				assert(self._vtScrollBar, "FairyGUI: cannot create scrollbar from " .. res)
				
				self._vtScrollBar:setScrollPane(self, true)
				self._owner.displayObject:insert(self._vtScrollBar.displayObject)
			end
		end
		if self._scrollType == ScrollType.Both or self._scrollType == ScrollType.Horizontal then
			local res
			if hzScrollBarRes ~= nil then
				res = hzScrollBarRes
			else
				res = UIConfig.horizontalScrollBar
			end
			if res and #res>0 then
				self._hzScrollBar = UIPackage.createObjectFromURL(res)
				assert(self._hzScrollBar, "FairyGUI: cannot create scrollbar from " .. res)
				
				self._hzScrollBar:setScrollPane(self, false)
				self._owner.displayObject:insert(self._hzScrollBar.displayObject)
			end
		end

		self._scrollBarDisplayAuto = scrollBarDisplay == ScrollBarDisplayType.Auto
		if self._scrollBarDisplayAuto then
			if self._vtScrollBar then
				self._vtScrollBar.visible = false
			end
			if self._hzScrollBar then
				self._hzScrollBar.visible = false
			end
			self._scrollBarVisible = false
		else
			if self._vtScrollBar then
				self._vtScrollBar.visible = true
			end
			if self._hzScrollBar then
				self._hzScrollBar.visible = true
			end
		end
	else
		self._mouseWheelEnabled = false
	end

	if headerRes ~= nil then
		self._header = UIPackage.createObjectFromURL(headerRes)
		self._maskContainer:insert(self._header.displayObject)
		self._header.visible = false
		assert(self._header, "FairyGUI: cannot create scrollPane header from " .. headerRes)
	end

	if footerRes ~= nil then
		self._footer = UIPackage.createObjectFromURL(footerRes)
		self._maskContainer:insert(self._footer.displayObject)
		self._footer.visible = false
		assert(self._footer, "FairyGUI: cannot create scrollPane footer from " .. footerRes)
	end

	if self._header ~= nil or self._footer ~= nil then
		self._refreshBarAxis = (self._scrollType == ScrollType.Both or self._scrollType == ScrollType.Vertical) and 'y' or 'x'
	else
		self._refreshBarAxis = 'x'
	end

	self:setSize(self._owner.width, self._owner.height)
end

function ScrollPane:dispose()
	if ScrollPane.draggingPane == self then
		ScrollPane.draggingPane = nil
	end

	self._pageController = nil

	if self._hzScrollBar ~= nil then
		self._hzScrollBar:dispose()
	end
	if self._vtScrollBar ~= nil then
		self._vtScrollBar:dispose()
	end
	if self._header ~= nil then
		self._header:dispose()
	end
	if self._footer ~= nil then
		self._footer:dispose()
	end
end

function getters:vtScrollBar()
	return self._vtScrollBar
end

function getters:hzScrollBar()
	return self._hzScrollBar
end

function getters:header()
	return self._header
end

function getters:footer()
	return self._footer
end

function getters:scrollStep()
	return self._scrollStep
end

function setters:scrollStep(value)
	self._scrollStep = value
	if self._scrollStep == 0 then
		self._scrollStep = UIConfig.defaultScrollStep
	end
	self._mouseWheelStep = self._scrollStep * 2
end

function getters:percX()
	return self._overlapSize.x == 0 and 0 or self._xPos / self._overlapSize.x
end

function setters:percX(value)
	self:setPercX(value, false)
end

function ScrollPane:setPercX(value, ani)
	self._owner:ensureBoundsCorrect()
	self:setPosX(self._overlapSize.x * math.clamp01(value), ani)
end

function getters:percY()
	return self._overlapSize.y == 0 and 0 or self._yPos / self._overlapSize.y
end

function setters:percY(value)
	self:setPercY(value, false)
end

function ScrollPane:setPercY(value, ani)
	self._owner:ensureBoundsCorrect()
	self:setPosY(self._overlapSize.y * math.clamp01(value), ani)
end

function getters:posX()
	return self._xPos
end

function setters:posX(value)
	self:setPosX(value, false)
end

function ScrollPane:setPosX (value, ani)
	self._owner:ensureBoundsCorrect()

	if self._loop == 1 then
		value = self:loopCheckingNewPos(value, 'x')
	end

	value = math.clamp(value, 0, self._overlapSize.x)
	if value ~= self._xPos then
		self._xPos = value
		self:posChanged(ani)
	end
end

function getters:posY()
	return self._yPos
end

function setters:posY(value)
	self:setPosY(value, false)
end

function ScrollPane:setPosY(value, ani)
	self._owner:ensureBoundsCorrect()

	if self._loop == 2 then
		value = self:loopCheckingNewPos(value, 'y')
	end

	value = math.clamp(value, 0, self._overlapSize.y)
	if value ~= self._yPos then
		self._yPos = value
		self:posChanged(ani)
	end
end

function getters:isBottomMost()
	return self._yPos == self._overlapSize.y or self._overlapSize.y == 0
end

function getters:isRightMost()
	return self._xPos == self._overlapSize.x or self._overlapSize.x == 0
end

function getters:currentPageX()
	if not self._pageMode then
		return 0
	end

	local page = math.floor(self._xPos / self._pageSize.x)
	if self._xPos - page * self._pageSize.x > self._pageSize.x * 0.5 then
		page = page + 1
	end

	return page
end

function setters:currentPageX(value)
	if not self._pageMode then
		return
	end

	if self._overlapSize.x > 0 then
		self:setPosX(value * self._pageSize.x, false)
	end
end

function ScrollPane:setCurrentPageX(value, ani)
	if self._overlapSize.x > 0 then
		self:setPosX(value * self._pageSize.x, ani)
	end
end

function getters:currentPageY()
	if not self._pageMode then
		return 0
	end

	local page = math.floor(self._yPos / self._pageSize.y)
	if self._yPos - page * self._pageSize.y > self._pageSize.y * 0.5 then
		page = page + 1
	end

	return page
end

function setters:currentPageY(value)
	if self._overlapSize.y > 0 then
		self:setPosY(value * self._pageSize.y, false)
	end
end

function ScrollPane:setCurrentPageY(value, ani)
	if self._overlapSize.y > 0 then
		self:setPosY(value * self._pageSize.y, ani)
	end
end

function getters:scrollingPosX()
	return math.clamp(- self._container.x, 0, self._overlapSize.x)
end

function getters:scrollingPosY()
	return math.clamp(- self._container.y, 0, self._overlapSize.y)
end

function getters:contentWidth()
	return self._contentSize.x
end

function getters:contentHeight()
	return self._contentSize.y
end

function getters:viewWidth()
	return self._viewSize.x
end

function setters:viewWidth(value)
	value = value + self._owner._margin.left + self._owner._margin.right
	if self._vtScrollBar ~= nil then
		value = value + self._vtScrollBar.width
	end
	self._owner.width = value
end

function getters:viewHeight()
	return self._viewSize.y
end

function setters:viewHeight(value)
	value = value + self._owner._margin.top + self._owner._margin.bottom
	if self._hzScrollBar ~= nil then
		value = value + self._hzScrollBar.height
	end
	self._owner.height = value
end

function ScrollPane:scrollTop(ani)
	self:setPercY(0, ani)
end

function ScrollPane:scrollBottom(ani)
	self:setPercY(1, ani)
end

function ScrollPane:scrollUp(ratio, ani)
	ratio = ratio or 1

	if self._pageMode then
		self:setPosY(self._yPos - self._pageSize.y * ratio, ani)
	else
		self:setPosY(self._yPos - self._scrollStep * ratio, ani)
	end
end

function ScrollPane:scrollDown(ratio, ani)
	ratio = ratio or 1
	
	if self._pageMode then
		self:setPosY(self._yPos + self._pageSize.y * ratio, ani)
	else
		self:setPosY(self._yPos + self._scrollStep * ratio, ani)
	end
end

function ScrollPane:scrollLeft1(ratio, ani)
	ratio = ratio or 1

	if self._pageMode then
		self:setPosX(self._xPos - self._pageSize.x * ratio, ani)
	else
		self:setPosX(self._xPos - self._scrollStep * ratio, ani)
	end
end

function ScrollPane:scrollRight1(ratio, ani)
	ratio = ratio or 1

	if self._pageMode then
		self:setPosX(self._xPos + self._pageSize.x * ratio, ani)
	else
		self:setPosX(self._xPos + self._scrollStep * ratio, ani)
	end
end

function ScrollPane:scrollToView(target, ani, setFirst)
	self._owner:ensureBoundsCorrect()
	if self._needRefresh then
		self:refresh()
	end

	local rect

	if typeof(target, GObject) then
		rect = {x=target.x, y=target.y, width=target.width, height=target.height}
		if target.parent ~= self._owner then
			rect = target.parent:transformRect(self._owner, rect)
		end
	else
		rect = target
	end

	if self._overlapSize.y > 0 then
		local bottom = self._yPos + self._viewSize.y
		if setFirst or rect.y <= self._yPos or rect.height >= self._viewSize.y then
			if self._pageMode then
				self:setPosY(math.floor(rect.y / self._pageSize.y) * self._pageSize.y, ani)
			else
				self:setPosY(rect.y, ani)
			end
		elseif rect.y + rect.height > bottom then
			if self._pageMode then
				self:setPosY(math.floor(rect.y / self._pageSize.y) * self._pageSize.y, ani)
			elseif rect.height <= self._viewSize.y / 2 then
				self:setPosY(rect.y + rect.height * 2 - self._viewSize.y, ani)
			else
				self:setPosY(rect.y + rect.height - self._viewSize.y, ani)
			end
		end
	end
	if self._overlapSize.x > 0 then
		local right = self._xPos + self._viewSize.x
		if setFirst or rect.x <= self._xPos or rect.width >= self._viewSize.x then
			if self._pageMode then
				self:setPosX(math.floor(rect.x / self._pageSize.x) * self._pageSize.x, ani)
			end
			self:setPosX(rect.x, ani)
		elseif rect.x + rect.width > right then
			if self._pageMode then
				self:setPosX(math.floor(rect.x / self._pageSize.x) * self._pageSize.x, ani)
			elseif rect.width <= self._viewSize.x / 2 then
				self:setPosX(rect.x + rect.width * 2 - self._viewSize.x, ani)
			else
				self:setPosX(rect.x + rect.width - self._viewSize.x, ani)
			end
		end
	end

	if not ani and self._needRefresh then
		self:refresh()
	end
end

function ScrollPane:isChildInView(obj)
	if self._overlapSize.y > 0 then
		local dist = obj.y + self._container.y
		if dist <= - obj.height or dist >= self._viewSize.y then
			return false
		end
	end
	if self._overlapSize.x > 0 then
		local dist = obj.x + self._container.x
		if dist <= - obj.width or dist >= self._viewSize.x then
			return false
		end
	end

	return true
end

function ScrollPane:cancelDragging()
	InputProcessor.removeTouchMonitor(self._owner)

	if ScrollPane.draggingPane == self then
		ScrollPane.draggingPane = nil
	end

	_gestureFlagX = 0
	_gestureFlagY = 0
	self._isMouseMoved = false
end

function ScrollPane:lockHeader(size)
	if self._headerLockedSize == size then
		return
	end

	self._headerLockedSize = size
	if not self._owner:isDispatching("pullDownRelease") and self._container[self._refreshBarAxis] >= 0 then
		self._tweenStart:copy(self._container)
		self._tweenChange:set(0,0)
		self._tweenChange[self._refreshBarAxis] = self._headerLockedSize - self._tweenStart[self._refreshBarAxis]
		self._tweenDuration:set(TWEEN_TIME_DEFAULT, TWEEN_TIME_DEFAULT)
		self._tweenTime:set(0,0)
		self._tweening = 2
		self._owner:frameLoop(self.tweenUpdate, self)
	end
end

function ScrollPane:lockFooter(size)
	if self._footerLockedSize == size then
		return
	end

	self._footerLockedSize = size
	if not self._owner:isDispatching("pullUpRelease") and self._container[self._refreshBarAxis] <= - self._overlapSize[self._refreshBarAxis] then
		self._tweenStart:copy(self._container)
		self._tweenChange:set(0,0)
		local max = self._overlapSize[self._refreshBarAxis]
		if max == 0 then
			max = math.max(self._contentSize[self._refreshBarAxis] + self._footerLockedSize - self._viewSize[self._refreshBarAxis], 0)
		else
			max = max + self._footerLockedSize
		end
		self._tweenChange[self._refreshBarAxis] = - max - self._tweenStart[self._refreshBarAxis]
		self._tweenDuration:set(TWEEN_TIME_DEFAULT, TWEEN_TIME_DEFAULT)
		self._tweenTime:set(0,0)
		self._tweening = 2
		self._owner:frameLoop(self.tweenUpdate, self)
	end
end

function ScrollPane:onOwnerSizeChanged()
	self:setSize(self._owner.width, self._owner.height)
	self:posChanged(false)
end

function ScrollPane:handleControllerChanged(c)
	if self._pageController == c then
		if self._scrollType == 0  then
			self:setCurrentPageX(c.selectedIndex, true)
		else
			self:setCurrentPageY(c.selectedIndex, true)
		end
	end
end

function ScrollPane:updatePageController()
	if self._pageController ~= nil and not self._pageController.changing then
		local index
		if self._scrollType == ScrollType.Horizontal then
			index = self.currentPageX
		else
			index = self.currentPageY
		end
		if index < self._pageController.pageCount then
			local c = self._pageController
			self._pageController = nil
			--防止HandleControllerChanged的调用
			c.selectedIndex = index
			self._pageController = c
		end
	end
end

function ScrollPane:adjustMaskContainer()
	local mx, my
	if self._displayOnLeft and self._vtScrollBar ~= nil then
		mx = math.floor(self._owner._margin.left + self._vtScrollBar.width)
	else
		mx = self._owner._margin.left
	end
	my = self._owner._margin.top
	mx = mx + (self._owner._alignOffsetX or 0)
	my = my + (self._owner._alignOffsetY or 0)

	mx = mx - self._owner._pivotX*self._owner._width
	my = my - self._owner._pivotY*self._owner._height

	self._maskContainer.x = mx
	self._maskContainer.y = my
end

function ScrollPane:setSize(aWidth, aHeight)
	self:adjustMaskContainer()

	if self._hzScrollBar ~= nil then
		self._hzScrollBar.y = (aHeight - self._hzScrollBar.height)
		if self._vtScrollBar ~= nil then
			self._hzScrollBar.width = (aWidth - self._vtScrollBar.width - self._scrollBarMargin.left - self._scrollBarMargin.right)
			if self._displayOnLeft then
				self._hzScrollBar.x = self._scrollBarMargin.left + self._vtScrollBar.width
			else
				self._hzScrollBar.x = self._scrollBarMargin.left
			end
		else
			self._hzScrollBar.width = (aWidth - self._scrollBarMargin.left - self._scrollBarMargin.right)
			self._hzScrollBar.x = self._scrollBarMargin.left
		end
	end
	if self._vtScrollBar ~= nil then
		if not self._displayOnLeft then
			self._vtScrollBar.x = aWidth - self._vtScrollBar.width
		end
		if self._hzScrollBar ~= nil then
			self._vtScrollBar.height = (aHeight - self._hzScrollBar.height - self._scrollBarMargin.top - self._scrollBarMargin.bottom)
		else
			self._vtScrollBar.height = (aHeight - self._scrollBarMargin.top - self._scrollBarMargin.bottom)
		end
		self._vtScrollBar.y = self._scrollBarMargin.top
	end

	self._viewSize.x = aWidth
	self._viewSize.y = aHeight
	if self._hzScrollBar ~= nil and not self._hScrollNone then
		self._viewSize.y = self._viewSize.y - self._hzScrollBar.height
	end
	if self._vtScrollBar ~= nil and not self._vScrollNone then
		self._viewSize.x = self._viewSize.x - self._vtScrollBar.width
	end
	self._viewSize.x = self._viewSize.x - (self._owner._margin.left + self._owner._margin.right)
	self._viewSize.y = self._viewSize.y - (self._owner._margin.top + self._owner._margin.bottom)

	self._viewSize.x = math.max(1, self._viewSize.x)
	self._viewSize.y = math.max(1, self._viewSize.y)
	self._pageSize.x = self._viewSize.x
	self._pageSize.y = self._viewSize.y

	self:handleSizeChanged()
end

function ScrollPane:setContentSize(aWidth, aHeight)
	if self._contentSize.x==aWidth and self._contentSize.y==aHeight then
		return
	end

	self._contentSize.x = aWidth
	self._contentSize.y = aHeight
	self:handleSizeChanged()
end

function ScrollPane:changeContentSizeOnScrolling(deltaWidth, deltaHeight, deltaPosX, deltaPosY)
	local isRightmost = self._xPos == self._overlapSize.x
	local isBottom = self._yPos == self._overlapSize.y

	self._contentSize.x = self._contentSize.x + deltaWidth
	self._contentSize.y = self._contentSize.y + deltaHeight
	self:handleSizeChanged()

	if self._tweening == 1 then
		--如果原来滚动位置是贴边，加入处理继续贴边。
		if deltaWidth ~= 0 and isRightmost and self._tweenChange.x < 0 then
			self._xPos = self._overlapSize.x
			self._tweenChange.x = - self._xPos - self._tweenStart.x
		end

		if deltaHeight ~= 0 and isBottom and self._tweenChange.y < 0 then
			self._yPos = self._overlapSize.y
			self._tweenChange.y = - self._yPos - self._tweenStart.y
		end
	elseif self._tweening == 2 then
		--重新调整起始位置，确保能够顺滑滚下去
		if deltaPosX ~= 0 then
			self._container.x = (self._container.x - deltaPosX)
			self._tweenStart.x = self._tweenStart.x - deltaPosX
			self._xPos = - self._container.x
		end
		if deltaPosY ~= 0 then
			self._container.y = (self._container.y - deltaPosY)
			self._tweenStart.y = self._tweenStart.y - deltaPosY
			self._yPos = - self._container.y
		end
	elseif self._isMouseMoved then
		if deltaPosX ~= 0 then
			self._container.x = (self._container.x - deltaPosX)
			self._containerPos.x = self._containerPos.x - deltaPosX
			self._xPos = - self._container.x
		end
		if deltaPosY ~= 0 then
			self._container.y = (self._container.y - deltaPosY)
			self._containerPos.y = self._containerPos.y - deltaPosY
			self._yPos = - self._container.y
		end
	else
		--如果原来滚动位置是贴边，加入处理继续贴边。
		if deltaWidth ~= 0 and isRightmost then
			self._xPos = self._overlapSize.x
			self._container.x = (- self._xPos)
		end

		if deltaHeight ~= 0 and isBottom then
			self._yPos = self._overlapSize.y
			self._container.y = (- self._yPos)
		end
	end

	if self._pageMode then
		self:updatePageController()
	end
end

function ScrollPane:handleSizeChanged()
	if self._displayInDemand then
		if self._vtScrollBar ~= nil then
			if self._contentSize.y <= self._viewSize.y then
				if not self._vScrollNone then
					self._vScrollNone = true
					self._viewSize.x = self._viewSize.x + self._vtScrollBar.width
				end
			else
				if self._vScrollNone then
					self._vScrollNone = false
					self._viewSize.x = self._viewSize.x - self._vtScrollBar.width
				end
			end
		end
		if self._hzScrollBar ~= nil then
			if self._contentSize.x <= self._viewSize.x then
				if not self._hScrollNone then
					self._hScrollNone = true
					self._viewSize.y = self._viewSize.y + self._hzScrollBar.height
				end
			else
				if self._hScrollNone then
					self._hScrollNone = false
					self._viewSize.y = self._viewSize.y - self._hzScrollBar.height
				end
			end
		end
	end

	if self._vtScrollBar ~= nil then
		if self._viewSize.y < self._vtScrollBar.minSize then
			self._vtScrollBar.visible = false
		else
			self._vtScrollBar.visible = self._scrollBarVisible and not self._vScrollNone
			if self._contentSize.y == 0 then
				self._vtScrollBar.displayPerc = 0
			else
				self._vtScrollBar.displayPerc = math.min(1, self._viewSize.y / self._contentSize.y)
			end
		end
	end
	if self._hzScrollBar ~= nil then
		if self._viewSize.x < self._hzScrollBar.minSize then
			self._hzScrollBar.visible = false
		else
			self._hzScrollBar.visible = self._scrollBarVisible and not self._hScrollNone
			if self._contentSize.x == 0 then
				self._hzScrollBar.displayPerc = 0
			else
				self._hzScrollBar.displayPerc = math.min(1, self._viewSize.x / self._contentSize.x)
			end
		end
	end

	if not self._maskDisabled then
		self._maskContainer.width = self._viewSize.x
		self._maskContainer.height = self._viewSize.y
	end

	if self._scrollType == ScrollType.Horizontal or self._scrollType == ScrollType.Both then
		self._overlapSize.x = math.ceil(math.max(0, self._contentSize.x - self._viewSize.x))
	else
		self._overlapSize.x = 0
	end
	if self._scrollType == ScrollType.Vertical or self._scrollType == ScrollType.Both then

		self._overlapSize.y = math.ceil(math.max(0, self._contentSize.y - self._viewSize.y))
	else
		self._overlapSize.y = 0
	end

	--边界检查
	self._xPos = math.clamp(self._xPos, 0, self._overlapSize.x)
	self._yPos = math.clamp(self._yPos, 0, self._overlapSize.y)
	local max = self._overlapSize[self._refreshBarAxis]
	if max == 0 then
		max = math.max(self._contentSize[self._refreshBarAxis] + self._footerLockedSize - self._viewSize[self._refreshBarAxis], 0)
	else
		max = max + self._footerLockedSize
	end
	if self._refreshBarAxis == 'x' then
		self._container.x = math.clamp(self._container.x, - max, self._headerLockedSize)
		self._container.y = math.clamp(self._container.y, - self._overlapSize.y, 0)
	else
		self._container.x = math.clamp(self._container.x, - self._overlapSize.x, 0)
		self._container.y = math.clamp(self._container.y, - max, self._headerLockedSize)
	end

	if self._header ~= nil then
		if self._refreshBarAxis == 'x' then
			self._header.height = self._viewSize.y
		else
			self._header.width = self._viewSize.x
		end
	end

	if self._footer ~= nil then
		if self._refreshBarAxis == 'x' then
			self._footer.height = self._viewSize.y
		else
			self._footer.width = self._viewSize.x
		end
	end

	self:syncScrollBar(true)
	self:checkRefreshBar()
	if self._pageMode then
		self:updatePageController()
	end
end

function ScrollPane:posChanged(ani)
	--只要有1处要求不要缓动，那就不缓动
	if self._aniFlag == 0 then
		self._aniFlag = ani and 1 or - 1
	elseif self._aniFlag == 1 and not ani then
		self._aniFlag = - 1
	end

	self._needRefresh = true

	self._owner:delayedCall(self.refresh, self)
end

function ScrollPane:refresh()
	self._needRefresh = false
	self._owner:cancelDelayedCall(self.refresh, self)

	if self._pageMode or self._snapToItem then
		local x,y = self:alignPosition(-self._xPos, -self._yPos, false)
		self._xPos = -x
		self._yPos = -y
	end

	self:refresh2()

	self._owner:emit("scroll")

	if self._needRefresh then
		self._needRefresh = false
		self._owner:cancelDelayedCall(self.refresh, self)

		self:refresh2()
	end

	self:syncScrollBar(false)
	self._aniFlag = 0
end

function ScrollPane:refresh2()
	if self._aniFlag == 1 and not self._isMouseMoved then
		local x = 0
		local y = 0

		if self._overlapSize.x > 0 then
			x = -math.floor(self._xPos)
		else
			if self._container.x ~= 0 then
				self._container.x = 0
			end
			x = 0
		end
		if self._overlapSize.y > 0 then
			y = -math.floor(self._yPos)
		else
			if self._container.y ~= 0 then
				self._container.y = 0
			end
			y = 0
		end

		if x ~= self._container.x or y ~= self._container.y then
			self._tweening = 1
			self._tweenTime:set(0,0)
			self._tweenDuration:set(TWEEN_TIME_GO, TWEEN_TIME_GO)
			self._tweenStart:copy(self._container)
			self._tweenChange:set(x - self._tweenStart.x, y - self._tweenStart.y)
			self._owner:frameLoop(self.tweenUpdate, self)
		elseif self._tweening ~= 0 then
			self:killTween()
		end
	else
		if self._tweening ~= 0 then
			self:killTween()
		end

		self._container.x = -math.floor(self._xPos)
		self._container.y = -math.floor(self._yPos)

		self:loopCheckingCurrent()
	end

	if self._pageMode then
		self:updatePageController()
	end
end

function ScrollPane:syncScrollBar(end_)
	if self._vtScrollBar ~= nil then
		self._vtScrollBar.scrollPerc = self._overlapSize.y == 0 and 0 or math.clamp(- self._container.y, 0, self._overlapSize.y) / self._overlapSize.y
		if self._scrollBarDisplayAuto then
			self:showScrollBar(not end_)
		end
	end
	if self._hzScrollBar ~= nil then
		self._hzScrollBar.scrollPerc = self._overlapSize.x == 0 and 0 or math.clamp(- self._container.x, 0, self._overlapSize.x) / self._overlapSize.x
		if self._scrollBarDisplayAuto then
			self:showScrollBar(not end_)
		end
	end
end


function ScrollPane:_touchBegin(context)
	if not self._touchEffect then
		return
	end

	context:captureTouch()

	local evt = context.inputEvent

	local x,y = self._owner:globalToLocal(evt.x, evt.y)

	if self._tweening ~= 0 then
		self:killTween()
		InputProcessor.cancelClick(evt.touchId)

		--立刻停止惯性滚动，可能位置不对齐，设定这个标志，使touchEnd时归位
		self._isMouseMoved = true
	else
		self._isMouseMoved = false
	end

	self._containerPos:copy(self._container)
	self._lastTouchPos:set(x,y)
	self._beginTouchPos:set(x,y)
	self._lastTouchGlobalPos:set(evt.x, evt.y)
	self._isHoldAreaDone = false
	self._velocity:set(0,0)
	self._velocityScale = 1
	self._lastMoveTime = system.getTimer()
end

function ScrollPane:_touchMove(context)
	if not self._touchEffect or ScrollPane.draggingPane ~= nil and ScrollPane.draggingPane ~= self or GObject.draggingObject ~= nil then
		return
	end

	local evt = context.inputEvent

	local x,y = self._owner:globalToLocal(evt.x, evt.y)

	local sensitivity = UIConfig.touchScrollSensitivity

	local diff
	local sv = false
	local sh = false

	if self._scrollType == ScrollType.Vertical then
		if not self._isHoldAreaDone then
			--表示正在监测垂直方向的手势
			_gestureFlagY = true

			diff = math.abs(self._beginTouchPos.y - y)
			if diff < sensitivity then
				return
			end

			if _gestureFlagX then
				local diff2 = math.abs(self._beginTouchPos.x - x)
				if diff < diff2 then
					return
				end
			end
		end

		sv = true
	elseif self._scrollType == ScrollType.Horizontal then
		if not self._isHoldAreaDone then
			_gestureFlagX = true

			diff = math.abs(self._beginTouchPos.x - x)
			if diff < sensitivity then
				return
			end

			if _gestureFlagY then
				local diff2 = math.abs(self._beginTouchPos.y - y)
				if diff < diff2 then
					return
				end
			end
		end

		sh = true
	else
		_gestureFlagX = true
		_gestureFlagY = true

		if not self._isHoldAreaDone then
			diff = math.abs(self._beginTouchPos.y - y)
			if diff < sensitivity then
				diff = math.abs(self._beginTouchPos.x - x)
				if diff < sensitivity then
					return
				end
			end
		end

		sh = true 
		sv = sh
	end

	local nx,ny = math.floor(self._containerPos.x + x - self._beginTouchPos.x),
			math.floor(self._containerPos.y + y - self._beginTouchPos.y)

	if sv then
		if ny > 0 then
			if not self._bouncebackEffect then
				self._container.y = 0
			elseif self._header ~= nil and self._header.maxHeight ~= 0 then
				self._container.y = math.floor(math.min(ny * 0.5, self._header.maxHeight))
			else
				self._container.y = math.floor(math.min(ny * 0.5, self._viewSize.y *  PULL_RATIO))
			end
		elseif ny < - self._overlapSize.y then
			if not self._bouncebackEffect then
				self._container.y = -self._overlapSize.y
			elseif self._footer ~= nil and self._footer.maxHeight > 0 then
				self._container.y = math.floor(math.max((ny + self._overlapSize.y) * 0.5, - self._footer.maxHeight)) - self._overlapSize.y
			else
				self._container.y = math.floor(math.max((ny + self._overlapSize.y) * 0.5, - self._viewSize.y * PULL_RATIO)) - self._overlapSize.y
			end
		else
			self._container.y = ny
		end
	end

	if sh then
		if nx > 0 then
			if not self._bouncebackEffect then
				self._container.x = 0
			elseif self._header ~= nil and self._header.maxWidth ~= 0 then
				self._container.x = math.floor(math.min(nx * 0.5, self._header.maxWidth))
			else
				self._container.x = math.floor(math.min(nx * 0.5, self._viewSize.x * PULL_RATIO))
			end
		elseif nx < 0 - self._overlapSize.x then
			if not self._bouncebackEffect then
				self._container.x = -self._overlapSize.x
			elseif self._footer ~= nil and self._footer.maxWidth > 0 then
				self._container.x = math.floor(math.max((nx + self._overlapSize.x) * 0.5, - self._footer.maxWidth)) - self._overlapSize.x
			else
				self._container.x = math.floor(math.max((nx + self._overlapSize.x) * 0.5, - self._viewSize.x * PULL_RATIO)) - self._overlapSize.x
			end
		else
			self._container.x = nx
		end
	end

	--更新速度
	local deltaTime = 0.016
	local elapsed = (system.getTimer() - self._lastMoveTime)/1000 * 60 - 1
	if elapsed > 1 then
		local pow = math.pow(0.833, elapsed)
		self._velocity:set(self._velocity.x*pow, self._velocity.y*pow)
	end
	local dx 
	local dy
	if sh then
		dx = x - self._lastTouchPos.x
	else
		dx = 0
	end
	if sv then
		dy = y - self._lastTouchPos.y
	else
		dy = 0
	end
	self._velocity.x = math.lerp(self._velocity.x, dx/deltaTime, deltaTime * 10)
	self._velocity.y = math.lerp(self._velocity.y, dy/deltaTime, deltaTime * 10)

	--[[速度计算使用的是本地位移，但在后续的惯性滚动判断中需要用到屏幕位移，所以这里要记录一个位移的比例。
	 *后续的处理要使用这个比例但不使用坐标转换的方法的原因是，在曲面UI等异形UI中，还无法简单地进行屏幕坐标和本地坐标的转换。
	 ]]
	local dgx = self._lastTouchGlobalPos.x - evt.x
	local dgy = self._lastTouchGlobalPos.y - evt.y
	if dx ~= 0 then
		self._velocityScale = math.abs(dgx / dx)
	elseif dy ~= 0 then
		self._velocityScale = math.abs(dgy / dy)
	end

	self._lastTouchPos:set(x, y)
	self._lastTouchGlobalPos:set(evt.x, evt.y)
	self._lastMoveTime = system.getTimer()

	--同步更新pos值
	if self._overlapSize.x > 0 then
		self._xPos = math.clamp(- self._container.x, 0, self._overlapSize.x)
	end
	if self._overlapSize.y > 0 then
		self._yPos = math.clamp(- self._container.y, 0, self._overlapSize.y)
	end

	--循环滚动特别检查
	if self._loop ~= 0 then
		nx = self._container.x
		ny = self._container.y
		if self:loopCheckingCurrent() then
			self._containerPos:set(self._containerPos.x + self._container.x - nx, 
				self._containerPos.y + self._container.y - ny)
		end
	end

	ScrollPane.draggingPane = self
	self._isHoldAreaDone = true
	self._isMouseMoved = true

	self:syncScrollBar(false)
	self:checkRefreshBar()
	if self._pageMode then
		self:updatePageController()
	end

	self._owner:emit("scroll")
end

function ScrollPane:_touchEnd(context)
	if ScrollPane.draggingPane == self then
		ScrollPane.draggingPane = nil
	end

	_gestureFlagX = false
	_gestureFlagY = false

	if not self._isMouseMoved or not self._touchEffect then
		self._isMouseMoved = false
		return
	end

	self._isMouseMoved = false
	self._tweenStart:set(self._container.x, self._container.y)

	local ex, ey = self._tweenStart.x, self._tweenStart.y
	local flag = false
	if self._container.x > 0 then
		ex = 0
		flag = true
	elseif self._container.x < - self._overlapSize.x then
		ex = - self._overlapSize.x
		flag = true
	end
	if self._container.y > 0 then
		ey = 0
		flag = true
	elseif self._container.y < - self._overlapSize.y then
		ey = - self._overlapSize.y
		flag = true
	end

	if flag then
		self._tweenChange:set(ex - self._tweenStart.x, ey - self._tweenStart.y)
		if self._tweenChange.x < - UIConfig.touchDragSensitivity or self._tweenChange.y < - UIConfig.touchDragSensitivity then
			self._owner:emit("pullDownRelease")
		elseif self._tweenChange.x > UIConfig.touchDragSensitivity or self._tweenChange.y > UIConfig.touchDragSensitivity then
			self._owner:emit("pullUpRelease")
		end

		local er = self._refreshBarAxis=='x' and ex or ey

		if self._headerLockedSize > 0 and er == 0 then
			if self._refreshBarAxis=='x' then
				ex = self._headerLockedSize
			else
				ey = self._headerLockedSize
			end
			self._tweenChange:set(ex - self._tweenStart.x, ey - self._tweenStart.y)
		elseif self._footerLockedSize > 0 and er == - self._overlapSize[self._refreshBarAxis] then
			local max = self._overlapSize[self._refreshBarAxis]
			if max == 0 then
				max = math.max(self._contentSize[self._refreshBarAxis] + self._footerLockedSize - self._viewSize[self._refreshBarAxis], 0)
			else
				max = max + self._footerLockedSize
			end
			if self._refreshBarAxis=='x' then
				ex = -max
			else
				ey = -max
			end

			self._tweenChange:set(ex - self._tweenStart.x, ey - self._tweenStart.y)
		end

		self._tweenDuration:set(TWEEN_TIME_DEFAULT, TWEEN_TIME_DEFAULT)
	else
		--更新速度
		if not self._inertiaDisabled then
			local elapsed = (system.getTimer() - self._lastMoveTime) /1000 * 60 - 1
			if elapsed > 1 then
				local pow = math.pow(0.833, elapsed)
				self._velocity:set(self._velocity.x * pow, self._velocity.y * pow)
			end

			--根据速度计算目标位置和需要时间
			ex, ey = self:updateTargetAndDuration(self._tweenStart.x, self._tweenStart.y)
		else
			self._tweenDuration:set(TWEEN_TIME_DEFAULT, TWEEN_TIME_DEFAULT)
		end
		local ox, oy = ex-self._tweenStart.x, ey-self._tweenStart.y

		--调整目标位置
		ex,ey = self:loopCheckingTarget(ex, ey)
		if self._pageMode or self._snapToItem then
			ex,ey = self:alignPosition(ex, ey, true)
		end

		self._tweenChange:set(ex - self._tweenStart.x, ey - self._tweenStart.y)
		if self._tweenChange.x == 0 and self._tweenChange.y == 0 then
			if self._scrollBarDisplayAuto then
				self:showScrollBar(false)
			end
			return
		end

		--如果目标位置已调整，随之调整需要时间
		if self._pageMode or self._snapToItem then
			self:fixDuration('x', ox)
			self:fixDuration('y', oy)
		end
	end

	self._tweening = 2
	self._tweenTime:set(0, 0)
	self._owner:frameLoop(self.tweenUpdate, self)
end

function ScrollPane:_mouseWheel(context)
	if not self._mouseWheelEnabled then
		return
	end

	local delta = context.mouseWheelDelta
	delta = delta>0 and 1 or -1
	if self._overlapSize.x > 0 and self._overlapSize.y == 0 then
		if self._pageMode then
			self:setPosX(self._xPos + self._pageSize.x * delta, false)
		else
			self:setPosX(self._xPos + self._mouseWheelStep * delta, false)
		end
	else
		if self._pageMode then
			self:setPosY(self._yPos + self._pageSize.y * delta, false)
		else
			self:setPosY(self._yPos + self._mouseWheelStep * delta, false)
		end
	end
end

function ScrollPane:_rollOver()
	self:showScrollBar(true)
end

function ScrollPane:_rollOut()
	self:showScrollBar(false)
end

function ScrollPane:showScrollBar(show)
	if show then
		self:onShowScrollBar(true)
		GTween.kill(self)
	else
		GTween.delayedCall(0.5):onComplete(self.onShowScrollBar2, self):setUserData(show):setTarget(self)
	end
end

function ScrollPane:onShowScrollBar2(tweener)
	self:onShowScrollBar(tweener.data)
end

function ScrollPane:onShowScrollBar(show)
	if self._owner._disposed then
		return
	end

	self._scrollBarVisible = show and self._viewSize.x > 0 and self._viewSize.y > 0
	if self._vtScrollBar ~= nil then
		self._vtScrollBar.visible = self._scrollBarVisible and not self._vScrollNone
	end
	if self._hzScrollBar ~= nil then
		self._hzScrollBar.visible = self._scrollBarVisible and not self._hScrollNone
	end
end

function ScrollPane:getLoopPartSize(division, axis)
	return (self._contentSize[axis] + (axis == 'x' and self._owner._columnGap or self._owner._lineGap)) / division
end

-- <summary>
-- 对当前的滚动位置进行循环滚动边界检查。当到达边界时，回退一半内容区域（循环滚动内容大小通常是真实内容大小的偶数倍）。
-- </summary>
function ScrollPane:loopCheckingCurrent()
	local changed = false
	if self._loop == 1 and self._overlapSize.x > 0 then
		if self._xPos < 0.001 then
			self._xPos = self._xPos + self:getLoopPartSize(2, 'x')
			changed = true
		elseif self._xPos >= self._overlapSize.x then
			self._xPos = self._xPos - self:getLoopPartSize(2, 'x')
			changed = true
		end
	elseif self._loop == 2 and self._overlapSize.y > 0 then
		if self._yPos < 0.001 then
			self._yPos = self._yPos + self:getLoopPartSize(2, 'y')
			changed = true
		elseif self._yPos >= self._overlapSize.y then
			self._yPos = self._yPos - self:getLoopPartSize(2, 'y')
			changed = true
		end
	end

	if changed then
		self._container.x = -math.floor(self._xPos)
		self._container.y = -math.floor(self._yPos)
	end

	return changed
end

-- <summary>
-- 对目标位置进行循环滚动边界检查。当到达边界时，回退一半内容区域（循环滚动内容大小通常是真实内容大小的偶数倍）。
-- </summary>
function ScrollPane:loopCheckingTarget(ex, ey)
	if self._loop == 1 then
		ex,ey = self:loopCheckingTarget2(ex, ey, 'x')
	end

	if self._loop == 2 then
		ex,ey = self:loopCheckingTarget2(ex, ey, 'y')
	end
	return ex,ey
end

local _helperVector = Vector2.new()

function ScrollPane:loopCheckingTarget2(ex, ey, axis)
	local endPos = _helperVector
	endPos:set(ex, ey)
	if endPos[axis] > 0 then
		local halfSize = self:getLoopPartSize(2, axis)
		local tmp = self._tweenStart[axis] - halfSize
		if tmp <= 0 and tmp >= - self._overlapSize[axis] then
			endPos[axis] = endPos[axis] - halfSize
			self._tweenStart[axis] = tmp
		end
	elseif endPos[axis] < - self._overlapSize[axis] then
		local halfSize = self:getLoopPartSize(2, axis)
		local tmp = self._tweenStart[axis] + halfSize
		if tmp <= 0 and tmp >= - self._overlapSize[axis] then
			endPos[axis] = endPos[axis] + halfSize
			self._tweenStart[axis] = tmp
		end
	end
	return endPos.x, endPos.y
end

function ScrollPane:loopCheckingNewPos(value, axis)
	if self._overlapSize[axis] == 0 then
		return value
	end

	local pos = axis == 'x' and self._xPos or self._yPos
	local changed = false
	if value < 0.001 then
		value = value + self:getLoopPartSize(2, axis)
		if value > pos then
			local v = self:getLoopPartSize(6, axis)
			v = math.ceil((value - pos) / v) * v
			pos = math.clamp(pos + v, 0, self._overlapSize[axis])
			changed = true
		end
	elseif value >= self._overlapSize[axis] then
		value = value - self:getLoopPartSize(2, axis)
		if value < pos then
			local v = self:getLoopPartSize(6, axis)
			v = math.ceil((pos - value) / v) * v
			pos = math.clamp(pos - v, 0, self._overlapSize[axis])
			changed = true
		end
	end

	if changed then
		if axis == 'x' then
			self._container.x = -math.floor(pos)
		else
			self._container.y = -math.floor(pos)
		end
	end
	return value
end

-- <summary>
-- 从oldPos滚动至pos，调整pos位置对齐页面、对齐item等（如果需要）。
-- </summary>
-- <param name="inertialScrolling"></param>
function ScrollPane:alignPosition(x, y, inertialScrolling)
	if self._pageMode then
		x = self:alignByPage(x, 'x', inertialScrolling)
		y = self:alignByPage(y, 'y', inertialScrolling)
	elseif self._snapToItem then
		local tmpX, tmpY = self._owner:getSnappingPosition(-x, -y)
		if x < 0 and x > - self._overlapSize.x then
			x = -tmpX
		end
		if y < 0 and y > - self._overlapSize.y then
			y = -tmpY
		end
	end
	return x,y
end

-- <summary>
-- 从oldPos滚动至pos，调整目标位置到对齐页面。
-- </summary>
-- <param name="axis"></param>
-- <param name="inertialScrolling"></param>
-- <returns></returns>
function ScrollPane:alignByPage(pos, axis, inertialScrolling)
	local page

	if pos > 0 then
		page = 0
	elseif pos < - self._overlapSize[axis] then
		page = math.ceil(self._contentSize[axis] / self._pageSize[axis]) - 1
	else
		page = math.floor(- pos / self._pageSize[axis])
		local change = inertialScrolling and (pos - self._containerPos[axis]) or (pos - self._container[axis])
		local testPageSize = math.min(self._pageSize[axis], self._contentSize[axis] - (page + 1) * self._pageSize[axis])
		local delta = - pos - page * self._pageSize[axis]

		--页面吸附策略
		if math.abs(change) > self._pageSize[axis] then
			if delta > testPageSize * 0.5 then
				page = page + 1
			end
		else
			if delta > testPageSize * (change < 0 and 0.3 or 0.7) then
				page = page + 1
			end
		end

		--重新计算终点
		pos = - page * self._pageSize[axis]
		if pos < - self._overlapSize[axis] then
			pos = - self._overlapSize[axis]
		end
	end

	--惯性滚动模式下，会增加判断尽量不要滚动超过一页
	if inertialScrolling then
		local oldPos = self._tweenStart[axis]
		local oldPage
		if oldPos > 0 then
			oldPage = 0
		elseif oldPos < - self._overlapSize[axis] then
			oldPage = math.ceil(self._contentSize[axis] / self._pageSize[axis]) - 1
		else
			oldPage = math.floor(- oldPos / self._pageSize[axis])
		end
		local startPage = math.floor(- self._containerPos[axis] / self._pageSize[axis])
		if math.abs(page - startPage) > 1 and math.abs(oldPage - startPage) <= 1 then
			if page > startPage then
				page = startPage + 1
			else
				page = startPage - 1
			end
			pos = - page * self._pageSize[axis]
		end
	end

	return pos
end

-- <summary>
-- 根据当前速度，计算滚动的目标位置，以及到达时间。
-- </summary>
-- <returns></returns>
function ScrollPane:updateTargetAndDuration(x, y)
	x = self:updateTargetAndDuration2(x, 'x')
	y = self:updateTargetAndDuration2(y, 'y')
	return x, y
end

function ScrollPane:updateTargetAndDuration2(pos, axis)
	local v = self._velocity[axis]
	local duration = 0

	if pos > 0 then
		pos = 0
	elseif pos < - self._overlapSize[axis] then
		pos = - self._overlapSize[axis]
	elseif v~=0 then
		--以屏幕像素为基准
		local v2 = math.abs(v) * self._velocityScale

		--在移动设备上，需要对不同分辨率做一个适配，我们的速度判断以1136分辨率为基准
		v2 = v2 * (1136 / math.max(display.pixelWidth, display.pixelHeight))
		self._velocity[axis] = v

		--算法：v*（_decelerationRate的n次幂）= 60，即在n帧后速度降为60（假设每秒60帧）。
		duration = math.log(60/v2) / math.log(self._decelerationRate) / 60

		--计算距离要使用本地速度
		--理论公式貌似滚动的距离不够，改为经验公式
		--float change = (int)((v/ 60 - 1) / (1 - _decelerationRate))
		local change = math.floor(v * duration * 0.4)
		pos = pos + change
	end

	if duration < TWEEN_TIME_DEFAULT then
		duration = TWEEN_TIME_DEFAULT
	end
	self._tweenDuration[axis] = duration

	return pos
end

-- <summary>
-- 根据修改后的tweenChange重新计算减速时间。
-- </summary>
function ScrollPane:fixDuration(axis, oldChange)
	if self._tweenChange[axis] == 0 or math.abs(self._tweenChange[axis]) >= math.abs(oldChange) then
		return
	end

	local newDuration = math.abs(self._tweenChange[axis] / oldChange) * self._tweenDuration[axis]
	if newDuration < TWEEN_TIME_DEFAULT then
		newDuration = TWEEN_TIME_DEFAULT
	end

	self._tweenDuration[axis] = newDuration
end

function ScrollPane:killTween()
	if self._tweening == 1 then
		self._container.x = self._tweenStart.x + self._tweenChange.x
		self._container.y = self._tweenStart.y + self._tweenChange.y
		self._owner:emit("scroll")
	end

	self._tweening = 0
	self._owner:cancelFrameLoop(self.tweenUpdate, self)
	self._owner:emit("scrollEnd")
end

function ScrollPane:checkRefreshBar()
	if self._header == nil and self._footer == nil then
		return
	end

	local pos = self._container[self._refreshBarAxis]
	if self._header ~= nil then
		if pos > 0 then
			self._header.visible = true
			_helperVector:set(self._header.width, self._header.height)
			_helperVector[self._refreshBarAxis] = pos
			self._header:setSize(_helperVector.x, _helperVector.y)
		else
			self._header.visible = false
		end
	end

	if self._footer ~= nil then
		local max = self._overlapSize[self._refreshBarAxis]
		if pos < - max or max == 0 and self._footerLockedSize > 0 then
			self._footer.visible = true

			_helperVector:copy(self._footer)
			if max > 0 then
				_helperVector[self._refreshBarAxis] = pos + self._contentSize[self._refreshBarAxis]
			else
				_helperVector[self._refreshBarAxis] = math.max(math.min(pos + self._viewSize[self._refreshBarAxis], self._viewSize[self._refreshBarAxis] - self._footerLockedSize), self._viewSize[self._refreshBarAxis] - self._contentSize[self._refreshBarAxis])
			end
			self._footer.x = _helperVector.x

			_helperVector:set(self._footer.width, self._footer.height)
			if max > 0 then
				_helperVector[self._refreshBarAxis] = - max - pos
			else
				_helperVector[self._refreshBarAxis] = self._viewSize[self._refreshBarAxis] - self._footer[self._refreshBarAxis]
			end
			self._footer:setSize(_helperVector.x, _helperVector.y)
		else
			self._footer.visible = false
		end
	end
end

function ScrollPane:tweenUpdate(dt)
	local nx = self:runTween('x', dt)
	local ny = self:runTween('y', dt)

	self._container.x = nx
	self._container.y = ny

	if self._tweening == 2 then
		if self._overlapSize.x > 0 then
			self._xPos = math.clamp(- nx, 0, self._overlapSize.x)
		end
		if self._overlapSize.y > 0 then
			self._yPos = math.clamp(- ny, 0, self._overlapSize.y)
		end

		if self._pageMode then
			self:updatePageController()
		end
	end

	if self._tweenChange.x == 0 and self._tweenChange.y == 0 then
		self._tweening = 0
		self._owner:cancelFrameLoop(self.tweenUpdate, self)

		self:loopCheckingCurrent()

		self:syncScrollBar(true)
		self:checkRefreshBar()
		self._owner:emit('scroll')
		self._owner:emit('scrollEnd')
	else
		self:syncScrollBar(false)
		self:checkRefreshBar()
		self._owner:emit('scroll')
	end
end

function ScrollPane:runTween(axis, dt)
	local newValue
	if self._tweenChange[axis] ~= 0 then
		self._tweenTime[axis] = self._tweenTime[axis] + dt
		if self._tweenTime[axis] >= self._tweenDuration[axis] then
			newValue = self._tweenStart[axis] + self._tweenChange[axis]
			self._tweenChange[axis] = 0
		else
			local ratio = easeFunc(self._tweenTime[axis], self._tweenDuration[axis])
			newValue = self._tweenStart[axis] + math.floor(self._tweenChange[axis] * ratio)
		end

		local threshold1 = 0
		local threshold2 = - self._overlapSize[axis]
		if self._headerLockedSize > 0 and self._refreshBarAxis == axis then
			threshold1 = self._headerLockedSize
		end
		if self._footerLockedSize > 0 and self._refreshBarAxis == axis then
			local max = self._overlapSize[self._refreshBarAxis]
			if max == 0 then
				max = math.max(self._contentSize[self._refreshBarAxis] + self._footerLockedSize - self._viewSize[self._refreshBarAxis], 0)
			else
				max = max + self._footerLockedSize
			end
			threshold2 = - max
		end

		if self._tweening == 2 and self._bouncebackEffect then
			if newValue > 20 + threshold1 and self._tweenChange[axis] > 0 or newValue > threshold1 and self._tweenChange[axis] == 0 then
				self._tweenTime[axis] = 0
				self._tweenDuration[axis] = TWEEN_TIME_DEFAULT
				self._tweenChange[axis] = -newValue + threshold1
				self._tweenStart[axis] = newValue
			elseif newValue < threshold2 - 20 and self._tweenChange[axis] < 0 or newValue < threshold2 and self._tweenChange[axis] == 0 then
				self._tweenTime[axis] = 0
				self._tweenDuration[axis] = TWEEN_TIME_DEFAULT
				self._tweenChange[axis] = threshold2 - newValue
				self._tweenStart[axis] = newValue
			end
		else
			if newValue > threshold1 then
				newValue = threshold1
				self._tweenChange[axis] = 0
			elseif newValue < threshold2 then
				newValue = threshold2
				self._tweenChange[axis] = 0
			end
		end
	else
		newValue = self._container[axis]
	end

	return newValue
end

return ScrollPane