local tools = require('Utils.ToolSet')

GComboBox = class('GComboBox', GComponent)

local getters = GComboBox.getters
local setters = GComboBox.setters

function GComboBox:ctor()
	GComboBox.super.ctor(self)

	self.visibleItemCount = UIConfig.defaultComboBoxVisibleItemCount
	self._itemsUpdated = true
	self._selectedIndex = - 1
	self._items = {}
	self._values = {}
	self._popupDirection = PopupDirection.Auto
end

function getters:icon()
	if self._iconObject ~= nil then
		return self._iconObject.icon
	else
		return nil
	end
end

function setters:icon(value)
	if self._iconObject ~= nil then
		self._iconObject.icon = value
	end
	self:updateGear(7)
end

function getters:title()
	if self._titleObject ~= nil then
		return self._titleObject.text
	else
		return nil
	end
end

function setters:title(value)
	if self._titleObject ~= nil then
		self._titleObject.text = value
	end
	self:updateGear(6)
end

function getters:text()
	return self.title
end

function setters:text(value)
	self.title = value
end

function getters:titleColor()
	local tf = self:getTextField()
	if tf ~= nil then
		return tf.color
	else
		return 0
	end
end

function setters:titleColor(value)
	local tf = self:getTextField()
	if tf ~= nil then
		tf.color = value
	end
end

function getters:titleFontSize()
	local tf = self:getTextField()
	if tf ~= nil then
		return tf.textFormat.size
	else
		return 0
	end
end

function setters:titleFontSize(value)
	local tf = self:getTextField()
	if tf ~= nil then
		local format = tf.textFormat
		format.size = value
		tf.textFormat = format
	end
end

function getters:items()
	return self._items
end

function setters:items(value)
	self._items = value or {}
	if #self._items > 0 then
		if self._selectedIndex >= #self._items then
			self._selectedIndex = #self._items - 1
		elseif self._selectedIndex == - 1 then
			self._selectedIndex = 0
		end
		self.text = self._items[self._selectedIndex+1]
		if self._icons ~= nil and self._selectedIndex < #self._icons then
			self.icon = self._icons[self._selectedIndex+1]
		end
	else
		self.text = ""
		if self._icons ~= nil then
			self.icon = nil
		end
		self._selectedIndex = - 1
	end
	self._itemsUpdated = true
end

function getters:icons()
	return self._icons
end

function setters:icons(value)
	self._icons = value
	if self._icons ~= nil and self._selectedIndex ~= - 1 and self._selectedIndex < #self._icons then
		self.icon = self._icons[self._selectedIndex+1]
	end
end

function getters:values()
	return self._values
end

function setters:values(value)
	self._values = value or {}
end

function getters:selectedIndex()
	return self._selectedIndex
end

function setters:selectedIndex(value)
	if self._selectedIndex == value then
		return
	end

	self._selectedIndex = value
	if self._selectedIndex >= 0 and self._selectedIndex < #self._items then
		self.text = self._items[self._selectedIndex+1]
		if self._icons ~= nil and self._selectedIndex < #self._icons then
			self.icon = self._icons[self._selectedIndex+1]
		end
	else
		self.text = ""
		if self._icons ~= nil then
			self.icon = nil
		end
	end

	self:updateSelectionController()
end

function getters:selectionController()
	return self._selectionController
end

function setters:selectionController(value)
	self._selectionController = value
end

function getters:value()
	if self._selectedIndex >= 0 and self._selectedIndex < #self._values then
		return self._values[self._selectedIndex+1]
	else
		return nil
	end
end

function setters:value(value)
	self.selectedIndex = tools.indexOf(self._values, value)+1
end

function getters:popupDirection()
	return self._popupDirection
end

function setters:popupDirection(value)
	self._popupDirection = value
end

function GComboBox:getTextField()
	if not self._titleObject then return end

	if self._titleObject.getTextField then
		return self._titleObject:getTextField()
	else
		return self._titleObject
	end
end

function GComboBox:setState(value)
	if self._buttonController ~= nil then
		self._buttonController.selectedPage = value
	end
end

function GComboBox:setCurrentState()
	if self._grayed and self._buttonController ~= nil and self._buttonController:hasPage("disabled" --[[GButton.DISABLED]]) then
		self:setState(GButton.DISABLED)
	elseif self.dropdown ~= nil and self.dropdown.parent ~= nil then
		self:setState(GButton.DOWN)
	else
		self:setState(self._over and GButton.OVER or GButton.UP)
	end
end

function GComboBox:handleGrayedChanged()
	if self._buttonController ~= nil and self._buttonController:hasPage(GButton.DISABLED) then
		if self_grayed then
			self:setState(GButton.DISABLED)
		else
			self:setState(GButton.UP)
		end
	else
		GComboBox.super.handleGrayedChanged(self)
	end
end

function GComboBox:handleControllerChanged(c)
	GComboBox.super.handleControllerChanged(self, c)

	if self._selectionController == c then
		self.selectedIndex = c.selectedIndex
	end
end

function GComboBox:updateSelectionController()
	if self._selectionController ~= nil and not self._selectionController.changing 
		and self._selectedIndex < self._selectionController.pageCount then
		local c = self._selectionController
		self._selectionController = nil
		c.selectedIndex = self._selectedIndex
		self._selectionController = c
	end
end

function GComboBox:dispose()
	if self.dropdown ~= nil then
		self.dropdown:dispose()
		self.dropdown = nil
	end
	self._selectionController = nil

	GComboBox.super.dispose(self)
end

function GComboBox:constructExtension(buffer)
	buffer:seek(0, 6)

	self._buttonController = self:getController("button")
	self._titleObject = self:getChild("title")
	self._iconObject = self:getChild("icon")

	local str = buffer:readS()
	if str ~= nil then
		self.dropdown = UIPackage.createObjectFromURL(str)
		assert(self.dropdown,  "FairyGUI: " .. self.resourceURL .. " should be a component.")

		self._list = self.dropdown:getChild("list")
		assert(self._list, "FairyGUI: " .. self.resourceURL .. ": should container a list component named list.")
		
		self._list:on("clickItem", self._clickItem, self)

		self._list:addRelation(self.dropdown, RelationType.Width)
		self._list:removeRelation(self.dropdown, RelationType.Height)

		self.dropdown:addRelation(self._list, RelationType.Height)
		self.dropdown:removeRelation(self._list, RelationType.Width)
	end

	self:on("touchBegin", self._touchBegin, self)
	self:on("touchEnd", self._touchEnd, self)
end

function GComboBox:setup_AfterAdd(buffer, beginPos)
	GComboBox.super.setup_AfterAdd(self, buffer, beginPos)

	if not buffer:seek(beginPos, 6) then
		return
	end

	if buffer:readByte() ~= self.packageItem.objectType then
		return
	end

	local str
	local itemCount = buffer:readShort()
	self._items = {}
	self._values = {}
	do
		local i = 1
		while i <= itemCount do
			local nextPos = buffer:readShort()
			nextPos = nextPos + buffer.pos

			self._items[i] = buffer:readS()
			self._values[i] = buffer:readS()
			str = buffer:readS()
			if str ~= nil then
				if self._icons == nil then
					self._icons = {}
				end
				self._icons[i] = str
			end

			buffer.pos = nextPos
			i = i + 1
		end
	end

	str = buffer:readS()
	if str ~= nil then
		self.text = str
		self._selectedIndex = tools.indexOf(self._items, str)+1
	elseif #self._items > 0 then
		self._selectedIndex = 0
		self.text = self._items[1]
	else
		self._selectedIndex = - 1
	end

	str = buffer:readS()
	if str ~= nil then
		self.icon = str
	end

	if buffer:readBool() then
		self.titleColor = buffer:readColor()
	end
	local iv = buffer:readInt()
	if iv > 0 then
		self.visibleItemCount = iv
	end
	self._popupDirection = buffer:readByte()

	iv = buffer:readShort()
	if iv >= 0 then
		self._selectionController = self.parent:getControllerAt(iv)
	end
end

function GComboBox:updateDropdownList()
	if self._itemsUpdated then
		self._itemsUpdated = false
		self:renderDropdownList()
		self._list:resizeToFit(self.visibleItemCount)
	end
end

function GComboBox:showDropdown()
	self:updateDropdownList()
	if self._list.selectionMode == ListSelectionMode.Single then
		self._list.selectedIndex = -1
	end
	self.dropdown.width = self.width

	local downward
	if self._popupDirection == PopupDirection.Down then
		downward = true
	elseif self._popupDirection == PopupDirection.Up then
		downward = false
	end

	self.root:togglePopup(self.dropdown, self, downward)
	if self.dropdown.parent ~= nil then
		self.dropdown:on("removeFromStage", self._popupWinClosed, self)
		self:setState(GButton.DOWN)
	end
end

function GComboBox:renderDropdownList()
	self._list:removeChildrenToPool()
	local cnt = #self._items
	for i=1,cnt do
		local item = self._list:addItemFromPool()
		item.text= self._items[i]
		if (self._icons ~= nil and i < #self._icons) then
			item.icon = self._icons[i]
		else
			item.icon = nil
		end
		if i < #self._values then
			item.name = self._values[i]
		else
			item.name = ""
		end
	end
end

function GComboBox:_popupWinClosed()
	self.dropdown:off("removeFromStage", self._popupWinClosed, self)
	self:setCurrentState()
end

function GComboBox:_clickItem(item)
	if typeof(self.dropdown.parent, GRoot) then
		self.dropdown.parent:hidePopup(self.dropdown)
	end

	self._selectedIndex = -1
	self.selectedIndex = self._list:getChildIndex(item)

	self:emit("statusChanged")
end

function GComboBox:_touchBegin(context)
	if typeof(context.initiator, GTextInput) then
		return
	end

	self._down = true

	if self.dropdown ~= nil then
		self:showDropdown()
	end

	context:captureTouch()
end

function GComboBox:_touchEnd(context)
	if self._down then
		self._down = false
		if self.dropdown ~= nil and self.dropdown.parent ~= nil then
			self:setCurrentState()
		end
	end
end