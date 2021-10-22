local UISprite = require('UISprite')

GImage = class('GImage', GObject)

local getters = GImage.getters
local setters = GImage.setters

function GImage:ctor()
	GImage.super.ctor(self)
end

function GImage:dispose()
	if self._disposed then return end

	GImage.super.dispose(self)

	self._isMask = nil
end

function getters:color() 
	return self._content.color
end

function setters:color(value)
	if self._content.color~=value then
		self._content.color = value
		self:updateGear(4)
	end
end

function getters:fillMethod() return self._content.fillMethod end
function setters:fillMethod(value) self._content.fillMethod = value  end

function getters:fillOrigin() return self._content.fillOrigin end
function setters:fillOrigin(value) self._content.fillOrigin = value end

function getters:fillClockwise() return self._content.fillClockwise end
function setters:fillClockwise(value) self._content.fillClockwise = value end

function getters:fillAmount() return self._content.fillAmount end
function setters:fillAmount(value) self._content.fillAmount = value end

function GImage:constructFromResource()
	local texture = self.packageItem.owner:getItemAsset(self.packageItem)

	self.sourceWidth = self.packageItem.width
	self.sourceHeight = self.packageItem.height
	self.initWidth = self.sourceWidth
	self.initHeight = self.sourceHeight

	self._content = UISprite.new(self)

	if not self.packageItem.is_mask then
		self._content:initImage(texture, self.packageItem.scaleOption, self.packageItem.scale9Grid)

		local obj = self._content.nativeObject
		obj.gOwner = self
		self.displayObject = obj
	else
		self._isMask = graphics.newMask(texture.filename, texture.baseDir)
	end
	
	self:setSize(self.sourceWidth, self.sourceHeight)
end

function GImage:setup_BeforeAdd(buffer, beginPos)
	GImage.super.setup_BeforeAdd(self, buffer, beginPos)

	buffer:seek(beginPos, 5)

	local ct = self._content

	if buffer:readBool() then
		ct.color = buffer:readColor()
	end
	ct.flip = buffer:readByte()
	ct.fillMethod = buffer:readByte()
	if ct.fillMethod ~= FillMethod.None then
		ct.fillOrigin = buffer:readByte()
		ct.fillClockwise = buffer:readBool()
		ct.fillAmount = buffer:readFloat()
	end
end
