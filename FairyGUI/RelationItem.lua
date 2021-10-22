local RelationItem = class('RelationItem')

function RelationItem:ctor(owner)
	self._owner = owner
	self._defs = {}
	self._targetData = {}
end

function RelationItem:setTarget(value)
	if self.target == value then return end
	if self.target~=nil then
		self:releaseRefTarget(self.target)
	end
	self.target = value
	if self.target~=nil then
		self:addRefTarget(self.target)
	end
end

function RelationItem:add(relationType, usePercent)
	if relationType == RelationType.Size then
		self:add(RelationType.Width, usePercent)
		self:add(RelationType.Height, usePercent)
		return
	end

	local dc = #self._defs
	for k=1,dc do
		if self._defs[k].type == relationType then
			return
		end
	end

	self:internalAdd(relationType, usePercent)
end

function RelationItem:internalAdd(relationType, usePercent)
	if relationType == RelationType.Size then
		self:internalAdd(RelationType.Width, usePercent)
		self:internalAdd(RelationType.Height, usePercent)
		return
	end

	local info = {}
	info.percent = usePercent
	info.type = relationType
	if (relationType <= RelationType.Right_Right or relationType == RelationType.Width or relationType >= RelationType.LeftExt_Left and relationType <= RelationType.RightExt_Right) then
		info.axis = 0
	else
		info.axis = 1
	end
	table.insert(self._defs, info)

	--当使用中线关联时，因为需要除以2，很容易因为奇数宽度/高度造成小数点坐标；当使用百分比时，也会造成小数坐标；
	--所以设置了这类关联的对象，自动启用pixelSnapping
	if (usePercent or relationType == RelationType.Left_Center or relationType == RelationType.Center_Center or relationType == RelationType.Right_Center
			or relationType == RelationType.Top_Middle or relationType == RelationType.Middle_Middle or relationType == RelationType.Bottom_Middle) then
		self._owner.pixelSnapping = true
	end
end

function RelationItem:remove(relationType)
	if relationType == RelationType.Size then
		self:remove(RelationType.Width)
		self:remove(RelationType.Height)
		return
	end

	local dc = #self._defs
	for k=1,dc do
		if self._defs[k].type == relationType then
			table.remove(self._defs, k)
			break
		end
	end
end

function RelationItem:copyFrom(source)
	self:setTarget(source.target)

	self._defs = {}
	for _, info in ipairs(source._defs) do
		local info2 = {}
		info2.percent = info.percent
		info2.type = info.type
		info2.axis = info.axis
		table.insert(self._defs, info2)
	end
end

function RelationItem:dispose()
	if self.target~=nil then
		self:releaseRefTarget(self.target)
		self.target = nil
	end
end

function RelationItem:isEmpty()
	return #self._defs == 0 
end

function RelationItem:applyOnSelfSizeChanged(dWidth, dHeight, applyPivot)
	local cnt = #self._defs
	if cnt == 0 then return end

	local ox = self._owner.x
	local oy = self._owner.y

	for i=1,cnt do
		local info = self._defs[i]
		if info.type==RelationType.Center_Center then
			self._owner.x = self._owner.x - (0.5 - (applyPivot and self._owner.pivotX or 0)) * dWidth
		elseif info.type==RelationType.Right_Center or info.type==RelationType.Right_Left or info.type==RelationType.Right_Right then
			self._owner.x = self._owner.x - (1 - (applyPivot and self._owner.pivotX or 0)) * dWidth
		elseif info.type==RelationType.Middle_Middle then
			self._owner.y = self._owner.y - (0.5 - (applyPivot and self._owner.pivotY or 0)) * dHeight
		elseif info.type==RelationType.Bottom_Middle or info.type==RelationType.Bottom_Top or info.type==RelationType.Bottom_Bottom then
			self._owner.y = self._owner.y - (1 - (applyPivot and self._owner.pivotY or 0)) * dHeight
		end
	end

	if ox~=self._owner.x or oy~=self._owner.y then
		ox = self._owner.x - ox
		oy = self._owner.y - oy

		self._owner:updateGearFromRelations(1, ox, oy)

		if self._owner.parent~=nil then
			local transCount = #self._owner.parent._transitions
			for i=1,transCount do
				self._owner.parent._transitions[i]:updateFromRelations(self._owner.id, ox, oy)
			end
		end
	end
end

function RelationItem:applyOnXYChanged(info, dx, dy)
	local tmp
	if info.type==RelationType.Left_Left or info.type==RelationType.Left_Center or info.type==RelationType.Left_Right
		or info.type==RelationType.Center_Center or info.type==RelationType.Right_Left or info.type==RelationType.Right_Center
		or info.type==RelationType.Right_Right then
		self._owner.x = self._owner.x+dx
	elseif info.type==RelationType.Top_Top or info.type==RelationType.Top_Middle or info.type==RelationType.Top_Bottom
		or info.type==RelationType.Middle_Middle or info.type==RelationType.Bottom_Top or info.type==RelationType.Bottom_Middle
		or info.type==RelationType.Bottom_Bottom then
		self._owner.y = self._owner.y+dy
	elseif info.type==RelationType.LeftExt_Left or info.type==RelationType.LeftExt_Right then
		tmp = self._owner.xMin
		self._owner.width = self._owner._rawWidth - dx
		self._owner.xMin = tmp + dx
	elseif info.type==RelationType.RightExt_Left or info.type==RelationType.RightExt_Right then
		tmp = self._owner.xMin
		self._owner.width = self._owner._rawWidth + dx
		self._owner.xMin = tmp
	elseif info.type==RelationType.TopExt_Top or info.type==RelationType.TopExt_Bottom then
		tmp = self._owner.yMin
		self._owner.height = self._owner._rawHeight - dy
		self._owner.yMin = tmp + dy
	elseif info.type==RelationType.BottomExt_Top or info.type==RelationType.BottomExt_Bottom then
		tmp = self._owner.yMin
		self._owner.height = self._owner._rawHeight + dy
		self._owner.yMin = tmp
	end
end

function RelationItem:applyOnSizeChanged(info)
	local pos = 0
	local pivot = 0
	local delta = 0
	if info.axis == 0 then
		if self.target ~= self._owner.parent then
			pos = self.target.x
			if self.target.pivotAsAnchor then
				pivot = self.target.pivotX
			end
		end

		if info.percent then
			if self._targetData.z~=0 then
				delta = self.target._width / self._targetData.z
			end
		else
			delta = self.target._width - self._targetData.z
		end
	else
		if self.target ~= self._owner.parent then
			pos = self.target.y
			if self.target.pivotAsAnchor then
				pivot = self.target.pivotY
			end
		end

		if info.percent then
			if self._targetData.w~=0 then
				delta = self.target._height / self._targetData.w
			end
		else
			delta = self.target._height - self._targetData.w
		end
	end

	local v, tmp

	if info.type==RelationType.Left_Left then
		if info.percent then
			self._owner.xMin = pos + (self._owner.xMin - pos) * delta
		elseif pivot ~= 0 then
			self._owner.x = self._owner.x + delta * (-pivot)
		end
	elseif info.type==RelationType.Left_Center then
		if info.percent then
			self._owner.xMin = pos + (self._owner.xMin - pos) * delta
		else
			self._owner.x = self._owner.x + delta * (0.5 - pivot)
		end
	elseif info.type==RelationType.Left_Right then
		if info.percent then
			self._owner.xMin = pos + (self._owner.xMin - pos) * delta
		else
			self._owner.x = self._owner.x + delta * (1 - pivot)
		end
	elseif info.type==RelationType.Center_Center then
		if info.percent then
			self._owner.xMin = pos + (self._owner.xMin + self._owner._rawWidth * 0.5 - pos) * delta - self._owner._rawWidth * 0.5
		else
			self._owner.x = self._owner.x + delta * (0.5 - pivot)
		end
	elseif info.type==RelationType.Right_Left then
		if info.percent then
			self._owner.xMin = pos + (self._owner.xMin + self._owner._rawWidth - pos) * delta - self._owner._rawWidth
		elseif pivot ~= 0 then
			self._owner.x = self._owner.x + delta * (-pivot)
		end
	elseif info.type==RelationType.Right_Center then
		if info.percent then
			self._owner.xMin = pos + (self._owner.xMin + self._owner._rawWidth - pos) * delta - self._owner._rawWidth
		else
			self._owner.x = self._owner.x + delta * (0.5 - pivot)
		end
	elseif info.type==RelationType.Right_Right then
		if info.percent then
			self._owner.xMin = pos + (self._owner.xMin + self._owner._rawWidth - pos) * delta - self._owner._rawWidth
		else
			self._owner.x = self._owner.x + delta * (1 - pivot)
		end
	elseif info.type==RelationType.Top_Top then
		if info.percent then
			self._owner.yMin = pos + (self._owner.yMin - pos) * delta
		elseif pivot ~= 0 then
			self._owner.y = self._owner.y + delta * (-pivot)
		end
	elseif info.type==RelationType.Top_Middle then
		if info.percent then
			self._owner.yMin = pos + (self._owner.yMin - pos) * delta
		else
			self._owner.y = self._owner.y + delta * (0.5 - pivot)
		end
	elseif info.type==RelationType.Top_Bottom then
		if info.percent then
			self._owner.yMin = pos + (self._owner.yMin - pos) * delta
		else
			self._owner.y = self._owner.y + delta * (1 - pivot)
		end
	elseif info.type==RelationType.Middle_Middle then
		if info.percent then
			self._owner.yMin = pos + (self._owner.yMin + self._owner._rawHeight * 0.5 - pos) * delta - self._owner._rawHeight * 0.5
		else
			self._owner.y = self._owner.y + delta * (0.5 - pivot)
		end
	elseif info.type==RelationType.Bottom_Top then
		if info.percent then
			self._owner.yMin = pos + (self._owner.yMin + self._owner._rawHeight - pos) * delta - self._owner._rawHeight
		elseif pivot ~= 0 then
			self._owner.y = self._owner.y + delta * (-pivot)
		end
	elseif info.type==RelationType.Bottom_Middle then
		if info.percent then
			self._owner.yMin = pos + (self._owner.yMin + self._owner._rawHeight - pos) * delta - self._owner._rawHeight
		else
			self._owner.y = self._owner.y + delta * (0.5 - pivot)
		end
	elseif info.type==RelationType.Bottom_Bottom then
		if info.percent then
			self._owner.yMin = pos + (self._owner.yMin + self._owner._rawHeight - pos) * delta - self._owner._rawHeight
		else
			self._owner.y = self._owner.y + delta * (1 - pivot)
		end
	elseif info.type==RelationType.Width then
		if self._owner._underConstruct and self._owner == self.target.parent then
			v = self._owner.sourceWidth - self.target.initWidth
		else
			v = self._owner._rawWidth - self._targetData.z
		end
		if info.percent then
			v = v * delta
		end
		if self.target == self._owner.parent then
			if self._owner.pivotAsAnchor then
				tmp = self._owner.xMin
				self._owner:setSize(self.target._width + v, self._owner._rawHeight, true)
				self._owner.xMin = tmp
			else
				self._owner:setSize(self.target._width + v, self._owner._rawHeight, true)
			end
		else
			self._owner.width = self.target._width + v
		end
	elseif info.type==RelationType.Height then
		if self._owner._underConstruct and self._owner == self.target.parent then
			v = self._owner.sourceHeight - self.target.initHeight
		else
			v = self._owner._rawHeight - self._targetData.w
		end
		if info.percent then
			v = v * delta
		end
		if self.target == self._owner.parent then
			if self._owner.pivotAsAnchor then
				tmp = self._owner.yMin
				self._owner:setSize(self._owner._rawWidth, self.target._height + v, true)
				self._owner.yMin = tmp
			else
				self._owner:setSize(self._owner._rawWidth, self.target._height + v, true)
			end
		else
			self._owner.height = self.target._height + v
		end
	elseif info.type==RelationType.LeftExt_Left then
		tmp = self._owner.xMin
		if info.percent then
			v = pos + (tmp - pos) * delta - tmp
		else
			v = delta * (-pivot)
		end
		self._owner.width = self._owner._rawWidth - v
		self._owner.xMin = tmp + v
	elseif info.type==RelationType.LeftExt_Right then
		tmp = self._owner.xMin
		if info.percent then
			v = pos + (tmp - pos) * delta - tmp
		else
			v = delta * (1 - pivot)
		end
		self._owner.width = self._owner._rawWidth - v
		self._owner.xMin = tmp + v
	elseif info.type==RelationType.RightExt_Left then
		tmp = self._owner.xMin
		if info.percent then
			v = pos + (tmp + self._owner._rawWidth - pos) * delta - (tmp + self._owner._rawWidth)
		else
			v = delta * (-pivot)
		end
		self._owner.width = self._owner._rawWidth + v
		self._owner.xMin = tmp
	elseif info.type==RelationType.RightExt_Right then
		tmp = self._owner.xMin
		if info.percent then
			if self._owner == self.target.parent then
				if self._owner._underConstruct then
					self._owner.width = pos + self.target._width - self.target._width * pivot +
						(self._owner.sourceWidth - pos - self.target.initWidth + self.target.initWidth * pivot) * delta
				else
					self._owner.width = pos + (self._owner._rawWidth - pos) * delta
				end
			else
				v = pos + (tmp + self._owner._rawWidth - pos) * delta - (tmp + self._owner._rawWidth)
				self._owner.width = self._owner._rawWidth + v
				self._owner.xMin = tmp
			end
		else
			if self._owner == self.target.parent then
				if self._owner._underConstruct then
					self._owner.width = self._owner.sourceWidth + (self.target._width - self.target.initWidth) * (1 - pivot)
				else
					self._owner.width = self._owner._rawWidth + delta * (1 - pivot)
				end
			else
				v = delta * (1 - pivot)
				self._owner.width = self._owner._rawWidth + v
				self._owner.xMin = tmp
			end
		end
	elseif info.type==RelationType.TopExt_Top then
		tmp = self._owner.yMin
		if info.percent then
			v = pos + (tmp - pos) * delta - tmp
		else
			v = delta * (-pivot)
		end
		self._owner.height = self._owner._rawHeight - v
		self._owner.yMin = tmp + v
	elseif info.type==RelationType.TopExt_Bottom then
		tmp = self._owner.yMin
		if info.percent then
			v = pos + (tmp - pos) * delta - tmp
		else
			v = delta * (1 - pivot)
		end
		self._owner.height = self._owner._rawHeight - v
		self._owner.yMin = tmp + v
	elseif info.type==RelationType.BottomExt_Top then
		tmp = self._owner.yMin
		if info.percent then
			v = pos + (tmp + self._owner._rawHeight - pos) * delta - (tmp + self._owner._rawHeight)
		else
			v = delta * (-pivot)
		end
		self._owner.height = self._owner._rawHeight + v
		self._owner.yMin = tmp
	elseif info.type==RelationType.BottomExt_Bottom then
		tmp = self._owner.yMin
		if info.percent then
			if self._owner == self.target.parent then
				if self._owner._underConstruct then
					self._owner.height = pos + self.target._height - self.target._height * pivot +
						(self._owner.sourceHeight - pos - self.target.initHeight + self.target.initHeight * pivot) * delta
				else
					self._owner.height = pos + (self._owner._rawHeight - pos) * delta
				end
			else
				v = pos + (tmp + self._owner._rawHeight - pos) * delta - (tmp + self._owner._rawHeight)
				self._owner.height = self._owner._rawHeight + v
				self._owner.yMin = tmp
			end
		else
			if self._owner == self.target.parent then
				if self._owner._underConstruct then
					self._owner.height = self._owner.sourceHeight + (self.target._height - self.target.initHeight) * (1 - pivot)
				else
					self._owner.height = self._owner._rawHeight + delta * (1 - pivot)
				end
			else
				v = delta * (1 - pivot)
				self._owner.height = self._owner._rawHeight + v
				self._owner.yMin = tmp
			end
		end
	end
end

function RelationItem:addRefTarget(target)
	if target ~= self._owner.parent then
		target:on('posChanged', self._targetXYChanged, self)
	end
	target:on('sizeChanged', self._targetSizeChanged, self)
	target:on('sizeWillChange', self._targetSizeWillChange, self)
	self._targetData.x = self.target.x
	self._targetData.y = self.target.y
	self._targetData.z = self.target._width
	self._targetData.w = self.target._height
end

function RelationItem:releaseRefTarget(target)
	target:off('posChanged', self._targetXYChanged, self)
	target:off('sizeChanged', self._targetXYChanged, self)
	target:off('sizeWillChange', self._targetSizeWillChange, self)
end

function RelationItem:_targetXYChanged(context)
	if self._owner._relations.handling or self._owner.group ~= nil and self._owner.group._updating ~= 0 then
		self._targetData.x = self.target.x
		self._targetData.y = self.target.y
		return
	end

	self._owner._relations.handling = context.sender

	local ox = self._owner.x
	local oy = self._owner.y
	local dx = self.target.x - self._targetData.x
	local dy = self.target.y - self._targetData.y

	local cnt = #self._defs
	for i=1,cnt do
		self:applyOnXYChanged(self._defs[i], dx, dy)
	end

	self._targetData.x = self.target.x
	self._targetData.y = self.target.y

	if ox~=self._owner.x or oy~=self._owner.y then
		ox = self._owner.x - ox
		oy = self._owner.y - oy

		self._owner:updateGearFromRelations(1, ox, oy)

		if self._owner.parent ~= nil then
			local transCount = #self._owner.parent._transitions
			for i=1,transCount do
				self._owner.parent._transitions[i]:updateFromRelations(self._owner.id, ox, oy)
			end
		end
	end

	self._owner._relations.handling = nil
end

function RelationItem:_targetSizeChanged(context)
	if self._owner._relations.handling or self._owner.group ~= nil and self._owner.group._updating ~= 0 then
		self._targetData.z = self.target._width
		self._targetData.w = self.target._height
		return
	end

	self._owner._relations.handling = context.sender

	local ox = self._owner.x
	local oy = self._owner.y
	local ow = self._owner._rawWidth
	local oh = self._owner._rawHeight

	local cnt = #self._defs
	for i=1,cnt do
		self:applyOnSizeChanged(self._defs[i])
	end

	self._targetData.z = self.target._width
	self._targetData.w = self.target._height

	if ox~=self._owner.x or oy~=self._owner.y then
		ox = self._owner.x - ox
		oy = self._owner.y - oy

		self._owner:updateGearFromRelations(1, ox, oy)

		if self._owner.parent ~= nil then
			local transCount = #self._owner.parent._transitions
			for i=1,transCount do
				self._owner.parent._transitions[i]:updateFromRelations(self._owner.id, ox, oy)
			end
		end
	end

	if ow~=self._owner._rawWidth or oh~=self._owner._rawHeight then
		ow = self._owner._rawWidth - ow
		oh = self._owner._rawHeight - oh

		self._owner:updateGearFromRelations(2, ow, oh)
	end

	self._owner._relations.handling = nil
end

function RelationItem:_targetSizeWillChange()
	if not self._owner._sizeDirty then
		self._owner._sizeDirty = true
		self._owner:emit("sizeWillChange")
	end
end

return RelationItem