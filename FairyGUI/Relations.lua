local RelationItem = require('RelationItem')

local Relations = class('Relations')

function Relations:ctor(owner)
	self._owner = owner
	self._items = {}
end

function Relations:add(target, relationType, usePercent)
	local cnt = #self._items
	for i=1,cnt do
		local item = self._items[i]
		if item.target == target then
			item:add(relationType, usePercent)
			return
		end
	end
	local newItem = RelationItem.new(self._owner)
	newItem:setTarget(target)
	newItem:add(relationType, usePercent)
	table.insert(self._items, newItem)
end

function Relations:remove(target, relationType)
	local cnt = #self._items
	local i = 1
	while i <= cnt do
		local item = self._items[i]
		if item.target == target then
			item:remove(relationType)
			if item:isEmpty() then
				item:dispose()
				table.remove(self._items, i)
				cnt = cnt-1
			else
				i=i+1
			end
		else
			i=i+1
		end
	end
end

function Relations:contains(target)
	local cnt = #self._items
	for i=1,cnt do
		local item = self._items[i]
		if item.target == target then
			return true
		end
	end
	return false
end

function Relations:clearFor(target)
	local cnt = #self._items
	local i = 1
	while i <= cnt do
		local item = self._items[i]
		if item.target == target then
			item:dispose()
			table.remove(self._items, i)
			cnt = cnt-1
		else
			i=i+1
		end
	end
end

function Relations:clearAll()
	local cnt = #self._items
	for i=1,cnt do
		local item = self._items[i]
		item:dispose()
	end
	self._items={}
end

function Relations:copyFrom(source)
	self:clearAll()

	local arr = source._items
	for _,ri in ipairs(arr) do
		local item = RelationItem.new(self._owner)
		item:copyFrom(ri)
		table.insert(self._items, item)
	end
end

function Relations:dispose()
	self:clearAll()
	self.handling = nil
end

function Relations:onOwnerSizeChanged(dWidth, dHeight, applyPivot)
	local cnt = #self._items
	if cnt == 0 then return end

	for i=1,cnt do
		self._items[i]:applyOnSelfSizeChanged(dWidth, dHeight, applyPivot)
	end
end

function Relations:ensureRelationsSizeCorrect()
	local cnt = #self._items
	if cnt == 0 then return end

	for i=1,cnt do
		local item = self._items[i]
		item.target:ensureSizeCorrect()
	end
end

function Relations:isEmpty()
	return #self._items == 0
end

function Relations:setup(buffer, parentToChild)
	local cnt = buffer:readByte()
	local target
	for i=1,cnt do
		local targetIndex = buffer:readShort()
		if targetIndex == -1 then
			target = self._owner.parent
		elseif parentToChild then
			target = self._owner:getChildAt(targetIndex)
		else
			target = self._owner.parent:getChildAt(targetIndex)
		end

		local newItem = RelationItem.new(self._owner)
		newItem:setTarget(target)
		table.insert(self._items, newItem)

		local cnt2 = buffer:readByte()
		for j=1,cnt2 do
			local rt = buffer:readByte()
			local usePercent = buffer:readBool()
			newItem:internalAdd(rt, usePercent)
		end
	end
end

return Relations