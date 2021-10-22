local TextFormat=class('TextFormat')

local _keys = { 
	"font", "size", "color", "bold", "italic", "underline", "lineSpacing",
	"letterSpacing", "strokeWidth", "strokeColor"
}

function TextFormat:ctor()
	self.font = ''
	self.size = 12
	self.color = 0
	self.bold = false
	self.italic = false
	self.underline = false
	self.strokeWidth = 0
	self.strokeColor = 0
end

function TextFormat:copyFrom(f2)
	for i=1,#_keys do
		local k = _keys[i]
		local rv = f2[k]
		if rv then self[k] = rv end
	end
end

function TextFormat:clone()
	local c = TextFormat.new()
	c:copyFrom(self)

	return c
end

function TextFormat:equalStyle(f2)
	return self.size == f2.size 
		and self.color==f2.color
		and self.bold == f2.bold 
		and self.underline == f2.underline
		and self.italic == f2.italic
		and self.strokeWidth == f2.strokeWidth
		and self.strokeColor==f2.strokeColor
end

return TextFormat