local tools = require('Utils.ToolSet')
local generateFillMesh = require('Utils.FillMesh')
local UISprite = class('UISprite')

local getters = UISprite.getters
local setters = UISprite.setters

local ZERO_ARRAY_4 = { 0,0,0,0,0,0,0,0 }
local ZERO_ARRAY_8 = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
local ZERO_ARRAY_16 = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

local UVS_SIMPLE = { { 0,1,0,0,1,0,1,1 }, { 1,1,1,0,0,0,0,1 }, {0,0,0,1,1,1,1,0}, {1,0,1,1,0,1,0,0} }
local TRIANGLES_4 = { 0,1,2,0,2,3 }
local TRIANGLES_8 = { 0,1,2,0,2,3, 4,5,6,4,6,7 }
local TRIANGLES_16 = { 0,1,2,0,2,3, 4,5,6,4,6,7, 8,9,10,8,10,11, 12,13,14,12,14,15 }
local TRIANGLES_SLICED = {
	4,0,1,1,5,4,
	5,1,2,2,6,5,
	6,2,3,3,7,6,
	8,4,5,5,9,8,
	9,5,6,6,10,9,
	10,6,7,7,11,10,
	12,8,9,9,13,12,
	13,9,10,10,14,13,
	14,10,11,
	11,15,14
}

function UISprite:ctor(owner)
	self.timeScale = 1

	self._owner = owner
	self._width = 100
	self._height = 100
	self._scaleX = 1
	self._scaleY = 1
	self._flip = 0
	self._playing = true
	self._frame = 0
	self._frameCount = 0
	self._color = 0xFFFFFF
	self._fillMethod = 0
	self._objType = 0
	self._isDisplayObj = self._owner.class==GImage or self._owner.class==GMovieClip
end

function UISprite:initImage(texture, scaleOption, scale9Grid)
	self._texture = texture

	if scaleOption==1 then
		self._scale9Grid = scale9Grid
		self._objType = 3
		self:newRenderer(self:slicedMesh())

	elseif scaleOption==2 then
		display.setDefault( "textureWrapX", "repeat" )
		display.setDefault( "textureWrapY", "repeat" )

		self._objType = 4
		self:newRenderer(self:repeatMesh())
		self:setRepeatParams()

		display.setDefault( "textureWrapX", "clampToEdge" )
		display.setDefault( "textureWrapY", "clampToEdge" )
	elseif not texture.width then --for remote image
		self._objType = 2
		self:setNativeObject(display.newImageRect(texture.filename, texture.baseDir, self._width, self._height))
	elseif self._fillMethod~=0 then
		self._objType = 4 + self._fillMethod
		self:newRenderer(self:fillMesh())
		self:updateFillMesh()
	else
		self._objType = 1
		self:newRenderer(self:simpleMesh())
	end
end

function UISprite:initMovieClip(interval, swing, repeatDelay, frames)
	self.interval = interval
	self.repeatDelay = repeatDelay
	self.swing = swing
	self._frames = frames
	self._frameCount = #frames
	
	if self._status==nil then
		self:setPlaySettings(0,-1,0,-1)
	else
		if self._end == -1 or self._end > self._frameCount - 1 then
			self._end = self._frameCount - 1
		end
		if self._endAt == -1 or self._endAt > self._frameCount - 1 then
			self._endAt = self._frameCount - 1
		end
	end

	if self._frame < 0 or self._frame > self._frameCount - 1 then
		self._frame = self._frameCount - 1
	end

	self._frameElapsed = 0
	self._repeatedCount = 0
	self._reversed = false

	if self._frameCount>0 then
		self._texture = self._frames[1].texture
		self._objType = 1
		self:newRenderer(self:simpleMesh())
		self:drawFrame()
		self:checkTimer()
	else
		self:clear()
	end
end

function UISprite:clear()
	if self.nativeObject then	
		self.nativeObject.fill = nil
	end
	self._frames = nil
	self._texture = nil
	self._objType = 0

	self._owner:cancelFrameLoop(self.enterFrame, self)
end

function UISprite:setPosition(x, y)
	self.nativeObject.x = x
	self.nativeObject.y = y
end

function UISprite:setSize(w, h)
	if self._width==w and self._height==h then return end

	self._width = w
	self._height = h

	if not self.nativeObject then return end

	if self._objType==2 then
		self.nativeObject.width = w
		self.nativeObject.height = h
	elseif self._objType==3 then
		self:updateSlicedMesh()
		if self._isDisplayObj then
			self:setAnchor(self._owner._pivotX, self._owner._pivotY)
		end
	elseif self._objType==4 then
		self:updateRepeatMesh()
		self:setRepeatParams()
		if self._isDisplayObj then
			self:setAnchor(self._owner._pivotX, self._owner._pivotY)
		end
	else
		self:applyScale()
	end
end

function UISprite:setScale(x, y)
	self._scaleX = x
	self._scaleY = y

	if self.nativeObject then
		self:applyScale()
	end
end

function UISprite:setAnchor(x, y)
	local obj = self.nativeObject
	if obj then
		obj.anchorX = x * (self._width / self._sourceWidth)
		obj.anchorY = y * (self._height / self._sourceHeight)
	end
end

function UISprite:applyScale()
	local scaleX
	local scaleY
	if self._objType==1  or self._objType>=5 then
		local w = self._texture.sourceWidth or self._texture.width
		local h = self._texture.sourceHeight or self._texture.height

		scaleX = self._width/w*self._scaleX
		scaleY = self._height/h*self._scaleY
	else
		scaleX = self._scaleX
		scaleY = self._scaleY
	end

	if scaleX==0 or scaleY==0 then
		self.nativeObject.xScale = 0.00001
		self.nativeObject.yScale = 0.00001
	else
		self.nativeObject.xScale = scaleX
		self.nativeObject.yScale = scaleY
	end
end

function getters:color()
	return self._color
end

function setters:color(value)
	if self._color ~= value then
		self._color = value
		if self.nativeObject then
			self.nativeObject:setFillColor(tools.unpackColor(self._color))
		end
	end
end

function getters:flip()
	return self._flip
end

function setters:flip(value)
	if self._flip ~= value then
		self._flip = value

		if not self.nativeObject then return end

		if self._objType==1 then
			self:updateSimpleMesh()
		elseif self._objType==3 then
			self:updateSlicedMesh()
		elseif self._objType==4 then
			self:updateRepeatMesh()
			self:setRepeatParams()
		elseif self._objType>=5 then
			self:updateFillMesh()
		end
	end
end

function getters:fillMethod()
	return self._fillMethod
end

function setters:fillMethod(value)
	if self._fillMethod~=value then
		if self._objType==2 or self._objType==3 or self._objType==4 then
			return --not supported
		end

		self._fillMethod = value
		if self._fillMethod==0 then
			self._objType = 1
			self:newRenderer(self:simpleMesh())
		else
			self._objType = 4+self._fillMethod
			self:newRenderer(self:fillMesh())
			self:updateFillMesh()
		end
	end
end

function getters:fillOrigin()
	return self._fillOrigin
end

function setters:fillOrigin(value)
	if self._fillOrigin~=value then
		self._fillOrigin = value
		self:updateFillMesh()
	end
end

function getters:fillClockwise()
	return self._fillClockwise
end

function setters:fillClockwise(value)
	if self._fillClockwise~=value then
		self._fillClockwise = value
		self:updateFillMesh()
	end
end

function getters:fillAmount()
	return self._fillAmount
end

function setters:fillAmount(value)
	if self._fillAmount~=value then
		self._fillAmount = value
		self:updateFillMesh()
	end
end

function getters:playing()
	return self._playing
end

function setters:playing(value)
	if self._playing ~= value then
		self._playing = value
		self:checkTimer()
	end
end

function getters:frame()
	return self._frame
end

function setters:frame(value)
	if self._frame ~= value then
		if self._frames ~= nil and value >= self._frameCount then
			value = self._frameCount - 1
		end

		self._frame = value
		self._frameElapsed = 0
		self:drawFrame()
	end
end

function UISprite:rewind()
	self._frame = 0
	self._frameElapsed = 0
	self._reversed = false
	self._repeatedCount = 0
	self:drawFrame()
end

function UISprite:syncStatus(anotherMc)
	self._frame = anotherMc._frame
	self._frameElapsed = anotherMc._frameElapsed
	self._reversed = anotherMc._reversed
	self._repeatedCount = anotherMc._repeatedCount
	self:drawFrame()
end

function UISprite:advance(time)
	local beginFrame = self._frame
	local beginReversed = self._reversed
	local backupTime = time
	while (true) do
		local tt = self.interval + self._frames[self._frame+1].addDelay
		if self._frame == 0 and self._repeatedCount > 0 then
			tt = tt + self.repeatDelay
		end
		if time < tt then
			self._frameElapsed = 0
			break
		end

		time = time - tt

		if self.swing then
			if self._reversed then
				self._frame = self._frame - 1
				if self._frame <= 0 then
					self._frame = 0
					self._repeatedCount = self._repeatedCount+1
					self._reversed = not self._reversed
				end
			else
				self._frame = self._frame+1
				if self._frame > self._frameCount - 1 then
					self._frame = math.max(0, self._frameCount - 2)
					self._repeatedCount = self._repeatedCount+1
					self._reversed = not self._reversed
				end
			end
		else
			self._frame = self._frame+1
			if self._frame > self._frameCount - 1 then
				self._frame = 0
				self._repeatedCount = self._repeatedCount+1
			end
		end

		if self._frame == beginFrame and self._reversed == beginReversed then --走了一轮了
			local roundTime = backupTime - time --这就是一轮需要的时间
			time = time - math.floor(time / roundTime) * roundTime --跳过
		end
	end

	self:drawFrame()
end

function UISprite:setPlaySettings(start, endf, times, endAt)
	self._start = start
	self._end = endf
	if self._end == -1 or self._end > self._frameCount - 1 then
		self._end = self._frameCount - 1
	end
	self._times = times
	self._endAt = endAt
	if self._endAt == -1 then
		self._endAt = self._end
	end
	self._status = 0

	self.frame = start
end

function UISprite:checkTimer()
	if self._playing and self._frameCount > 0 then
		self._owner:frameLoop(self.enterFrame, self)
	else
		self._owner:cancelFrameLoop(self.enterFrame, self)
	end
end

function UISprite:enterFrame(dt)
	if not self._playing or self._frameCount == 0 or self._status == 3 then return end

	if self.timeScale ~= 1 then dt = dt * self.timeScale end

	self._frameElapsed = self._frameElapsed + dt
	local  tt = self.interval + self._frames[self._frame+1].addDelay
	if self._frame == 0 and self._repeatedCount > 0 then
		tt = tt + self.repeatDelay
	end
	if self._frameElapsed < tt then return end

	self._frameElapsed = self._frameElapsed - tt
	if self._frameElapsed > self.interval then
		self._frameElapsed = self.interval
	end

	if self.swing then
		if self._reversed then
			self._frame = self._frame-1
			if self._frame <= 0 then
				self._frame = 0
				self._repeatedCount = self._repeatedCount+1
				self._reversed = not self._reversed
			end
		else
			self._frame = self._frame+1
			if self._frame > self._frameCount - 1 then
				self._frame = math.max(0, _frameCount - 2)
				self._repeatedCount = self._repeatedCount+1
				self._reversed = not self._reversed
			end
		end
	else
		self._frame = self._frame+1
		if self._frame > self._frameCount - 1 then
			self._frame = 0
			self._repeatedCount = self._repeatedCount+1
		end
	end

	if self._status == 1 then --new loop
		self._frame = self._start
		self._frameElapsed = 0
		self._status = 0
		self:drawFrame()
	elseif self._status == 2 then --ending
		self._frame = self._endAt
		self._frameElapsed = 0
		self._status = 3 --ended
		self:drawFrame()
		self._owner:emit("playEnd")
	else
		self:drawFrame()
		if self._frame == self._end then
			if self._times > 0 then
				self._times = self._times-1
				if self._times == 0 then
					self._status = 2  --ending
				else
					self._status = 1 --new loop
				end
			elseif self._start~=0 then
				self._status = 1 --new loop
			end
		end
	end
end

function UISprite:drawFrame()
	if self._frameCount > 0 then
		local texture = self._frames[self._frame+1].texture
		if texture then
			local path = self.nativeObject.path
			path:setVertex(1, texture.sourceX, texture.sourceY+texture.height)
			path:setVertex(2, texture.sourceX, texture.sourceY)
			path:setVertex(3, texture.sourceX+texture.width, texture.sourceY)
			path:setVertex(4, texture.sourceX+texture.width, texture.sourceY+texture.height)
		end

		self.nativeObject.fill.frame = texture.frame
	end
end

function UISprite:newRenderer(vertices, uvs, indices)
	local mesh = {
		mode = "indexed",
		zeroBasedIndices = true,
		vertices = vertices,
		uvs = uvs,
		indices = indices
	}

	local newObj = display.newMesh(GRoot._hidden_root, mesh)
	newObj.fill = self._texture

	self:setNativeObject(newObj)
	self:applyScale()
end

function UISprite:setNativeObject(newObj)
	local oldObj = self.nativeObject
	self.nativeObject = newObj

	if not newObj then
		if oldObj then
			if self._isDisplayObj then
				self._owner:replaceDisplayObject(nil)
			else
				oldObj:removeSelf()
				oldObj = nil
			end
		end
		return
	end

	newObj:setFillColor(tools.unpackColor(self._color))
	self._sourceWidth = self._width
	self._sourceHeight = self._height

	local this = self
	newObj.setSize = function(w, h)
		this:setSize(w, h)
	end
	newObj.setScale = function(x, y)
		this:setScale(x, y)
	end

	if self._objType~=1 and self._objType~=2 then
		newObj.setAnchor = function(x, y)
			this:setAnchor(x, y)
		end
	end

	if self._isDisplayObj then
		self._owner:replaceDisplayObject(newObj)
	else
		newObj.anchorX = 0
		newObj.anchorY = 0

		if oldObj then
			oldObj:removeSelf()
			oldObj = nil
		end

		self._owner.displayObject:insert(newObj)
	end
end

function UISprite:simpleMesh()
	local w = self._texture.sourceWidth or self._texture.width
	local h = self._texture.sourceHeight or self._texture.height

	return { 0,h, 0,0, w,0, w,h },  UVS_SIMPLE[self._flip+1], TRIANGLES_4
end

function UISprite:updateSimpleMesh()
	local path = self.nativeObject.path
	local uvs = UVS_SIMPLE[self._flip+1]
	path:setUV(1, uvs[1], uvs[2])
	path:setUV(2, uvs[3], uvs[4])
	path:setUV(3, uvs[5], uvs[6])
	path:setUV(4, uvs[7], uvs[8])
end

function UISprite:repeatMesh()
	local w = self._width
	local h = self._height
	return { 0,h, 0,0, w,0,w, h },  UVS_SIMPLE[self._flip+1], TRIANGLES_4
end

function UISprite:updateRepeatMesh()
	local path = self.nativeObject.path
	local w = self._width
	local h = self._height
	path:setVertex(1, 0, h)
	path:setVertex(2, 0, 0)
	path:setVertex(3, w, 0)
	path:setVertex(4, w, h)

	local uvs = UVS_SIMPLE[self._flip+1]
	path:setUV(1, uvs[1], uvs[2])
	path:setUV(2, uvs[3], uvs[4])
	path:setUV(3, uvs[5], uvs[6])
	path:setUV(4, uvs[7], uvs[8])
end

function UISprite:setRepeatParams()
	local obj = self.nativeObject
	obj.fill.x = -(self._width%self._texture.width)/self._texture.width*0.5
	obj.fill.y = (self._height%self._texture.height)/self._texture.height*0.5
	obj.fill.scaleX = self._texture.width/self._width
	obj.fill.scaleY = self._texture.height/self._height
end

local _gridX = {}
local _gridY = {}
local _gridTexX = {}
local _gridTexY = {}
local _gridRect = {}

function UISprite:generateGrids()
	local gridRect = _gridRect
	gridRect.x = self._scale9Grid.x
	gridRect.y = self._scale9Grid.y
	gridRect.width = self._scale9Grid.width
	gridRect.height = self._scale9Grid.height

	local sourceW = self._texture.width
	local sourceH = self._texture.height

	if self._flip ~= FlipType.None then
		if self._flip == FlipType.Horizontal or self._flip == FlipType.Both then
			gridRect.x = sourceW - (gridRect.x + gridRect.width)
		end

		if self._flip == FlipType.Vertical or self._flip == FlipType.Both then
			gridRect.y = sourceH - (gridRect.y + gridRect.height)
		end
	end

	local sx = 1 / sourceW
	local sy = 1 / sourceH
	local xMax2 = gridRect.x+gridRect.width
	local yMax2 = gridRect.y+gridRect.height

	_gridTexX[1] = 0
	_gridTexX[2] = gridRect.x * sx
	_gridTexX[3] = xMax2 * sx
	_gridTexX[4] = 1

	_gridTexY[1] = 0
	_gridTexY[2] = gridRect.y * sy
	_gridTexY[3] = yMax2 * sy
	_gridTexY[4] = 1

	_gridX[1] = 0
	_gridY[1] = 0
	if self._width >= (sourceW - gridRect.width) then
		_gridX[2] = gridRect.x
		_gridX[3] = self._width - (sourceW - xMax2)
		_gridX[4] = self._width
	else
		local tmp = gridRect.x / (sourceW - xMax2)
		tmp = self._width * tmp / (1 + tmp)
		_gridX[2] = tmp
		_gridX[3] = tmp
		_gridX[4] = self._width
	end

	if self._height >= (sourceH - gridRect.height) then
		_gridY[2] = gridRect.y
		_gridY[3] = self._height - (sourceH - yMax2)
		_gridY[4] = self._height
	else
		local tmp = gridRect.y / (sourceH - yMax2)
		tmp = self._height * tmp / (1 + tmp)
		_gridY[2] = tmp
		_gridY[3] = tmp
		_gridY[4] = self._height
	end
end

function UISprite:slicedMesh()
	self:generateGrids()

	local vertices = {}
	local uvs = {}

	for cy=1,4 do
		for cx=1,4 do
			table.insert(vertices, _gridX[cx])
			table.insert(vertices, _gridY[cy])

			table.insert(uvs, _gridTexX[cx])
			table.insert(uvs, _gridTexY[cy])
		end
	end
	
	return vertices, uvs, TRIANGLES_SLICED
end

function UISprite:updateSlicedMesh()
	local path = self.nativeObject.path
	self:generateGrids()
	local i=1
	for cy=1,4 do
		for cx=1,4 do
			path:setVertex(i, _gridX[cx], _gridY[cy])
			path:setUV(i, _gridTexX[cx], _gridTexY[cy])
			i = i+1
		end
	end
end

function UISprite:fillMesh()
	local method = self._fillMethod
	if method==FillMethod.Horizontal or method==FillMethod.Vertical or method==FillMethod.Radial90 then
		return self:simpleMesh()
	elseif method==FillMethod.Radial180 then
		return ZERO_ARRAY_8,  ZERO_ARRAY_8, TRIANGLES_8
	elseif self._fillMethod==FillMethod.Radial360 then
		return ZERO_ARRAY_16,  ZERO_ARRAY_16, TRIANGLES_16
	end
end

function UISprite:updateFillMesh()
	if self._fillMethod==0 then return end

	self._owner:delayedCall(self._updateFillMesh, self)
end

function UISprite:_updateFillMesh()
	if self._fillMethod==0 then return end

	local w = self._texture.sourceWidth or self._texture.width
	local h = self._texture.sourceHeight or self._texture.height
	generateFillMesh(self.nativeObject.path, w, h, self._fillMethod, self._fillOrigin, self._fillAmount, self._fillClockwise)
end

return UISprite