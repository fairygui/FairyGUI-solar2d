local InputProcessor = require("Event.InputProcessor")
local tools = require('Utils.ToolSet')

GRoot = class('GRoot', GComponent)
GRoot._hidden_root = display.newGroup()
GRoot._hidden_root.isVisible = false

UIRoot = nil

local getters = GRoot.getters
local setters = GRoot.setters

function GRoot.create(scene)
	local group = scene and scene.view or display.currentStage

	local inst = GRoot.new()
	group:insert(inst.displayObject)

	UIRoot = inst

	return inst
end

function GRoot:ctor()
	GRoot.super.ctor(self)

	self.opaque = true
	self._popupStack = {}
	self._justClosedPopups = {}

	Runtime:addEventListener( "resize", self)
	Runtime:addEventListener( "orientation", self)

	self:resize()
end

function GRoot:dispose()
	GRoot.super.dispose(self)

	Runtime:removeEventListener( "resize", self)
	Runtime:removeEventListener( "orientation", self)

	if UIRoot==self then UIRoot = nil end
end

function GRoot:showWindow(win)
	self:addChild(win)
	self:adjustModalLayer()
end

function GRoot:hideWindow(win)
	win:hide()
end

function GRoot:hideWindowImmediately(win, dispose)
	if win.parent == self then
		self:removeChild(win, dispose)
	elseif dispose then
		win:dispose()
	end

	self:adjustModalLayer()
end

function GRoot:bringToFront(win)
	local cnt = self.numChildren
	local i
	if self._modalLayer.parent ~= nil and not win.modal then
		i = self:getChildIndex(self._modalLayer) - 1
	else
		i = cnt - 1
	end

	while i >= 0 do
		local g = self:getChildAt(i)
		if g == win then
			return
		end
		if typeof(g, Window) then
			break
		end
		i = i - 1
	end

	if i >= 0 then
		self:setChildIndex(win, i)
	end
end

function GRoot:showModalWait ()
	if UIConfig.globalModalWaiting ~= nil then
		if self._modalWaitPane == nil then
			self._modalWaitPane = UIPackage.createObjectFromURL(UIConfig.globalModalWaiting)
		end
		self._modalWaitPane:setSize(self.width, self.height)
		self._modalWaitPane:addRelation(self, RelationType.Size)

		self:addChild(self._modalWaitPane)
	end
end

function GRoot:closeModalWait ()
	if self._modalWaitPane ~= nil and self._modalWaitPane.parent ~= nil then
		self:removeChild(self._modalWaitPane)
	end
end

function GRoot:closeAllExceptModals ()
	local arr = tools.copy(self._children)
	for _, g in ipairs(arr) do
		if typeof(g, Window) and not g.modal then
			self:hideWindowImmediately(g)
		end
	end
end

function GRoot:closeAllWindows ()
	local arr = tools.copy(self._children)
	for _, g in ipairs(arr) do
		if typeof(g, Window) then
			self:hideWindowImmediately(g)
		end
	end
end

function GRoot:getTopWindow ()
	local cnt = self.numChildren
	for i = cnt - 1, 0, -1 do
		local g = self:getChildAt(i)
		if typeof(g, Window) then
			return g
		end
	end

	return nil
end

function getters:modalLayer()
	if self._modalLayer == nil then
		self:createModalLayer()
	end

	return self._modalLayer
end

function GRoot:createModalLayer()
	self._modalLayer = GGraph.new()
	self._modalLayer:setSize(self._width, self._height)
	self._modalLayer:drawRect(0, 0, 0, UIConfig.modalLayerColor, UIConfig.modalLayerAlpha)
	self._modalLayer:addRelation(self, RelationType.Size)
end

function getters:hasModalWindow()
	return self._modalLayer ~= nil and self._modalLayer.parent ~= nil
end

function getters:modalWaiting()
	return (self._modalWaitPane ~= nil) and self._modalWaitPane.onStage
end

function getters:touchPos()
	return InputProcessor._lastTouch.x, InputProcessor._lastTouch.y
end

function getters:touchTarget()
	return InputProcessor._lastTouch.target
end

function GRoot:adjustModalLayer ()
	if self._modalLayer == nil then
		self:createModalLayer()
	end

	local cnt = self.numChildren

	if self._modalWaitPane ~= nil and self._modalWaitPane.parent ~= nil then
		self:setChildIndex(self._modalWaitPane, cnt - 1)
	end

	for i = cnt - 1, 0, -1 do
		local g = self:getChildAt(i)
		if typeof(g, Window) and g.modal then
			if self._modalLayer.parent == nil then
				self:addChildAt(self._modalLayer, i)
			else
				self:setChildIndexBefore(self._modalLayer, i)
			end
			return
		end
	end

	if self._modalLayer.parent ~= nil then
		self:removeChild(self._modalLayer)
	end
end

function GRoot:showPopup(popup, target, downward)
	if #self._popupStack > 0 then
		local k = tools.indexOf(self._popupStack, popup)
		if k ~= 0 then
			do
				local i = #self._popupStack
				while i >= k do
					local last = #self._popupStack
					self:closePopup(self._popupStack[last])
					table.remove(self._popupStack, last)
					i = i - 1
				end
			end
		end
	end
	table.insert(self._popupStack, popup)

	if target ~= nil then
		local p = target
		while p ~= nil do
			if p.parent == self then
				if popup.sortingOrder < p.sortingOrder then
					popup.sortingOrder = p.sortingOrder
				end
				break
			end
			p = p.parent
		end
	end

	self:addChild(popup)
	self:adjustModalLayer()

	if typeof(popup, Window) and target == nil and downward == nil then
		return
	end

	local x,y = self:getPoupPosition(popup, target, downward)
	popup:setPosition(x,y)
end

function GRoot:getPoupPosition(popup, target, downward)
	local x
	local y
	local w = 0
	local h = 0
	if target ~= nil then
		x,y = target:localToRoot(0, 0)
		w,h = target:localToRoot(target.width, target.height)
		w = w - x
		h = h - y
	else
		x, y = self.touchPos
		x,y = self:globalToLocal(x, y)
	end
	local xx, yy
	xx = x
	if xx + popup.width > self._width then
		xx = xx + w - popup._width
	end
	yy = y + h

	if (downward == nil and yy + popup.height > self._height) or downward ~= nil and downward == false then
		yy = y - popup.height - 1
		if yy < 0 then
			yy = 0
			xx = xx + (w / 2)
		end
	end

	return math.floor(xx), math.floor(yy)
end

function GRoot:togglePopup(popup, target, downward)
	if tools.indexOf(self._justClosedPopups, popup) ~= 0 then
		return
	end

	self:showPopup(popup, target, downward)
end

function GRoot:hidePopup(popup)
	if popup ~= nil then
		local k = tools.indexOf(self._popupStack, popup)
		if k ~= 0 then
			do
				local i = #self._popupStack
				while i >= k do
					local last = #self._popupStack
					self:closePopup(self._popupStack[last])
					table.remove(self._popupStack, last)
					i = i - 1
				end
			end
		end
	else
		for _, obj in ipairs(self._popupStack) do
			self:closePopup(obj)
		end
		self._popupStack = {}
	end
end

function getters:hasAnyPopup ()
	return #self._popupStack > 0
end

function GRoot:closePopup(target)
	if target.parent ~= nil then
		if typeof(target, Window) then
			target:hide()
		else
			self:removeChild(target)
		end
	end
end

function GRoot:showTooltips(msg)
	if self._defaultTooltipWin == nil then
		local resourceURL = UIConfig.tooltipsWin
		assert(resourceURL and #resourceURL>0, "FairyGUI: UIConfig.tooltipsWin not defined")

		self._defaultTooltipWin = UIPackage.createObjectFromURL(resourceURL)
		self._defaultTooltipWin.touchable = false
	end

	self._defaultTooltipWin.text = msg
	self:showTooltipsWin( self._defaultTooltipWin)
end


function GRoot:showTooltipsWin(tooltipWin)
	self:hideTooltips(this)

	self._tooltipWin = tooltipWin
	GTween.delayedCall(0.1):onComplete(self._showTooltipsWin, self)
end

function GRoot:_showTooltipsWin()
	if self._tooltipWin == nil then
		return
	end

	local xx,yy = self.touchPos
	xx = xx + 10
	yy = yy + 20

	xx, yy = self:globalToLocal(xx, yy)

	if xx + self._tooltipWin.width > self._width then
		xx = xx - self._tooltipWin._width
	end
	if yy + self._tooltipWin.height > self._height then
		yy = yy - self._tooltipWin._height - 1
		if yy < 0 then
			yy = 0
		end
	end

	self._tooltipWin:setPosition(math.floor(xx), math.floor(yy))
	self:addChild(self._tooltipWin)
end

function GRoot:hideTooltips ()
	if self._tooltipWin ~= nil then
		if self._tooltipWin.parent ~= nil then
			self:removeChild(self._tooltipWin)
		end
		self._tooltipWin = nil
	end
end

function GRoot:checkPopups ()
	while #self._justClosedPopups>0 do
		table.remove(self._justClosedPopups, #self._justClosedPopups)
	end

	if #self._popupStack > 0 then
		local mc = self.touchTarget
		local handled = false
		while mc ~= self and mc ~= nil do
			local k = tools.indexOf(self._popupStack, mc)
			if k ~= 0 then
				local i = #self._popupStack
				while i > k do
					local last = #self._popupStack
					local popup = self._popupStack[last]
					self:closePopup(popup)
					table.insert(self._justClosedPopups, popup)
					table.remove(self._popupStack, last)
					i = i - 1
				end
				handled = true
				break
			end
			mc = mc:findParent()
		end

		if not handled then
			for i = #self._popupStack, 1, -1 do
				local popup = self._popupStack[i]
				self:closePopup(popup)
				table.insert(self._justClosedPopups, popup)
			end
			while #self._popupStack>0 do
				table.remove(self._popupStack, #self._popupStack)
			end
		end
	end
end

function GRoot:enableSound()
	
end

function GRoot:disableSound()

end

function GRoot:playOneShotSound(clip, volumeScale)
	audio.play(clip)
end

function getters:soundVolume ()
	return 0
end

function setters:soundVolume(value)
	
end

function GRoot:resize()
	self:setSize(display.actualContentWidth, display.actualContentHeight)
	self:setPosition(display.screenOriginX, display.screenOriginY)
end

function GRoot:orientation()
	self:resize()
end

function GRoot.onTouchBeginCapture()
	native.setKeyboardFocus( nil )
	
	local self = UIRoot

	if self._tooltipWin ~= nil then
		self:hideTooltips()
	end

	self:checkPopups()
end
