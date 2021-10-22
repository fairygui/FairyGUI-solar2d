local Delegate = require('Utils.Delegate')
local EventContext = require('Event.EventContext')
local InputProcessor = require('Event.InputProcessor')

local EventDispatcher = class('EventDispatcher')

function EventDispatcher:ctor()
	self._dict = {}
end

function EventDispatcher:dispose()
end

function EventDispatcher:on(strType, callback, thisObj)
	assert(strType, 'event type cant be nil')

	local delegate = self._dict[strType]
	if not delegate then
		delegate = Delegate:new()
		self._dict[strType] = delegate
	end

	delegate:add(callback, thisObj)
end

function EventDispatcher:off(strType, callback, thisObj)
	assert(strType, 'event type cant be nil')

	local delegate = self._dict[strType]
	if delegate then
		delegate:remove(callback, thisObj)
	end
end

function EventDispatcher:offAll(strType)
	if not strType then
		for _,v in pairs(self._dict) do
			v:clear()
		end
	else
		local delegate = self._dict[strType]
		if delegate then
			delegate:clear()
		end
	end
end

function EventDispatcher:hasListener(strType)
	local delegate = self._dict[strType]
	return delegate and delegate.count>0
end

function EventDispatcher:isDispatching(strType)
	local delegate = self._dict[strType]
	return delegate and delegate.calling
end

function EventDispatcher:emit(strType, param)
	local context = EventContext.borrow()
	context.type = strType
	context.inputEvent = InputProcessor._lastTouch
	context.data = param

	local delegate = self._dict[strType]
	if delegate then
		context.sender = self
		delegate:call(context)
	end

	EventContext.returns(context)

	return context._defaultPrevented
end

local function getNativeChildren(group, chain, len, exclude)
	local cnt = group.numChildren
	for i=1,cnt do
		local obj = group[i]
		if obj~=exclude then
			if obj.insert then
				len = getNativeChildren(obj, chain, len, exclude)
			elseif obj.gOwner then
				if typeof(obj, GComponent) then
					len = getChildren(obj, chain, len)
				else
					len = len+1
					chain[len] = obj.gOwner
				end
			end
		end
	end

	return len
end

local function getChildren(gcom, chain, len)
	len = len+1
	chain[len] = gcom

	local cnt = #gcom._children
	for i=1,cnt do
		local obj = gcom._children[i]
		if typeof(obj, GComponent) then
			len = getChildren(obj, chain, len)
		else
			len = len+1
			chain[len] = obj
		end
	end

	return getNativeChildren(gcom.displayObject, chain, len, gcom._container);
end

function EventDispatcher:broadcast(strType, param)
	local context = EventContext.borrow()
	context.type = strType
	context.inputEvent = InputProcessor._lastTouch
	context.data = param

	local chain = context._bubbleChain
	local len = getChildren(self, chain, 0)

	local obj
	for i=1,len do
		obj = chain[i]
		local delegate = obj._dict[strType]
		if delegate then
			context.sender = obj
			delegate:call(context)
		end
	end

	for i=1,len do
		chain[i] = nil
	end

	EventContext.returns(context)

	return context._defaultPrevented
end

function EventDispatcher:bubble(strType, param, addChain, addChainLen)
	local context = EventContext.borrow()
	context.type = strType
	context.inputEvent = InputProcessor._lastTouch
	context.data = param

	local obj = self
	local chain = context._bubbleChain
	local len = 0
	while obj do
		len = len + 1
		chain[len] = obj
		obj = obj:findParent()
	end

	for i=1,len do
		obj = chain[i]
		local delegate = obj._dict[strType]
		if delegate then
			context.sender = obj
			delegate:call(context)
			if context._captureTouch and strType=="touchBegin" then
				InputProcessor.addTouchMonitor(context.inputEvent.touchId, obj)
			end

			if context._stopsPropagation then
				break
			end
		end
	end

	if addChain then
		for i=1,addChainLen do
			obj = addChain[i]
			if obj then
				local delegate = obj._dict[strType]
				if delegate then
					context.sender = obj
					delegate:call(context)
				end
			end
		end
	end

	for i=1,len do
		chain[i] = nil
	end

	EventContext.returns(context)

	return context._defaultPrevented
end

return EventDispatcher