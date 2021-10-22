local ByteBuffer = require('Utils.ByteBuffer')
local PixelHitTest = require('Utils.PixelHitTest')

UIPackage = class('UIPackage')

UIPackage.all = {}
UIPackage._constructing = 0

function UIPackage.addPackage(assetPath, baseDir)
	baseDir = baseDir or system.ResourceDirectory
	local pkg = UIPackage.new()

	local path = system.pathForFile(assetPath..'.fui', baseDir)
	local file, errorString = io.open( path, "rb" )
	assert(not errorString)
	local buffer = ByteBuffer.new(file:read('*a'))
	file:close()

	pkg.assetPath = assetPath
	pkg.baseDir = baseDir
	pkg:load(buffer)
	UIPackage.all[pkg.id] = pkg
	UIPackage.all[pkg.name] = pkg
	UIPackage.all[pkg.assetPath] = pkg
	return pkg
end

function UIPackage.removePackage(idOrName)
	local pkg = UIPackage.all[idOrName]
	assert(pkg, 'pkg not exists')

	pkg:dispose()
	UIPackage.all[pkg.id] = nil
	UIPackage.all[pkg.name] = nil
	UIPackage.all[pkg.assetPath] = nil
end

function UIPackage.get(idOrName)
	return UIPackage.all[idOrName]
end

function UIPackage.createObject(pkgName, resName)
	local pkg = UIPackage.all[pkgName]
	if pkg then
		return pkg:_createObject(resName)
	else
		return nil
	end
end

function UIPackage.createObjectFromURL(url)
	local pi = UIPackage.getItemByURL(url)
	if pi then
		return pi.owner:_createObject2(pi)
	else
		return nil
	end
end

function UIPackage.getItemAssetByURL(url)
	local pi = UIPackage.getItemByURL(url)
	if pi then
		return pi.owner:getItemAsset(pi)
	else
		return nil
	end
end

function UIPackage.getItemURL(pkgName, resName)
	local pkg = UIPackage.all[pkgName]
	if not pkg then return nill end

	local pi = pkg._itemsByName[resName]
	if not pi then return nil end

	return 'ui://'..pkg.id..pi.id
end

function UIPackage.getItemByURL(url)
	if not url then return nil end

	local pos1 = string.find(url, '//', 1, true)
	if not pos1 then return nil end

	local pos2 = string.find(url, '/', pos1+2, true)
	if not pos2 then
		if string.len(url)>13 then
			local pkgId = string.sub(url, 6, 13)
			local pkg = UIPackage.all[pkgId]
			if pkg then
				local srcId = string.sub(url, 14)
				return pkg:getItem(srcId)
			end
		end
	else
		local pkgName = string.sub(url, pos1+2, pos2-1)
		local pkg = UIPackage.all[pkgName]
		if pkg then
			local srcName = string.sub(url, pos2+1)
			return pkg:getItemByName(srcName)
		end
	end

	return nil
end

function UIPackage.normalizeURL(url)
	if not url then return nil end

	local pos1 = string.find(url, '//', 1, true)
	if not pos1 then return nil end

	local pos2 = string.find(url, '/', pos1+2, true)
	if not pos2 then return url end

	local pkgName = string.sub(url, pos1+2, pos2-1)
	local srcName = string.sub(url, pos2+1)
	return UIPackage.getItemURL(pkgName, srcName)
end

function UIPackage:ctor()
	self._itemsById = {}
	self._itemsByName = {}
	self._sprites = {}
end

function UIPackage:dispose()
	local cnt = #self._itemsById
	for i=1,cnt do
		local pi = self._itemsById[i]
	end

	self._itemsById = nil
	self._itemsByName = nil
end

function UIPackage:load(buffer)
	assert(buffer:readUint() == 0x46475549, 'invalid package format')

	buffer.version = buffer:readInt()
	buffer:readBool()
	self.id = buffer:readString()
	self.name = buffer:readString()
	buffer:skip(20)

	local indexTablePos = buffer.pos
	local cnt

	buffer:seek(indexTablePos, 4)

	cnt = buffer:readInt()
	local stringTable = {}
	for i=1,cnt do
		stringTable[i] = buffer:readString()
	end
	buffer.stringTable = stringTable

	if buffer:seek(indexTablePos, 5) then
		cnt = buffer:readInt()
		for i=1,cnt do
			local index = buffer:readUshort()
			local len = buffer:readInt()
			stringTable[index] = buffer:readString(len)
		end
	end

	buffer:seek(indexTablePos, 1)

	cnt = buffer:readShort()
	for i=1,cnt do
		local nextPos = buffer:readInt()
		nextPos = nextPos + buffer.pos

		local pi = {}
		pi.owner = self
		pi.type = buffer:readByte()
		pi.id = buffer:readS()
		pi.name = buffer:readS('')
		buffer:readS()
		pi.file = buffer:readS()
		pi.exported = buffer:readBool()
		pi.width = buffer:readInt()
		pi.height = buffer:readInt()

		if pi.type==PackageItemType.Image then
			pi.objectType = ObjectType.Image
			pi.scaleOption = buffer:readByte()
			if pi.scaleOption==1 then
				pi.scale9Grid = buffer:readRect()
				pi.tileGridIndice = buffer:readInt()
			end

			buffer:readBool() --smoothing
		elseif pi.type==PackageItemType.MovieClip then
			buffer:readBool() --smoothing
			pi.objectType = ObjectType.MovieClip
			pi.rawData = buffer:readBuffer()

		elseif pi.type==PackageItemType.Font then
			pi.rawData = buffer:readBuffer()

		elseif pi.type==PackageItemType.Component then
			local extension = buffer:readByte()
			if extension>0 then
				pi.objectType = extension
			else
				pi.objectType = ObjectType.Component
			end
			pi.rawData = buffer:readBuffer()

			UIObjectFactory.resolveExtension(pi)
		elseif pi.file then
			pi.file = self.assetPath..'_'..pi.file
		end

		self._itemsById[pi.id] = pi
		if #pi.name>0 then
			self._itemsByName[pi.name] = pi
		end

		buffer.pos = nextPos
	end

	buffer:seek(indexTablePos, 2)

	cnt = buffer:readShort()
	for i=1,cnt do
		local nextPos = buffer:readShort()
		nextPos = nextPos + buffer.pos

		local sprite = { type='image' }
		local itemId = buffer:readS()
		sprite.atlas = self._itemsById[buffer:readS()]
		buffer:readRect(sprite)
		sprite.rotated = buffer:readBool()
		self._sprites[itemId] = sprite

		buffer.pos = nextPos
	end

	if buffer:seek(indexTablePos, 3) then
		cnt = buffer:readShort()
		for i=1,cnt do
			local nextPos = buffer:readInt()
			nextPos = nextPos + buffer.pos

			local pi = self._itemsById[buffer:readS()]
			if pi and pi.type==PackageItemType.Image then
				pi.pixelHitTestData = PixelHitTest.parse(buffer)
			end

			buffer.pos = nextPos
		end
	end
end

function UIPackage:_createObject(resName)
	local pi = self._itemsByName[resName]
	if not pi then return nil end

	return self:_createObject2(pi)
end

function UIPackage:_createObject2(item)
	self:getItemAsset(item)

	local g = UIObjectFactory.newObject(item)
	if not g then return nil end

	UIPackage._constructing = UIPackage._constructing+1
	g.packageItem = item
	g:constructFromResource()
	UIPackage._constructing = UIPackage._constructing-1

	return g
end

function UIPackage:getItem(itemId)
	return self._itemsById[itemId]
end

function UIPackage:getItemByName(itemName)
	return self._itemsByName[itemName]
end

function UIPackage:getTexture(spriteId)
	local sprite = self._sprites[spriteId]
	if sprite then self:getItemAsset(sprite.atlas) end
	return sprite
end

function UIPackage:getItemAsset(item)
	if item.type==PackageItemType.Image then
		if not item.texture then item.texture = self:getTexture(item.id) end
		return item.texture

	elseif item.type==PackageItemType.MovieClip then
		if not item.frames then self:loadMovieClip(item) end

	elseif item.type==PackageItemType.Atlas then
		if not item.loaded then self:loadAtlas(item) end
		return item.sheet

	elseif item.type==PackageItemType.Sound then
		if not item.sound then item.sound = audio.loadSound(item.file, self.baseDir) end
		return item.sound

	elseif item.type==PackageItemType.Font then
		if not item.font then self:loadFont(item) end
		return item.font
	end
end

function UIPackage:loadAtlas(item)
	item.loaded = true
	local frames = {}
	local ss2
	local itemId2
	for itemId,ss in pairs(self._sprites) do
		if ss.atlas==item then
			table.insert(frames, {x=ss.x,y=ss.y,width=ss.width,height=ss.height})
			ss.frame = #frames
			ss2 = ss
			itemId2 = itemId
		end
	end
	local options
	if #frames==1 then --平铺的，和作为遮罩的图片，要求单独载入
		local item2 = self._itemsById[itemId2]
		if item2 and (item2.scaleOption==2 or item2.is_mask) then
			ss2.filename = item.file
			ss2.baseDir = self.baseDir
			return
		end
	end

	item.sheet = graphics.newImageSheet(item.file, self.baseDir, { frames=frames })
	for _,ss in pairs(self._sprites) do
		if ss.atlas==item then
			ss.sheet = item.sheet
		end
	end
end

function UIPackage:loadMovieClip(item)
	local buffer = item.rawData

	buffer:seek(0,0)
	item.interval = buffer:readInt() * 0.001
	item.swing = buffer:readBool()
	item.repeatDelay = buffer:readInt() * 0.001
	local frames = {}
	item.frames = frames

	buffer:seek(0,1)
	local cnt = buffer:readShort()

	for i=1,cnt do
		local nextPos = buffer:readShort()
		nextPos = nextPos + buffer.pos
		local frame = {}
		local sourceX = buffer:readInt()
		local sourceY = buffer:readInt()
		buffer:skip(8)
		frame.addDelay = buffer:readInt() * 0.001
		local spriteId = buffer:readS()
		if spriteId and string.len(spriteId)>0 then
			frame.texture = self:getTexture(spriteId)
			if frame.texture then
				frame.texture.sourceWidth = item.width
				frame.texture.sourceHeight = item.height
				frame.texture.sourceX = sourceX
				frame.texture.sourceY = sourceY
			end
		end

		table.insert(frames, frame)
	end
end

function UIPackage:loadFont(item)
	local font = {}
	item.font = font
	local buffer = item.rawData

	buffer:seek(0, 0)

	local ttf = buffer:readBool()
	font.canTint = buffer:readBool()
	font.resizable = buffer:readBool()
	font.hasChannel = buffer:readBool()
	font.size = buffer:readInt()
	local xadvance = buffer:readInt()
	local lineHeight = buffer:readInt()

	local glyphs = {}
	font.glyphs = glyphs

	local frames
	local sprite
	if ttf then
		frames = {}
		sprite = self._sprites[item.id]
		assert(sprite, 'cannot load font:'..item.name)
	end

	buffer:seek(0, 1)

	local glyph
	local cnt = buffer:readInt()
	for i=1,cnt do
		local nextPos = buffer:readShort()
		nextPos = nextPos + buffer.pos

		glyph = {}
		local ch = buffer:readUshort()
		glyphs[ch] = glyph

		local img = buffer:readS()
		local bx = buffer:readInt()
		local by = buffer:readInt()
		glyph.offsetX = buffer:readInt()
		glyph.offsetY = buffer:readInt()
		glyph.width = buffer:readInt()
		glyph.height = buffer:readInt()
		glyph.advance = buffer:readInt()
		glyph.channel = buffer:readByte()
		--The texture channel where the character image is found (1 = blue, 2 = green, 4 = red, 8 = alpha).
		if (glyph.channel == 1) then
			glyph.channel = 2
		elseif (glyph.channel == 2) then
			glyph.channel = 1
		elseif (glyph.channel == 3) then
			glyph.channel = 0
		elseif (glyph.channel == 8) then
			glyph.channel = 3
		end

		if ttf then
			local frame = {
				x = bx + sprite.x,
				y = by + sprite.y,
				width = glyph.width,
				height = glyph.height
			}
			table.insert(frames, frame)
			glyph.lineHeight = lineHeight
			glyph.frame = #frames
		else
			sprite = self:getTexture(img)
			if sprite then
				glyph.width = sprite.width
				glyph.height = sprite.height
				glyph.sheet =  sprite.sheet
				glyph.frame = sprite.frame
			end

			if font.size == 0 then
				font.size = glyph.height
			end

			if glyph.advance == 0 then
				if xadvance == 0 then
					glyph.advance = glyph.offsetX + glyph.width
				else
					glyph.advance = xadvance
				end
			end

			glyph.lineHeight = glyph.offsetY < 0 and glyph.height or (glyph.offsetY + glyph.height)
			if glyph.lineHeight < font.size then
				glyph.lineHeight = font.size
			end
		end

		buffer.pos = nextPos
	end

	if ttf then
		item.sheet = graphics.newImageSheet(sprite.atlas.file, self.baseDir, {frames=frames})

		for _,v in pairs(glyphs) do
			v.sheet = item.sheet
		end
	end
end