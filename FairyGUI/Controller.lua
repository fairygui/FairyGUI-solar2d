local EventDispatcher = require('Event.EventDispatcher')
local ChangePageAction = require('Action.ChangePageAction')
local PlayTransitionAction = require('Action.PlayTransitionAction')

local Controller = class('Controller', EventDispatcher)

local getters = Controller.getters
local setters = Controller.setters

local _nextPageId = 0

local function createAction(type)
	if type == 0 then
		return PlayTransitionAction.new()
	elseif type == 1 then
		return ChangePageAction.new()
	end
end

function Controller:ctor()
	Controller.super.ctor(self)
	
	self.name = ''
	self.autoRadioGroupDepth = false
	self._changing = false
	self._selectedIndex = -1
	self._previousIndex = -1
	self._pageIds = {}
	self._pageNames = {}
end

function getters:selectedIndex() return self._selectedIndex end
function setters:selectedIndex(value)
	if self._selectedIndex~=value then
		assert(value<#self._pageIds, "IndexOutOfRangeException:"..value)

		self._changing = true

		self._previousIndex = self._selectedIndex
		self._selectedIndex = value
		self.parent:applyController(self)

		self:emit("statusChanged")

		self._changing = false
	end
end

function Controller:setSelectedIndex(value)
	if self._selectedIndex~= value then
		assert(value<#self._pageIds, "IndexOutOfRangeException:"..value)

		self._changing = true
		self._previousIndex = self._selectedIndex
		self._selectedIndex = value
		self.parent:applyController(self)
		self._changing = false
	end
end

function getters:selectedPage() 
	if self._selectedIndex == -1 then
		return ''
	else
		return self._pageNames[self._selectedIndex+1]
	end
end

function setters:selectedPage(value)
	for i=1,#self._pageNames do
		if self._pageNames[i]==value then
			self:setSelectedIndex(i-1)
			return
		end
	end

	self:setSelectedIndex(0)
end

function Controller:setSelectedPage(value)
	for i=1,#self._pageNames do
		if self._pageNames[i]==value then
			self:setSelectedIndex(i-1)
			return
		end
	end
end

function getters:previsousIndex() 
	return self._previousIndex
end

function getters:previousPage() 
	if self._previousIndex == -1 then
		return ''
	else
		return self._pageNames[self._previousIndex+1]
	end
end

function getters:pageCount()
	return #self._pageIds
end

function Controller:getPageName(index)
	return self._pageNames[index+1]
end

function Controller:getPageIdByName(name)
	for i=1,#self._pageNames do
		if self._pageNames[i]==name then
			return self._pageIds[i]
		end
	end
end

function Controller:addPage(name)
	name = name or ''
	self:addPageAt(name, #_pageIds)
end

function Controller:addPageAt(name, index)
	local nid = "_"..(_nextPageId+1)
	_nextPageId = _nextPageId+1
	if index == #_pageIds then
		table.insert(self._pageIds, nid)
		table.insert(self._pageNames, name)
	else
		index = index+1
		table.insert(self._pageIds, nid, index)
		table.insert(self._pageNames, name, index)
	end
end

function Controller:removePage(name)
	for i=1,#self._pageNames do
		if self._pageNames[i]==name then
			self:removePageAt(i-1)
		end
	end
end

function Controller:removePageAt(index)
	table.remove(self._pageIds, index+1)
	table.remove(self._pageNames, index+1)
	if self._selectedIndex >= #_pageIds then
		self.selectedIndex = self._selectedIndex - 1
	else
		self.parent:applyController(self)
	end
end

function Controller:clearPages()
	self._pageIds = {}
	self._pageNames = {}
	if self._selectedIndex ~= -1 then
		self.selectedIndex = -1
	else
		self.parent:applyController(self)
	end
end

function Controller:hasPage(name)
	for i=1,#self._pageNames do
		if self._pageNames[i]==name then
			return true
		end
	end
	return false
end

function Controller:getPageIndexById(aId)
	for i=1,#self._pageIds do
		if self._pageIds[i]==aId then
			return i-1
		end
	end
	return -1
end

function Controller:getPageNameById(aId)
	for i=1,#self._pageIds do
		if self._pageIds[i]==aId then
			return self._pageNames[i]
		end
	end
end

function Controller:getPageId(index)
	return self._pageIds[index+1]
end

function getters:selectedPageId()
	if self._selectedIndex == -1 then
		return ''
	else
		return self._pageIds[self._selectedIndex+1]
	end
end

function setters:selectedPageId(value)
	for i=1,#self._pageIds do
		if self._pageIds[i]==value then
			self.selectedIndex = i-1
		end
	end
end

function setters:oppositePageId(value)
	local j=0
	for i=1,#self._pageIds do
		if self._pageIds[i]==value then
			j = i-1
			break
		end
	end

	if j > 0 then
		self.selectedIndex = 0
	elseif #_pageIds > 1 then
		self.selectedIndex = 1
	end
end

function getters:previousPageId()
	if self._previousIndex == -1 then
		return ''
	else
		return self._pageIds[self._previousIndex+1]
	end
end

function Controller:runActions()
	local pr = self.previousPageId
	local sp = self.selectedPageId
	if self._actions~=nil then
		local cnt = #self._actions
		for i=1,cnt do
			self._actions[i]:run(self, pr, sp)
		end
	end
end

function Controller:setup(buffer)
	local beginPos = buffer.pos
	buffer:seek(beginPos, 0)

	self.name = buffer:readS()
	self.autoRadioGroupDepth = buffer:readBool()

	buffer:seek(beginPos, 1)

	local cnt = buffer:readShort()
	for i=1,cnt do
		table.insert(self._pageIds, buffer:readS())
		table.insert(self._pageNames, buffer:readS())
	end

	buffer:seek(beginPos, 2)

	local cnt = buffer:readShort()
	if cnt > 0 then
		if not self._actions then self._actions={} end

		for i=1,cnt do
			local nextPos = buffer:readShort()
			nextPos = nextPos + buffer.pos

			local action = createAction(buffer:readByte())
			action:setup(buffer)
			table.insert(self._actions, action)

			buffer.pos = nextPos
		end
	end

	if self.parent~=nil and #self._pageIds > 0 then
		self._selectedIndex = 0
	else
		self._selectedIndex = -1
	end
end

return Controller