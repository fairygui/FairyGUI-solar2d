Window = class('Window', GComponent)

local getters = Window.getters
local setters = Window.setters

function Window:ctor()
	Window.super.ctor(self)

	self._uiSources = {}
	self.bringToFontOnClick = UIConfig.bringWindowToFrontOnClick

	self:on("addedToStage", self._onShown, self)
	self:on("removeFromStage", self._onHide, self)
	self:on("touchBegin", self._touchBegin, self)
end

function Window:addUISource(source)
	table.insert(self._uiSources, source)
end

function setters:contentPane(value)
	if self._contentPane ~= value then
		if self._contentPane ~= nil then
			self:removeChild(self._contentPane)
		end
		self._contentPane = value
		if self._contentPane ~= nil then
			self:addChild(self._contentPane)
			self:setSize(self._contentPane.width, self._contentPane.height)
			self._contentPane:addRelation(self, RelationType.Size)
			self._frame = self._contentPane:getChild("frame")
			if self._frame ~= nil then
				self.closeButton = self._frame:getChild("closeButton")
				self.dragArea =  self._frame:getChild("dragArea")
				self.contentArea = self._frame:getChild("contentArea")
			end
		else
			self._frame = nil
		end
	end
end

function getters:contentPane()
	return self._contentPane
end

function getters:frame()
	return self._frame
end

function getters:closeButton()
	return self._closeButton
end

function setters:closeButton(value)
	if self._closeButton ~= nil then
		self._closeButton:off("tap", self.closeEventHandler, self)
	end
	self._closeButton = value
	if self._closeButton ~= nil then
		self._closeButton:on("tap", self.closeEventHandler, self)
	end
end

function getters:dragArea()
	return self._dragArea
end

function setters:dragArea(value)
	if self._dragArea ~= value then
		if self._dragArea ~= nil then
			self._dragArea.draggable = false
			self._dragArea:off("dragStart", self._dragStart, self)
		end

		self._dragArea = value
		if self._dragArea ~= nil then
			local graph = typeof(self._dragArea, GGraph)
			if graph ~= nil and graph.isEmpty then
				graph:drawRect(0, 0, 0, 0, 0)
			end
			self._dragArea.draggable = true
			self._dragArea:on("dragStart", self._dragStart, self)
		end
	end
end

function getters:contentArea()
	return self._contentArea
end

function setters:contentArea(value)
	self._contentArea = value
end

function getters:modalWaitingPane()
	return self._modalWaitPane
end

function Window:show()
	UIRoot:showWindow(self)
end

function Window:showOn(r)
	r:showWindow(self)
end

function Window:hide()
	if self.isShowing then
		self:doHideAnimation()
	end
end

function Window:hideImmediately()
	self.root:hideWindowImmediately(self)
end

function Window:centerOn(r, restraint)
	self:setPosition(math.floor((r.width - self.width) / 2), math.floor((r.height - self.height) / 2))
	if restraint then
		self:addRelation(r, RelationType.Center_Center)
		self:addRelation(r, RelationType.Middle_Middle)
	end
end

function Window:toggleStatus()
	if self.isTop then
		self:hide()
	else
		self:show()
	end
end

function getters:isShowing()
	return self.onStage
end

function getters:isTop()
	return self.parent ~= nil and self.parent:getChildIndex(self) == self.parent.numChildren - 1
end

function getters:modal()
	return self._modal
end

function setters:modal(value)
	self._modal = value
end

function Window:bringToFront()
	self.root:bringToFront(self)
end

function Window:showModalWait(requestingCmd)
	if requestingCmd and requestingCmd ~= 0 then
		self._requestingCmd = requestingCmd
	end

	if UIConfig.windowModalWaiting ~= nil then
		if self._modalWaitPane == nil then
			self._modalWaitPane = UIPackage.createObjectFromURL(UIConfig.windowModalWaiting)
		end

		self:layoutModalWaitPane()

		self:addChild(self._modalWaitPane)
	end
end

function Window:layoutModalWaitPane()
	if self._contentArea ~= nil then
		local x,y = self._frame:localToGlobal(0,0)
		x,y = self:globalToLocal(x,y)
		self._modalWaitPane:setPosition(x + self._contentArea.x, y + self._contentArea.y)
		self._modalWaitPane:setSize(self._contentArea.width, self._contentArea.height)
	else
		self._modalWaitPane:setSize(self.width, self.height)
	end
end

function Window:closeModalWait(requestingCmd)
	if requestingCmd and requestingCmd ~= 0 then
		if self._requestingCmd ~= requestingCmd then
			return false
		end
	end
	self._requestingCmd = 0

	if self._modalWaitPane ~= nil and self._modalWaitPane.parent ~= nil then
		self:removeChild(self._modalWaitPane)
	end

	return true
end

function getters:modalWaiting()
	return (self._modalWaitPane ~= nil) and self._modalWaitPane.parent~=nil
end

function Window:init()
	if self._inited or self._loading then
		return
	end

	if #self._uiSources > 0 then
		self._loading = false
		local cnt = #self._uiSources
		local this = self
		local cb = function() this._uiLoadComplete(this) end
		do
			for i=1,cnt do
				local lib = self._uiSources[i]
				if not lib.isLoaded then
					lib:load(cb)
					self._loading = true
				end
			end
		end

		if not self._loading then
			self:_init()
		end
	else
		self:_init()
	end
end

function Window:onInit()
end

function Window:onShown()
end

function Window:onHide()
end

function Window:doShowAnimation()
	self:onShown()
end

function Window:doHideAnimation()
	self:hideImmediately()
end

function Window:_uiLoadComplete()
	local cnt = #self._uiSources
	for i=1,cnt do
		local lib = self._uiSources[i]
		if not lib.isLoaded then
			return
		end
	end

	self._loading = false
	self:_init()
end

function Window:_init()
	self._inited = true
	self:onInit()

	if self.isShowing then
		self:doShowAnimation()
	end
end

function Window:dispose()
	if self._modalWaitPane ~= nil and self._modalWaitPane.parent == nil then
		self._modalWaitPane:dispose()
	end

	Window.super.dispose(self)
end

function Window:closeEventHandler()
	self:hide()
end

function Window:_onShown()
	if not self._inited then
		self:init()
	else
		self:doShowAnimation()
	end
end

function Window:_onHide()
	self:closeModalWait()
	self:onHide()
end

function Window:_touchBegin(context)
	if self.isShowing and self.bringToFontOnClick then
		self:bringToFront()
	end
end

function Window:_dragStart(context)
	context:preventDefault()

	self:startDrag(context.inputEvent.touchId)
end