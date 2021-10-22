local tools = require('Utils.ToolSet')
local XMLUtils = require('Utils.XMLUtils')

local XMLIterator = { 
	TagType = {
		Start = 0,
		End = 1,
		Void = 2,
		CDATA = 3,
		Comment = 4,
		Instruction = 5
	}
}

local TagType = XMLIterator.TagType

local _source
local _sourceLen
local _parsePos
local _tagPos
local _tagLength
local _lastTagEnd
local _lowerCaseName
local _buffer = {}
local _attributes

local CDATA_START = "<![CDATA["
local CDATA_END = "]]>"
local COMMENT_START = "<!--"
local COMMENT_END = "-->"

function XMLIterator.begin(source, lowerCaseName)
	lowerCaseName = lowerCaseName or false
	_source = source
	_lowerCaseName = lowerCaseName
	_sourceLen = #source
	_parsePos = 1
	_lastTagEnd = 0
	_tagPos = 0
	_tagLength = 0
	XMLIterator.tagName = nil
end

function XMLIterator.nextTag()
	local pos
	local c
	local blen = 0

	XMLIterator.tagType = TagType.Start	
	XMLIterator.lastTagName = XMLIterator.tagName
	_lastTagEnd = _parsePos
	_attributes = nil

	while true do
		pos = string.find(_source, '<', _parsePos, true)
		if pos==nil then break end
		_parsePos = pos
		pos = pos + 1

		if pos > _sourceLen then break end

		c = string.sub(_source, pos, pos)
		if c == '!' then
			if (_sourceLen >= pos + 7 and string.sub(_source, pos-1, pos+7) == CDATA_START) then
				pos = string.find(_source, CDATA_END, pos, true)
				XMLIterator.tagType = TagType.CDATA
				XMLIterator.tagName = ''
				_tagPos = _parsePos
				if (pos == nil) then
					_tagLength = _sourceLen - _parsePos
				else
					_tagLength = pos + 3 - _parsePos
				end
				_parsePos = _parsePos + _tagLength
				return true
			elseif (_sourceLen >= pos + 2 and string.sub(_source, pos-1, pos+2) == COMMENT_START) then
				pos = string.find(_source, COMMENT_END, pos, true)
				XMLIterator.tagType = TagType.Comment
				XMLIterator.tagName = ''
				_tagPos = _parsePos
				if (pos == nil) then
					_tagLength = _sourceLen - _parsePos
				else
					_tagLength = pos + 3 - _parsePos
				end
				_parsePos = _parsePos + _tagLength
				return true
			else
				pos = pos + 1
				XMLIterator.tagType = TagType.Instruction
			end
		elseif (c == '/') then
			pos = pos + 1
			XMLIterator.tagType = TagType.End
		elseif (c == '?') then
			pos = pos + 1
			XMLIterator.tagType = TagType.Instruction
		end

		for i=pos, _sourceLen do
			c = string.sub(_source, pos, pos)
			if c=='\r' or c=='\n' or c==' ' or c=='\t' or c == '>' or c == '/' then break end
			pos=pos+1
		end
		if (pos > _sourceLen) then break end

		blen = blen+1
		if XMLIterator.tagType == TagType.End then
			_buffer[blen] = string.sub(_source, _parsePos + 2, pos-1)
		else
			_buffer[blen] = string.sub(_source, _parsePos + 1, pos-1)
		end
		
		if blen > 0 and _buffer[1] == '/' then
			table.remove(_buffer, 1)
			blen = blen-1
		end

		local singleQuoted = false
		local doubleQuoted = false
		local possibleEnd = -1
		for i=pos, _sourceLen do
			c = string.sub(_source, pos, pos)
			if c == '"' then
				if (not singleQuoted) then
					doubleQuoted = not doubleQuoted
				end
			elseif (c == '\'') then
				if (not doubleQuoted) then
					singleQuoted = not singleQuoted
				end
			end

			if (c == '>') then
				if (not (singleQuoted or doubleQuoted)) then
					possibleEnd = -1
					break
				end

				possibleEnd = pos
			elseif (c == '<') then
				break
			end

			pos=pos+1
		end

		if (possibleEnd ~= -1) then
			pos = possibleEnd
		end

		if (pos > _sourceLen) then break end

		if (string.sub(_source, pos-1, pos-1) == '/') then
			XMLIterator.tagType = TagType.Void
		end

		XMLIterator.tagName = table.concat(_buffer,'', 1, blen)
		if _lowerCaseName then
			XMLIterator.tagName = string.lower(XMLIterator.tagName)
		end
		_tagPos = _parsePos
		_tagLength = pos + 1 - _parsePos
		_parsePos = _parsePos + _tagLength

		return true
	end

	_tagPos = _sourceLen+1
	_tagLength = 0
	XMLIterator.tagName = nil
	return false
end

function XMLIterator.getTagSource()
	return string.sub(_source, _tagPos, _tagPos+_tagLength-1)
end

function XMLIterator.getRawText(trim)
	if _lastTagEnd > _tagPos-1 then
		return ''
	elseif trim then
		return string.trim(string.sub(_source, _lastTagEnd, _tagPos - 1))
	else
		return string.sub(_source, _lastTagEnd, _tagPos - 1)
	end
end

function XMLIterator.getText(trim)
	return XMLUtils.decode(XMLIterator.getRawText(trim))
end

local function parseAttributes()
	_attributes = {}

	local attrName
	local valueStart
	local valueEnd
	local waitValue = false
	local quoted
	local blen = 0
	local pos = _tagPos
	local attrEnd = _tagPos + _tagLength - 1

	if pos <= attrEnd and string.sub(_source,pos,pos) == '<' then
		for i=pos, attrEnd do
			local c = string.sub(_source,pos,pos)
			if (c=='\r' or c=='\n' or c==' ' or c=='\t' or c == '>' or c == '/') then
				break
			end
			pos=pos+1
		end
	end

	while pos<=attrEnd do
		local c = string.sub(_source,pos,pos)
		if (c == '=') then
			valueStart = -1
			valueEnd = -1
			quoted = 0
			for j=pos+1, attrEnd do
				local c2 = string.sub(_source,j,j)
				if c2=='\r' or c2=='\n' or c2==' ' or c2=='\t' then
					if (valueStart ~= -1 and quoted == 0) then
						valueEnd = j - 1
						break
					end
				elseif c2 == '>' then
					if (quoted == 0) then
						valueEnd = j - 1
						break
					end
				elseif (c2 == '"') then
					if (valueStart ~= -1) then
						if (quoted ~= 1) then
							valueEnd = j - 1
							break
						end
					else
						quoted = 2
						valueStart = j + 1
					end
				elseif (c2 == '\'') then
					if (valueStart ~= -1) then
						if (quoted ~= 2) then
							valueEnd = j - 1
							break
						end
					else
						quoted = 1
						valueStart = j + 1
					end
				elseif (valueStart == -1) then
					valueStart = j
				end
			end

			if (valueStart ~= -1 and valueEnd ~= -1) then
				attrName = table.concat(_buffer,'',1,blen)
				if _lowerCaseName then
					attrName =  string.lower(attrName)
				end
				blen = 0
				_attributes[attrName] = XMLUtils.decode(string.sub(_source, valueStart, valueEnd))
				pos = valueEnd + 1
			else
				break
			end
		elseif not (c=='\r' or c=='\n' or c==' ' or c=='\t') then
			if (waitValue or c == '/' or c == '>') then
				if blen>0 then
					attrName = table.concat(_buffer,'',1,blen)
					if _lowerCaseName then
						attrName =  string.lower(attrName)
					end
					_attributes[attrName] = ''
					blen = 0
				end

				waitValue = false
			end

			if (c ~= '/' and c ~= '>') then
				blen = blen+1
				_buffer[blen] = c
			end
		else
			if blen>0 then
				waitValue = true
			end
		end

		pos=pos+1
	end
end

function XMLIterator.getAttribute(attrName, defValue)
	if not _attributes then
		parseAttributes()
	end

	local ret =  _attributes[attrName]
	if ret==nil then return defValue else return ret end
end

function XMLIterator.getAttributeNumber(attrName, defValue)
	local value = XMLIterator.getAttribute(attrName)
	if value == nil or #value==0 then
		return defValue
	end

	return tonumber(value)
end

function XMLIterator.getAttributeBool(attrName, defValue)
	local value = XMLIterator.getAttribute(attrName)
	if value == nil or #value==0 then
		return defValue
	end

	return value=='true'
end

function XMLIterator.getAttributes()
	if not _attributes then parseAttributes() end
	return _attributes
end

return XMLIterator,TagType