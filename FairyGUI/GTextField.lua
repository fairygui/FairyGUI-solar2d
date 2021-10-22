local tools = require('Utils.ToolSet')
local XMLUtils = require('Utils.XMLUtils')
local TextFormat = require('TextFormat')
local HtmlParser = require('Utils.HtmlParser')
local HtmlElementType = HtmlParser.ElementType
local UBBParser = require('Utils.UBBParser').inst
local utf8 = require( "plugin.utf8" )
local InputProcessor = require('Event.InputProcessor')

GTextField = class('GTextField', GObject)

local getters = GTextField.getters
local setters = GTextField.setters

function GTextField:ctor()
	GObject.ctor(self)

	self._textFormat = TextFormat.new()
	self._text = ''
	self._autoSize = AutoSizeType.Both
	self._ubbEnabled = false
	self._updatingSize = false
	self._lineSpacing = 3
	self._letterSpacing = 0
	self._singleLine = false
	self._yOffset = 0
end

function getters:text()
	return self._text
end

function setters:text(value)
	if value == nil then value = '' end
	if self._text==value then return end
	self._text = value

	self:setChanged()
	self:updateGear(6)
end

local function changeColor(obj, color)
	if child.baselineOffset~=nil then --is text
		child:setFillColor(tools.unpackColor(color))
	end
end

local function changeStrokeColor(obj, color)
	if child.setEmbossColor~=nil then --is text
		local r,g,b = tools.unpackColor(color)
		child:setEmbossColor({highlight={r=r,g=g,b=b}, shadow={r=r,g=g,b=b}})
	end
end

function getters:color()
	return self._textFormat.color 
end

function setters:color(value)
	if self._textFormat.color~=value then
		self._textFormat.color = value
		if not self._pendingChange then
			self:eachDisplayObject(changeColor, self._textFormat.color)
		end
	end
end

function getters:strokeColor() 
	return self._textFormat.strokeColor
end

function setters:strokeColor(value)
	if self._textFormat.strokeColor~=value then
		self._textFormat.strokeColor = value
		if not self._pendingChange then
			self:eachDisplayObject(changeStrokeColor, self._textFormat.strokeColor)
		end
	end
end

function getters:templateVars()
	return _templateVars or {}
end

function setters:templateVars(value)
	if self._templateVars == nil and value == nil then return end

	self._templateVars = value

	self:flushVars()
end

function GTextField:setVar(name, value)
	if self._templateVars == nil then
		_templateVars = {}
	end
	self._templateVars[name] = value

	return self
end

function GTextField:flushVars()
	self:setTextFieldText()
	self:setChanged()
end

function getters:textFormat()
	return _textFormat
end

function setters:textFormat(value)
	if value~=self._textFormat then
		self._textFormat:copyFrom(value)
	end
	self:setChanged()
end

function getters:color()
	return self._textFormat.color
end

function setters:color(value)
	self._textFormat.color = value
	self.textFormat = self._textFormat
	self:updateGear(4)
end

function getters:align()	
	return self._align
end

function setters:align(value)
	if self._align ~= value then
		self._align = value
		self:setChanged()
	end
end

function getters:verticalAlign()	
	return self._verticalAlign
end

function setters:verticalAlign(value)
	if self._verticalAlign ~= value then
		self._verticalAlign = value
		self:setChanged()
	end
end

function getters:singleLine()	
	return self._singleLine
end

function setters:singleLine(value)
	if self._singleLine~=value then
		self._singleLine = value
		self:setChanged()
	end
end

function getters:UBBEnabled()	
	return self._ubbEnabled
end

function setters:UBBEnabled(value)
	if self._ubbEnabled ~= value then
		self._ubbEnabled = value
		self:setChanged()
	end
end

function getters:autoSize()	
	return self._autoSize
end

function setters:autoSize(value)
	if self._autoSize~=value then
		self._autoSize = value
		self:setChanged()
	end
end

function getters:textWidth()
	if self._pendingChange then self:applyChange() end

	return self._textWidth
end

function getters:textHeight()
	if self._pendingChange then self:applyChange() end

	return self._textHeight
end

function GTextField:handleSizeChanged()
	if self._updatingSize then return end

	if not self._underConstruct and #self._text>0 then
		self:setChanged()
	end
end

function GTextField:ensureSizeCorrect()
	if self._pendingChange then self:applyChange() end
	GTextField.super.ensureSizeCorrect(self)
end

function GTextField:setup_BeforeAdd(buffer, beginPos)
	GObject.setup_BeforeAdd(self, buffer, beginPos)

	buffer:seek(beginPos, 5)

	local tf = self._textFormat

	tf.font = buffer:readS()
	tf.size = buffer:readShort()
	tf.color = buffer:readColor()
	self._align = buffer:readByte()
	self._verticalAlign = buffer:readByte()
	self._lineSpacing = buffer:readShort()
	self._letterSpacing = buffer:readShort()
	self._ubbEnabled = buffer:readBool()
	self._autoSize = buffer:readByte()
	tf.underline = buffer:readBool()
	tf.italic = buffer:readBool()
	tf.bold = buffer:readBool()
	self.singleLine = buffer:readBool()
	if buffer:readBool() then
		tf.strokeColor = buffer:readColor()
		tf.strokeWidth = buffer:readFloat()
	end

	if buffer:readBool() then
		tf.strokeColor = buffer:readColor()
		local f1 = buffer:readFloat()
		local f2 = buffer:readFloat()
		tf.shadowOffset = {f1, f2}
	end

	if buffer:readBool() then
		_templateVars = {}
	end

	self.textFormat = tf
end

function GTextField:setup_AfterAdd(buffer, beginPos)
	GObject.setup_AfterAdd(self, buffer, beginPos)

	buffer:seek(beginPos, 6)

	local str = buffer:readS()
	if str and #str>0 then 
		self.text = str
	end
end

function GTextField:parseTemplate(template)
	local pos1 = 1
	local pos2 = 1
	local pos3
	local tag
	local value
	local buffer = {}

	while true do
		pos2 = string.find(template, '{', pos1, true)
		if pos2==nil then break end
		if pos2 > 1 and template[pos2 - 1] == '\\' then
			table.insert(buffer, string.sub(template, pos1, pos2 - 2))
			table.insert(buffer, '{')
			pos1 = pos2 + 1
		else
			table.insert(buffer, string.sub(template, pos1, pos2 - 1))
			pos1 = pos2
			pos2 = string.find(template, '}', pos1, true)
			if pos2 == nil then break end

			if pos2 == pos1 + 1 then
				table.insert(buffer, string.sub(template, pos1, pos1+1))
				pos1 = pos2 + 1
			else
				tag = string.sub(template, pos1 + 1, pos2 - 1)
				pos3 = string.find(tag, '=', 1, true)
				if pos3 ~= nil then
					value = self._templateVars[string.sub(tag, 0, pos3-1)]
					if value==nil then
						value = string.sub(tag, pos3 + 1)
					end
				else
					value = self._templateVars[tag]
					if value==nil then
						value = ""
					end
				end
				table.insert(buffer, value)
				pos1 = pos2 + 1
			end
		end
	end

	if pos1 <= #template then
		table.insert(buffer, string.sub(template, pos1))
	end

	return table.concat(buffer)
end

function GTextField:setChanged()
	if not self._pendingChange then
		self._pendingChange = true
		self:delayedCall(self.applyChange, self)
	end

	if not self._underConstruct and self._autoSize~=AutoSizeType.None then
		if not self._sizeEventEmitted then
			self._sizeEventEmitted = true
			self:emit('sizeWillChange')
		end
	end
end

function GTextField:getRealFont(font)
	if font==nil or #font==0 then font = UIConfig.defaultFont end
	if string.find(font, "ui://") then
		local font2 = UIPackage.getItemAssetByURL(font)
		if font2 then return font2 end
	else
		local font2 = UIConfig.fontRegistry[font]
		if font2 then return font2 end
	end

	return font
end

function GTextField:checkDisplayObject(complex)
	if self.displayObject and self.displayObject.insert~=nil then
		local group = self.displayObject
		while group.numChildren>0 do
			group:remove(1)
		end
	elseif complex then
		local group = display.newGroup()
		self:replaceDisplayObject(group)
	end
end

function GTextField:touch(evt)
	if self:finalTouchable() then
		InputProcessor.onTouch(evt, self)

		if evt.target.link then
			self:bubble('link', evt.target.link)
		end

		return true
	end
end

function GTextField:_onClickObjectInLink(context)
	self:bubble('link', context.sender.link)
end

local _elements = {}
local _elementCount = 0

function GTextField:applyChange()
	if not self._pendingChange then return end
	self._pendingChange = false
	self._sizeEventEmitted = false

	local str = self._text
	if self._templateVars then
		str = self:parseTemplate(str)
	end

	local isHtml = self.createObject~=nil
	if self._ubbEnabled then
		if not isHtml then str = XMLUtils.encode(str) end
		str = UBBParser:parse(str)
		isHtml = true
	end

	if not isHtml and not self:getRealFont(self._textFormat.font).glyphs then
		self:renderSimple(str)
	else
		self._simpleTextOptions = nil

		if isHtml then
			_elementCount = HtmlParser.parse(str, self._textFormat, _elements, self._htmlParseOptions)
		else
			local element = { type=HtmlElementType.Text, text=str, format=self._textFormat }
			_elements[1] = element
			_elementCount = 1
		end

		self:wrapText()

		if self.onStage then
			local cnt = self.displayObject.numChildren
			for i=1,cnt do
				local child = self.displayObject[i]
				if child.gOwner then
					child.gOwner:emit("addedToStage")
				end
			end
		end
	end

	if self._autoSize==AutoSizeType.Both then
		self._updatingSize = true
		self:setSize(self._textWidth, self._textHeight)
		self._updatingSize = false
	elseif self._autoSize==AutoSizeType.Height then
		self._updatingSize = true
		self.height = self._textHeight
		self._updatingSize = false
	end

	local offset
	if self._autoSize == AutoSizeType.Both or self._autoSize == AutoSizeType.Height	or self._verticalAlign == VertAlignType.Top then
		offset = 0
	else
		local dh = self._height - self._textHeight
		if dh < 0 then dh = 0 end
		if self._verticalAlign == VertAlignType.Middle then
			offset = math.floor(dh*0.5)
		else
			offset = dh
		end
	end

	if self._yOffset~=offset then
		local dh = offset - self._yOffset
		self._yOffset = offset
		self.displayObject.y = self.displayObject.y + dh
	end

	self:applyEffects()
end

function GTextField:renderSimple(text)
	local format = self._textFormat
	local font = self:getRealFont(format.font)
	local align = self._align==0 and 'left' or (self._align==1 and 'center' or 'right')
	local width
	if self._autoSize==AutoSizeType.Both then
		if self.maxWidth>0 then
			width = self.maxWidth
		end
	else
		if not self._singleLine then --corona没有单行设置,只能通过设置为自动宽度,然后再看情况处理
			width = self._width
		end
	end

	local options = self._simpleTextOptions
	local textObj
	if options
		and options.width==width
		and options.font==font
		and options.hasStroke==(format.strokeWidth>0)
		and options.align==align then
		textObj = self.displayObject
	end

	if textObj then
		textObj.size = format.size
		textObj.text = text
	else
		if not options then 
			options = {} 
			self._simpleTextOptions = options
		end
		options.text = text
		options.font = font
		options.fontSize = format.size
		options.align = align
		options.hasStroke = format.strokeWidth>0 --corona not use
		options.width = width

		if format.strokeWidth>0 then
			textObj = display.newEmbossedText(options)
		else
			textObj = display.newText(options)
		end
	end

	if not options.width
		and self._align~=0
		and self._singleLine
		and self._autoSize~=AutoSizeType.Both
		and textObj.width<self._width then

		if textObj~=self.displayObject then
			textObj:removeSelf()
			textObj = nil
		else
			options.text = text
			options.fontSize = format.size
		end
		options.width = self._width

		if format.strokeWidth>0 then
			textObj = display.newEmbossedText(options)
		else
			textObj = display.newText(options)
		end
	end

	if textObj~=self.displayObject then
		self:checkDisplayObject(false)
		self:replaceDisplayObject(textObj)
	end

	textObj:setFillColor(tools.unpackColor(format.color))
	if format.strokeWidth>0 and textObj.setEmbossColor then
		local r,g,b = tools.unpackColor(format.strokeColor)
		textObj:setEmbossColor({highlight={r=r,g=g,b=b}, shadow={r=r,g=g,b=b}})
	end

	self._textWidth = math.ceil(textObj.width)
	self._textHeight = math.ceil(textObj.height)
end

local GUTTER_X = 2
local GUTTER_Y = 2
local _hPos
local _vPos
local _defaultLineHeight
local _childIndex
local _temp_options = {}
local _wrap
local _wrapWidth
local _maxLineWidth = 0
local _objects = {}
local _objects_len = 0
local _link_level = 0
local _links = {}

function GTextField:newLine()
	local lineWidth = 0
	local lineHeight = 0
	
	if _objects_len>0 then
		local child = _objects[_objects_len]
		lineWidth = child.x + child.width
	end
	if lineWidth>_maxLineWidth then _maxLineWidth = lineWidth end

	local offsetX = 0
	if self._autoSize~=AutoSizeType.Both then
		if self._align==AlignType.Center then
			offsetX = (_wrapWidth - lineWidth)*0.5
		elseif self._align==AlignType.Right then
			offsetX = _wrapWidth - lineWidth
		end
		if offsetX<0 then offsetX = 0 end
	end

	local baseline = 0
	local textHeight = 0
	local imgHeight = 0
	for i=1,_objects_len do
		local child = _objects[i]
		if child.baselineOffset~=nil then --textObj
			local b = child.height*0.5-child.baselineOffset
			if b>baseline then baseline = b end

			if child.height>textHeight then textHeight = child.height end
		elseif child.glyph~=nil then
			if child.glyph.lineHeight>imgHeight then imgHeight = child.glyph.lineHeight end
		else
			if child.height>imgHeight then imgHeight = child.height end
		end
	end

	local adjust = 3
	if imgHeight>baseline+adjust then
		lineHeight=imgHeight-baseline-adjust+textHeight
		baseline=imgHeight-adjust
	else
		lineHeight=textHeight
	end
	if lineHeight==0 then lineHeight = _defaultLineHeight end

	for i=1,_objects_len do 
		local child = _objects[i]
		
		if child.displayObject then
			child:setPosition(child.x+offsetX, _vPos + baseline + adjust - child.height)
			self.displayObject:insert(child.displayObject)
		else
			child.x = child.x + offsetX
			if child.baselineOffset~=nil then --textObj
				child.y = _vPos + baseline - (child.height*0.5-child.baselineOffset)
			elseif child.glyph~=nil then
				child.y = _vPos + baseline + adjust - child.glyph.lineHeight + child.glyph.offsetY
				chid.glyph = nil
			else
				child.y = _vPos + baseline + adjust - child.height
			end

			self.displayObject:insert(child)
			child.anchorX = 0
			child.anchorY = 0

			if self._grayed then child.fill.effect = 'filter.grayscale' end
		end

		_objects[i] = nil
	end
	_objects_len = 0

	_hPos = 0
	_vPos = _vPos + lineHeight + self._lineSpacing
end

function GTextField:wrapText()
	self:checkDisplayObject(true)

	_wrap = (self._autoSize~=AutoSizeType.Both or self.maxWidth>0) and not self._singleLine
	if self.maxWidth > 0 then
		_wrapWidth = self.maxWidth - GUTTER_X * 2
	else
		_wrapWidth = self._width - GUTTER_X * 2
	end

	_hPos = 0
	_vPos = GUTTER_Y
	_childIndex = 1
	_maxLineWidth = 0
	_defaultLineHeight = 0
	_objects_len = 0
	_link_level = 0

	local format
	local font
	local pos
	local str
	local len

	for i=1,_elementCount do
		local element = _elements[i]
		if element.type == HtmlElementType.Text then
			format = element.format
			font = self:getRealFont(format.font)
			_defaultLineHeight = format.size
			pos = 1
			len = #element.text
			while pos<=len do
				if _wrap and _hPos>=_wrapWidth then self:newLine() end

				local pos2,_,s = string.find(element.text, "[\r\n]", pos)
				if pos2~=nil then
					if pos2==pos then
						str = nil
					else
						str = string.sub(element.text, pos, pos2-1)
						pos = pos2+1
						if pos<=len and s=='\r' and string.byte(element.text, pos, pos)==10 then pos=pos+1 end
					end
				else
					if pos~=1 then
						str = string.sub(element.text, pos)
					else
						str = element.text
					end
				end

				if str then
					if font.glyphs then
						self:wrapText_bmf(str, element.format, font)
					else
						self:wrapText_ttf(str, element.format, font)	
					end
				end

				if pos2~=nil then self:newLine() else break end
			end

		elseif element.type == HtmlElementType.Link then
			_link_level = _link_level + 1
			_links[_link_level] = element.attrs.href or ''

		elseif element.type == HtmlElementType.LinkEnd then
			_link_level = _link_level - 1

		elseif self.createObject~=nil then
			local htmlObject = self:createObject(element, _wrap and (_wrapWidth - _hPos - 4) or 10000000)
			if htmlObject then
				if _link_level>0 then
					htmlObject.link = _links[_link_level]
					htmlObject:onClick(self._onClickObjectInLink, self)
				end

				local pos = _hPos
				if pos~=0 then pos=pos+self._letterSpacing end				
				local newPos = pos + htmlObject.width + 3
				if _wrap and newPos > _wrapWidth then
					if _hPos~=0 then
						self:newLine()
						pos = 0
						newPos = htmlObject.width + 3
					end
				end

				htmlObject.x = pos
				_objects_len = _objects_len+1
				_objects[_objects_len] = htmlObject
				_hPos = newPos
			end
		end
	end

	self:newLine()

	self._textWidth = math.ceil(_maxLineWidth)
	if _vPos<=GUTTER_Y then
		self._textHeight = 0
	else
		self._textHeight = math.ceil(_vPos - self._lineSpacing)
	end
end

function GTextField:wrapText_ttf(text, format, font)
	_temp_options.font = font
	_temp_options.fontSize = format.size

	local textObj
	if _wrap then 
		local ww = _wrapWidth - _hPos
		--通过二分法测量折行的位置
	 	while true do
	 		local textLen = utf8.len(text)
			local low = 1
			local high = textLen
			local cur = math.ceil(ww / format.size)
			local str
			if cur>high then
				cur = high
			 	str = text
			else
				str = utf8.sub(text,1,cur) 
			end

			while true do
				if not textObj then
					_temp_options.text = str
					if format.strokeWidth>0 then
						textObj = display.newEmbossedText(_temp_options)
					else
						textObj = display.newText(_temp_options)
					end
				else
					textObj.text = str
				end

				if textObj.width>ww then
					high = cur-1
					if high==low or cur==low then
						break
					end
					cur = low + math.floor((cur - low)*0.5)
				else
					low = cur
					if high==low or cur==high then
						break
					end

					cur = cur + math.ceil((high - cur)*0.5)
				end

				str = utf8.sub(text,1,cur)
			end

			--单词截断检查
			local nextLine
			if cur<textLen then
				nextLine = utf8.sub(text, cur+1)

				local i1,i2 = string.find(str, '%s%a+$')
				if i1 and i2>=i1 and i2-i1<10 and (_hPos~=0 or i1~=1) then
					local i3 = string.find(nextLine, '^%a+')
					if i3 then
						textObj.text = utf8.sub(str,1,i1)
						nextLine = utf8.sub(str,i1+1, #str)..nextLine
					end
				end
			end

			textObj:setFillColor(tools.unpackColor(format.color))
			if format.strokeWidth>0 and textObj.setEmbossColor then
				local r,g,b = tools.unpackColor(format.strokeColor)
				textObj:setEmbossColor({highlight={r=r,g=g,b=b}, shadow={r=r,g=g,b=b}})
			end
			if _link_level>0 then
				textObj.link = _links[_link_level]
				textObj:addEventListener("touch", self)
			end

			if _hPos~=0 then _hPos=_hPos+self._letterSpacing end
			textObj.x = _hPos
			_hPos = _hPos + textObj.width
			_objects_len = _objects_len+1
			_objects[_objects_len] = textObj
			textObj = nil

			if nextLine then
				text = nextLine
				self:newLine()
				ww = _wrapWidth
			else
				break
			end
		end
	else
		_temp_options.text = text

		if format.strokeWidth>0 then
			textObj = display.newEmbossedText(_temp_options)
			local r,g,b = tools.unpackColor(format.strokeColor)
			textObj:setEmbossColor({highlight={r=r,g=g,b=b}, shadow={r=r,g=g,b=b}})
		else
			textObj = display.newText(_temp_options)
		end
		textObj:setFillColor(tools.unpackColor(format.color))
		if _link_level>0 then
			textObj.link = _links[_link_level]
			textObj:addEventListener("touch", self)
		end

		if _hPos~=0 then _hPos=_hPos+self._letterSpacing end
		textObj.x = _hPos
		_hPos = _hPos + textObj.width
		_objects_len = _objects_len+1
		_objects[_objects_len] = textObj
		textObj = nil
	end
end

function GTextField:wrapText_bmf(text, format, font)
	local wordStart = -1
	local wordChars = 0
	
	_defaultLineHeight = font.size

	for charpos, ch in utf8.next, text do
		--单词截断检查
		if ch == 32 then
			wordStart = _hPos
			wordChars = 0
		elseif wordStart~=-1 then
			if ch >= 97 or ch <= 122 or ch >= 65 or ch <= 90 then
				wordChars = wordChars+1
				if wordChars>10 then
					wordStart = -1
				end
			else
				wordStart = -1
			end
		end

		local glyph = font.glyphs[ch]
		if glyph then
			if _hPos ~= 0 then _hPos = _hPos + self._letterSpacing end

			local imgObj = display.newImage(glyph.sheet, glyph.frame, _hPos+glyph.offsetX, 0)
			if _link_level>0 then
				imgObj.link = _links[_link_level]
				imgObj:addEventListener("touch", self)
			end

			_objects_len = _objects_len+1
			_objects[_objects_len] = imgObj
			_hPos = _hPos+glyph.advance

		elseif ch==32 then
			if _hPos ~= 0 then _hPos = _hPos + self._letterSpacing end
			_hPos = _hPos+font.size

		end

		if _wrap and _hPos > _wrapWidth then
			if _objects_len==0 then
				self:newLine()
			else
				if wordStart==-1 and _objects[_objects_len].x~=0 then
					wordStart = _objects[_objects_len].x
				end

				if wordStart~=-1 then --if word had broken, move it to new line
					local j=1
					while j<=_objects_len do
						if _objects[j].x>wordStart then break end
						j = j+1
					end

					local tmp = _objects_len
					_objects_len = j-1
					self:newLine()

					if j>1 then
						for i=j,tmp do
							_objects[i-j+1] = _objects[j]
							_objects[j] = nil
						end
					end

					_objects_len = tmp
				end
			end
		end
	end
end