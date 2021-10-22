local EventDispatcher = require('Event.EventDispatcher')
local InputProcessor = require('Event.InputProcessor')
local Relations = require('Relations')
local Delegate = require('Utils.Delegate')

GObject = class('GObject', EventDispatcher)

local getters = GObject.getters
local setters = GObject.setters

local _gInstanceCounter = 0
local _gearClasses = {
	require('Gears.GearDisplay'),
	require('Gears.GearXY'),
	require('Gears.GearSize'),
	require('Gears.GearLook'),
	require('Gears.GearColor'),
	require('Gears.GearAnimation'),
	require('Gears.GearText'),
	require('Gears.GearIcon')
}

local _blendModes = {
	"normal",
	{ srcColor = "one", dstColor = "one" },
	"add",
	"multiply",
	"screen"
}

local _globalDragStartX
local _globalDragStartY
local _globalRect = {x=0, y=0, width=0, height=0}
local _updateInDragging

function GObject:ctor()
	GObject.super.ctor(self)

	self.id = "_n".._gInstanceCounter
	_gInstanceCounter = _gInstanceCounter+1
	self.name = ""

	self._x = 0
	self._y = 0
	self._width = 0
	self._height = 0
	self._rawWidth = 0
	self._rawHeight = 0
	self.sourceWidth = 0
	self.sourceHeight = 0
	self.initWidth = 0
	self.initHeight = 0
	self.minWidth = 0
	self.minHeight = 0
	self.maxWidth = 0
	self.maxHeight = 0
	self._pivotX = 0
	self._pivotY = 0
	self._pivotAsAnchor = false
	self._alpha = 1
	self._visible = true
	self._touchable = true
	self._scaleX = 1
	self._scaleY = 1
	self._rotation = 0
	self._internalVisible = true
	self._handlingController = false
	self._grayed = false
	self._sortingOrder = 0
	self._pixelSnapping = false
	self._gearLocked = false
	self._sizePercentInGroup = 0

	self._relations = Relations.new(self)
	self._gears = {}
end

function getters:x() return self._x end
function setters:x(value) self:setPosition(value, self._y) end

function getters:y() return self._y end
function setters:y(value) self:setPosition(self._x, value) end

function GObject:setPosition(xv, yv)
	if self._x == xv and self._y == yv then return end
	local dx = xv - self._x
	local dy = yv - self._y
	self._x = xv
	self._y = yv

	self:handlePositionChanged()

	if self.class==GGroup then
		self:moveChildren(dx, dy)
	end

	self:updateGear(1)

	if self.parent and self.parent.class~=GList then
		self.parent:setBoundsChangedFlag()
		if self._group then
			self._group:setBoundsChangedFlag()
		end
		self:emit("posChanged")
	end

	if GObject.draggingObject == self and not _updateInDragging then
		self:localToGlobal(0, 0, self.width, self.height, _globalRect)
	end
end

function getters:pixelSnapping() return self._pixelSnapping end
function setters:pixelSnapping(value)
	self._pixelSnapping = value
	self:handlePositionChanged()
end

function GObject:center(restraint)
	local r
	if self.parent then
		r = self.parent
	else
		r = self.root
	end

	self:setPosition(math.floor((r.width - self._width) * 0.5), math.floor((r.height - self._height) * 0.5), true)
	if restraint then
		self:addRelation(r, RelationType.Center_Center)
		self:addRelation(r, RelationType.Middle_Middle)
	end
end

function GObject:makeFullScreen(restraint)
	self:setSize(UIRoot.width, UIRoot.height)
	if restraint then
		local r
		if self.parent then
			r = self.parent
		else
			r = self.root
		end
		self:addRelation(r, RelationType.Size)
	end
end

function getters:width() 
	if not self._underConstruct then
		self:ensureSizeCorrect()
	end

	return self._width 
end

function setters:width(value)
	self:setSize(value, self._rawHeight)
end

function getters:height() 
	if not self._underConstruct then
		self:ensureSizeCorrect()
	end

	return self._height
 end

function setters:height(value) 
	self:setSize(self._rawWidth, value)
end

function GObject:ensureSizeCorrect()
	if self._sizeDirty then
		self._sizeDirty = nil
		self._relations:ensureRelationsSizeCorrect()
	end
end

function GObject:setSize(wv, hv, ignorePivot)
	if self._rawWidth == wv and self._rawHeight == hv then return end
	self._rawWidth = wv
	self._rawHeight = hv
	if wv < self.minWidth then
		wv = self.minWidth
	elseif self.maxWidth > 0 and wv > self.maxWidth then
		wv = self.maxWidth
	end
	if hv < self.minHeight then
		hv = self.minHeight
	elseif self.maxHeight > 0 and hv > self.maxHeight then
		hv = self.maxHeight
	end
	local dWidth = wv - self._width
	local dHeight = hv - self._height
	self._width = wv
	self._height = hv

	self:handleSizeChanged()

	if self._pivotX ~= 0 or self._pivotY ~= 0 then
		if not self._pivotAsAnchor then
			if not ignorePivot then
				self:setPosition(self._x - self._pivotX * dWidth, self._y - self._pivotY * dHeight)
			else
				self:handlePositionChanged()
			end
		else
			self:handlePositionChanged()
		end
	end

	if self.class==GGroup then
		self:resizeChildren(dWidth, dHeight)
	end

	self:updateGear(2)

	if self.parent then
		self._relations:onOwnerSizeChanged(dWidth, dHeight, self._pivotAsAnchor or not ignorePivot)
		self.parent:setBoundsChangedFlag()
		if self._group then
			self._group:setBoundsChangedFlag(true)
		end
	end

	self:emit("sizeChanged")
end


function GObject:_setSizeDirectly(wv, hv)
	self._rawWidth = wv
	self._rawHeight = hv
	if wv < 0 then wv = 0 end
	if hv < 0 then hv = 0 end
	self._width = wv
	self._height = hv
end

function getters:xMin() 
	if self._pivotAsAnchor then 
		return self._x - self._width * self._pivotX 
	else 
		return self._x 
	end
end

function setters:xMin(value)
	if self._pivotAsAnchor then
		self:setPosition(value + self._width * self._pivotX, self._y)
	else
		self:setPosition(value, self._y, self._z)
	end
end

function getters:yMin()
	if self._pivotAsAnchor then
		return self._y - self._height * self._pivotY
	else
		return self._y
	end
end

function setters:yMin(value)
	if self._pivotAsAnchor then
		self:setPosition(self._x, value + self._height * self._pivotY)
	else
		self:setPosition(self._x, value)
	end
end

function getters:scaleX() return self._scaleX end
function setters:scaleX(value) self:setScale(value, self._scaleY) end

function getters:scaleY() return self._scaleY end
function setters:scaleY(value) self:setScale(self._scaleX, value) end
	
function GObject:setScale(wv, hv)
	if self._scaleX == wv and self._scaleY == hv then return end
	
	self._scaleX = wv
	self._scaleY = hv
	self:handleScaleChanged()

	self:updateGear(2)
end

function getters:pivotX() return self._pivotX end
function setters:pivotX(value) self:setPivot(value, self._pivotY, self._pivotAsAnchor) end

function getters:pivotY() return self._pivotY end
function setters:pivotY(value) self:setPivot(self._pivotX, value, self._pivotAsAnchor) end

function getters:pivotAsAnchor() return self._pivotAsAnchor end
function setters:pivotAsAnchor(value) self:setPivot(self._pivotX, self._pivotY, value) end

function GObject:setPivot(xv, yv, asAnchor)
	if self._pivotX == xv and self._pivotY == yv and self._pivotAsAnchor == asAnchor then return end
	
	self._pivotX = xv
	self._pivotY = yv
	self._pivotAsAnchor = asAnchor
	self:handlePivotChanged()
end

function GObject:setSkew(xv, yv)
end

function getters:touchable() return self._touchable end
function setters:touchable(value) 
	if self._touchable == value then return end
	self._touchable = value
	self:updateGear(3)
end

function getters:grayed() return self._grayed end
function setters:grayed(value) 
	if self._grayed == value then return end
	self._grayed = value
	self:handleGrayedChanged()
	self:updateGear(3)
end

function getters:enabled() return (not self._grayed) and self._touchable end
function setters:enabled(value) 
	self.grayed = not value
	self.touchable = value
end

function getters:rotation() return self._rotation end
function setters:rotation(value) 
	self._rotation = value
	self:updateGear(3)
	if self._isMask then
		local p = self.parent
		if p then
			p._container.maskRotation = self._rotation
		end
	elseif self.displayObject then
		self.displayObject.rotation = self._rotation
	end
end

function getters:alpha() return self._alpha end
function setters:alpha(value) 
	self._alpha = value
	self:handleAlphaChanged()
	self:updateGear(3)
end

function getters:visible() return self._visible end
function setters:visible(value) 
	if self._visible~=value then
		self._visible = value
		if self.parent then self.parent:setBoundsChangedFlag() end
		self:handleVisibleChanged()
	end
end

function GObject:internalVisible()
	return self._internalVisible and (self.group == nil or self.group:internalVisible())
end

function GObject:internalVisible2()
	return self._visible and (self.group == nil or self.group:internalVisible2())
end

function GObject:findParent()
	if self.parent then
		return self.parent
	elseif self.displayObject then
		local p = self.displayObject.parent
		while p do
			if p.gOwner then
				return p.gOwner
			end

			p = p.parent
		end
	end
end

function GObject:finalTouchable()
	if not self._touchable or self.class==GTextField or self.class==GImage or self.class==GMovieClip then return false end
	local obj = self:findParent()
	while obj~=nil do
		if not self._touchable then return false end
		obj = obj:findParent()
	end

	return true
end

function getters:sortingOrder() return self._sortingOrder end
function setters:sortingOrder(value) 
	if value < 0 then value = 0 end
	if self._sortingOrder==value then return end
	local old = self._sortingOrder
	self._sortingOrder = value
	if self.parent then
		self.parent:childSortingOrderChanged(self, old, self._sortingOrder)
	end
end

function getters:filter() 
	return self._filter 
end

function GObject:setFilter(effect, params) 
	self._filter = effect
	self._filterParams = params
	self:applyEffects()
end

function getters:blendMode() 
	return self._blendMode
end

function setters:blendMode(value)
	if self._blendMode~=value then
		self._blendMode = value
		self:applyEffects()
	end
end

function getters:resourceURL()
	if self.packageItem then
		return 'ui://'..self.packageItem.owner.id..self.packageItem.id
	else
		return nil
	end
end

function GObject:getGear(index)
	index = index + 1
	local gear = self._gears[index]
	if gear == nil then
		local gearClass = _gearClasses[index]
		gear = gearClass.new(self)
		self._gears[index] = gear
	end
	return gear
end

function GObject:updateGear(index)
	if self._underConstruct or self._gearLocked then return end

	local gear = self._gears[index+1]
	if gear ~= nil and gear.controller ~= nil then
		gear:updateState()
	end
end

function GObject:checkGearController(index, c)
	local gear = self._gears[index+1]
	return gear ~= nil and gear.controller == c
end

function GObject:updateGearFromRelations(index, dx, dy)
	local gear = self._gears[index+1]
	if gear ~= nil then
		gear:updateFromRelations(dx, dy)
	end
end

function GObject:addDisplayLock()
	local gearDisplay = self._gears[1]
	if gearDisplay ~= nil and gearDisplay.controller ~= nil then
		local ret = gearDisplay:addLock()
		self:checkGearDisplay()

		return ret
	else
		return 0
	end
end

function GObject:releaseDisplayLock(token)
	local gearDisplay = self._gears[1]
	if gearDisplay ~= nil and gearDisplay.controller ~= nil then
		gearDisplay:releaseLock(token)
		self:checkGearDisplay()
	end
end

function GObject:checkGearDisplay()
	if self._handlingController then return end

	local connected = self._gears[1] == nil or self._gears[1]:isConnected()
	if connected ~= self._internalVisible then
		self._internalVisible = connected
		if self.parent then
			self.parent:childStateChanged(self)
		end
	end
end

function GObject:handleControllerChanged(c)
	self._handlingController = true
	for i=1,8 do
		local gear = self._gears[i]
		if gear ~= nil and gear.controller == c then
			gear:apply()
		end
	end
	self._handlingController = false

	self:checkGearDisplay()
end

function GObject:addRelation(target, relationType, usePercent)
	self._relations:add(target, relationType, usePercent or false)
end

function GObject:removeRelation(target, relationType)
	self._relations:remove(target, relationType)
end

function GObject:removeFromParent()
	if self.parent ~= nil then
		self.parent:removeChild(self)
	end
end

function getters:group() return self._group end
function setters:group(value) 
	if self._group==value then return end
	if self._group ~= nil then
		self._group:setBoundsChangedFlag(true)
	end
	self._group = value
	if self._group ~= nil then
		self._group:setBoundsChangedFlag(true)
	end
	self:handleVisibleChanged()
end

function getters:onStage()
	local p = self
	while true do
		local p2 = p:findParent()
		if not p2 then break end
		p = p2
	end

	return p.class==GRoot
end

function getters:root() 
	local p = self
	while true do
		local p2 = p:findParent()
		if not p2 then break end
		p = p2
	end

	if p.class==GRoot then 
		return p 
	else 
		return UIRoot
	end
end

function getters:text() 
	return '' 
end
function setters:text(value) 
end

function getters:icon()
	return '' 
end
function setters:icon(value) 
end

function getters:draggable() return self._draggable end
function setters:draggable(value)
	if self._draggable ~= value then
		self._draggable = value
		self:initDrag()
	end
end

function GObject:startDrag(touchId)
	if not self.onStage then
		return
	end

	self:dragBegin(touchId)
end

function GObject:stopDrag()
	self:dragEnd()
end

function getters:dragging()
	return GObject.draggingObject == self
end

function GObject:localToGlobal(x, y)
	if not self._pivotAsAnchor then
		x = x - (self._width * self._pivotX)
		y = y - (self._height * self._pivotY)
	end

	if not self.displayObject.insert then --not group
		x = x - self.displayObject.width*0.5
		y = y - self.displayObject.height*0.5
	end

	return self.displayObject:localToContent(x, y)
end


function GObject:globalToLocal(x, y)
	x, y = self.displayObject:contentToLocal(x, y)
	if not self.displayObject.insert then --not group
		x = x + self.displayObject.width*0.5
		y = y + self.displayObject.height*0.5
	end

	if not self._pivotAsAnchor then
		x = x - (self._width * self._pivotX)
		y = y - (self._height * self._pivotY)
	end

	return x,y
end

function GObject:localToGlobalRect(x, y, w, h, ret)
	ret = ret or {}
	ret.x, ret.y = self:localToGlobal(x, y)
	x,y = self:localToGlobal(x+w, y+h)
	ret.width = x - ret.x
	ret.height = y - ret.y
	return ret
end

function GObject:globalToLocalRect(x, y, w, h, ret)
	ret = ret or {}
	ret.x, ret.y = self:globalToLocal(x, y)
	x,y = self:globalToLocal(x+w, y+h)
	ret.width = x - ret.x
	ret.height = y - ret.y
	return ret
end


function GObject:localToRoot(x, y, r)
	r = r or UIRoot
	x,y = self:localToGlobal(x, y)
	return r:globalToLocal(x, y)
end

function GObject:rootToLocal(x, y, r)
	r = r or UIRoot
	x,y = r:localToGlobal(x, y)
	return self:globalToLocal(x, y)
end

function GObject:transformPoint(x, y, targetSpace)
	x,y = self:localToGlobal(x, y)
	return targetSpace:globalToLocal(x, y)
end

function GObject:transformRect(x, y, w, h, targetSpace, ret)
	ret = ret or {}
	ret.x, ret.y = self:transformPoint(x, y, targetSpace)
	local x, y =  self:transformPoint(x+w, y+h, targetSpace)
	ret.width = x-ret.x
	ret.height = y-ret.y
	return ret
end

function GObject:dispose()
	if self._disposed then return end

	self._disposed = true

	self:removeFromParent()
	self:offAll()
	self._relations:dispose()
	self._relations = nil
	for i=1,8 do
		local gear = self._gears[i]
		if gear ~= nil then
			gear:dispose()
		end
	end
	if self.displayObject ~= nil then
		self.displayObject:removeSelf()
		self.displayObject = nil
	end

	if self._frameEventRegistered==true then
		Runtime:removeEventListener("enterFrame", self )
	end
end

function GObject:replaceDisplayObject(newObj)
	local oldObj = self.displayObject

	local added
	if oldObj~=nil and newObj~=nil then
		local group = oldObj.parent
		for i=1,group.numChildren do
			if group[i]==oldObj then
				group:insert(i, newObj)
				break
			end
		end
		added = true
	end

	if oldObj then
		oldObj.gOwner = nil
		oldObj:removeSelf()
		oldObj = nil
	end

	self.displayObject = newObj

	if newObj then
		newObj.gOwner = self

		if self._rotation~=0 then
			newObj.rotation = self._rotation
		end
		if self._alpha~=1 then
			newObj.alpha = self._alpha
		end

		self:handleVisibleChanged()
		self:handlePivotChanged()
		self:handleScaleChanged()

		self:applyEffects()

		if not added then
			if self.parent then
				self.parent:childStateChanged(self)
			else
				GRoot._hidden_root:insert(newObj)
			end
		end
	end
end

function GObject:enterFrame(event)
	if self._delayedCallbacks and self._delayedCallbacks.count>0 then
		self._delayedCallbacks:once()
	end

	if self._frameCallbacks and self._frameCallbacks.count>0 then
		if self.onStage then
			local dt = self._lastTime and (event.time - self._lastTime) or (1000/display.fps)
			dt = dt/1000
			self._frameCallbacks:call(dt)
		elseif not self._delayedCallbacks or self._delayedCallbacks.count==0 then
			self._frameEventRegistered = 1
			Runtime:removeEventListener("enterFrame", self )
			self._lastTime = nil
		end
	elseif not self._delayedCallbacks or self._delayedCallbacks.count==0 then
		Runtime:removeEventListener("enterFrame", self )
		self._frameEventRegistered = nil
		self._lastTime = nil
	end
end
		
function GObject:delayedCall(func, target)
	if not self._delayedCallbacks then self._delayedCallbacks = Delegate.new() end
	self._delayedCallbacks:add(func, target)

	if not self._frameEventRegistered or self._frameEventRegistered==1 then
		self._frameEventRegistered = true
		Runtime:addEventListener("enterFrame", self )
	end
end

function GObject:frameLoop(func, target)
	assert(func, "callback cant be nil")

	if not self._frameCallbacks then self._frameCallbacks = Delegate.new() end
	self._frameCallbacks:add(func, target)

	if not self._frameEventRegistered then
		if self.onStage then
			self._frameEventRegistered = true
			Runtime:addEventListener("enterFrame", self )
		else
			self._frameEventRegistered = 1
			local this = self
			self:on("addedToStage", function()
				if this._frameEventRegistered == 1 then
					this._frameEventRegistered = true
					Runtime:addEventListener("enterFrame", this )
				end
			end)
		end
	end
end

function GObject:cancelDelayedCall(func, target)
	if not self._delayedCallbacks then return end
	self._delayedCallbacks:remove(func, target)
end

function GObject:cancelFrameLoop(func, target)
	if not self._frameCallbacks then return end
	self._frameCallbacks:remove(func, target)
end

function GObject:onClick(func, target)
	self:on('tap', func, target)
end

function GObject:offClick(func, target)
	self:off('tap', func, target)
end

function GObject:handlePositionChanged()
	if not self.displayObject and not self._isMask then return end

	local xv = self._x
	local yv = self._y
	if not self._pivotAsAnchor then
		xv = xv + self._width * self._pivotX
		yv = yv + self._height * self._pivotY
	end
	if self._yOffset then
		yv = yv + self._yOffset
	end
	if self._pixelSnapping then
		xv = math.floor(xv)
		yv = math.floor(yv)
	end

	if self._isMask then
		local p = self.parent
		if p then
			p._container.maskX =  xv + self._width*0.5
			p._container.maskY =  yv + self._height*0.5
		end
	else
		self.displayObject.x = xv
		self.displayObject.y = yv
	end
end

function GObject:handleSizeChanged()
	if self._isMask then
		local p = self.parent
		if p then
			p._container.maskScaleX = self._width/self.sourceWidth*self._scaleX
			p._container.maskScaleY = self._height/self.sourceHeight*self._scaleY
			return
		end
	end

	local obj = self.displayObject
	if obj then
		if obj.setSize then
			obj.setSize(self._width, self._height)
		else
			obj.width = self._width
			obj.height = self._height
		end
	end
end

function GObject:handleScaleChanged()
	if self._isMask then
		local p = self.parent
		if p then
			p._container.maskScaleX = self._width/self.sourceWidth*self._scaleX
			p._container.maskScaleY = self._height/self.sourceHeight*self._scaleY
			return
		end
	end

	local obj = self.displayObject
	if obj then
		if obj.setScale then
			obj.setScale(self._scaleX, self._scaleY)
		else
			obj.xScale = self._scaleX
			obj.yScale = self._scaleY
		end
	end
end

function GObject:handlePivotChanged()
	local obj = self.displayObject
	if obj then
		if obj.setAnchor then
			obj.setAnchor(self._pivotX, self._pivotY)
		else
			obj.anchorX = self._pivotX
			obj.anchorY = self._pivotY
		end
		self:handlePositionChanged()
	end
end

function GObject:handleAlphaChanged()
	if self.displayObject then self.displayObject.alpha = self._alpha end
end

function GObject:handleVisibleChanged()
	local obj = self.displayObject
	if obj then
		local v = self:internalVisible2()
		obj.isVisible = v
		obj.isHitTestable = v
	end
end

function GObject:handleGrayedChanged()
	self:applyEffects()
end

local function _applyProps(obj, func, param1, param2)
	if obj.insert~=nil then --group
		for i=1,obj.numChildren do
			local obj2 = obj[i]
			if not obj2.isHitTestable then --isHitTestable means background
				if _applyProps(obj2, func, param1, param2) then
					break
				end
			end
		end
	else
		return func(obj, param1, param2)
	end
end

function GObject:eachDisplayObject(func, param1, param2)
	if not self.displayObject then return end

	_applyProps(self.displayObject, func, param1, param2)
end

local function assignFilterParams(effect, params)
	for K1,V1 in pairs( params ) do
		if ( type(V1) == "table" and #V1 == 0 ) then
			for K2,V2 in pairs(V1) do
				if ( type(V2) == "table" and #V2 == 0 ) then
					for K3,V3 in pairs(V2) do
						if not ( type(V3) == "table" and #V3 == 0 ) then
							effect[K1][K2][K3] = V3
						end
					end
				else
					effect[K1][K2] = V2
				end
			end
		else
			effect[K1] = V1
		end
	end
end

local function assignFilterAndBlend(obj, grayscale, blendMode)
	if obj.fill then
		if grayscale~=nil then
			obj.fill.effect = grayscale and 'filter.grayscale' or nil
		else
			obj.fill.effect = self._filter
			if self._filterParams then assignFilterParams(obj.fill.effect, self._filterParams) end
		end

		if blendMode then
			obj.fill.blendMode = blendMode
		end
	end
end

function GObject:applyEffects()
	if not self.displayObject then return end

	if not self._grayed and self._filter then
		self:eachDisplayObject(assignFilterAndBlend, nil, self._blendMode)
	else
		self:eachDisplayObject(assignFilterAndBlend, self._grayed, self._blendMode)
	end
end

function GObject:constructFromResource()
end

function GObject:setup_BeforeAdd(buffer, beginPos)
	buffer:seek(beginPos, 0)
	buffer:skip(5)

	self.id = buffer:readS()
	self.name = buffer:readS()
	local f1 = buffer:readInt()
	local f2 = buffer:readInt()
	self:setPosition(f1, f2)

	if buffer:readBool() then
		self.initWidth = buffer:readInt()
		self.initHeight = buffer:readInt()
		self:setSize(self.initWidth, self.initHeight, true)
	end

	if buffer:readBool() then
		self.minWidth = buffer:readInt()
		self.maxWidth = buffer:readInt()
		self.minHeight = buffer:readInt()
		self.maxHeight = buffer:readInt()
	end

	if buffer:readBool() then
		f1 = buffer:readFloat()
		f2 = buffer:readFloat()
		self:setScale(f1, f2)
	end

	if buffer:readBool() then
		f1 = buffer:readFloat()
		f2 = buffer:readFloat()
		self:setSkew(f1, f2)
	end

	if buffer:readBool() then
		f1 = buffer:readFloat()
		f2 = buffer:readFloat()
		self:setPivot(f1, f2, buffer:readBool())
	end

	f1 = buffer:readFloat()
	if f1 ~= 1 then self.alpha = f1 end

	f1 = buffer:readFloat()
	if f1 ~=0 then self.rotation = f1 end

	if not buffer:readBool() then self.visible = false end
	if not buffer:readBool() then self.touchable = false end
	if buffer:readBool() then self.grayed = true end
	local blendMode = buffer:readByte()
	if blendMode~=0 then self.blendMode = _blendModes[blendMode+1] end

	local filter = buffer:readByte()
	if filter == 1 then
		buffer:skip(16)
	end

	self.data = buffer:readS()
end

function GObject:setup_AfterAdd(buffer, beginPos)
	buffer:seek(beginPos, 1)

	local str = buffer:readS()
	if str~=nil and string.len(str)>0 then self.tooltips = str end

	local groupId = buffer:readShort()
	if groupId >= 0 then
		self.group = self.parent:getChildAt(groupId)
	end

	buffer:seek(beginPos, 2)

	local cnt = buffer:readShort()
	for i = 1,cnt do
		local nextPos = buffer:readShort()
		nextPos = nextPos + buffer.pos

		local gear = self:getGear(buffer:readByte())
		gear:setup(buffer)

		buffer.pos = nextPos
	end
end

function GObject:touch(evt)
	if self:finalTouchable() then
		if self.pixelHitTest then
			local x,y = self:globalToLocal(evt.x, evt.y)
			if not self.pixelHitTest:hitTest(x, y, self._width, self._height) then
				return false
			end
		end

		InputProcessor.onTouch(evt, self)

		return true
	end
end

--[[ Drag support ]]--

local _globalDragStartX
local _globalDragStartY
local _globalRect = {}
local _updateInDragging
local _helperRect = {}

function GObject:initDrag()
	if self._draggable then
		self:on("touchBegin", self._ds_touchBegin, self)
		self:on("touchMove", self._ds_touchMove, self)
		self:on("touchEnd", self._ds_touchEnd, self)
	else
		self:off("touchBegin", self._ds_touchBegin, self)
		self:off("touchMove", self._ds_touchMove, self)
		self:off("touchEnd", self._ds_touchEnd, self)
	end
end

function GObject:dragBegin(touchId)
	if GObject.draggingObject ~= nil then
		local tmp = GObject.draggingObject
		tmp:stopDrag(GObject.draggingObject)
		GObject.draggingObject = nil
		tmp:emit("dragEnd")
	end

	self:on("touchMove", self._ds_touchMove, self)
	self:on("touchEnd", self._ds_touchEnd, self)

	_globalDragStartX,_globalDragStartY = InputProcessor.getTouchPos(touchId)
	self:localToGlobalRect(0, 0, self._width, self._height, _globalRect)
	self._dragTesting = false

	GObject.draggingObject = self
	InputProcessor.addTouchMonitor(touchId, self)
end

function GObject:dragEnd()
	if GObject.draggingObject == self then
		self._dragTesting = false
		GObject.draggingObject = nil
	end
end

function GObject:_ds_touchBegin(context)
	local evt = context.inputEvent
	self._dragTouchStartPosX, self._dragTouchStartPosY = evt.x, evt.y
	self._dragTesting = true
	context:captureTouch()
end

function GObject:_ds_touchMove(context)
	local evt = context.inputEvent

	if self._dragTesting and GObject.draggingObject ~= self then
		local sensitivity
		sensitivity = UIConfig.touchDragSensitivity

		if math.abs(self._dragTouchStartPosX - evt.x) < sensitivity and math.abs(self._dragTouchStartPosY - evt.y) < sensitivity then
			return
		end

		self._dragTesting = false
		if not self:emit("dragStart", evt.touchId) then
			self:dragBegin(evt.touchId)
		end
	end

	if GObject.draggingObject == self then
		local xx = evt.x - _globalDragStartX + _globalRect.x
		local yy = evt.y - _globalDragStartY + _globalRect.y

		if self.dragBounds then
			local rect = self.dragBounds
			if xx < rect.x then
				xx = rect.x
			elseif xx + _globalRect.width > rect.x+rect.width then
				xx = rect.x+rect.width - _globalRect.width
				if xx < rect.x then
					xx = rect.x
				end
			end

			if yy < rect.y then
				yy = rect.y
			elseif yy + _globalRect.height > rect.y+rect.height then
				yy = rect.y+rect.height - _globalRect.height
				if yy < rect.y then
					yy = rect.y
				end
			end
		end

		local xx,yy = self.parent:globalToLocal(xx, yy)

		_updateInDragging = true
		self:setPosition(math.floor(xx), math.floor(yy))
		_updateInDragging = false

		self:emit("dragMove")
	end
end

function GObject:_ds_touchEnd(context)
	if GObject.draggingObject == self then
		GObject.draggingObject = nil
		self:emit("dragEnd")
	end
end