local UBBParser = class('UBBParser', false)

function UBBParser:ctor()
	self.handlers = {
		url = self.onTag_URL,
		url = self.onTag_URL,
		img = self.onTag_IMG,
		b = self.onTag_Simple,
		i = self.onTag_Simple,
		u = self.onTag_Simple,
		sup = self.onTag_Simple,
		sub = self.onTag_Simple,
		color = self.onTag_COLOR,
		font = self.onTag_FONT,
		size = self.onTag_SIZE,
		align = self.onTag_ALIGN
	}
end

local _buffer = {}

function UBBParser:parse(text, removing)
	self.parsingText = text

	local pos1 = 1
	local pos2
	local pos3
	local ends
	local tag
	local attr
	local repl
	local func
	local blen = 0

	while true do
		pos2 = string.find(text, '[', pos1, true)
		if pos2==nil then break end

		if pos2 > 1 and string.find(text, pos2-1, pos2-1) == '\\' then
			blen = blen + 1
			_buffer[blen] = string.sub(text, pos1, pos2-2)..'['
			pos1 = pos2 + 1
		else
			blen = blen + 1
			_buffer[blen] = string.sub(text, pos1, pos2-1)

			pos1 = pos2
			pos2 = string.find(text, ']', pos1, true)
			if pos2 == nil then break end
				
			if pos2 == pos1 + 1 then
				blen = blen + 1
				_buffer[blen] = string.sub(text, pos1, pos1+1)
				pos1 = pos2 + 1
			else
				ends = string.sub(text, pos1 + 1, pos1+1) == '/'
				pos3 = ends and (pos1 + 2) or (pos1 + 1)
				tag = string.sub(text, pos3, pos2-1)
				self.parsingPos = pos2 + 1
				pos3 = string.find(tag, '=', 1, true)
				if pos3~=nil then
					attr = string.sub(tag, pos3 + 1)
					tag = string.sub(tag, 1, pos3-1)
				end
				tag = string.lower(tag)
				func = self.handlers[tag]
				if func~=nil then
					repl = func(self, tag, ends, attr)
					if repl ~= nil and not removing then
						blen = blen + 1
						_buffer[blen] = repl
					end
				else
					blen = blen + 1
					_buffer[blen] = string.sub(text, pos1, pos2)
				end
				pos1 = self.parsingPos
			end
		end
	end

	self.parsingText = nil

	if blen==0 then
		return text
	else
		if pos1 <= #text then
			blen = blen + 1
			_buffer[blen] = string.sub(text, pos1)
		end

		return table.concat(_buffer,'',1,blen)
	end
end

function UBBParser:onTag_URL(tagName, ends, attr)
	if not ends then
		if attr~=nil then
			return "<a href=\""..attr.."\" target=\"_blank\">"
		else
			local href = self:getTagText(false)
			return "<a href=\""..href.."\" target=\"_blank\">"
		end
	else
		return "</a>"
	end
end

function UBBParser:onTag_IMG(tagName, ends, attr)
	if not ends then
		local src = self:getTagText(true)
		if not src or #src==0 then return nil end

		return "<img src=\""..src.."\"/>"
	end
end

function UBBParser:onTag_Simple(tagName, ends, attr)
	return ends and ("</"..tagName..">") or ("<"..tagName..">")
end

function UBBParser:onTag_COLOR(tagName, ends, attr)
	if not ends then
		return "<font color=\""..attr.."\">"
	else
		return "</font>"
	end
end

function UBBParser:onTag_FONT(tagName, ends, attr)
	if not ends then
		return "<font face=\""..attr.."\">"
	else
		return "</font>"
	end
end

function UBBParser:onTag_SIZE(tagName, ends, attr)
	if not ends then
		return "<font size=\""..attr.."\">"
	else
		return "</font>"
	end
end

function UBBParser:onTag_ALIGN(tagName, ends, attr)
	if not ends then
		return "<p align=\""..attr.."\">"
	else
		return "</p>"
	end
end

local _buffer2 = {}
function UBBParser:getTagText(remove)
	local text = self.parsingText
	local pos1 =  self.parsingPos
	local pos2
	local blen = 0

	while true do
		pos2 = string.find(text, '[', pos1, true)
		if pos2==nil then break end

		if string.sub(text, pos2-1, pos2-1) == '\\' then
			blen = blen + 1
			_buffer2[blen] = string.sub(text, pos1, pos2 - 2)..'['
			pos1 = pos2 + 1
		else
			blen = blen + 1
			_buffer2[blen] = string.sub(text, pos1, pos2 - 1)
			break
		end
	end
	if pos2 == nil then return nil end

	if remove then self.parsingPos = pos2 end

	return table.concat(_buffer2, '', 1, blen)
end

UBBParser.inst = UBBParser.new()

return UBBParser