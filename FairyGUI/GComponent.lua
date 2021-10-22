local Controller = require('Controller')
local Transition = require('Transition')
local ScrollPane = require('ScrollPane')
local PixelHitTest = require('Utils.PixelHitTest')
local tools = require('Utils.ToolSet')

GComponent = class('GComponent', GObject)

local getters = GComponent.getters
local setters = GComponent.setters

function GComponent:ctor()
	GComponent.super.ctor(self)
	
	self._children = {}
	self._controllers = {}
	self._transitions = {}
	self._margin = {left=0, right=0, top=0, bottom=0}
	self._boundsChanged = false
	self._childrenRenderOrder = 0
	self._apexIndex = 0
	self._sortingChildCount = 0

	local obj = display.newGroup()
	GRoot._hidden_root:insert(obj)
	obj.anchorX = 0
	obj.anchorY = 0
	obj.gOwner = self

	local cc = display.newGroup()
	cc.anchorX = 0
	cc.anchorY = 0
	self._container = cc
	obj:insert(cc)

	self.displayObject = obj
end

function GComponent:dispose()
	if self._disposed then return end

	local cnt = #self._transitions
	for i=1,cnt do
		local trans = self._transitions[i]
		trans:dispose()
	end

	cnt = #self._controllers
	for i=1,cnt do
		local c = self._controllers[i]
		c:dispose()
	end

	if self.scrollPane then self.scrollPane:dispose() end

	GComponent.super.dispose(self) --Dispose native tree first, avoid DisplayObject.RemoveFromParent call

	cnt = #self._children
	for i=cnt,1,-1 do
		local obj = self._children[i]
		obj.parent = nil
		obj:dispose()
	end
end

function getters:opaque()
	return self._background~=nil
end

function setters:opaque(value) 
	local v = self._background~=nil
	if v~=value then
		if value then
			local obj = display.newRect(0,0,1,1)
			self._background = obj
			obj.isVisible = false
			obj.isHitTestable = true
			obj.anchorX = 0
			obj.anchorY = 0
			obj.width = self._width
			obj.height = self._height
			obj.x = -self._pivotX*self._width
			obj.y = -self._pivotY*self._height
			obj:addEventListener( "touch", self )
			self.displayObject:insert(1, obj)
		else
			self._background:removeSelf()
			self._background = nil
		end
	end
end

function getters:margin() end
function setters:margin(value)
	self._margin = value
	self:handleSizeChanged()
 end

function getters:childrenRenderOrder() return self._childrenRenderOrder end
function setters:childrenRenderOrder(value) 
	if self._childrenRenderOrder~=value then
		self._childrenRenderOrder = value
		self:delayedCall(self.buildNativeDisplayList, self)
	end
end

function getters:apexIndex() return self._apexIndex end
function setters:apexIndex(value) 
	if self._apexIndex~=value then
		self._apexIndex = value
		if self._childrenRenderOrder == ChildrenRenderOrder.Arch then
			self:buildNativeDisplayList()
		end
	end
end

function GComponent:addChild(child)
	self:addChildAt(child, #self._children)
	return child
end

function GComponent:addChildAt(child, index)
	assert(child, "child is null")
	assert(index >= 0 and index <= self.numChildren, "Invalid child index: "..index..">"..self.numChildren)

	if child.parent == self then	
		self:setChildIndex(child, index)
	else	
		child:removeFromParent()
		child.parent = self

		local cnt = #self._children
		if child._sortingOrder~=0 then
			self._sortingChildCount = self._sortingChildCount+1
			index = self:getInsertPosForSortingChild(child)
		elseif self._sortingChildCount > 0 then
			if index > (cnt - self._sortingChildCount) then
				index = cnt - self._sortingChildCount
			end
		end

		table.insert(self._children, index+1, child)

		self:childStateChanged(child)
		if child.group then	child.group:setBoundsChangedFlag(true)	end
		self:setBoundsChangedFlag()

		if self.onStage then
			if typeof(child, GComponent) then
				child:broadcast("addedToStage")
			else
				child:emit("addedToStage")
			end
		end
	end
	return child
end

function GComponent:getInsertPosForSortingChild(target)
	local cnt = #self._children
	for i=1,cnt do	
		local child = self._children[i]
		if child ~= target then
			if target._sortingOrder < child._sortingOrder then
				return i-1
			end
		end
	end
	return cnt
end

function GComponent:removeChild(child, dispose)
	local childIndex = tools.indexOf(self._children, child)
	if childIndex ~= 0 then	
		self:removeChildAt(childIndex-1, dispose)
	end
	return child
end

function GComponent:removeChildAt(index, dispose)
	assert(index >= 0 and index < self.numChildren, "Invalid child index: "..index..">"..self.numChildren)

	local child = self._children[index+1]
	child.parent = nil

	if child.sortingOrder ~= 0 then
		self._sortingChildCount = self._sortingChildCount-1
	end

	table.remove(self._children, index+1)
	child.group = nil
	if child.displayObject then
		GRoot._hidden_root:insert(child.displayObject)
		if self._childrenRenderOrder == ChildrenRenderOrder.Arch then
			self:delayedCall(self.buildNativeDisplayList, self)
		end
	end

	self:setBoundsChangedFlag()

	if dispose then
		child:dispose()
	else
		if self.onStage then
			if typeof(child, GComponent) then
				child:broadcast("removeFromStage")
			else
				child:emit("removeFromStage")
			end
		end
	end

	return child
end

function GComponent:removeChildren(beginIndex, endIndex, dispose)
	beginIndex = beginIndex or 0
	endIndex = beginIndex or -1

	if endIndex < 0 or endIndex >= self.numChildren then
		endIndex = self.numChildren - 1
	end

	for i = beginIndex,endIndex do
		self:removeChildAt(beginIndex, dispose)
	end
end

function GComponent:getChildAt(index)
	assert(index >= 0 and index < self.numChildren, "Invalid child index: "..index..">"..self.numChildren)
	return self._children[index+1]
end

function GComponent:getChild(name)
	local cnt = #self._children
	for i=1,cnt do	
		if self._children[i].name == name then
			return self._children[i]
		end
	end
end

function GComponent:getChildById(id)
local cnt = #self._children
	for i=1,cnt do	
		if self._children[i].id == id then
			return self._children[i]
		end
	end
end

function GComponent:getChildIndex(child)
	local cnt = #self._children
	for i=1,cnt do	
		if self._children[i] == child then
			return i-1
		end
	end

	return -1
end

function GComponent:setChildIndex(child, index)
	local oldIndex = self:getChildIndex(child)
	assert(oldIndex ~= -1,  "Not a child of this container")

	if child.sortingOrder ~= 0 then return end --no effect

	if self._sortingChildCount > 0 then	
		local cnt = #self._children
		if index > (cnt - self._sortingChildCount - 1) then
			index = cnt - self._sortingChildCount - 1
		end
	end

	self:_setChildIndex(child, oldIndex, index)
end

function GComponent:setChildIndexBefore(child, index)
	local oldIndex = self:getChildIndex(child)
	assert(oldIndex ~= -1,  "Not a child of this container")

	if child.sortingOrder ~= 0 then return end --no effect

	if self._sortingChildCount > 0 then	
		local cnt = #self._children
		if index > (cnt - _sortingChildCount - 1) then
			index = cnt - _sortingChildCount - 1
		end
	end

	if oldIndex < index then
		return self:_setChildIndex(child, oldIndex, index - 1)
	else
		return self:_setChildIndex(child, oldIndex, index)
	end
end

function GComponent:_setChildIndex(child, oldIndex, index)
	local cnt = #self._children
	if index > cnt then index = cnt end

	if oldIndex == index then return oldIndex end

	table.remove(self._children, oldIndex+1)
	if index==cnt then
		table.insert(self._children, index, child)
	else
		table.insert(self._children, index+1, child)
	end

	if not self._buildingDisplayList
		and child.displayObject 
		and child.displayObject.parent==self._container then

		local displayIndex = 1
		local ct = self._container
		if self._childrenRenderOrder == ChildrenRenderOrder.Ascent then
			for i=1,index do
				local g = self._children[i]
				if g.displayObject and g.displayObject.parent==ct then
					displayIndex = displayIndex + 1
				end
			end
			ct:insert(displayIndex, child.displayObject)
		elseif self._childrenRenderOrder == ChildrenRenderOrder.Descent then
			for i=cnt,index+1,-1 do
				local g = self._children[i]
				if g.displayObject and g.displayObject.parent==ct then
					displayIndex = displayIndex + 1
				end
			end
			ct:insert(displayIndex, child.displayObject)
		else
			self:delayedCall(self.buildNativeDisplayList, self)
		end
	end

	self:setBoundsChangedFlag()

	return index
end

function GComponent:swapChildren(child1, child2)
	local index1 = self:getChildIndex(child1)
	local index2 = self:getChildIndex(child2)
	assert(index1 ~= -1 and index2 ~= -1, "Not a child of this container")
	self:swapChildrenAt(index1, index2)
end

function GComponent:swapChildrenAt(index1, index2)
	local child1 = self._children[index1+1]
	local child2 = self._children[index2+1]

	self:setChildIndex(child1, index2)
	self:setChildIndex(child2, index1)
end

function getters:numChildren()
	return #self._children
end

function GComponent:isAncestorOf(obj)
	if not obj then return false end

	local p = obj.parent
	while p ~= nil do
		if p == self then return true end
		p = p.parent
	end
	return false
end

function GComponent:addController(controller)
	table.insert(self._controllers, controller)
	controller.parent = self
	self:applyController(controller)
end

function GComponent:getControllerAt(index)
	return self._controllers[index+1]
end

function GComponent:getController(name)
	local cnt = #self._controllers
	for i=1,cnt do
		local c = self._controllers[i]
		if c.name == name then return c end
	end
end

function GComponent:getControllerIndex(c)
	local cnt = #self._controllers
	for i=1,cnt do	
		if self._controllers[i] == c then
			return i-1
		end
	end

	return -1
end

function GComponent:removeController(c)
	local index = self:getControllerIndex(c)
	assert(index>=0, "controller not exists: "..c.name)

	c.parent = nil
	table.remove(self._controllers, index+1)

	local cnt = #self._children
	for i=1,cnt do
		local child = self._children[i]
		child:handleControllerChanged(c)
	end
end

function GComponent:getTransitionAt(index)
	return self._transitions[index]
end

function GComponent:getTransition(name)
	local cnt = #self._transitions
	for i=1,cnt do
		local trans = self._transitions[i]
		if trans.name == name then return trans end
	end
end

function GComponent:childStateChanged(child)
	if self._buildingDisplayList then return end

	local cnt = #self._children

	if child.class==GGroup then
		for i=1,cnt do
			local g = self._children[i]
			if g.group == child then
				self:childStateChanged(g)
			end
		end
		return
	end

	if not child.displayObject then return end

	if child:internalVisible() then
		local ct = self._container
		if child.displayObject.parent ~= ct then
			if self._childrenRenderOrder == ChildrenRenderOrder.Ascent then
				local index = 1
				for i = 1,cnt do
					local g = self._children[i]
					if g == child then
						break
					end

					if g.displayObject and g.displayObject.parent==ct then
						index = index+1
					end
				end
				ct:insert(index, child.displayObject)
			elseif self._childrenRenderOrder == ChildrenRenderOrder.Descent then
				local index = 1
				for i=cnt,1,-1 do
					local g = self._children[i]
					if g == child then
						break
					end

					if g.displayObject and g.displayObject.parent==ct then
						index = index+1
					end
				end
				ct:insert(index, child.displayObject)
			else
				ct:insert(child.displayObject)
				self:delayedCall(self.buildNativeDisplayList, self)
			end
		end
	else
		if child.displayObject.parent ~= GRoot._hidden_root then
			GRoot._hidden_root:insert(child.displayObject)

			if self._childrenRenderOrder == ChildrenRenderOrder.Arch then
				self:delayedCall(self.buildNativeDisplayList, self)
			end
		end
	end
end

function GComponent:buildNativeDisplayList()
	local cnt = #self._children
	if cnt == 0 then return end

	local ct = self._container

	if self._childrenRenderOrder==ChildrenRenderOrder.Ascent then			
		for i=1,cnt do		
			local child = self._children[i]
			if child.displayObject and child:internalVisible() then
				ct:insert(child.displayObject)
			end
		end
	elseif self._childrenRenderOrder==ChildrenRenderOrder.Descent then
		for i=cnt,1,-1 do		
			local child = self._children[i]
			if child.displayObject and child:internalVisible() then
				ct:insert(child.displayObject)
			end
		end
	elseif self._childrenRenderOrder==ChildrenRenderOrder.Arch then
		for i=1,_apexIndex do		
			local child = self._children[i]
			if child.displayObject and child:internalVisible() then
				ct:insert(child.displayObject)
			end
		end
		for i=cnt, _apexIndex+1,-1 do		
			local child = self._children[i]
			if child.displayObject and child:internalVisible() then
				ct:insert(child.displayObject)
			end
		end
	end
end

function GComponent:applyController(c)
	self._applyingController = c
	local cnt = #self._children
	for i=1,cnt do	
		local child = self._children[i]
		child:handleControllerChanged(c)
	end
	self._applyingController = nil

	c:runActions()
end

function GComponent:applyAllControllers()
	local cnt = #self._controllers
	for i=1,cnt do	
		local controller = self._controllers[i]
		self:applyController(controller)
	end
end

function GComponent:adjustRadioGroupDepth(obj, c)
	local cnt = #self._children
	local i
	local child
	local myIndex = -1
	local maxIndex = -1
	for i=1,cnt do	
		child = self._children[i]
		if child == obj then		
			myIndex = i-1
		elseif child.class==GButton and child.relatedController == c then		
			if i-1 > maxIndex then
				maxIndex = i-1
			end
		end
	end
	if myIndex < maxIndex then	
		if self._applyingController~=nil then
			self._children[maxIndex+1]:handleControllerChanged(self._applyingController)
		end
		self:swapChildrenAt(myIndex, maxIndex)
	end
end

function getters:baseUserData()
	local buffer = self.packageItem.rawData
	buffer:seek(0, 4)
	return buffer:readS()
end

function GComponent:isChildInView(child)
	if self.scrollPane~=nil then	
		return self.scrollPane:isChildInView(child)
	elseif self._maskContainer then
		return child.x + child.width >= 0 and child.x <= self._width
			and child.y + child.height >= 0 and child.y <= self._height
	else
		return true
	end
end

function GComponent:getFirstChildInView()
	local cnt = #self._children
	for i=1,cnt do	
		local child = self._children[i]
		if self:isChildInView(child) then return i-1 end
	end
	return -1
end

function GComponent:setupScroll(buffer)
	self.scrollPane = ScrollPane.new(self)
	self.scrollPane:setup(buffer)
end

function GComponent:setupOverflow(overflow)
	if overflow == OverflowType.Hidden then
		self._maskContainer = display.newContainer(0,0,10,10)
		self._maskContainer.anchorX = 0
		self._maskContainer.anchorY = 0
		self._maskContainer.anchorChildren = false
		self._maskContainer.x = -self._pivotX*self._width + self._margin.left
		self._maskContainer.y = -self._pivotX*self._width + self._margin.top
		self._maskContainer.width = self._width - (self._margin.left + self._margin.right)
		self._maskContainer.height = self._height - (self._margin.top + self._margin.bottom)
		self.displayObject:insert(self._maskContainer)

		self._container.x = 0
		self._container.y = 0
		self._maskContainer:insert(self._container)
	elseif self._margin.left ~= 0 or self._margin.top ~= 0 then
		self._container.x = -self._pivotX*self._width + self._margin.left
		self._container.y = -self._pivotX*self._width + self._margin.top
	end
end

function GComponent:updateInnerPos()
	local px = -self._pivotX*self._width
	local py = -self._pivotY*self._height
	
	if self._maskContainer then
		self._maskContainer.x = px + self._margin.left + (self._alignOffsetX or 0)
		self._maskContainer.y = py + self._margin.top + (self._alignOffsetY or 0)
	else
		self._container.x = px + self._margin.left + (self._alignOffsetX or 0)
		self._container.y = py + self._margin.top + (self._alignOffsetY or 0)
	end

	if self._background then
		self._background.x = px
		self._background.y = py
	end
end

function GComponent:handleSizeChanged()
	if self._pivotX~=0 or self._pivotY~=0 then
		self:updateInnerPos()
	end

	if self._background~=nil then
		self._background.width = self._width
		self._background.height = self._height
	end

	if self.scrollPane~=nil then
		self.scrollPane:onOwnerSizeChanged()
	elseif self._maskContainer then
		self._maskContainer.width = self._width - (self._margin.left + self._margin.right)
		self._maskContainer.height = self._height - (self._margin.top + self._margin.bottom)
	end
end

function GComponent:handlePivotChanged()
	if self.scrollPane ~= nil then
		self.scrollPane:adjustMaskContainer()
	else
		self:updateInnerPos()
	end

	GComponent.super.handlePivotChanged(self)
end

function GComponent:handleGrayedChanged()
	local cc = self:getController("grayed")
	if cc~=nil then
		cc.selectedIndex = self._grayed and 1 or 0
	else
		for i=1,#self._children do
			self._children[i].grayed = self._grayed
		end
	end
end

function GComponent:handleControllerChanged(c)
	GComponent.super.handleControllerChanged(self, c)

	if self.scrollPane~=nil then
		self.scrollPane:handleControllerChanged(c)
	end
end

function GComponent:setBoundsChangedFlag()
	if self.scrollPane==nil and not self._trackBounds then return end

	self._boundsChanged = true
	self:delayedCall(self._ensureBoundsCorrect, self)
end

function GComponent:_ensureBoundsCorrect()
	if self._boundsChanged then self:ensureBoundsCorrect() end
end

function GComponent:ensureBoundsCorrect()
	local cnt = #self._children
	for i=1,cnt do
		self._children[i]:ensureSizeCorrect()
	end

	if self._boundsChanged then 
		self:updateBounds()
	end
end

function GComponent:updateBounds()
	local ax, ay, aw, ah
	if #self._children>0 then	
		ax = 2^32
		ay = 2^32
		local ar = -2^32
		local ab = -2^32
		local tmp

		local cnt = #self._children
		for i=1,cnt do		
			local child = self._children[i]
			tmp = child.x
			if tmp < ax then ax = tmp end
			tmp = child.y
			if tmp < ay then ay = tmp end
			tmp = child.x + child.width
			if tmp > ar then ar = tmp end
			tmp = child.y + child.height
			if tmp > ab then ab = tmp end
		end
		aw = ar - ax
		ah = ab - ay
	else	
		ax = 0
		ay = 0
		aw = 0
		ah = 0
	end

	self:setBounds(ax, ay, aw, ah)
end

function GComponent:setBounds(ax, ay, aw, ah)
	self._boundsChanged = false
	if self.scrollPane~=nil then
		self.scrollPane:setContentSize(math.round(ax + aw), math.round(ay + ah))
	end
end

function getters:viewWidth()
	if self.scrollPane~=nil then
		return self.scrollPane.viewWidth
	else
		return self.width - self._margin.left - self._margin.right
	end
end

function setters:viewWidth(value)
	if self.scrollPane~=nil then
		self.scrollPane.viewWidth = value
	else
		self.width = value + self._margin.left + self._margin.right
	end
end

function getters:viewHeight()
	if self.scrollPane~=nil then
		return self.scrollPane.viewHeight
	else
		return self.height - self._margin.top - self._margin.bottom
	end
end

function setters:viewHeight(value)
	if self.scrollPane~=nil then
		self.scrollPane.viewHeight = value
	else
		self.height = value + self._margin.top + self._margin.bottom
	end
end

function GComponent:getSnappingPosition(xValue, yValue)
	local cnt = #self._children
	if cnt == 0 then 
		return xValue, yValue
	end

	self:ensureBoundsCorrect()

	local obj
	local i=1
	if yValue~=0 then	
		for i=1,cnt do		
			obj = self._children[i]
			if yValue < obj.y then			
				if i == 1 then				
					yValue = 0
				else
					local prev = self._children[i - 1]
					if yValue < prev.y + prev.height / 2 then --top half part
						yValue = prev.y
					else --bottom half part
						yValue = obj.y
					end
				end
				break
			end
		end

		if i>cnt then
			yValue = obj.y
		end
	end

	if xValue~=0 then	
		if i > 1 then i=i-1 end
		for i=1,cnt do		
			obj = self._children[i]
			if xValue < obj.x then			
				if i == 1 then				
					xValue = 0
				else
					local prev = self._children[i - 1]
					if xValue < prev.x + prev.width / 2 then --top half part
						xValue = prev.x
					else --bottom half part
						xValue = obj.x
					end
				end
				break
			end
		end
		if i>cnt then
			xValue = obj.x
		end
	end

	return xValue, yValue
end

function GComponent:childSortingOrderChanged(child, oldValue, newValue)
	if newValue == 0 then
		self._sortingChildCount = self._sortingChildCount-1
		self:setChildIndex(child, #_children)
	else	
		if oldValue == 0 then
			self._sortingChildCount = self._sortingChildCount+1
		end

		local oldIndex = self:getChildIndex(child)
		local index = self:getInsertPosForSortingChild(child)
		if oldIndex < index then
			self:_setChildIndex(child, oldIndex, index - 1)
		else
			self:_setChildIndex(child, oldIndex, index)
		end
	end
end

function GComponent:constructFromResource(objectPool, poolIndex)
	if not self.packageItem.translated then	
		self.packageItem.translated = true
		--TranslationHelper.TranslateComponent(packageItem)
	end

	local buffer = self.packageItem.rawData
	buffer:seek(0, 0)

	self._underConstruct = true

	self.sourceWidth = buffer:readInt()
	self.sourceHeight = buffer:readInt()
	self.initWidth = self.sourceWidth
	self.initHeight = self.sourceHeight

	self:setSize(self.sourceWidth, self.sourceHeight)

	if buffer:readBool() then
		self.minWidth = buffer:readInt()
		self.maxWidth = buffer:readInt()
		self.minHeight = buffer:readInt()
		self.maxHeight = buffer:readInt()
	end

	if buffer:readBool() then	
		local f1 = buffer:readFloat()
		local f2 = buffer:readFloat()
		self:setPivot(f1, f2, buffer:readBool())
	end

	if buffer:readBool() then
		self._margin.top = buffer:readInt()
		self._margin.bottom = buffer:readInt()
		self._margin.left = buffer:readInt()
		self._margin.right = buffer:readInt()
	end

	local overflow = buffer:readByte()
	if overflow == OverflowType.Scroll then	
		local savedPos = buffer.pos
		buffer:seek(0, 7)
		self:setupScroll(buffer)
		buffer.pos = savedPos
	else
		self:setupOverflow(overflow)
	end

	if buffer:readBool() then	
		local i1 = buffer:readInt()
		local i2 = buffer:readInt()
		--this.clipSoftness = new Vector2(i1, i2)
	end

	self._buildingDisplayList = true

	buffer:seek(0, 1)

	local controllerCount = buffer:readShort()
	for i=1,controllerCount do	
		local nextPos = buffer:readShort()
		nextPos = nextPos + buffer.pos

		local controller = Controller:new()
		table.insert(self._controllers, controller)
		controller.parent = self
		controller:setup(buffer)

		buffer.pos = nextPos
	end

	buffer:seek(0, 4)
	buffer:skip(3)
	local maskIndex = buffer:readShort()

	buffer:seek(0, 2)

	local child
	local childCount = buffer:readShort()
	for i=0,childCount-1 do	
		local dataLen = buffer:readShort()
		local curPos = buffer.pos

		if objectPool~=nil then
			child = objectPool[poolIndex + i]
		else
			buffer:seek(curPos, 0)

			local objectType = buffer:readByte()
			local src = buffer:readS()
			local pkgId = buffer:readS()
			local pi
			if src~=nil then			
				local pkg
				if pkgId~=nil then
					pkg = UIPackage.get(pkgId)
				else
					pkg = self.packageItem.owner
				end

				if pkg~=nil then
					pi = pkg:getItem(src)
				end
			end
			if pi~=nil then
				if i==maskIndex then
					pi.is_mask = true
				end
				child = UIObjectFactory.newObject(pi)
				child.packageItem = pi
				child:constructFromResource()
			else
				child = UIObjectFactory.newObject2(objectType)
			end
		end

		child._underConstruct = true
		child:setup_BeforeAdd(buffer, curPos)
		child.parent = self
		table.insert(self._children, child)

		buffer.pos = curPos + dataLen
	end

	buffer:seek(0, 3)
	self._relations:setup(buffer, true)

	buffer:seek(0, 2)
	buffer:skip(2)

	for i=1,childCount do	
		local nextPos = buffer:readShort()
		nextPos = nextPos + buffer.pos

		buffer:seek(buffer.pos, 3)
		self._children[i]._relations:setup(buffer, false)

		buffer.pos = nextPos
	end

	buffer:seek(0, 2)
	buffer:skip(2)

	for i=1,childCount do
		local nextPos = buffer:readShort()
		nextPos = nextPos + buffer.pos

		child = self._children[i]
		child:setup_AfterAdd(buffer, buffer.pos)
		child._underConstruct = nil

		buffer.pos = nextPos
	end

	buffer:seek(0, 4)

	buffer:skip(2)  --customData
	self.opaque = buffer:readBool()
	buffer:skip(2) --maskIndex
	if maskIndex~=-1 then
		local maskChild = self:getChildAt(maskIndex)
		self._container:setMask(maskChild._isMask)
		maskChild:handlePositionChanged()
		maskChild:handleSizeChanged()
		if buffer:readBool() then
			--self.container.reversedMask = true
		end
	end
	local hitTestId = buffer:readS()
	if hitTestId~=nil then	
		local pi = self.packageItem.owner:getItem(hitTestId)
		if pi and pi.pixelHitTestData then		
			local i1 = buffer:readInt()
			local i2 = buffer:readInt()
			self.pixelHitTest = PixelHitTest.new(pi.pixelHitTestData, i1, i2, self.sourceWidth, self.sourceHeight)
		end
	end

	buffer:seek(0, 5)

	local transitionCount = buffer:readShort()
	for i=1,transitionCount do	
		local nextPos = buffer:readShort()
		nextPos = nextPos + buffer.pos

		local trans = Transition.new(self)
		trans:setup(buffer)
		table.insert(self._transitions, trans)

		buffer.pos = nextPos
	end

	if transitionCount > 0 then
		self:on("addedToStage", self._addedToStage, self)
		self:on("removedFromStage", self._removedFromStage, self)
	end

	self:applyAllControllers()

	self._buildingDisplayList = nil
	self._underConstruct = nil

	self:buildNativeDisplayList()
	self:setBoundsChangedFlag()

	if self.packageItem.objectType ~= ObjectType.Component then
		self:constructExtension(buffer)
	end

	self:onConstruct()
end

function GComponent:constructExtension(buffer)
end

function GComponent:onConstruct()
end

function GComponent:setup_AfterAdd(buffer, beginPos)
	GComponent.super.setup_AfterAdd(self, buffer, beginPos)

	buffer:seek(beginPos, 4)

	local pageController = buffer:readShort()
	if pageController~=-1 and self.scrollPane~=nil and self.scrollPane._pageMode then
		self.scrollPane._pageController = self.parent:getControllerAt(pageController)
	end

	local cnt = buffer:readShort()
	for i=1,cnt do	
		local cc = self:getController(buffer:readS())
		local pageId = buffer:readS()
		if cc~=nil then
			cc.selectedPageId = pageId
		end
	end
end

function GComponent:_addedToStage()
	local cnt = #self._transitions
	for i=1,cnt do
		self._transitions[i]:onOwnerAddedToStage();
	end
end

function GComponent:_removedFromStage()
	local cnt = #self._transitions
	for i=1,cnt do
		self._transitions[i]:onOwnerRemovedFromStage();
	end
end