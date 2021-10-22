local tools = require('Utils.ToolSet')
local XMLIterator = require('Utils.XMLIterator')
local TextFormat = require('TextFormat')
local XMLTagType = XMLIterator.TagType

local HtmlParser = {
	ElementType = {
		Text=0,
		Link=1,
		Image=2,
		Input=3,
		Select=4,
		Object=5,

		--internal
		LinkEnd=99,
	},

	options = {
		linkUnderline = true,
		linkColor = 0x3A67CC,
		ignoreWhiteSpace = false,
	}
}

local ElementType = HtmlParser.ElementType

local _textFormatStack = {}
local _textFormatStackTop
local _format
local _elements
local _elementCount

local function addElement(element)
	_elementCount = _elementCount + 1
	_elements[_elementCount] = element
end

local function pushTextFormat()
	local tf
	if (#_textFormatStack <= _textFormatStackTop) then
		tf = TextFormat.new()
		table.insert(_textFormatStack, tf)
	else
		tf = _textFormatStack[_textFormatStackTop+1]
	end
	tf:copyFrom(_format)
	tf.colorChanged = _format.colorChanged
	_textFormatStackTop = _textFormatStackTop+1
end

local function popTextFormat()
	if _textFormatStackTop > 0 then
		local tf = _textFormatStack[_textFormatStackTop]
		_format:copyFrom(tf)
		_format.colorChanged = tf.colorChanged
		_textFormatStackTop = _textFormatStackTop-1
	end
end

local function isNewLine()
	if _elementCount>0 then
		local element = _elements[_elementCount]
		if element~=nil and element.type == ElementType.Text then
			local cnt = #element.text
			return cnt>0 and string.byte(element.text, cnt, cnt) == "\n"
		else
			return false
		end
	end

	return true
end

local function appendText(text)
	local element
	if _elementCount > 0 then
		element = _elements[_elementCount]
		if element.type == ElementType.Text and element.format:equalStyle(_format) then
			element.text = element.text..text
			return
		end
	end

	addElement( {
		type=ElementType.Text,
		text=text,
		format=_format:clone()
	})
end

function HtmlParser.parse(aSource, defaultFormat, elements, parseOptions)
	parseOptions = parseOptions or HtmlParser.options
	if not _format then _format =  TextFormat.new() end

	_elements = elements
	_elementCount = 0
	_textFormatStackTop = 0
	_format:copyFrom(defaultFormat)
	_format.colorChanged = false
	local skipText = 0
	local ignoreWhiteSpace = parseOptions.ignoreWhiteSpace
	local skipNextCR = false
	local text

	XMLIterator.begin(aSource, true)
	while XMLIterator.nextTag() do
		if skipText == 0 then
			text = XMLIterator.getText(ignoreWhiteSpace)
			if #text>0 then
				if skipNextCR and string.sub(text,1,1) == '\n' then
					text = string.sub(text,1)
				end

				appendText(text)
			end
		end

		skipNextCR = false
		local tagName=XMLIterator.tagName
		if tagName=="b" then
			if (XMLIterator.tagType == XMLTagType.Start) then
				pushTextFormat()
				_format.bold = true
			else
				popTextFormat()
			end
		elseif tagName=="i" then
			if (XMLIterator.tagType == XMLTagType.Start) then
				pushTextFormat()
				_format.italic = true
			else
				popTextFormat()
			end
		elseif tagName=="u" then
			if (XMLIterator.tagType == XMLTagType.Start) then
				pushTextFormat()
				_format.underline = true
			else
				popTextFormat()
			end
		elseif tagName=="sub" then
			if (XMLIterator.tagType == XMLTagType.Start) then
				pushTextFormat()
				_format.size = math.ceil(_format.size * 0.58)
				--_format.specialStyle = TextFormat.SpecialStyle.Subscript
			else
				popTextFormat()
			end
		elseif tagName=="sup" then
			if (XMLIterator.tagType == XMLTagType.Start) then
				pushTextFormat()
				_format.size = math.ceil(_format.size * 0.58)
				--_format.specialStyle = TextFormat.SpecialStyle.Superscript
			else
				popTextFormat()
			end
		elseif tagName=="font" then
			if (XMLIterator.tagType == XMLTagType.Start) then
				pushTextFormat()

				_format.size = XMLIterator.getAttributeNumber("size", _format.size)
				local color = XMLIterator.getAttribute("color")
				if color~=nil then
					_format.color = string.tocolor(color)
					_format.colorChanged = true
				end
			elseif (XMLIterator.tagType == XMLTagType.End) then
				popTextFormat()
			end
		elseif tagName=="br" then
			appendText("\n")
		elseif tagName=="img" then
			if (XMLIterator.tagType == XMLTagType.Start or XMLIterator.tagType == XMLTagType.Void) then
				addElement({
					type=ElementType.Image,
					attrs=XMLIterator.getAttributes()
				})
			end
		elseif tagName=="a" then
			if (XMLIterator.tagType == XMLTagType.Start) then
				pushTextFormat()

				_format.underline = _format.underline or parseOptions.linkUnderline
				if (not _format.colorChanged and parseOptions.linkColor) then
					_format.color = parseOptions.linkColor
				end

				addElement({
					type=ElementType.Link,
					attrs=XMLIterator.getAttributes()
				})
			elseif (XMLIterator.tagType == XMLTagType.End) then
				popTextFormat()

				addElement({type=ElementType.LinkEnd})
			end
		elseif tagName=="ui" or tagName=="div" or tagName=="li" then
			if (XMLIterator.tagType == XMLTagType.Start) then
				if not isNewLine() then
					appendText("\n")
				end
			else
				appendText("\n")
				skipNextCR = true
			end
		elseif tagName=="html" or tagName=="body" then
			--full html
			ignoreWhiteSpace = true
		elseif tagName=="head" or tagName=="style" or tagName=="script" or tagName=="form" then
			if (XMLIterator.tagType == XMLTagType.Start) then
				skipText = skipText+1
			elseif (XMLIterator.tagType == XMLTagType.End) then
				skipText = skipText-1
			end
		end
	end

	if skipText == 0 then
		text = XMLIterator.getText(ignoreWhiteSpace)
		if #text>0 then
			if skipNextCR and string.sub(text,1,1) == '\n' then
				text = string.sub(text,1)
			end

			appendText(text)
		end
	end

	return _elementCount
end

return HtmlParser