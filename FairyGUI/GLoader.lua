local UISprite = require('UISprite')

GLoader = class('GLoader', GObject)

local getters = GLoader.getters
local setters = GLoader.setters

function GLoader:ctor()
	GLoader.super.ctor(self)

	self._url = ''
	self._align = 0
	self._verticalAlign = 0
	self._autoSize = false
	self._fill = 0
	self._shrinkOnly = false
	self._updatingLayout = false
	self._contentWidth = 0
	self._contentHeight = 0
	self._contentSourceWidth = 0
	self._contentSourceHeight = 0

	local obj = display.newGroup()
	GRoot._hidden_root:insert(obj)
	obj.anchorX = 0
	obj.anchorY = 0
	obj.gOwner = self
	self.displayObject = obj
	
	local bg = display.newRect(0,0,1,1)
	bg.anchorX = 0
	bg.anchorY = 0
	bg.isVisible = false
	bg.isHitTestable = true
	bg:addEventListener( "touch", self )
	obj:insert(1, bg)
	self._background = bg

	self._content = UISprite.new(self)
end

function getters:url() return self._url end
function setters:url(value)
	if self._url == value then return end

	self._url = value
	self:loadContent()
	self:updateGear(7)
end

function getters:icon() return self._url end
function setters:icon(value) self.url = value end

function getters:color() return self._content.color end
function setters:color(value) self._content.color=value end

function getters:align() return self._align end
function setters:align(value)
	if self._align~=value then
		self._align = value
		self:updateLayout()
	end
end

function getters:verticalAlign() return self._verticalAlign end
function setters:verticalAlign(value)
	if self._verticalAlign~=value then
		self._verticalAlign = value
		self:updateLayout()
	end
end

function getters:fill() return self._fill end
function setters:fill(value)
	if self._fill~=value then
		self._fill = value
		self:updateLayout()
	end
end

function getters:shrinkOnly() return self._shrinkOnly end
function setters:shrinkOnly(value)
	if self._shrinkOnly~=value then
		self._shrinkOnly = value
		self:updateLayout()
	end
end

function getters:autoSize() return self._autoSize end
function setters:autoSize(value)
	if self._autoSize~=value then
		self._autoSize = value
		self:updateLayout()
	end
end

function getters:playing() return self._content.playing end
function setters:playing(value)
	if self._content.playing~=value then
		self._content.playing = value
		self._content2:updateGear(5)
	end
end

function getters:frame() return self._content.frame end
function setters:frame(value)
	if self._content.frame~=value then
		self._content.frame = value
		self._content2:updateGear(5)
	end
end

function getters:timeScale() return self._content.timeScale end
function setters:timeScale(value) self._content.timeScale = value end

function getters:ignoreEngineTimeScale() return self._content.ignoreEngineTimeScale end
function setters:ignoreEngineTimeScale(value) self._content.ignoreEngineTimeScale = value end

function GLoader:advance(time)
	self._content:advance(time)
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
function setters:fillMethod(value) self._content.fillMethod = value end

function getters:fillOrigin() return self._content.fillOrigin end
function setters:fillOrigin(value) self._content.fillOrigin = value end

function getters:fillClockwise() return self._content.fillClockwise end
function setters:fillClockwise(value) self._content.fillClockwise = value end

function getters:fillAmount() return self._content.fillAmount end
function setters:fillAmount(value) self._content.fillAmount = value end

function getters:component() return self._content2 end

function GLoader:loadContent()
	self:clearContent()

	if not self._url or #self._url==0 then return end

	if string.find(self._url, "ui://")==1 then
		self:loadFromPackage(self._url)
	else
		self:loadExternal()
	end
end

function GLoader:loadFromPackage(itemURL)
	self._contentItem = UIPackage.getItemByURL(itemURL)

	if self._contentItem then
		self._contentItem.owner:getItemAsset(self._contentItem)

		if self._contentItem.type == PackageItemType.Image then
			local texture = self._contentItem.owner:getItemAsset(self._contentItem)
			self._content:initImage(texture, self._contentItem.scaleOption, self._contentItem.scale9Grid)
			self._contentSourceWidth = self._contentItem.width
			self._contentSourceHeight = self._contentItem.height
			self:updateLayout()

		elseif self._contentItem.type == PackageItemType.MovieClip then
			self._content:initMovieClip(self._contentItem.interval, self._contentItem.swing, self._contentItem.repeatDelay, self._contentItem.frames)
			self._contentSourceWidth = self._contentItem.width
			self._contentSourceHeight = self._contentItem.height
			self:updateLayout()

		elseif self._contentItem.type == PackageItemType.Component then
			self._contentSourceWidth = self._contentItem.width
			self._contentSourceHeight = self._contentItem.height

			local obj = UIPackage.createObjectFromURL(itemURL)
			if obj == nil then
				self:setErrorState()
			elseif typeof(obj, GComponent) then
				obj:dispose()
				self:setErrorState()
			else
				self._content2 = obj
				self.displayObject:insert(self._content2.displayObject)
				if self.onStage then
					self._content2:broadcast("addedToStage")
				end
				self:updateLayout()
			end
		else
			if self._autoSize then
				self:setSize(self._contentItem.width, self._contentItem.height)
			end

			self:setErrorState()

			print("Unsupported type of GLoader: ".._contentItem.type)
		end

		self:applyEffects()
	else
		self:setErrorState()
	end
end

function GLoader:loadExternal()
	if string.find(self._url, "http://") or string.find(self._url, "https://") then
		local this = self
		local url = self._url
		local listener = function(event)
			if url~=this._url then return end

			if ( event.isError ) then
				print( "Network error - download failed: ", event.response )
				self:onExternalLoadFailed()
			elseif ( event.phase == "ended" ) then
				self:onExternalLoadSuccess({filename=event.response.filename, baseDir=event.response.baseDirectory})
			end
		end

		network.download(url, "GET", listener, nil, "helloCopy.png", system.TemporaryDirectory)
	else
		self:onExternalLoadSuccess({filename=self._url, baseDir=system.ResourceDirectory})
	end
end

function GLoader:freeExternal(texture)
end

function GLoader:onExternalLoadSuccess(texture)
	self._content:initImage(texture)
	if self._content.nativeObject then
		self._contentSourceWidth = self._content.nativeObject.width
		self._contentSourceHeight = self._content.nativeObject.height
		self:updateLayout()
	else
		self:onExternalLoadFailed()
	end
end

function GLoader:onExternalLoadFailed()
	self:setErrorState()
end

function GLoader:setErrorState()
end

function GLoader:clearErrorState()
end

function GLoader:updateLayout()
	if self._content2 == nil and self._content.nativeObject==nil then
		if self._autoSize then
			self._updatingLayout = true
			self:setSize(50, 30)
			self._updatingLayout = false
		end
		return
	end

	self._contentWidth = self._contentSourceWidth
	self._contentHeight = self._contentSourceHeight

	if self._autoSize then
		self._updatingLayout = true
		if self._contentWidth == 0 then
			self._contentWidth = 50
		end
		if self._contentHeight == 0 then
			self._contentHeight = 30
		end
		self:setSize(self._contentWidth, self._contentHeight)

		self._updatingLayout = false

		if self._width == self._contentWidth and self._height == self._contentHeight then
			if self._content2~=nil then
				self._content2:setPosition(self._background.x, self._background.y)
				self._content2:setScale(1, 1)
			else
				self._content:setPosition(self._background.x, self._background.y)
				self._content:setSize(self._contentWidth, self._contentHeight)
			end

			return
		end
		--如果不相等，可能是由于大小限制造成的，要后续处理
	end

	local sx = 1
	local sy = 1
	if self._fill ~= FillType.None then
		sx = self.width / self._contentSourceWidth
		sy = self.height / self._contentSourceHeight

		if sx ~= 1 or sy ~= 1 then
			if self._fill == FillType.ScaleMatchHeight then
				sx = sy
			elseif self._fill == FillType.ScaleMatchWidth then
				sy = sx
			elseif self._fill == FillType.Scale then
				if sx > sy then sx = sy else sy = sx end
			elseif self._fill == FillType.ScaleNoBorder then
				if sx > sy then sy = sx  else sx = sy end
			end

			if self._shrinkOnly then
				if sx > 1 then sx = 1 end
				if sy > 1 then sy = 1 end
			end

			self._contentWidth = math.floor(self._contentSourceWidth * sx)
			self._contentHeight = math.floor(self._contentSourceHeight * sy)
		end
	end

	if self._content2~=nil then
		self._content2:setScale(sx, sy)
	else
		self._content:setSize(self._contentWidth, self._contentHeight)
	end

	local nx
	local ny
	if self._align == AlignType.Center then
		nx = math.floor((self.width - self._contentWidth) / 2)
	elseif self._align == AlignType.Right then
		nx = math.floor(self.width - self._contentWidth)
	else
		nx = 0
	end
	if self._verticalAlign == VertAlignType.Middle then
		ny = math.floor((self.height - self._contentHeight) / 2)
	elseif self._verticalAlign == VertAlignType.Bottom then
		ny = math.floor(self.height - self._contentHeight)
	else
		ny = 0
	end

	nx = nx + self._background.x
	ny = ny + self._background.y

	if self._content2~=nil then
		self._content2:setPosition(nx, ny)
	else
		self._content:setPosition(nx, ny)
	end
end

function GLoader:clearContent()
	self:clearErrorState()

	self._content:clear()
	if self._content2~=nil then
		self._content2:dispose()
		self._content2 = nil
	end
	self._contentItem = nil
end

function GLoader:handleSizeChanged()
	self._background.x = -self._pivotX*self._width
	self._background.y = -self._pivotY*self._height

	if not self._updatingLayout then
		self:updateLayout()
	end
end

function GLoader:handlePivotChanged()
	GLoader.super.handlePivotChanged(self)

	self._background.x = -self._pivotX*self._width
	self._background.y = -self._pivotY*self._height

	if not self._updatingLayout then
		self:updateLayout()
	end
end

function GLoader:setup_BeforeAdd(buffer, beginPos)
	GLoader.super.setup_BeforeAdd(self, buffer, beginPos)

	buffer:seek(beginPos, 5)

	local ct = self._content

	self._url = buffer:readS()
	self._align = buffer:readByte()
	self._verticalAlign = buffer:readByte()
	self._fill = buffer:readByte()
	self._shrinkOnly = buffer:readBool()
	self._autoSize = buffer:readBool()
	self.showErrorSign = buffer:readBool()
	ct.playing = buffer:readBool()
	ct.frame = buffer:readInt()

	if buffer:readBool() then
		ct.color = buffer:readColor()
	end

	ct.fillMethod = buffer:readByte()
	if ct.fillMethod ~= FillMethod.None then
		ct.fillOrigin = buffer:readByte()
		ct.fillClockwise = buffer:readBool()
		ct.fillAmount = buffer:readFloat()
	end

	if self._url~=nil and #self._url>0 then
		self:loadContent()
	end
end