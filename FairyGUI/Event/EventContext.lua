local EventContext = class('EventContext', false)

local _pool = {}
local _poolSize = 0

function EventContext.borrow()
	local inst
	if _poolSize>0 then
		inst = _pool[_poolSize]
		_pool[_poolSize] = nil
		_poolSize = _poolSize-1

		inst._stopsPropagation = false
		inst._defaultPrevented = false
		inst._captureTouch = false
	else
		inst = EventContext.new()
	end

	return inst
end

function EventContext.returns(inst)
	_poolSize = _poolSize+1
	_pool[_poolSize] = inst

	inst.data = nil
end

function EventContext:ctor()
	self._bubbleChain = {}
end

function EventContext:stopPropagation()
	self._stopsPropagation = true
end

function EventContext:preventDefault()
	self._defaultPrevented = true
end

function EventContext:captureTouch()
	self._captureTouch = true
end

return EventContext