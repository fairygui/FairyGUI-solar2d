local XMLUtils = {}

local _buffer = {}
local _entities = { amp=38, apos=39, gt=62, lt=60, nbsp=32, quot=34 }

function XMLUtils.encode(str)
	 str = string.gsub(str, "&", "&amp;")
	 str = string.gsub(str, "<", "&lt;")
	 str = string.gsub(str, ">", "&gt;")
	 str = string.gsub(str, "'", "&apos;")
	 return str
end

function XMLUtils.decode(aSource)
	local len = #aSource
	local blen = 0
	local pos1 = 1
	local pos2 = 1

	while true do
		pos2 = string.find(aSource, '&', pos1, true)
		if pos2 == nil then
			blen = blen+1
			_buffer[blen] = string.sub(aSource, pos1)
			break
		end
		if pos2>pos1 then
			blen = blen+1
			_buffer[blen] = string.sub(aSource, pos1, pos2 - 1)
		end

		pos1 = pos2 + 1
		pos2 = pos1
		local ends = math.min(len, pos2 + 10)
		for i=pos2,ends do
			if string.byte(aSource,pos2,pos2) == 59 then -- ''
				break
			end
			pos2=pos2+1
		end
		if pos2 <= ends and pos2 > pos1 then
			local entity = string.sub(aSource, pos1, pos2-1)
			local u = 0
			if string.byte(entity,1,1) == 35 then --'#'
				if #entity > 1 then
					if string.byte(entity,2,2) == 120 then --'x'
						u = tonumber(string.sub(entity, 3), 16)
					else
						u = tonumber(string.sub(entity, 2))
					end
					blen = blen+1
					_buffer[blen] = string.char(u)
					pos1 = pos2 + 1
				else
					blen = blen+1
					_buffer[blen] = '&'
				end
			else
				u = _entities[entity]
				if u ~= nil then
					blen = blen+1
					_buffer[blen] = string.char(u)
					pos1 = pos2 + 1
				else
					blen = blen+1
					_buffer[blen] = '&'
				end
			end
		else
			blen = blen+1
			_buffer[blen] = '&'
		end
	end

	return table.concat(_buffer,'',1,blen)
end

return XMLUtils