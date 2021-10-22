local HtmlElementType = require('Utils.HtmlParser').ElementType

GRichTextField = class('GRichTextField', GTextField)

local getters = GRichTextField.getters
local setters = GRichTextField.setters

function GRichTextField:ctor()
	GRichTextField.super.ctor(self)
end

function GRichTextField:createObject(element)
	if element.type==HtmlElementType.Image then
		local loader = GLoader.new()
		local w
		local h
		local src = element.attrs.src
		if src then 
			local pi = UIPackage.getItemByURL(src)
			if pi then
				w = pi.width
				h = pi.height
			end
		end
		w = w or element.attrs.width or 10
		h = h or element.attrs.height or 10
		loader.url = src
		loader:setSize(w, h)
		return loader
	end
end