local Delegate = class('Delegate', false)

local _pool = {}
local _poolLen = 0

function Delegate:ctor()
	self.elements = {}
	self.calling = false
	self.count = 0
end

function Delegate:add(func, thisObj)
	assert(func, "func cant be nil")

	for i=1,#self.elements do
		local m = self.elements[i]
		if m[1]==func and m[2]==thisObj then return end
	end

	self.count = self.count+1
	table.insert(self.elements, {func, thisObj})
end

function Delegate:set(func, thisObj)
	self:clear()
	self:add(func, thisObj)
end

function Delegate:remove(func, thisObj)
	assert(func, "func cant be nil")
	
	for i=1,#self.elements do
		local m = self.elements[i]
		if m[1]==func and m[2]==thisObj then
			self.count = self.count - 1
			table.remove(self.elements, i)
			return
		end
	end
end

function Delegate:contains(func, thisObj)
	for i=1,#self.elements do
		local m = self.elements[i]
		if m[1]==func and m[2]==thisObj then return true end
	end
end

function Delegate:clear()
	local cnt = #self.elements
	while cnt>0 do
		table.remove(self.elements, cnt)
		cnt = cnt-1
	end
	self.count = 0
end

function Delegate:call(param)
	if self.count==0 then return end

	self.calling = true

	local array
	if _poolLen==0 then
		array = {}
	else
		array = _pool[_poolLen]
		_poolLen = _poolLen-1
	end

	local cnt = #self.elements
	for i=1,cnt do
		array[i] = self.elements[i]
	end

	for i=1,cnt do
		local m = array[i]
		if m[2]==nil then
			m[1](param)
		else
			m[1](m[2], param)
		end
		array[i] = nil
	end

	_poolLen = _poolLen+1
	_pool[_poolLen] = array

	self.calling = false
end

function Delegate:once(param)
	if self.count==0 then return end

	self.calling = true

	local array
	if _poolLen==0 then
		array = {}
	else
		array = _pool[_poolLen]
		_poolLen = _poolLen-1
	end

	local cnt = #self.elements
	for i=1,cnt do
		array[i] = self.elements[i]
	end

	self:clear()

	for i=1,cnt do
		local m = array[i]
		if m[2]==nil then
			m[1](param)
		else
			m[1](m[2], param)
		end
		array[i] = nil
	end

	_poolLen = _poolLen+1
	_pool[_poolLen] = array

	self.calling = false
end

return Delegate