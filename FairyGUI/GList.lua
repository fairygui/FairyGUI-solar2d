local GObjectPool = require('GObjectPool')

GList = class('GList', GComponent)

local getters = GList.getters
local setters = GList.setters

function GList:ctor()
	GList.super.ctor(self)

	self._itemWidth = 0
	self._itemHeight = 0
	self._trackBounds = true
	self.opaque = true
	self.scrollItemToViewOnClick = true

	self._pool = GObjectPool.new()
end

function GList:dispose()
	self._pool:clear()

	self._selectionController = nil
	self.scrollItemToViewOnClick = false
	self.itemRenderer = nil
	self.itemProvider = nil

	GList.super.dispose(self)
end

function getters:layout()
	return self._layout
end

function setters:layout(value)
	if self._layout ~= value then
		self._layout = value
		self:setBoundsChangedFlag()
		if self._virtual then
			self:setVirtualListChangedFlag(true)
		end
	end
end

function getters:lineCount()
	return self._lineCount
end

function setters:lineCount(value)
	if self._lineCount ~= value then
		self._lineCount = value
		if self._layout == ListLayoutType.FlowVertical or self._layout == ListLayoutType.Pagination then
			self:setBoundsChangedFlag()
			if self._virtual then
				self:setVirtualListChangedFlag(true)
			end
		end
	end
end

function getters:columnCount()
	return self._columnCount
end

function setters:columnCount(value)
	if self._columnCount ~= value then
		self._columnCount = value
		if self._layout == ListLayoutType.FlowHorizontal or self._layout == ListLayoutType.Pagination then
			self:setBoundsChangedFlag()
			if self._virtual then
				self:setVirtualListChangedFlag(true)
			end
		end
	end
end

function getters:lineGap()
	return self._lineGap
end

function setters:lineGap(value)
	if self._lineGap ~= value then
		self._lineGap = value
		self:setBoundsChangedFlag()
		if self._virtual then
			self:setVirtualListChangedFlag(true)
		end
	end
end

function getters:columnGap()
	return self._columnGap
end

function setters:columnGap(value)
	if self._columnGap ~= value then
		self._columnGap = value
		self:setBoundsChangedFlag()
		if self._virtual then
			self:setVirtualListChangedFlag(true)
		end
	end
end

function getters:align()
	return self._align
end

function setters:align(value)
	if self._align ~= value then
		self._align = value
		self:setBoundsChangedFlag()
		if self._virtual then
			self:setVirtualListChangedFlag(true)
		end
	end
end

function getters:verticalAlign()
	return self._verticalAlign
end

function setters:verticalAlign(value)
	if self._verticalAlign ~= value then
		self._verticalAlign = value
		self:setBoundsChangedFlag()
		if self._virtual then
			self:setVirtualListChangedFlag(true)
		end
	end
end

function getters:autoResizeItem()
	return self._autoResizeItem
end

function setters:autoResizeItem(value)
	if self._autoResizeItem ~= value then
		self._autoResizeItem = value
		self:setBoundsChangedFlag()
		if self._virtual then
			self:setVirtualListChangedFlag(true)
		end
	end
end

function getters:itemPool()
	return self._pool
end

function GList:getFromPool(url)
	if not url or #url==0 then
		url = self.defaultItem
	end

	local ret = self._pool:getObject(url)
	if ret ~= nil then
		ret.visible = true
	end
	return ret
end

function GList:returnToPool(obj)
	self._pool:returnObject(obj)
end

function GList:addItemFromPool(url)
	local obj = self:getFromPool(url)

	return self:addChild(obj)
end

function GList:addChildAt(child, index)
	GList.super.addChildAt(self, child, index)
	if typeof(child, GButton) then
		child.selected = false
		child.changeStateOnClick = false
	end

	child:on("tap", self._clickItem, self)
	return child
end

function GList:removeChildAt1(index, dispose)
	local child = GList.super.removeChildAt(self, index, dispose)
	child:off("tap", self._clickItem, self)

	return child
end

function GList:removeChildToPoolAt(index)
	local child = self:removeChildAt(index)
	self:returnToPool(child)
end

function GList:removeChildToPool(child)
	self:removeChild(child)
	self:returnToPool(child)
end

function GList:removeChildrenToPool(beginIndex, endIndex)
	beginIndex = beginIndex or 0
	endIndex = endIndex or -1
	if endIndex < 0 or endIndex >= #self._children then
		endIndex = #self._children - 1
	end

	do
		local i = beginIndex
		while i <= endIndex do
			self:removeChildToPoolAt(beginIndex)
			i = i + 1
		end
	end
end

function getters:selectedIndex()
	if self._virtual then
		local cnt = self._realNumItems
		do
			local i = 0
			while i < cnt do
				local ii = self._virtualItems[i+1]
				if (typeof(ii.obj, GButton) and ii.obj.selected) or (ii.obj == nil and ii.selected) then
					if self._loop then
						return i%self._numItems
					else
						return i
					end
				end
				i = i + 1
			end
		end
	else
		local cnt = #self._children
		do
			local i = 0
			while i < cnt do
				local obj = typeof(self:getChildAt(i), GButton)
				if obj ~= nil and obj.selected then
					return i
				end
				i = i + 1
			end
		end
	end
	return -1
end

function setters:selectedIndex(value)
	if value >= 0 and value < self.numItems then
		if self.selectionMode ~= ListSelectionMode.Single then
			self:clearSelection()
		end
		self:addSelection(value, false)
	else
		self:clearSelection()
	end
end

function getters:selectionController()
	return self._selectionController
end

function setters:selectionController(value)
	self._selectionController = value
end

function GList:getSelection()
	local ret = {}
	if self._virtual then
		local ret2 = {}
		local cnt = self._realNumItems
		do
			local i = 0
			while i < cnt do
				local ii = self._virtualItems[i+1]
				if (typeof(ii.obj, GButton) and ii.obj.selected) or (ii.obj == nil and ii.selected) then
					local j = i
					if self._loop then
						j = i%self._numItems
					end
					ret2[j] = true
				end
				i = i + 1
			end
		end

		for k,_ in pairs(ret2) do
			table.insert(ret, k)
		end

		table.sort(ret)
	else
		local cnt = #self._children
		do
			local i = 0
			while i < cnt do
				local obj = typeof(self:getChildAt(i), GButton)
				if obj ~= nil and obj.selected then
					table.insert(ret, i)
				end
				i = i + 1
			end
		end
	end
	return ret
end

function GList:addSelection(index, scrollItToView)
	if self.selectionMode == ListSelectionMode.None then
		return
	end

	self:checkVirtualList()

	if self.selectionMode == ListSelectionMode.Single then
		self:clearSelection()
	end

	if scrollItToView then
		self:scrollToView(index)
	end

	self._lastSelectedIndex = index
	local obj = nil
	if self._virtual then
		local ii = self._virtualItems[index+1]
		if ii.obj ~= nil then
			obj = typeof(ii.obj, GButton)
		end
		ii.selected = true
	else
		obj = typeof(self:getChildAt(index), GButton)
	end

	if obj ~= nil and not obj.selected then
		obj.selected = true
		self:updateSelectionController(index)
	end
end

function GList:removeSelection(index)
	if self.selectionMode == ListSelectionMode.None then
		return
	end

	local obj = nil
	if self._virtual then
		local ii = self._virtualItems[index+1]
		if ii.obj ~= nil then
			obj = typeof(ii.obj, GButton)
		end
		ii.selected = false
	else
		obj = typeof(self:getChildAt(index), GButton)
	end

	if obj ~= nil then
		obj.selected = false
	end
end

function GList:clearSelection()
	if self._virtual then
		local cnt = self._realNumItems
		do
			local i = 0
			while i < cnt do
				local ii = self._virtualItems[i+1]
				if typeof(ii.obj, GButton) then
					ii.obj.selected = false
				end
				ii.selected = false
				i = i + 1
			end
		end
	else
		local cnt = #self._children
		do
			local i = 0
			while i < cnt do
				local obj = typeof(self:getChildAt(i),GButton)
				if obj ~= nil then
					obj.selected = (false)
				end
				i = i + 1
			end
		end
	end
end

function GList:clearSelectionExcept(g)
	if self._virtual then
		local cnt = self._realNumItems
		do
			local i = 0
			while i < cnt do
				local ii = self._virtualItems[i+1]
				if ii.obj ~= g then
					if typeof(ii.obj, GButton) then
						ii.obj.selected = false
					end
					ii.selected = false
				end
				i = i + 1
			end
		end
	else
		local cnt = #self._children
		do
			local i = 0
			while i < cnt do
				local obj = typeof(self:getChildAt(i), GButton)
				if obj ~= nil and obj ~= g then
					obj.selected = false
				end
				i = i + 1
			end
		end
	end
end

function GList:selectAll()
	self:checkVirtualList()

	local last = - 1
	if self._virtual then
		local cnt = self._realNumItems
		do
			local i = 0
			while i < cnt do
				local ii = self._virtualItems[i+1]
				if typeof(ii.obj, GButton) and not ii.obj.selected then
					ii.obj.selected = true
					last = i
				end
				ii.selected = true
				i = i + 1
			end
		end
	else
		local cnt = #self._children
		do
			local i = 0
			while i < cnt do
				local obj = typeof(self:getChildAt(i), GButton)
				if obj ~= nil and not obj.selected then
					obj.selected = true
					last = i
				end
				i = i + 1
			end
		end
	end

	if last ~= - 1 then
		self:updateSelectionController(last)
	end
end

function GList:selectNone()
	self:clearSelection()
end

function GList:selectReverse()
	self:checkVirtualList()

	local last = - 1
	if self._virtual then
		local cnt = self._realNumItems
		for i=1,cnt do
			local ii = self._virtualItems[i]
			if typeof(ii.obj, GButton) then
				ii.obj.selected = not ii.obj.selected
				if ii.obj.selected then
					last = i-1
				end
			end
			ii.selected = not ii.selected
		end
	else
		local cnt = #self._children
		for i=0,cnt-1 do
			local obj = typeof(self:getChildAt(i), GButton)
			if obj ~= nil then
				obj.selected = not obj.selected
				if obj.selected then
					last = i
				end
			end
		end
	end

	if last ~= - 1 then
		self:updateSelectionController(last)
	end
end
-- <summary>
-- 
-- </summary>
function GList:handleArrowKey(dir)
	local index = self.selectedIndex
	if index == - 1 then
		return
	end

	if dir == 1 then
		if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.FlowVertical then
			index = index - 1
			if index >= 0 then
				self:clearSelection()
				self:addSelection(index, true)
			end
		elseif self._layout == ListLayoutType.FlowHorizontal or self._layout == ListLayoutType.Pagination then
			local current = self:getChildAt(index)
			local k = 0
			local i
			i = index - 1
			while i >= 0 do
				local obj = self:getChildAt(i)
				if obj.y ~= current.y then
					current = obj
					break
				end
				k = k + 1
				i = i - 1
			end
			while i >= 0 do
				local obj = self:getChildAt(i)
				if obj.y ~= current.y then
					self:clearSelection()
					self:addSelection(i + k + 1, true)
					break
				end
				i = i - 1
			end
		end
	elseif dir == 3 then
		if self._layout == ListLayoutType.SingleRow or self._layout == ListLayoutType.FlowHorizontal or self._layout == ListLayoutType.Pagination then
			index = index + 1
			if index < #self._children then
				self:clearSelection()
				self:addSelection(index, true)
			end
		elseif self._layout == ListLayoutType.FlowVertical then
			local current = self:getChildAt(index)
			local k = 0
			local cnt = #self._children
			local i
			i = index + 1
			while i < cnt do
				local obj = self:getChildAt(i)
				if obj.x ~= current.x then
					current = obj
					break
				end
				k = k + 1
				i = i + 1
			end
			while i < cnt do
				local obj = self:getChildAt(i)
				if obj.x ~= current.x then
					self:clearSelection()
					self:addSelection(i - k - 1, true)
					break
				end
				i = i + 1
			end
		end
	elseif dir == 5 then
		if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.FlowVertical then
			index = index + 1
			if index < #self._children then
				self:clearSelection()
				self:addSelection(index, true)
			end
		elseif self._layout == ListLayoutType.FlowHorizontal or self._layout == ListLayoutType.Pagination then
			local current = self:getChildAt(index)
			local k = 0
			local cnt = #self._children
			local i
			i = index + 1
			while i < cnt do
				local obj = self:getChildAt(i)
				if obj.y ~= current.y then
					current = obj
					break
				end
				k = k + 1
				i = i + 1
			end
			while i < cnt do
				local obj = self:getChildAt(i)
				if obj.y ~= current.y then
					self:clearSelection()
					self:addSelection(i - k - 1, true)
					break
				end
				i = i + 1
			end
		end
	elseif dir == 7 then
		if self._layout == ListLayoutType.SingleRow or self._layout == ListLayoutType.FlowHorizontal or self._layout == ListLayoutType.Pagination then
			index = index - 1
			if index >= 0 then
				self:clearSelection()
				self:addSelection(index, true)
			end
		elseif self._layout == ListLayoutType.FlowVertical then
			local current = self:getChildAt(index)
			local k = 0
			local i
			i = index - 1
			while i >= 0 do
				local obj = self:getChildAt(i)
				if obj.x ~= current.x then
					current = obj
					break
				end
				k = k + 1
				i = i - 1
			end
			while i >= 0 do
				local obj = self:getChildAt(i)
				if obj.x ~= current.x then
					self:clearSelection()
					self:addSelection(i + k + 1, true)
					break
				end
				i = i - 1
			end
		end
	end
end

function GList:_clickItem(context)
	local item = context.sender
	if typeof(item, GButton) and self.selectionMode ~= ListSelectionMode.None then
		self:setSelectionOnEvent(item, context)
	end

	if self.scrollPane ~= nil and self.scrollItemToViewOnClick then
		self.scrollPane:scrollToView(item, true)
	end

	self:emit("clickItem", item)
end

function GList:setSelectionOnEvent(button, evt)
	local dontChangeLastIndex = false
	local index = self:childIndexToItemIndex(self:getChildIndex(button))

	if self.selectionMode == ListSelectionMode.Single then
		if not button.selected then
			self:clearSelectionExcept(button)
			button.selected = true
		end
	else
		if evt.shiftKey then
			if not button.selected then
				if self._lastSelectedIndex ~= - 1 then
					local min = math.min(self._lastSelectedIndex, index)
					local max = math.max(self._lastSelectedIndex, index)
					max = math.min(max, self.numItems - 1)
					if self._virtual then
						do
							local i = min
							while i <= max do
								local ii = self._virtualItems[i+1]
								if typeof(ii.obj, GButton) then
									ii.obj.selected = (true)
								end
								ii.selected = true
								i = i + 1
							end
						end
					else
						do
							local i = min
							while i <= max do
								local obj = typeof(self:getChildAt(i), GButton)
								if obj ~= nil and not obj.selected then
									obj.selected = true
								end
								i = i + 1
							end
						end
					end

					dontChangeLastIndex = true
				else
					button.selected = true
				end
			end
		elseif evt.ctrlKey or self.selectionMode == ListSelectionMode.Multiple_SingleClick then
			button.selected = not button.selected
		else
			if not button.selected then
				self:clearSelectionExcept(button)
				button.selected = true
			else
				self:clearSelectionExcept(button)
			end
		end
	end

	if not dontChangeLastIndex then
		self._lastSelectedIndex = index
	end

	if button.selected then
		self:updateSelectionController(index)
	end
end

function GList:resizeToFit(itemCount, minSize)
	self:ensureBoundsCorrect()

	minSize = minSize or 0

	local curCount = self.numItems
	if itemCount > curCount then
		itemCount = curCount
	end

	if self._virtual then
		local lineCount = math.ceil(itemCount / self._curLineItemCount)
		if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.FlowHorizontal then
			self.viewHeight = (lineCount * self._itemHeight + math.max(0, lineCount - 1) * self._lineGap)
		else
			self.viewWidth = (lineCount * self._itemWidth + math.max(0, lineCount - 1) * self._columnGap)
		end
	elseif itemCount == 0 then
		if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.FlowHorizontal then
			self.viewHeight = (minSize)
		else
			self.viewWidth = (minSize)
		end
	else
		local i = itemCount - 1
		local obj = nil
		while i >= 0 do
			obj = self:getChildAt(i)
			if not self.foldInvisibleItems or obj.visible then
				break
			end
			i = i - 1
		end
		if i < 0 then
			if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.FlowHorizontal then
				self.viewHeight = minSize
			else
				self.viewWidth = minSize
			end
		else
			local size
			if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.FlowHorizontal then
				size = obj.y + obj.height
				if size < minSize then
					size = minSize
				end
				self.viewHeight = size
			else
				size = obj.x + obj.width
				if size < minSize then
					size = minSize
				end
				self.viewWidth = size
			end
		end
	end
end

function GList:handleSizeChanged()
	GList.super.handleSizeChanged(self)

	self:setBoundsChangedFlag()
	if self._virtual then
		self:setVirtualListChangedFlag(true)
	end
end

function GList:handleControllerChanged(c)
	GList.super.handleControllerChanged(self, c)

	if self._selectionController == c then
		self.selectedIndex = c.selectedIndex
	end
end

function GList:updateSelectionController(index)
	if self._selectionController ~= nil and not self._selectionController.changing and index < self._selectionController.pageCount then
		local c = self._selectionController
		self._selectionController = nil
		c.selectedIndex = index
		self._selectionController = c
	end
end

-- <summary>
-- Scroll the list to make an item with certain index visible.
-- </summary>
-- <param name="ani">True to scroll smoothly, othewise immdediately.</param>
-- <param name="setFirst">If true, scroll to make the target on the top/left If false, scroll to make the target any position in view.</param>
function GList:scrollToView(index, ani, setFirst)
	if self._virtual then
		if self._numItems == 0 then
			return
		end

		self:checkVirtualList()

		assert(index < #self._virtualItems, "Invalid child index: " .. index .. ">" .. #self._virtualItems)

		if self._loop then
			index = math.floor(self._firstIndex / self._numItems) * self._numItems + index
		end

		local rect
		local ii = self._virtualItems[index+1]
		if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.FlowHorizontal then
			local pos = 0
			do
				local i = self._curLineItemCount - 1
				while i < index do
					pos = pos + (self._virtualItems[i+1].height + self._lineGap)
					i = i + self._curLineItemCount
				end
			end
			rect = {x=0, y=pos, width=self._itemWidth, height=ii.height}
		elseif self._layout == ListLayoutType.SingleRow or self._layout == ListLayoutType.FlowVertical then
			local pos = 0
			do
				local i = self._curLineItemCount - 1
				while i < index do
					pos = pos + (self._virtualItems[i+1].width + self._columnGap)
					i = i + self._curLineItemCount
				end
			end
			rect = {x=pos, y=0, width=ii.width, height=self._itemHeight}
		else
			local page = math.floor( index / (self._curLineItemCount * self._curLineItemCount2))
			rect = { x=page * self.viewWidth + (index % self._curLineItemCount) * (ii.width + self._columnGap), 
				y=(math.floor(index /self._curLineItemCount) % self._curLineItemCount2) * (ii.height + self._lineGap), 
				width=ii.width,
				height= ii.height}
		end

		setFirst = true
		--因为在可变item大小的情况下，只有设置在最顶端，位置才不会因为高度变化而改变，所以只能支持setFirst=true
		if self.scrollPane ~= nil then
			self.scrollPane:scrollToView(rect, ani, setFirst)
		elseif self.parent ~= nil and self.parent.scrollPane ~= nil then
			self.parent.scrollPane:scrollToView(self:transformRect(rect, self.parent), ani, setFirst)
		end
	else
		local obj = self:getChildAt(index)
		if self.scrollPane ~= nil then
			self.scrollPane:scrollToView(obj, ani, setFirst)
		elseif self.parent ~= nil and self.parent.scrollPane ~= nil then
			self.parent.scrollPane:scrollToView(obj, ani, setFirst)
		end
	end
end

function getters:touchItem()
	--find out which item is under finger
	--逐层往上知道查到点击了那个item
	local obj = self.root.touchTarget
	local p = obj.parent
	while p ~= nil do
		if p == self then
			return obj
		end

		obj = p
		p = p.parent
	end

	return nil
end

-- <summary>
-- Get first child in view.
-- </summary>
function GList:getFirstChildInView()
	return self:childIndexToItemIndex(GList.super.getFirstChildInView(self))
end

function GList:childIndexToItemIndex(index)
	if not self._virtual then
		return index
	end

	if self._layout == ListLayoutType.Pagination then
		do
			local i = self._firstIndex
			while i < self._realNumItems do
				if self._virtualItems[i+1].obj ~= nil then
					index = index - 1
					if index < 0 then
						return i
					end
				end
				i = i + 1
			end
		end

		return index
	else
		index = index + self._firstIndex
		if self._loop and self._numItems > 0 then
			index = index % self._numItems
		end

		return index
	end
end

function GList:itemIndexToChildIndex(index)
	if not self._virtual then
		return index
	end

	if self._layout == ListLayoutType.Pagination then
		return self:getChildIndex(self._virtualItems[index+1].obj)
	else
		if self._loop and self._numItems > 0 then
			local j = self._firstIndex % self._numItems
			if index >= j then
				index = index - j
			else
				index = self._numItems - j + index
			end
		else
			index = index - self._firstIndex
		end

		return index
	end
end

function getters:isVirtual()
	return self._virtual
end

function GList:setVirtualAndLoop()
	self:setVirtual(true)
end

function GList:setVirtual(loop)
	if not self._virtual then
		assert(self.scrollPane, "FairyGUI: Virtual list must be scrollable!")

		if loop then
			assert(self._layout~=2 and self._layout~=3, "FairyGUI: Loop list is not supported for FlowHorizontal or FlowVertical layout!")

			self.scrollPane.bouncebackEffect = false
		end

		self._virtual = true
		self._loop = loop
		self._virtualItems = {}
		self._firstIndex = 0
		self._itemInfoVer = 0
		self._realNumItems = 0
		self._virtualListChanged = 0
		self:removeChildrenToPool()

		if self._itemWidth == 0 or self._itemHeight == 0 then
			local obj = self:getFromPool()
			assert(obj, "FairyGUI: Virtual List must have a default list item resource.")
			self._itemWidth = math.ceil(obj.width)
			self._itemHeight = math.ceil(obj.height)
			self:returnToPool(obj)
		end

		if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.FlowHorizontal then
			self.scrollPane.scrollStep = self._itemHeight
			if self._loop then
				self.scrollPane._loop = 2
			end
		else
			self.scrollPane.scrollStep = self._itemWidth
			if self._loop then
				self.scrollPane._loop = 1
			end
		end

		self:on("scroll", self._onScroll, self)
		self:setVirtualListChangedFlag(true)
	end
end

function GList:_onScroll()
	self:handleScroll()
end

function getters:numItems()
	if self._virtual then
		return self._numItems
	else
		return #self._children
	end
end

function setters:numItems(value)
	if self._virtual then
		assert(self.itemRenderer, "FairyGUI: Set itemRenderer first!")

		self._numItems = value
		if self._loop then
			self._realNumItems = self._numItems * 6
		else
			self._realNumItems = self._numItems
		end

		--_virtualItems的设计是只增不减的
		local oldCount = #self._virtualItems
		if self._realNumItems > oldCount then
			do
				local i = oldCount
				while i < self._realNumItems do
					local ii = {}
					ii.width = self._itemWidth
					ii.height = self._itemHeight
					i = i + 1
					self._virtualItems[i] = ii
				end
			end
		else
			do
				local i = self._realNumItems
				while i < oldCount do
					i = i + 1
					self._virtualItems[i].selected = false
				end
			end
		end

		if self._virtualListChanged ~= 0 then
			self:cancelDelayedCall(self.refreshVirtualList, self)
		end
		--立即刷新
		self:refreshVirtualList()
	else
		local cnt = #self._children
		if value > cnt then
			do
				local i = cnt
				while i < value do
					if self.itemProvider == nil then
						self:addItemFromPool()
					else
						self:addItemFromPool(self.itemProvider(i))
					end
					i = i + 1
				end
			end
		else
			self:removeChildrenToPool(value, cnt)
		end

		if self.itemRenderer ~= nil then
			do
				local i = 0
				while i < value do
					self.itemRenderer(i, self:getChildAt(i))
					i = i + 1
				end
			end
		end
	end
end

function GList:refreshVirtualList()
	assert(self._virtual, "FairyGUI: not virtual list")

	self:setVirtualListChangedFlag(false)
end

function GList:checkVirtualList()
	if not self._virtual then return end

	if self._virtualListChanged ~= 0 then
		self:refreshVirtualList()
		self:cancelDelayCall(self.refreshVirtualList, self)
	end
end

function GList:setVirtualListChangedFlag(layoutChanged)
	if layoutChanged then
		self._virtualListChanged = 2
	elseif self._virtualListChanged == 0 then
		self._virtualListChanged = 1
	end

	self:delayedCall(self.refreshVirtualList, self)
end

function GList:refreshVirtualList()
	local layoutChanged = self._virtualListChanged == 2
	self._virtualListChanged = 0
	self._eventLocked = true

	if layoutChanged then
		if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.SingleRow then
			self._curLineItemCount = 1
		elseif self._layout == ListLayoutType.FlowHorizontal then
			if self._columnCount > 0 then
				self._curLineItemCount = self._columnCount
			else
				self._curLineItemCount = math.floor((self.scrollPane.viewWidth + self._columnGap) / (self._itemWidth + self._columnGap))
				if self._curLineItemCount <= 0 then
					self._curLineItemCount = 1
				end
			end
		elseif self._layout == ListLayoutType.FlowVertical then
			if self._lineCount > 0 then
				self._curLineItemCount = self._lineCount
			else
				self._curLineItemCount = math.floor((self.scrollPane.viewHeight + self._lineGap) / (self._itemHeight + self._lineGap))
				if self._curLineItemCount <= 0 then
					self._curLineItemCount = 1
				end
			end
		else
			if self._columnCount > 0 then
				self._curLineItemCount = self._columnCount
			else
				self._curLineItemCount = math.floor((self.scrollPane.viewWidth + self._columnGap) / (self._itemWidth + self._columnGap))
				if self._curLineItemCount <= 0 then
					self._curLineItemCount = 1
				end
			end

			if self._lineCount > 0 then
				self._curLineItemCount2 = self._lineCount
			else
				self._curLineItemCount2 = math.floor((self.scrollPane.viewHeight + self._lineGap) / (self._itemHeight + self._lineGap))
				if self._curLineItemCount2 <= 0 then
					self._curLineItemCount2 = 1
				end
			end
		end
	end

	local ch = 0 
	local cw = 0
	if self._realNumItems > 0 then
		local len = math.ceil(self._realNumItems / self._curLineItemCount) * self._curLineItemCount
		local len2 = math.min(self._curLineItemCount, self._realNumItems)
		if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.FlowHorizontal then
			do
				local i = 0
				while i < len do
					ch = ch + (self._virtualItems[i+1].height + self._lineGap)
					i = i + self._curLineItemCount
				end
			end
			if ch > 0 then
				ch = ch - self._lineGap
			end

			if self._autoResizeItem then
				cw = self.scrollPane.viewWidth
			else
				do
					local i = 0
					while i < len2 do
						cw = cw + (self._virtualItems[i+1].width + self._columnGap)
						i = i + 1
					end
				end
				if cw > 0 then
					cw = cw - self._columnGap
				end
			end
		elseif self._layout == ListLayoutType.SingleRow or self._layout == ListLayoutType.FlowVertical then
			do
				local i = 0
				while i < len do
					cw = cw + (self._virtualItems[i+1].width + self._columnGap)
					i = i + self._curLineItemCount
				end
			end
			if cw > 0 then
				cw = cw - self._columnGap
			end

			if self._autoResizeItem then
				ch = self.scrollPane.viewHeight
			else
				do
					local i = 0
					while i < len2 do
						ch = ch + (self._virtualItems[i+1].height + self._lineGap)
						i = i + 1
					end
				end
				if ch > 0 then
					ch = ch - self._lineGap
				end
			end
		else
			local pageCount = math.ceil(len / (self._curLineItemCount * self._curLineItemCount2))
			cw = pageCount * self.viewWidth
			ch = self.viewHeight
		end
	end

	self:handleAlign(cw, ch)
	self.scrollPane:setContentSize(cw, ch)

	self._eventLocked = false

	self:handleScroll(true)
end

function GList:getIndexOnPos1(pos, forceUpdate)
	if self._realNumItems < self._curLineItemCount then
		pos = 0
		return 0, pos
	end

	if self.numChildren > 0 and not forceUpdate then
		local pos2 = self:getChildAt(0).y
		if pos2 + (self._lineGap > 0 and 0 or - self._lineGap) > pos then
			do
				local i = self._firstIndex - self._curLineItemCount
				while i >= 0 do
					pos2 = pos2 - (self._virtualItems[i+1].height + self._lineGap)
					if pos2 <= pos then
						pos = pos2
						return i, pos
					end
					i = i - self._curLineItemCount
				end
			end

			pos = 0
			return 0, pos
		else
			local testGap = self._lineGap > 0 and self._lineGap or 0
			do
				local i = self._firstIndex
				while i < self._realNumItems do
					local pos3 = pos2 + self._virtualItems[i+1].height
					if pos3 + testGap > pos then
						pos = pos2
						return i, pos
					end
					pos2 = pos3 + self._lineGap
					i = i + self._curLineItemCount
				end
			end

			pos = pos2
			return self._realNumItems - self._curLineItemCount, pos
		end
	else
		local pos2 = 0
		local testGap = self._lineGap > 0 and self._lineGap or 0
		do
			local i = 0
			while i < self._realNumItems do
				local pos3 = pos2 + self._virtualItems[i+1].height
				if pos3 + testGap > pos then
					pos = pos2
					return i, pos
				end
				pos2 = pos3 + self._lineGap
				i = i + self._curLineItemCount
			end
		end

		pos = pos2
		return self._realNumItems - self._curLineItemCount, pos
	end
end

function GList:getIndexOnPos2(pos, forceUpdate)
	if self._realNumItems < self._curLineItemCount then
		pos = 0
		return 0, pos
	end

	if self.numChildren > 0 and not forceUpdate then
		local pos2 = self:getChildAt(0).x
		if pos2 + (self._columnGap > 0 and 0 or - self._columnGap) > pos then
			do
				local i = self._firstIndex - self._curLineItemCount
				while i >= 0 do
					pos2 = pos2 - (self._virtualItems[i+1].width + self._columnGap)
					if pos2 <= pos then
						pos = pos2
						return i, pos
					end
					i = i - self._curLineItemCount
				end
			end

			pos = 0
			return 0, pos
		else
			local testGap = self._columnGap > 0 and self._columnGap or 0
			do
				local i = self._firstIndex
				while i < self._realNumItems do
					local pos3 = pos2 + self._virtualItems[i+1].width
					if pos3 + testGap > pos then
						pos = pos2
						return i, pos
					end
					pos2 = pos3 + self._columnGap
					i = i + self._curLineItemCount
				end
			end

			pos = pos2
			return self._realNumItems - self._curLineItemCount, pos
		end
	else
		local pos2 = 0
		local testGap = self._columnGap > 0 and self._columnGap or 0
		do
			local i = 0
			while i < self._realNumItems do
				local pos3 = pos2 + self._virtualItems[i+1].width
				if pos3 + testGap > pos then
					pos = pos2
					return i, pos
				end
				pos2 = pos3 + self._columnGap
				i = i + self._curLineItemCount
			end
		end

		pos = pos2
		return self._realNumItems - self._curLineItemCount, pos
	end
end

function GList:getIndexOnPos3(pos, forceUpdate)
	if self._realNumItems < self._curLineItemCount then
		pos = 0
		return 0, pos
	end

	local viewWidth = self.viewWidth
	local page = math.floor(pos / viewWidth)
	local startIndex = page * (self._curLineItemCount * self._curLineItemCount2)
	local pos2 = page * viewWidth
	local testGap = self._columnGap > 0 and self._columnGap or 0
	local i = 0
	while i < self._curLineItemCount do
		local pos3 = pos2 + self._virtualItems[startIndex + i + 1].width
		if pos3 + testGap > pos then
			pos = pos2
			return startIndex + i, pos
		end
		pos2 = pos3 + self._columnGap
		i = i + 1
	end

	pos = pos2
	return startIndex + self._curLineItemCount - 1, pos
end

function GList:handleScroll(forceUpdate)
	if self._eventLocked then
		return
	end

	if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.FlowHorizontal then
		local enterCounter = 0
		while self:handleScroll1(forceUpdate) do
			--可能会因为ITEM资源改变导致ITEM大小发生改变，所有出现最后一页填不满的情况，这时要反复尝试填满。
			enterCounter = enterCounter + 1
			forceUpdate = false
			assert(enterCounter < 20, "FairyGUI: list will never be filled as the item renderer function always returns a different size.")
		end

		self:handleArchOrder1()
	elseif self._layout == ListLayoutType.SingleRow or self._layout == ListLayoutType.FlowVertical then
		local enterCounter = 0
		while self:handleScroll2(forceUpdate) do
			enterCounter = enterCounter + 1
			forceUpdate = false
			assert(enterCounter < 20, "FairyGUI: list will never be filled as the item renderer function always returns a different size.")
		end

		self:handleArchOrder2()
	else
		self:handleScroll3(forceUpdate)
	end

	self._boundsChanged = false
end

function GList:handleScroll1(forceUpdate)
	local pos = self.scrollPane.scrollingPosY
	local max = pos + self.scrollPane.viewHeight
	local end_ = max == self.scrollPane.contentHeight
	--这个标志表示当前需要滚动到最末，无论内容变化大小

	--寻找当前位置的第一条项目
	local newFirstIndex
	newFirstIndex, pos = self:getIndexOnPos1(pos, forceUpdate)
	if newFirstIndex == self._firstIndex and not forceUpdate then
		return false
	end

	local oldFirstIndex = self._firstIndex
	self._firstIndex = newFirstIndex
	local curIndex = newFirstIndex
	local forward = oldFirstIndex > newFirstIndex
	local childCount = self.numChildren
	local lastIndex = oldFirstIndex + childCount - 1
	local reuseIndex = forward and lastIndex or oldFirstIndex
	local curX = 0 local curY = pos
	local needRender
	local deltaSize = 0
	local firstItemDeltaSize = 0
	local url = self.defaultItem
	local partSize = math.floor(((self.scrollPane.viewWidth - self._columnGap * (self._curLineItemCount - 1)) / self._curLineItemCount))

	self._itemInfoVer = self._itemInfoVer + 1
	while curIndex < self._realNumItems and (end_ or curY < max) do
		local ii = self._virtualItems[curIndex+1]

		if ii.obj == nil or forceUpdate then
			if self.itemProvider ~= nil then
				url = self.itemProvider(curIndex %self._numItems)
				if url == nil then
					url = self.defaultItem
				end
				url = UIPackage.normalizeURL(url)
			end

			if ii.obj ~= nil and ii.obj.resourceURL ~= url then
				if typeof(ii.obj, GButton) then
					ii.selected = ii.obj.selected
				end
				self:removeChildToPool(ii.obj)
				ii.obj = nil
			end
		end

		if ii.obj == nil then
			--搜索最适合的重用item，保证每次刷新需要新建或者重新render的item最少
			if forward then
				local j = reuseIndex
				while j >= oldFirstIndex do
					local ii2 = self._virtualItems[j+1]
					if ii2.obj ~= nil and ii2.updateFlag ~= self._itemInfoVer and ii2.obj.resourceURL == url then
						if typeof(ii2.obj, GButton) then
							ii2.selected = ii2.obj.selected
						end
						ii.obj = ii2.obj
						ii2.obj = nil
						if j == reuseIndex then
							reuseIndex = reuseIndex - 1
						end
						break
					end
					j = j - 1
				end
			else
				local j = reuseIndex
				while j <= lastIndex do
					local ii2 = self._virtualItems[j+1]
					if ii2.obj ~= nil and ii2.updateFlag ~= self._itemInfoVer and ii2.obj.resourceURL == url then
						if typeof(ii2.obj, GButton) then
							ii2.selected = ii2.obj.selected
						end
						ii.obj = ii2.obj
						ii2.obj = nil
						if j == reuseIndex then
							reuseIndex = reuseIndex + 1
						end
						break
					end
					j = j + 1
				end
			end

			if ii.obj ~= nil then
				self:setChildIndex(ii.obj, forward and curIndex - newFirstIndex or self.numChildren)
			else
				ii.obj = self._pool:getObject(url)
				if forward then
					self:addChildAt(ii.obj, curIndex - newFirstIndex)
				else
					self:addChild(ii.obj)
				end
			end
			if typeof(ii.obj, GButton) then
				ii.obj.selected = (ii.selected)
			end

			needRender = true
		else
			needRender = forceUpdate
		end

		if needRender then
			if self._autoResizeItem and (self._layout == ListLayoutType.SingleColumn or self._columnCount > 0) then
				ii.obj:setSize(partSize, ii.obj.height, true)
			end

			self.itemRenderer(curIndex % self._numItems, ii.obj)
			if (curIndex % self._curLineItemCount) == 0 then
				deltaSize = deltaSize + (math.ceil(ii.obj.height) - ii.height)
				if curIndex == newFirstIndex and oldFirstIndex > newFirstIndex then
					--当内容向下滚动时，如果新出现的项目大小发生变化，需要做一个位置补偿，才不会导致滚动跳动
					firstItemDeltaSize = math.ceil(ii.obj.height) - ii.height
				end
			end
			ii.width = math.ceil(ii.obj.width)
			ii.height = math.ceil(ii.obj.height)
		end

		ii.updateFlag = self._itemInfoVer
		ii.obj:setPosition(curX, curY)
		if curIndex == newFirstIndex then
			max = max + ii.height
		end

		curX = curX + (ii.width + self._columnGap)

		if (curIndex % self._curLineItemCount) == self._curLineItemCount - 1 then
			curX = 0
			curY = curY + (ii.height + self._lineGap)
		end
		curIndex = curIndex + 1
	end

	local i = 0
	while i < childCount do
		local ii = self._virtualItems[oldFirstIndex+i+1]
		if ii.updateFlag ~= self._itemInfoVer and ii.obj ~= nil then
			if typeof(ii.obj, GButton) then
				ii.selected = ii.obj.selected
			end
			self:removeChildToPool(ii.obj)
			ii.obj = nil
		end
		i = i + 1
	end

	childCount = #self._children
	local i = 0
	while i < childCount do
		local obj = self._virtualItems[newFirstIndex+i+1].obj
		if self:getChildAt(i) ~= obj then
			self:setChildIndex(obj, i)
		end
		i = i + 1
	end

	if deltaSize ~= 0 or firstItemDeltaSize ~= 0 then
		self.scrollPane:changeContentSizeOnScrolling(0, deltaSize, 0, firstItemDeltaSize)
	end

	if curIndex > 0 and self.numChildren > 0 and self._container.y <= 0 and self:getChildAt(0).y > - self._container.y then
		return true
	else
		return false
	end
end

function GList:handleScroll2(forceUpdate)
	local pos = self.scrollPane.scrollingPosX
	local max = pos + self.scrollPane.viewWidth
	local end_ = pos == self.scrollPane.contentWidth
	--这个标志表示当前需要滚动到最末，无论内容变化大小

	--寻找当前位置的第一条项目
	local newFirstIndex
	newFirstIndex, pos = self:getIndexOnPos2(pos, forceUpdate)
	if newFirstIndex == self._firstIndex and not forceUpdate then
		return false
	end

	local oldFirstIndex = self._firstIndex
	self._firstIndex = newFirstIndex
	local curIndex = newFirstIndex
	local forward = oldFirstIndex > newFirstIndex
	local childCount = self.numChildren
	local lastIndex = oldFirstIndex + childCount - 1
	local reuseIndex = forward and lastIndex or oldFirstIndex
	local curX = pos local curY = 0
	local needRender
	local deltaSize = 0
	local firstItemDeltaSize = 0
	local url = self.defaultItem
	local partSize = math.floor(((self.scrollPane.viewHeight - self._lineGap * (self._curLineItemCount - 1)) / self._curLineItemCount))

	self._itemInfoVer = self._itemInfoVer + 1
	while curIndex < self._realNumItems and (end_ or curX < max) do
		local ii = self._virtualItems[curIndex+1]

		if ii.obj == nil or forceUpdate then
			if self.itemProvider ~= nil then
				url = self.itemProvider(curIndex % self._numItems)
				if url == nil then
					url = self.defaultItem
				end
				url = UIPackage.normalizeURL(url)
			end

			if ii.obj ~= nil and ii.obj.resourceURL ~= url then
				if typeof(ii.obj, GButton) then
					ii.selected = ii.obj.selected
				end
				self:removeChildToPool(ii.obj)
				ii.obj = nil
			end
		end

		if ii.obj == nil then
			if forward then
				local j = reuseIndex
				while j >= oldFirstIndex do
					local ii2 = self._virtualItems[j+1]
					if ii2.obj ~= nil and ii2.updateFlag ~= self._itemInfoVer and ii2.obj.resourceURL == url then
						if typeof(ii2.obj, GButton) then
							ii2.selected = ii2.obj.selected
						end
						ii.obj = ii2.obj
						ii2.obj = nil
						if j == reuseIndex then
							reuseIndex = reuseIndex - 1
						end
						break
					end
					j = j - 1
				end
			else
				local j = reuseIndex
				while j <= lastIndex do
					local ii2 = self._virtualItems[j+1]
					if ii2.obj ~= nil and ii2.updateFlag ~= self._itemInfoVer and ii2.obj.resourceURL == url then
						if typeof(ii2.obj, GButton) then
							ii2.selected = ii2.obj.selected
						end
						ii.obj = ii2.obj
						ii2.obj = nil
						if j == reuseIndex then
							reuseIndex = reuseIndex + 1
						end
						break
					end
					j = j + 1
				end
			end

			if ii.obj ~= nil then
				self:setChildIndex(ii.obj, forward and curIndex - newFirstIndex or self.numChildren)
			else
				ii.obj = self._pool:getObject(url)
				if forward then
					self:addChildAt(ii.obj, curIndex - newFirstIndex)
				else
					self:addChild(ii.obj)
				end
			end
			if typeof(ii.obj, GButton) then
				ii.obj.selected = (ii.selected)
			end

			needRender = true
		else
			needRender = forceUpdate
		end

		if needRender then
			if self._autoResizeItem and (self._layout == ListLayoutType.SingleRow or self._lineCount > 0) then
				ii.obj:setSize(ii.obj.width, partSize, true)
			end

			self.itemRenderer(curIndex % self._numItems, ii.obj)
			if (curIndex % self._curLineItemCount) == 0 then
				deltaSize = deltaSize + (math.ceil(ii.obj.width) - ii.width)
				if curIndex == newFirstIndex and oldFirstIndex > newFirstIndex then
					--当内容向下滚动时，如果新出现的一个项目大小发生变化，需要做一个位置补偿，才不会导致滚动跳动
					firstItemDeltaSize = math.ceil(ii.obj.width) - ii.width
				end
			end
			ii.width = math.ceil(ii.obj.width)
			ii.height = math.ceil(ii.obj.height)
		end

		ii.updateFlag = self._itemInfoVer
		ii.obj:setPosition(curX, curY)
		if curIndex == newFirstIndex then
			max = max + ii.width
		end

		curY = curY + (ii.height + self._lineGap)

		if (curIndex % self._curLineItemCount) == self._curLineItemCount - 1 then
			curY = 0
			curX = curX + (ii.width + self._columnGap)
		end
		curIndex = curIndex + 1
	end

	local i = 0
	while i < childCount do
		local ii = self._virtualItems[oldFirstIndex+i+1]
		if ii.updateFlag ~= self._itemInfoVer and ii.obj ~= nil then
			if typeof(ii.obj, GButton) then
				ii.selected = ii.obj.selected
			end
			self:removeChildToPool(ii.obj)
			ii.obj = nil
		end
		i = i + 1
	end

	childCount = #self._children
	local i = 0
	while i < childCount do
		local obj = self._virtualItems[newFirstIndex+i+1].obj
		if self:getChildAt(i) ~= obj then
			self:setChildIndex(obj, i)
		end
		i = i + 1
	end

	if deltaSize ~= 0 or firstItemDeltaSize ~= 0 then
		self.scrollPane:changeContentSizeOnScrolling(deltaSize, 0, firstItemDeltaSize, 0)
	end

	if curIndex > 0 and self.numChildren > 0 and self._container.x <= 0 and self:getChildAt(0).x > - self._container.x then
		return true
	else
		return false
	end
end

function GList:handleScroll3(forceUpdate)
	local pos = self.scrollPane.scrollingPosX

	--寻找当前位置的第一条项目
	local newFirstIndex
	newFirstIndex, pos = self:getIndexOnPos3(pos, forceUpdate)
	if newFirstIndex == self._firstIndex and not forceUpdate then
		return
	end

	local oldFirstIndex = self._firstIndex
	self._firstIndex = newFirstIndex

	--分页模式不支持不等高，所以渲染满一页就好了

	local reuseIndex = oldFirstIndex
	local virtualItemCount = #self._virtualItems
	local pageSize = self._curLineItemCount * self._curLineItemCount2
	local startCol = newFirstIndex % self._curLineItemCount
	local viewWidth = self.viewWidth
	local page = math.floor(newFirstIndex / pageSize)
	local startIndex = page * pageSize
	local lastIndex = startIndex + pageSize * 2
	--测试两页
	local needRender
	local url = self.defaultItem
	local partWidth = math.floor(((self.scrollPane.viewWidth - self._columnGap * (self._curLineItemCount - 1)) / self._curLineItemCount))
	local partHeight = math.floor(((self.scrollPane.viewHeight - self._lineGap * (self._curLineItemCount2 - 1)) / self._curLineItemCount2))
	self._itemInfoVer = self._itemInfoVer + 1

	--先标记这次要用到的项目
	local i = startIndex
	while i < lastIndex do
		local continue
		if i < self._realNumItems then
			local col = i % self._curLineItemCount
			if i - startIndex < pageSize then
				if col < startCol then
					continue = true
				end
			else
				if col > startCol then
					continue = true
				end
			end

			if not continue then
				local ii = self._virtualItems[i+1]
				ii.updateFlag = self._itemInfoVer
			end
		end

		i = i + 1
	end

	local lastObj = nil
	local insertIndex = 0
	local i = startIndex
	while i < lastIndex do
		if i < self._realNumItems then
			local ii = self._virtualItems[i+1]
			if ii.updateFlag == self._itemInfoVer then
				if ii.obj == nil then
					--寻找看有没有可重用的
					while reuseIndex < virtualItemCount do
						local ii2 = self._virtualItems[reuseIndex+1]
						if ii2.obj ~= nil and ii2.updateFlag ~= self._itemInfoVer then
							if typeof(ii2.obj, GButton) then
								ii2.selected = ii2.obj.selected
							end
							ii.obj = ii2.obj
							ii2.obj = nil
							break
						end
						reuseIndex = reuseIndex + 1
					end

					if insertIndex == - 1 then
						insertIndex = self:getChildIndex(lastObj) + 1
					end

					if ii.obj == nil then
						if self.itemProvider ~= nil then
							url = self.itemProvider(i % self._numItems)
							if url == nil then
								url = self.defaultItem
							end
							url = UIPackage.normalizeURL(url)
						end

						ii.obj = self._pool:getObject(url)
						self:addChildAt(ii.obj, insertIndex)
					else
						insertIndex = self:setChildIndexBefore(ii.obj, insertIndex)
					end
					insertIndex = insertIndex + 1

					if typeof(ii.obj, GButton) then
						ii.obj.selected = ii.selected
					end

					needRender = true
				else
					needRender = forceUpdate
					insertIndex = - 1
					lastObj = ii.obj
				end

				if needRender then
					if self._autoResizeItem then
						if self._curLineItemCount == self._columnCount and self._curLineItemCount2 == self._lineCount then
							ii.obj:setSize(partWidth, partHeight, true)
						elseif self._curLineItemCount == self._columnCount then
							ii.obj:setSize(partWidth, ii.obj.height, true)
						elseif self._curLineItemCount2 == self._lineCount then
							ii.obj:setSize(ii.obj.width, partHeight, true)
						end
					end

					self.itemRenderer(i % self._numItems, ii.obj)
					ii.width = math.ceil(ii.obj.width)
					ii.height = math.ceil(ii.obj.height)
				end
			end
		end

		i = i + 1
	end

	--排列item
	local borderX = math.floor(startIndex / pageSize) * viewWidth
	local xx = borderX
	local yy = 0
	local lineHeight = 0
	local i = startIndex
	while i < lastIndex do
		if i < self._realNumItems then
			local ii = self._virtualItems[i+1]
			if ii.updateFlag == self._itemInfoVer then
				ii.obj:setPosition(xx, yy)
			end

			if ii.height > lineHeight then
				lineHeight = ii.height
			end
			if (i % self._curLineItemCount) == self._curLineItemCount - 1 then
				xx = borderX
				yy = yy + (lineHeight + self._lineGap)
				lineHeight = 0

				if i == startIndex + pageSize - 1 then
					borderX = borderX + viewWidth
					xx = borderX
					yy = 0
				end
			else
				xx = xx + (ii.width + self._columnGap)
			end
		end

		i = i + 1
	end

	--释放未使用的
	local i = reuseIndex
	while i < virtualItemCount do
		local ii = self._virtualItems[i+1]
		if ii.updateFlag ~= self._itemInfoVer and ii.obj ~= nil then
			if typeof(ii.obj, GButton) then
				ii.selected = ii.obj.selected
			end
			self:removeChildToPool(ii.obj)
			ii.obj = nil
		end
		i = i + 1
	end
end

function GList:handleArchOrder1()
	if self._childrenRenderOrder == ChildrenRenderOrder.Arch then
		local mid = self.scrollPane.posY + self.viewHeight / 2
		local minDist = 2147483647
		local dist
		local apexIndex = 0
		local cnt = self.numChildren
		local i = 0
		while i < cnt do
			local obj = self:getChildAt(i)
			if not self.foldInvisibleItems or obj.visible then
				dist = math.abs(mid - obj.y - obj.height / 2)
				if dist < minDist then
					minDist = dist
					apexIndex = i
				end
			end
			i = i + 1
		end
		self.apexIndex = apexIndex
	end
end

function GList:handleArchOrder2()
	if self._childrenRenderOrder == ChildrenRenderOrder.Arch then
		local mid = self.scrollPane.posX + self.viewWidth / 2
		local minDist = 2147483647 local dist
		local apexIndex = 0
		local cnt = self.numChildren
		local i = 0
		while i < cnt do
			local obj = self:getChildAt(i)
			if not self.foldInvisibleItems or obj.visible then
				dist = math.abs(mid - obj.x - obj.width / 2)
				if dist < minDist then
					minDist = dist
					apexIndex = i
				end
			end
			i = i + 1
		end
		self.apexIndex = apexIndex
	end
end

function GList:getSnappingPosition(xValue, yValue)
	if self._virtual then
		if self._layout == ListLayoutType.SingleColumn or self._layout == ListLayoutType.FlowHorizontal then
			local saved = yValue
			local index
			index, yValue = self:getIndexOnPos1(yValue, false)
			if index < #self._virtualItems and saved - yValue > self._virtualItems[index+1].height / 2 and index < self._realNumItems then
				yValue = yValue + (self._virtualItems[index+1].height + self._lineGap)
			end
		elseif self._layout == ListLayoutType.SingleRow or self._layout == ListLayoutType.FlowVertical then
			local saved = xValue
			local index
			index, xValue = self:getIndexOnPos2(xValue, false)
			if index < #self._virtualItems and saved - xValue > self._virtualItems[index+1].width / 2 and index < self._realNumItems then
				xValue = xValue + (self._virtualItems[index+1].width + self._columnGap)
			end
		else
			local saved = xValue
			local index
			index, xValue = self:getIndexOnPos3(xValue, false)
			if index < #self._virtualItems and saved - xValue > self._virtualItems[index+1].width / 2 and index < self._realNumItems then
				xValue = xValue + (self._virtualItems[index+1].width + self._columnGap)
			end
		end
	else
		xValue, yValue = GList.super.getSnappingPosition(self, xValue, yValue)
	end
	return xValue, yValue
end

function GList:handleAlign(contentWidth, contentHeight)
	local nx = 0
	local ny = 0

	if contentHeight < self.viewHeight then
		if self._verticalAlign == VertAlignType.Middle then
			ny = math.floor(((self.viewHeight - contentHeight) / 2))
		elseif self._verticalAlign == VertAlignType.Bottom then
			ny = self.viewHeight - contentHeight
		end
	end

	if contentWidth < self.viewWidth then
		if self._align == AlignType.Center then
			nx = math.floor(((self.viewWidth - contentWidth) / 2))
		elseif self._align == AlignType.Right then
			nx = self.viewWidth - contentWidth
		end
	end

	if nx~=self._alignOffsetX or ny~=self._alignOffsetY then
		self._alignOffsetX = nx
		self._alignOffsetY = ny
		if self.scrollPane ~= nil then
			self.scrollPane:adjustMaskContainer()
		else
			self:updateInnerPos()
		end
	end
end

function GList:updateBounds()
	if self._virtual then
		return
	end

	local cnt = #self._children
	local i
	local j = 0
	local child
	local curX = 0
	local curY = 0
	local cw, ch
	local maxWidth = 0
	local maxHeight = 0
	local viewWidth = self.viewWidth
	local viewHeight = self.viewHeight

	if self._layout == ListLayoutType.SingleColumn then
		for i=0,cnt-1 do
			child = self:getChildAt(i)
			if not self.foldInvisibleItems or child.visible then
				if curY ~= 0 then
					curY = curY + self._lineGap
				end
				child.y = curY
				if self._autoResizeItem then
					child:setSize(viewWidth, child.height, true)
				end
				curY = curY + math.ceil(child.height)
				if child.width > maxWidth then
					maxWidth = child.width
				end
			end
		end
		cw = math.ceil(maxWidth)
		ch = curY
	elseif self._layout == ListLayoutType.SingleRow then
		for i=0,cnt-1 do
			child = self:getChildAt(i)
			if not self.foldInvisibleItems or child.visible then
				if curX ~= 0 then
					curX = curX + self._columnGap
				end
				child.x = curX
				if self._autoResizeItem then
					child:setSize(child.width, viewHeight, true)
				end
				curX = curX + math.ceil(child.width)
				if child.height > maxHeight then
					maxHeight = child.height
				end
			end
		end
		cw = curX
		ch = math.ceil(maxHeight)
	elseif self._layout == ListLayoutType.FlowHorizontal then
		if self._autoResizeItem and self._columnCount > 0 then
			local lineSize = 0
			local lineStart = 0
			local remainSize
			local remainPercent

			for i=0,cnt-1 do
				child = self:getChildAt(i)
				if not self.foldInvisibleItems or child.visible then
					lineSize = lineSize + child.sourceWidth
					j = j + 1
					if j == self._columnCount or i == cnt - 1 then
						remainSize = viewWidth - (j - 1) * self._columnGap
						remainPercent = 1
						curX = 0
						j = lineStart
						while j <= i do
							child = self:getChildAt(j)
							if not self.foldInvisibleItems or child.visible then
								child:setPosition(curX, curY)
								local perc = child.sourceWidth / lineSize
								child:setSize(math.round(perc / remainPercent * remainSize), child.height, true)
								remainSize = remainSize - child.width
								remainPercent = remainPercent - perc
								curX = curX + (child.width + self._columnGap)

								if child.height > maxHeight then
									maxHeight = child.height
								end
							end
							j = j + 1
						end
						--new line
						curY = curY + (math.ceil(maxHeight) + self._lineGap)
						maxHeight = 0
						j = 0
						lineStart = i + 1
						lineSize = 0
					end
				end
			end
			ch = curY + math.ceil(maxHeight)
			cw = viewWidth
		else
			for i=0,cnt-1 do
				child = self:getChildAt(i)
				if not self.foldInvisibleItems or child.visible then
					if curX ~= 0 then
						curX = curX + self._columnGap
					end

					if self._columnCount ~= 0 and j >= self._columnCount or self._columnCount == 0 and curX + child.width > viewWidth and maxHeight ~= 0 then
						--new line
						curX = 0
						curY = curY + (math.ceil(maxHeight) + self._lineGap)
						maxHeight = 0
						j = 0
					end
					child:setPosition(curX, curY)
					curX = curX + math.ceil(child.width)
					if curX > maxWidth then
						maxWidth = curX
					end
					if child.height > maxHeight then
						maxHeight = child.height
					end
					j = j + 1
				end
			end
			ch = curY + math.ceil(maxHeight)
			cw = math.ceil(maxWidth)
		end
	elseif self._layout == ListLayoutType.FlowVertical then
		if self._autoResizeItem and self._lineCount > 0 then
			local lineSize = 0
			local lineStart = 0
			local remainSize
			local remainPercent

			for i=0,cnt-1 do
				child = self:getChildAt(i)
				if not self.foldInvisibleItems or child.visible then
					lineSize = lineSize + child.sourceHeight
					j = j + 1
					if j == self._lineCount or i == cnt - 1 then
						remainSize = viewHeight - (j - 1) * self._lineGap
						remainPercent = 1
						curY = 0
						j = lineStart
						while j <= i do
							child = self:getChildAt(j)
							if not self.foldInvisibleItems or child.visible then
								child:setPosition(curX, curY)
								local perc = child.sourceHeight / lineSize
								child:setSize(child.width, math.round(perc / remainPercent * remainSize), true)
								remainSize = remainSize - child.height
								remainPercent = remainPercent - perc
								curY = curY + (child.height + self._lineGap)

								if child.width > maxWidth then
									maxWidth = child.width
								end
							end
							j = j + 1
						end
						--new line
						curX = curX + (math.ceil(maxWidth) + self._columnGap)
						maxWidth = 0
						j = 0
						lineStart = i + 1
						lineSize = 0
					end
				end
			end
			cw = curX + math.ceil(maxWidth)
			ch = viewHeight
		else
			for i=0,cnt-1 do
				child = self:getChildAt(i)
				if not self.foldInvisibleItems or child.visible then
					if curY ~= 0 then
						curY = curY + self._lineGap
					end

					if self._lineCount ~= 0 and j >= self._lineCount or self._lineCount == 0 and curY + child.height > viewHeight and maxWidth ~= 0 then
						curY = 0
						curX = curX + (math.ceil(maxWidth) + self._columnGap)
						maxWidth = 0
						j = 0
					end
					child:setPosition(curX, curY)
					curY = curY + child.height
					if curY > maxHeight then
						maxHeight = curY
					end
					if child.width > maxWidth then
						maxWidth = child.width
					end
					j = j + 1
				end
			end
			cw = curX + math.ceil(maxWidth)
			ch = math.ceil(maxHeight)
		end
	else
		local page = 0
		local k = 0
		local eachHeight = 0
		if self._autoResizeItem and self._lineCount > 0 then
			eachHeight = math.floor((viewHeight - (self._lineCount - 1) * self._lineGap) / self._lineCount)
		end

		if self._autoResizeItem and self._columnCount > 0 then
			local lineSize = 0
			local lineStart = 0
			local remainSize
			local remainPercent

			for i=0,cnt-1 do
				child = self:getChildAt(i)
				if not self.foldInvisibleItems or child.visible then
					if j == 0 and (self._lineCount ~= 0 and k >= self._lineCount or self._lineCount == 0 and curY + (self._lineCount > 0 and eachHeight or child.height) > viewHeight) then
						--new page
						page = page + 1
						curY = 0
						k = 0
					end

					lineSize = lineSize + child.sourceWidth
					j = j + 1
					if j == self._columnCount or i == cnt - 1 then
						remainSize = viewWidth - (j - 1) * self._columnGap
						remainPercent = 1
						curX = 0
						j = lineStart
						while j <= i do
							child = self:getChildAt(j)
							if not self.foldInvisibleItems or child.visible then
								child:setPosition(page * viewWidth + curX, curY)
								local perc = child.sourceWidth / lineSize
								child:setSize(math.round(perc / remainPercent * remainSize), self._lineCount > 0 and eachHeight or child.height, true)
								remainSize = remainSize - child.width
								remainPercent = remainPercent - perc
								curX = curX + (child.width + self._columnGap)

								if child.height > maxHeight then
									maxHeight = child.height
								end
							end
							j = j + 1
						end
						--new line
						curY = curY + (math.ceil(maxHeight) + self._lineGap)
						maxHeight = 0
						j = 0
						lineStart = i + 1
						lineSize = 0

						k = k + 1
					end
				end
			end
		else
			for i=0,cnt-1 do
				child = self:getChildAt(i)
				if not self.foldInvisibleItems or child.visible then
					if curX ~= 0 then
						curX = curX + self._columnGap
					end

					if self._autoResizeItem and self._lineCount > 0 then
						child:setSize(child.width, eachHeight, true)
					end

					if self._columnCount ~= 0 and j >= self._columnCount or self._columnCount == 0 and curX + child.width > viewWidth and maxHeight ~= 0 then
						curX = 0
						curY = curY + (maxHeight + self._lineGap)
						maxHeight = 0
						j = 0
						k = k + 1

						if self._lineCount ~= 0 and k >= self._lineCount or self._lineCount == 0 and curY + child.height > viewHeight and maxWidth ~= 0 then
							page = page + 1
							curY = 0
							k = 0
						end
					end
					child:setPosition(page * viewWidth + curX, curY)
					curX = curX + math.ceil(child.width)
					if curX > maxWidth then
						maxWidth = curX
					end
					if child.height > maxHeight then
						maxHeight = child.height
					end
					j = j + 1
				end
			end
		end
		ch = page > 0 and viewHeight or (curY + math.ceil(maxHeight))
		cw = (page + 1) * viewWidth
	end

	self:handleAlign(cw, ch)
	self:setBounds(0, 0, cw, ch)
end

function GList:setup_BeforeAdd(buffer, beginPos)
	GList.super.setup_BeforeAdd(self, buffer, beginPos)

	buffer:seek(beginPos, 5)

	self._layout = buffer:readByte()
	self.selectionMode = buffer:readByte()
	self._align = buffer:readByte()
	self._verticalAlign = buffer:readByte()
	self._lineGap = buffer:readShort()
	self._columnGap = buffer:readShort()
	self._lineCount = buffer:readShort()
	self._columnCount = buffer:readShort()
	self._autoResizeItem = buffer:readBool()
	self._childrenRenderOrder = buffer:readByte()
	self._apexIndex = buffer:readShort()

	if buffer:readBool() then
		self._margin.top = buffer:readInt()
		self._margin.bottom = buffer:readInt()
		self._margin.left = buffer:readInt()
		self._margin.right = buffer:readInt()
	end

	local overflow = buffer:readByte()
	if overflow == OverflowType.Scroll then
		local savedPos = buffer.pos
		buffer:seek(beginPos, 7)
		self:setupScroll(buffer)
		buffer.pos = savedPos
	else
		self:setupOverflow(overflow)
	end

	if buffer:readBool() then
		buffer:skip(8) --softness
	end

	buffer:seek(beginPos, 8)

	self.defaultItem = buffer:readS()
	local itemCount = buffer:readShort()
	for i=1,itemCount do
		local nextPos = buffer:readShort()
		nextPos = nextPos + buffer.pos

		local str = buffer:readS()
		if str == nil then
			str = self.defaultItem
			if not str or #str==0 then
				buffer.pos = nextPos
				continue = true
				break
			end
		end

		local obj = self:getFromPool(str)
		if obj ~= nil then
			self:addChild(obj)
			str = buffer:readS()
			if str ~= nil then
				obj.text = str
			end
			str = buffer:readS()
			if str ~= nil and typeof(obj, GButton) then
				obj.selectedTitle = str
			end
			str = buffer:readS()
			if str ~= nil then
				obj.icon = str
			end
			str = buffer:readS()
			if str ~= nil and typeof(obj, GButton) then
				obj.selectedIcon = str
			end
			str = buffer:readS()
			if str ~= nil then
				obj.name = str
			end
			if typeof(obj, GComponent) then
				local cnt = buffer:readShort()
				do
					local j = 0
					while j < cnt do
						local cc = obj:getController(buffer:readS())
						str = buffer:readS()
						if cc ~= nil then
							cc.selectedPageId = str
						end
						j = j + 1
					end
				end
			end
		end

		buffer.pos = nextPos
	end
end

function GList:setup_AfterAdd(buffer, beginPos)
	GList.super.setup_AfterAdd(self, buffer, beginPos)

	buffer:seek(beginPos, 6)

	local i = buffer:readShort()
	if i ~= - 1 then
		self._selectionController = self.parent:getControllerAt(i)
	end
end