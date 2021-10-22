GButton = class('GButton', GComponent)

local getters = GButton.getters
local setters = GButton.setters

GButton.UP = "up"
GButton.DOWN = "down"
GButton.OVER = "over"
GButton.SELECTED_OVER = "selectedOver"
GButton.DISABLED = "disabled"
GButton.SELECTED_DISABLED = "selectedDisabled"

function GButton:ctor()
	GButton.super.ctor(self)

	self.sound = UIConfig.buttonSound
	self.soundVolumeScale = UIConfig.buttonSoundVolumeScale
	self.changeStateOnClick = true
	self._mode = 0
	self._selected = false
	self._downEffect = 0
	self._downEffectValue = 0.8
	self._downScaled = false
	self._down = false
	self._over = false
end

function getters:icon()
	return self._icon
end

function setters:icon(value)
	self._icon = value
	if self._selected and self._selectedIcon~=nil then
		value = self._selectedIcon
	else
		value = self._icon
	end
	
	if self._iconObject then self._iconObject.icon = value end
	self:updateGear(7)
end

function getters:title()
	return self._title
end

function setters:title(value)
	self._title = value
	if self._selected and self._selectedIcon~=nil then
		value = self._selectedTitle
	else
		value = self._title
	end

	if self._titleObject then self._titleObject.text = value end
	self:updateGear(8)
end

function getters:text()
	return self._title
end

function setters:text(value)
	self.title = value
end

function getters:selectedIcon()
	return self._selectedIcon
end

function setters:selectedIcon(value)
	self._selectedIcon = value
	if self._selected and self._selectedIcon~=nil then
		value = self._selectedIcon
	else
		value = self._icon
	end

	if self._iconObject then self._iconObject.icon = value end
end

function getters:selectedTitle()
	return self._selectedTitle
end

function setters:selectedTitle(value)
	self._selectedTitle = value
	if self._selected and self._selectedTitle~=nil then
		value = self._selectedTitle
	else
		value = self._icon
	end

	if self._titleObject then self._titleObject.text = value end
end


function getters:titleColor()
	local tf = self:getTextField()
	if tf~=nil then
		return tf.color
	else
		return 0
	end
end

function setters:titleColor(value)
	local tf = self:getTextField()
	if tf~=nil then
		tf.color = value
	end
	self:updateGear(4)
end


function getters:color()
	return self.titleColor
end

function setters:color(value)
	self.titleColor = value
end

function getters:titleFontSize()
	local tf = self:getTextField()
	if tf~=nil then
		return tf.size
	else
		return 0
	end
end

function setters:titleFontSize(value)
	local tf = self:getTextField()
	if tf~=nil then
		tf.size = value
	end
	self:updateGear(4)
end

function getters:selected()
	return self._selected
end

function setters:selected(value)
	if self._mode == ButtonMode.Common then return end

	if self._selected~=value then
		self._selected = value
		self:setCurrentState()
		if self._selectedTitle~=nil and self._titleObject~=nil then
			self._titleObject.text = self._selected and self._selectedTitle or self._title
		end
		if self._selectedIcon~=nil then
			local str = self._selected and self._selectedIcon or self._icon
			if self._iconObject~=nil then
				self._iconObject.icon = str
			end
		end
		if self._relatedController~=nil
			and self.parent~=nil
			and not self.parent._buildingDisplayList then
			if self._selected then
				self._relatedController.selectedPageId = self.pageOption
				if self._relatedController.autoRadioGroupDepth then
					self.parent:adjustRadioGroupDepth(self, self._relatedController)
				end
			elseif self._mode == ButtonMode.Check and self._relatedController.selectedPageId == self.pageOption then
				self._relatedController.oppositePageId = self.pageOption
			end
		end
	end
end

function getters:mode()
	return self._mode
end

function setters:mode(value)
	if self._mode~=value then
		if value == ButtonMode.Common then
			self.selected = false
		end
		self._mode = value
	end
end


function getters:relatedController()
	return self._relatedController
end

function setters:relatedController(value)
	if value ~= self._relatedController then
		self._relatedController = value
		self.pageOption = nil
	end
end

function GButton:fireClick(downEffect)
	if downEffect and self._mode == ButtonMode.Common then
		self:setState(GButton.OVER)
		GTween.delayedCall(0.1):onComplete(function() self:setState(GButton.DOWN) end)
		GTween.delayedCall(0.2):onComplete(function() self:setState(GButton.UP) end)
	end
	self:_click()
end

function GButton:getTextField()
	if self._titleObject.getTextField then
		 return self._titleObject:getTextField()
	else
		return self._titleObject
	end
end

function GButton:setState(value)
	if self._buttonController then
		self._buttonController.selectedPage = value
	end

	if self._downEffect == 1 then
		local cnt = self.numChildren
		if value == GButton.DOWN or value == GButton.SELECTED_OVER or value == GButton.SELECTED_DISABLED then
			local color = math.floor(self._downEffectValue*0xFFFFFF)
			for i=0,cnt-1 do
				local obj = self:getChildAt(i)
				if obj.color then obj.color = color end
			end
		else
			for i=0,cnt-1 do
				local obj = self:getChildAt(i)
				if obj.color then obj.color = 0xFFFFFF end
			end
		end
	elseif self._downEffect == 2 then
		if value == GButton.DOWN or value == GButton.SELECTED_OVER or value == GButton.SELECTED_DISABLED then
			if not self._downScaled then
				self._downScaled = true
				self:setScale(self.scaleX * self._downEffectValue, self.scaleY * self._downEffectValue)
			end
		else
			if self._downScaled then
				self._downScaled = false
				self:setScale(self.scaleX / self._downEffectValue, self.scaleY / self._downEffectValue)
			end
		end
	end
end

function GButton:setCurrentState()
	if self._grayed and self._buttonController~=nil and self._buttonController:hasPage(GButton.DISABLED) then
		if self._selected then
			self:setState(GButton.SELECTED_DISABLED)
		else
			self:setState(GButton.DISABLED)
		end
	else
		if self._selected then
			self:setState(self._over and GButton.SELECTED_OVER or GButton.DOWN)
		else
			self:setState(self._over and GButton.OVER or GButton.UP)
		end
	end
end

function GButton:handleControllerChanged(c)
	GButton.super.handleControllerChanged(self, c)

	if self._relatedController == c then
		self.selected = self.pageOption == c.selectedPageId
	end
end

function GButton:handleGrayedChanged()
	if self._buttonController ~= nil and self._buttonController:hasPage(GButton.DISABLED) then
		if self._grayed then
			if self._selected then
				self:setState(GButton.SELECTED_DISABLED)
			else
				self:setState(GButton.DISABLED)
			end
		else
			if self._selected then
				self:setState(GButton.DOWN)
			else
				self:setState(GButton.UP)
			end
		end
	else
		GComponent.handleGrayedChanged(self)
	end
end

function GButton:constructExtension(buffer)
	buffer:seek(0, 6)

	self._mode = buffer:readByte()
	local str = buffer:readS()
	if str~=nil then
		self.sound = UIPackage.getItemAssetByURL(str)
	end
	self.soundVolumeScale = buffer:readFloat()
	self._downEffect = buffer:readByte()
	self._downEffectValue = buffer:readFloat()
	if self._downEffect == 2 then
		self:setPivot(0.5, 0.5, self.pivotAsAnchor)
	end

	self._buttonController = self:getController("button")
	self._titleObject = self:getChild("title")
	self._iconObject = self:getChild("icon")
	if self._titleObject~=nil then
		self._title = self._titleObject.text
	end
	if self._iconObject~=nil then
		self._icon = self._iconObject.icon
	end

	if self._mode == ButtonMode.Common then
		self:setState(GButton.UP)
	end

	self:on('touchBegin', self._touchBegin, self)
	self:on('touchEnd', self._touchEnd, self)
	self:on('tap', self._click, self)
end

function GButton:setup_AfterAdd(buffer, beginPos)
	GObject.setup_AfterAdd(self, buffer, beginPos)

	if not buffer:seek(beginPos, 6) then return end
	if buffer:readByte() ~= self.packageItem.objectType then return end

	local str

	str = buffer:readS()
	if str~=nil then self.title = str end
	str = buffer:readS()
	if str~=nil then self.selectedTitle = str end
	str = buffer:readS()
	if str~=nil then self.icon = str end
	str = buffer:readS()
	if str~=nil then self.selectedIcon = str end
	if buffer:readBool() then self.titleColor = buffer:readColor() end
	local iv = buffer:readInt()
	if iv ~= 0 then self.titleFontSize = iv end
	iv = buffer:readShort()
	if iv >= 0 then self._relatedController = self.parent:getControllerAt(iv) end
	self.pageOption = buffer:readS()

	str = buffer:readS()
	if str~=nil then self.sound = UIPackage.getItemAssetByURL(str) end
	if buffer:readBool() then self.soundVolumeScale = buffer:readFloat() end

	self.selected = buffer:readBool()
end

function GButton:_touchBegin(context)
	self._down = true
	context:captureTouch()

	if self._mode == ButtonMode.Common then
		if self._grayed and self._buttonController ~= nil and self._buttonController:hasPage(GButton.DISABLED) then
			self:setState(GButton.SELECTED_DISABLED)
		else
			self:setState(GButton.DOWN)
		end
	end
end

function GButton:_touchEnd()
	if not self._down then return end

	self._down = false
	if self._mode == ButtonMode.Common then
		if self._grayed and self._buttonController ~= nil and self._buttonController:hasPage(GButton.DISABLED) then
			self:setState(GButton.DISABLED)
		elseif self._over then
			self:setState(GButton.OVER)
		else
			self:setState(GButton.UP)
		end
	else
		if not self._over
			and self._buttonController ~=nil
			and (self._buttonController.selectedPage == GButton.OVER or self._buttonController.selectedPage == GButton.SELECTED_OVER) then
			self:setCurrentState()
		end
	end
end

function GButton:_click()
	if self.sound ~= nil then
		self.root:playOneShotSound(self.sound, self.soundVolumeScale)
	end

	if self._mode == ButtonMode.Check then
		if self.changeStateOnClick then
			self.selected = not self._selected
			self:emit("statusChanged")
		end
	elseif self._mode == ButtonMode.Radio then
		if self.changeStateOnClick and not self._selected then
			self.selected = true
			self:emit("statusChanged")
		end
	else
		if self._relatedController~=nil then
			self._relatedController.selectedPageId = pageOption
		end
	end
end