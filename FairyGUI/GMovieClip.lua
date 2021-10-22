local UISprite = require('UISprite')

GMovieClip = class('GMovieClip', GObject)

local getters = GMovieClip.getters
local setters = GMovieClip.setters

function GMovieClip:ctor()
	GMovieClip.super.ctor(self)

	self._content = UISprite.new(self)
end

function getters:playing() return self._content.playing end
function setters:playing(value)
	self._content.playing = value
	self:updateGear(5)
end

function getters:frame() return self._content.frame end
function setters:frame(value)
	self._content.frame = value
	self:updateGear(5)
end

function getters:color() return self._content.color end
function setters:color(value)
	self._content.color = value
	self:updateGear(4)
end

function getters:timeScale() return self._content.timeScale end
function setters:timeScale(value) 
	self._content.timeScale = value 
end

function GMovieClip:rewind()
	self._content:rewind()
end

function GMovieClip:syncStatus(anotherMc)
	self._content:syncStatus(anotherMc._content)
end

function GMovieClip:advance(time)
	self._content:advance(time)
end

function GMovieClip:setPlaySettings(start, endf, times, endAt)
	self._content:setPlaySettings(start, endf, times, endAt)
end

function GMovieClip:constructFromResource()
	self.packageItem.owner:getItemAsset(self.packageItem)

	self.sourceWidth = self.packageItem.width
	self.sourceHeight = self.packageItem.height
	self.initWidth = self.sourceWidth
	self.initHeight = self.sourceHeight

	self._content:initMovieClip(self.packageItem.interval, self.packageItem.swing, self.packageItem.repeatDelay, self.packageItem.frames)

	local obj = self._content.nativeObject
	obj.gOwner = self
	self.displayObject = obj

	self:setSize(self.sourceWidth, self.sourceHeight)
end

function GMovieClip:setup_BeforeAdd(buffer, beginPos)
	GMovieClip.super.setup_BeforeAdd(self, buffer, beginPos)

	buffer:seek(beginPos, 5)

	if buffer:readBool() then
		self._content.color = buffer:readColor()
	end
	self._content.flip = buffer:readByte()
	self._content.frame = buffer:readInt()
	self._content.playing = buffer:readBool()
end