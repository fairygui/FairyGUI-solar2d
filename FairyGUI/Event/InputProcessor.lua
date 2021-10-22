local TouchInfo = class('TouchInfo', false)
local tools = require('Utils.ToolSet')

function TouchInfo:ctor()
	self.x = 0
	self.y = 0
	self.touchId = ''
	self.numTaps = 1
	self.began = false
	self.downX = 0
	self.downY = 0
	self.downTargets = {}
	self.downTargetsLen = 0
	self.lastClickTime = 0
	self.clickCount = 1
	self.captureList = {}
	self.captureListLen = 0
	self.clickCancelled = false
end

function TouchInfo:set(evt, target)
	self.touchId = evt.id
	self.x = evt.x
	self.y = evt.y
	self.target = target
end

function TouchInfo:cleanup()
	for i=1,self.captureListLen do
		self.captureList[i] = nil
	end
	self.captureListLen = 0

	for i=1,self.downTargetsLen do
		self.downTargets[i] = nil
	end
	self.downTargetsLen = 0
end

local InputProcessor = {}

local _touches = {}

InputProcessor._lastTouch = TouchInfo.new()

function InputProcessor.getFirstTouch()
	for k,v in pairs(_touches) do
		if v.began then
			return k
		end
	end
end

function InputProcessor.getTouchPos(touchId)
	if not touchId then
		touchId = InputProcessor.getFirstTouch()
	end
	assert(touchId, 'no touch available')

	local info = _touches[touchId]
	if not info then
		return 0,0
	else
		return info.x, info.y
	end
end

function InputProcessor.cancelClick(touchId)
	if not touchId then
		touchId = InputProcessor.getFirstTouch()
	end
	assert(touchId, 'no touch available')

	local info = _touches[touchId]
	assert(info, 'touch is not active')

	info.clickCancelled = true
end

function InputProcessor.onTouch(evt, target)
	target = target or UIRoot
	if not target then return end

	if ( evt.phase == "began" ) then
		--print("touchBegin", target)
		InputProcessor.setBegin(evt, target)
	elseif ( evt.phase == "ended" or evt.phase == "cancelled" ) then
		InputProcessor.setEnd(evt, target)
		--print("touchEnd", target)
	else
		--print("touchMove", target)
		InputProcessor.touchMove(evt, target)
	end
end

function InputProcessor.setBegin(evt, target)
	local info = InputProcessor.getTouch(evt.id)
	info:set(evt, target)
	InputProcessor._lastTouch = info

	--display.getCurrentStage():setFocus( evt.target )

	info.began = true
	info.downX = evt.x
	info.downY = evt.y
	info.clickCancelled = false

	if target then
		info.downTargetsLen = info.downTargetsLen+1
		info.downTargets[info.downTargetsLen] = target
		local obj = target
		while obj do
			info.downTargetsLen = info.downTargetsLen+1
			info.downTargets[info.downTargetsLen] = obj
			obj = obj:findParent()
		end
	end

	GRoot.onTouchBeginCapture()

	if target then
		target:bubble('touchBegin')
	end
end

local function clickTest(info, target)
	if info.downTargetsLen==0 or info.clickCancelled
		or math.abs(info.x - info.downX) > 50 or math.abs(info.y - info.downY) > 50 then
		return
	end

	local obj = info.downTargets[1]
	if obj.onStage then --依然派发到原来的downTarget，虽然可能它已经偏离当前位置，主要是为了正确处理点击缩放的效果
		return obj
	end

	obj = target
	while obj do
		local i = tools.indexOf(info.downTargets, obj)
		if i ~= 0 and obj.onStage then
			break
		end

		obj = obj:findParent()
	end

	return obj
end

function InputProcessor.setEnd(evt, target)
	local info = InputProcessor.getTouch(evt.id)
	info:set(evt, target)
	InputProcessor._lastTouch = info

	--display.getCurrentStage():setFocus( nil )

	info.began = false

	target:bubble('touchEnd', nil, info.captureList, info.captureListLen)

	if system.getTimer() - info.lastClickTime < 350 then
		info.numTaps = info.numTaps + 1
	else
		info.numTaps = 1
	end
	info.lastClickTime = system.getTimer()

	target = clickTest(info, target)
	if target then
		target:bubble('tap')
	end

	info:cleanup()
end

function InputProcessor.touchMove(evt, target)
	local info = InputProcessor.getTouch(evt.id)
	info:set(evt, target)
	InputProcessor._lastTouch = info

	if math.abs(info.x - info.downX) > 50 or math.abs(info.y - info.downY) > 50 then
		info.clickCancelled = true
	end

	UIRoot:bubble('touchMove', nil, info.captureList, info.captureListLen)
end

function InputProcessor.getTouch(touchId)
	if not touchId then
		touchId = InputProcessor.getFirstTouch()
	end
	assert(touchId, 'no touch available')

	local info = _touches[touchId]
	if not info then
		info = TouchInfo.new()
		_touches[touchId] = info
	end
	return info
end

function InputProcessor.addTouchMonitor(touchId, obj)
	local info = _touches[touchId]
	if not info or not info.began then return end

	for i=1,info.captureListLen do
		if info.captureList[i]==obj then
			return
		end
	end

	info.captureListLen = info.captureListLen + 1
	info.captureList[info.captureListLen] = obj
end

function InputProcessor.removeTouchMonitor(obj)
	for _,info in pairs(_touches) do
		for i=1,info.captureListLen do
			if info.captureList[i]==obj then
				info.captureList[i] = nil
				break
			end
		end
	end
end

display.currentStage:addEventListener("touch", function(evt)
	InputProcessor.onTouch(evt, nil)
end)

return InputProcessor