PopupMenu = class('PopupMenu')

local getters = PopupMenu.getters
local setters = PopupMenu.setters

function PopupMenu:ctor(resourceURL)
	if resourceURL == nil then
		resourceURL = UIConfig.popupMenu
	end

	assert(resourceURL, "FairyGUI: UIConfig.popupMenu not defined")

	self._contentPane = UIPackage.createObjectFromURL(resourceURL)
	self._contentPane:on("addedToStage", self._addedToStage, self)

	self._list = self._contentPane:getChild("list")
	self._list:removeChildrenToPool()

	self._list:addRelation(self._contentPane, RelationType.Width)
	self._list:removeRelation(self._contentPane, RelationType.Height)
	self._contentPane:addRelation(self._list, RelationType.Height)

	self._list:on("clickItem", self._clickItem, self)
end

function PopupMenu:addItem(caption, callback)
	local item = self._list:addItemFromPool()
	item.text=  caption
	item.data = callback
	item.grayed = false
	local c = item:getController("checked")
	if c ~= nil then
		c.selectedIndex = 0
	end

	return item
end

function PopupMenu:addItemAt(caption, index, callback)
	local item = self._list:getFromPool(self._list.defaultItem)
	self._list:addChildAt(obj, index)

	item.text = caption
	item.data = callback
	item.grayed = false
	local c = item:getController("checked")
	if c ~= nil then
		c.selectedIndex = 0
	end

	return item
end

function PopupMenu:addSeperator()
	assert(UIConfig.popupMenu_seperator, "FairyGUI: UIConfig.popupMenu_seperator not defined")

	self._list:addItemFromPool(UIConfig.popupMenu_seperator)
end

function PopupMenu:getItemName(index)
	local item = self._list:getChildAt(index)
	return item.name
end

function PopupMenu:setItemText(name, caption)
	local item = self._list:getChild(name)
	item.text = caption
end

function PopupMenu:setItemVisible(name, visible)
	local item = self._list:getChild(name)
	if item.visible ~= visible then
		item.visible = visible
		self._list:setBoundsChangedFlag()
	end
end

function PopupMenu:setItemGrayed(name, grayed)
	local item = self._list:getChild(name)
	item.grayed = grayed
end

function PopupMenu:setItemCheckable(name, checkable)
	local item = self._list:getChild(name)
	local c = item:getController("checked")
	if c ~= nil then
		if checkable then
			if c.selectedIndex == 0 then
				c.selectedIndex = 1
			end
		else
			c.selectedIndex = 0
		end
	end
end

function PopupMenu:setItemChecked(name, check)
	local item = self._list:getChild(name)
	local c = item:getController("checked")
	if c ~= nil then
		c.selectedIndex = check and 2 or 1
	end
end

function PopupMenu:isItemChecked(name)
	local item = self._list:getChild(name)
	local c = item:getController("checked")
	if c ~= nil then
		return c.selectedIndex == 2
	else
		return false
	end
end

function PopupMenu:removeItem(name)
	local item = self._list:getChild(name)
	if item ~= nil then
		local index = self._list:getChildIndex(item)
		self._list:removeChildToPoolAt(index)
		return true
	else
		return false
	end
end

function PopupMenu:clearItems()
	self._list:removeChildrenToPool()
end

function getters:itemCount()
	return self._list.numChildren
end

function PopupMenu:getcontentPane()
	return self._contentPane
end

function PopupMenu:getlist()
	return self._list
end

function PopupMenu:dispose()
	self._contentPane:dispose()
end

function PopupMenu:show(target, downward)
	local r
	if target ~= nil then
		r = target.root
	else
		r = UIRoot
	end
	if typeof(target, GRoot) then
		target = nil
	end
	r:showPopup(self._contentPane, target, downward)
end

function PopupMenu:_clickItem(context)
	local item = context.data
	if item.grayed then
		self._list.selectedIndex = -1
		return
	end

	local c = item:getController("checked")
	if c ~= nil and c.selectedIndex ~= 0 then
		if c.selectedIndex == 1 then
			c.selectedIndex = 2
		else
			c.selectedIndex = 1
		end
	end

	local r = self._contentPane.parent
	r:hidePopup(self._contentPane)
	if type(item.data)=="function" then
		item.data()
	end
end

function PopupMenu:_addedToStage()
	self._list.selectedIndex = -1
	self._list:resizeToFit(2147483647, 10)
end