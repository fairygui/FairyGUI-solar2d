local tools = require('Utils.ToolSet')
local UBBParser = require('Utils.UBBParser').inst

GTextInput = class('GTextInput', GTextField)

local getters = GTextInput.getters
local setters = GTextInput.setters

function GTextInput:ctor()
	GTextInput.super.ctor(self)

	self._editable = true
	self._autoSize = AutoSizeType.None
	self:setChanged() --force to create
end

function getters:keyboardType()
	return self._keyboardType
end

function setters:keyboardType(value)
	local str = value
	if type(value)=='number' then
		if value==2 then
			str = 'decimal'
		elseif value==3 then
			str = 'url'
		elseif value==4 then
			str = 'number'
		elseif value==5 then
			str = 'phone'
		elseif value==6 then
			str = 'email'
		else
			assert(false, 'unknown keyboardType'..value)
		end
	end

	self._keyboardType = str
	if self.displayObject then
		self.displayObject.inputType = str
	end
end

function getters:displayAsPassword()
	return self._displayAsPassword
end

function setters:displayAsPassword(value)
	self._displayAsPassword = value
	if self.displayObject then
		self.displayObject.isSecure = value or false
	end
end

function getters:prompText()
	return self._promptText
end

function setters:prompText(value)
	self._promptText = value
	if self.displayObject then
		self.displayObject.placeholder = UBBParser:parse(value, true)
	end
end

function getters:editable()
	return self._editable
end

function setters:editable(value)
	self._editable = value
	if self.displayObject then
		self.displayObject.isEditable = value
	end
end

function getters:restrict()
end

function setters:restrict(value)
end

function getters:maxLength()
	return 0
end

function setters:maxLength(value)
end

function GTextInput:requestFocus()
	local obj = self.displayObject
	if obj then
		native.setKeyboardFocus(obj)
	end
end

function GTextInput:setSelection(startPos, endPos)
	local obj = self.displayObject
	if obj then
		native.setKeyboardFocus(obj)
		obj:setSelection( startPos or 10000000, endPos or 10000000 )
	end
end

function GTextInput:handleSizeChanged()
	local obj = self.displayObject
	if obj then
		obj.width = self._width
		obj.height = self._height
	end
end

function GTextInput:applyChange()
	if not self._pendingChange then return end
	self._pendingChange = false

	local obj = self.displayObject

	if not obj or self._singleLine==self._isTextBox then
		if self._singleLine then
			obj = native.newTextField(0,0,100,30)
			self._isTextBox = false
		else
			obj = native.newTextBox(0,0,100,30)
			self._isTextBox = true
		end
		obj.hasBackground = false
		obj.isSecure = self._displayAsPassword or false
		if self._promptText and #self._promptText>0 then
			obj.placeholder = UBBParser:parse(self._promptText, true)
		end
		if self._keyboardType then obj.inputType = self._keyboardType end
		if not self._editable then obj.isEditable = false end

		obj:addEventListener( "userInput", self )
		obj.width = self._width
		obj.height = self._height

		self:replaceDisplayObject(obj)
	end

	obj.text = self._text
	obj.align = self._align==0 and 'left' or ( self._align==1 and 'center' or 'right')
	--obj.font = self:getRealFont(self._textFormat.font)
	obj.size = self._textFormat.size-4
	obj:setTextColor(tools.unpackColor(self._textFormat.color))
end

function GTextInput:userInput(event)
	if event.phase == "began"  then

	elseif event.phase == "ended" then
		self._text = event.target.text

	elseif event.phase == "submitted"  then
		self._text = event.target.text
		self:emit("submit")

	elseif ( event.phase == "editing" ) then
		self._text = event.text
	end
end

function GTextInput:setup_BeforeAdd(buffer, beginPos)
	GTextInput.super.setup_BeforeAdd(self, buffer, beginPos)

	buffer:seek(beginPos, 4)

	local str = buffer:readS()
	if str then
		self.prompText = str
	end

	str = buffer:readS()
	if str then
		self.restrict = str
	end

	local iv = buffer:readInt()
	if iv ~= 0 then
		self.maxLength = iv
	end
	iv = buffer:readInt()
	if iv ~= 0 then
		self.keyboardType = iv
	end

	if buffer:readBool() then
		self.displayAsPassword = true
	end
end