local tools = require('Utils.ToolSet')

GGraph = class('GGraph', GObject)

local getters = GGraph.getters
local setters = GGraph.setters

function GGraph:ctor()
	GGraph.super.ctor(self)

	self._type = 0
end

function getters:color() 
	return self._fillColor or 0
end

function setters:color(value) 
	if self.displayObject then
		self._fillColor = value
		self.displayObject:setFillColor(tools.unpackColor(value))
	end
end

function GGraph:drawRect(lineSize, lineColor, lineAlpha, fillColor, fillAlpha)
	local w,h,offset = self:getDrawInfo(lineSize)
	local obj = display.newRect(0,0,w,h)
	obj:setFillColor(tools.unpackColor(fillColor, fillAlpha))
	obj.strokeWidth = lineSize or 0
	obj:setStrokeColor(tools.unpackColor(lineColor, lineAlpha))
	obj.path.x1 = offset
	obj.path.x2 = offset
	obj.path.x3 = offset
	obj.path.x4 = offset
	obj.path.y1 = offset
	obj.path.y2 = offset
	obj.path.y3 = offset
	obj.path.y4 = offset

	self:updateGraphObj(1, obj, fillColor)
end

function GGraph:drawRoundRect(lineSize, lineColor, lineAlpha, fillColor, fillAlpha, cornerRadius )
	local w,h,offset = self:getDrawInfo(lineSize)
	local obj = display.newRoundedRect(0,0,w,h,cornerRadius )
	obj:setFillColor(tools.unpackColor(fillColor, fillAlpha))
	obj.strokeWidth = lineSize or 0
	obj:setStrokeColor(tools.unpackColor(lineColor, lineAlpha))

	self:updateGraphObj(2, obj, fillColor)
end

function GGraph:drawCircle(lineSize, lineColor, lineAlpha, fillColor, fillAlpha)
	local w,h,offset = self:getDrawInfo(lineSize)
	local obj = display.newCircle(w*0.5,h*0.5,w*0.5)
	obj:setFillColor(tools.unpackColor(fillColor, fillAlpha))
	obj.strokeWidth = lineSize or 0
	obj:setStrokeColor(tools.unpackColor(lineColor, lineAlpha))

	self:updateGraphObj(3, obj, fillColor)
end

function GGraph:drawPolygon(vertices, fillColor, fillAlpha)
	local obj = display.newPolygon(0,0,vertices)
	obj:setFillColor(tools.unpackColor(fillColor, fillAlpha))
	obj.strokeWidth = lineSize or 0
	obj:setStrokeColor(tools.unpackColor(lineColor, lineAlpha))

	self:updateGraphObj(4, obj, fillColor)
end

function GGraph:clear()
	self._type = 0
	self:replaceDisplayObject(nil)
end

function getters:isEmpty()
	return self._type==0
end

function GGraph:updateGraphObj(type, obj, fillColor)
	self._type = type
	self._sourceWidth = self._width
	self._sourceHeight = self._height
	self._fillColor = fillColor
	self:replaceDisplayObject(obj)
	obj:addEventListener("touch", self)
end

function GGraph:getDrawInfo(lineSize)
	local w = self._width
	local h = self._height
	local offset = 0
	
	--调整至描边为内包围
	if lineSize>0 then
		offset = math.ceil(lineSize*0.5)
		w = w-offset*2
		h = h-offset*2
	end

	if w<0 then w=0 end
	if h<0 then h=0 end
	return w,h,offset
end

function GGraph:setup_BeforeAdd(buffer, beginPos)
	GGraph.super.setup_BeforeAdd(self, buffer, beginPos)

	buffer:seek(beginPos, 5)

	local type = buffer:readByte()
	if type ~= 0 then
		local lineSize = buffer:readInt()
		local lineColor,lineAlpha = buffer:readColor()
		local fillColor,fillAlpha = buffer:readColor()
		local roundedRect = buffer:readBool()
		local cornerRadius
		if roundedRect then
			cornerRadius = {}
			for i=1,4 do
				cornerRadius[i] = buffer:readFloat()
			end
		end

		if type == 1 then
			if roundedRect then
				self:drawRoundRect(lineSize, lineColor, lineAlpha, fillColor, fillAlpha, cornerRadius[1])
			else
				self:drawRect(lineSize, lineColor, lineAlpha, fillColor, fillAlpha)
			end
		else
			self:drawCircle(lineSize, lineColor, lineAlpha, fillColor, fillAlpha)
		end
	end
end

function GGraph:handlePivotChanged()
	local obj = self.displayObject
	if obj then
		obj.anchorX = self._pivotX * (self._width / self._sourceWidth)
		obj.anchorY = self._pivotY * (self._height / self._sourceHeight)
		self:handlePositionChanged()
	end
end

function GGraph:handleSizeChanged()
	if self._type==0 then return end

	local obj = self.displayObject

	local w,h,offset = self:getDrawInfo(obj.strokeWidth)
	if self._type==1 then
		local dw = w - self._sourceWidth
		local dh = h - self._sourceHeight
		obj.path.x1 = offset
		obj.path.x2 = offset
		obj.path.x3 = offset+dw
		obj.path.x4 = offset+dw
		obj.path.y1 = offset
		obj.path.y2 = offset+dh
		obj.path.y3 = offset+dh
		obj.path.y4 = offset
	elseif self._type==2 then
		obj.path.width = w
		obj.path.height = h
	elseif self._type==3 then
		obj.path.radius = w*0.5
	end

	obj.anchorX = self._pivotX * (self._width / self._sourceWidth)
	obj.anchorY = self._pivotY * (self._height / self._sourceHeight)
end