local TweenValue = require('Tween.TweenValue')
local GTweener = class('GTweener')

local getters = GTweener.getters
local setters = GTweener.setters

local easeFunctions = {
	easing.linear,
	easing.inSine,
	easing.outSine,
	easing.inOutSine,
	easing.inQuad,
	easing.outQuad,
	easing.inOutQuad,
	easing.inCubic,
	easing.outCubic,
	easing.inOutCubic,
	easing.inQuart,
	easing.outQuart,
	easing.inOutQuart,
	easing.inQuint,
	easing.outQuint,
	easing.inOutQuint,
	easing.inExpo,
	easing.outExpo,
	easing.inOutExpo,
	easing.inCirc,
	easing.outCirc,
	easing.inOutCirc,
	easing.inElastic,
	easing.outElastic,
	easing.inOutElastic,
	easing.inBack,
	easing.outBack,
	easing.inOutBack,
	easing.inBounce,
	easing.outBounce,
	easing.inOutBounce,
}

function GTweener:ctor()
	--self._target = nil
	--self._propType = 0
 	--self._killed = false
	--self._paused = false

	self._delay = 0
	self._duration = 0
	self._breakpoint = 0
	self._easeType = 0
	self._easeOvershootOrAmplitude = 0
	self._easePeriod = 0
	self._repeat = 0
	self._yoyo = false
	self._timeScale = 1
	self._ignoreEngineTimeScale = false
	self._snapping = false
	--self._userData = nil
	
	--self._onUpdate = nil
	---self._onStart = nil
	--self._onComplete = nil

	self._startValue = TweenValue.new()
	self._endValue = TweenValue.new()
	self._value = TweenValue.new()
	self._deltaValue = TweenValue.new()
	self._valueSize = 0

	self._started = false
	self._ended = 0
	self._elapsedTime = 0
	self._normalizedTime = 0
	self._smoothStart = 0
end

function GTweener:setDelay(value)
	assert(value, 'delay cant be nil')
	self._delay = value
	return self
end

function getters:delay()
	return self._delay
end

function GTweener:setDuration(value)
	assert(value, 'duration cant be nil')
	self._duration = value
	return self
end

function getters:duration()
	return self._duration
end

function GTweener:setBreakpoint(value)
	self._breakpoint = value
	return self
end

function GTweener:setEase(value)
	self._easeType = value
	return self
end

function GTweener:setEasePeriod(value)
	self._easePeriod = value
	return self
end

function GTweener:setEaseOvershootOrAmplitude(value)
	self._easeOvershootOrAmplitude = value
	return self
end

function GTweener:setRepeat(times, yoyo)
	assert(times, 'times cant be nil')
	self._repeat = times
	self._yoyo = yoyo
	return self
end

function getters:repeats()
	return self._repeat
end

function GTweener:setTimeScale(value)
	self._timeScale = value
	return self
end

function GTweener:setIgnoreEngineTimeScale(value)
	self._ignoreEngineTimeScale = value
	return self
end

function GTweener:setSnapping(value)
	self._snapping = value
	return self
end

function GTweener:setTarget(value)
	self._target = value
	self._propType = TweenPropType.None
	return self
end

function GTweener:setTarget(value, propType)
	self._target = value
	self._propType = propType
	return self
end

function getters:target()
	return self._target 
end

function GTweener:setUserData(value)
	self._userData = value
	return self
end

function getters:userData()
	return self._userData
end

function GTweener:onUpdate(func, selfObj)
	self._onUpdate = func
	self._onUpdateTarget = selfObj
	return self
end

function GTweener:onStart(func, selfObj)
	self._onStart = func
	self._onStartTarget = selfObj
	return self
end

function GTweener:onComplete(func, selfObj)
	self._onComplete = func
	self._onCompleteTarget = selfObj
	return self
end

function getters:startValue()
	return self._startValue
end

function getters:endValue()
	return self._endValue
end

function getters:value()
	return self._value
end

function getters:deltaValue()
	return self._deltaValue
end

function getters:normalizedTime()
	return self._normalizedTime
end
function getters:completed()
	return self._ended~=0
end
function getters:allCompleted()
	return self._ended==1
end

function GTweener:setPaused(paused)
	self._paused = paused
	if self._paused then
		self._smoothStart = 0
	end
	return self
end

function GTweener:seek(time)
	if self._killed then return end

	self._elapsedTime = time
	if self._elapsedTime < self._delay then
		if self._started then
			self._elapsedTime = self._delay
		else
			return
		end
	end

	self:update()
end

function GTweener:kill(complete)
	if self._killed then return end

	if complete then
		if self._ended == 0 then
			if self._breakpoint >= 0 then
				self._elapsedTime = self._delay + self._breakpoint
			elseif self._repeat >= 0 then
				self._elapsedTime = self._delay + self._duration * (self._repeat + 1)
			else
				self._elapsedTime = self._delay + self._duration * 2
			end
			self:update()
		end

		self:callCompleteCallback()
	end

	self._killed = true
end

function GTweener:_init()
	self._delay = 0
	self._duration = 0
	self._breakpoint = -1
	self._easeType = EaseType.QuadOut
	self._timeScale = 1
	self._easePeriod = 0
	self._easeOvershootOrAmplitude = 1.70158
	self._snapping = false
	self._repeat = 0
	self._yoyo = false
	self._valueSize = 0
	self._started = false
	self._paused = false
	self._killed = false
	self._elapsedTime = 0
	self._normalizedTime = 0
	self._ended = 0
	self._smoothStart = 1
end

function GTweener:_reset()
	self._target = nil
	self._userData = nil
	self._onStart = nil
	self._onUpdate = nil
	self._onComplete = nil
	self._onStartTarget = nil
	self._onUpdateTarget = nil
	self._onCompleteTarget = nil
end

function GTweener:_update(dt)
	if self._ended ~= 0 then --Maybe completed by seek
		self:callCompleteCallback()
		self._killed = true
		return
	end

	if self._smoothStart > 0 then
		self._smoothStart = self._smoothStart-1
		dt = 0.016
	end

	if self._timeScale ~= 1 then
		dt = dt * self._timeScale
	end
	if dt == 0 then return end

	self._elapsedTime = self._elapsedTime + dt
	self:update()

	if self._ended ~= 0 then
		if not self._killed then
			self:callCompleteCallback()
			self._killed = true
		end
	end
end

function GTweener:update()
	self._ended = 0

	if self._valueSize == 0 then --DelayedCall
		if self._elapsedTime >= self._delay + self._duration then
			self._ended = 1
		end

		return
	end

	if not self._started then
		if self._elapsedTime < self._delay then
			return
		end

		self._started = true
		self:callStartCallback()
		if self._killed then return end
	end

	local reversed = false
	local tt = self._elapsedTime - self._delay
	if self._breakpoint >= 0 and tt >= self._breakpoint then
		tt = self._breakpoint
		self._ended = 2
	end

	if self._repeat ~= 0 then
		local round = math.floor(tt / self._duration)
		tt = tt - self._duration * round
		if self._yoyo then
			reversed = round % 2 == 1
		end

		if self._repeat > 0 and self._repeat - round < 0 then
			if self._yoyo then
				reversed = self._repeat % 2 == 1
			end
			tt = self._duration
			self._ended = 1
		end
	elseif tt >= self._duration then
		tt = self._duration
		self._ended = 1
	end

	self._normalizedTime = easeFunctions[self._easeType+1](reversed and (self._duration - tt) or tt, self._duration, 0, 1)

	self._value:setAll()
	self._deltaValue:setAll()

	if self._valueSize == 6 then
		if self._ended == 0 then
			local r = self._startValue.w * (1 - self._normalizedTime)
			local rx = r * (math.random()>0.5 and 1 or -1)
			local ry = r * (math.random()>0.5 and 1 or -1)

			self._deltaValue.x = rx
			self._deltaValue.y = ry
			self._value.x = self._startValue.x + rx
			self._value.y = self._startValue.y + ry
		else
			self._value.x = self._startValue.x
			self._value.y = self._startValue.y
		end
	else
		local cnt = self._valueSize
		if cnt>4 then cnt = 4 end
		for i=1,cnt do
			local n1 = self._startValue:get(i)
			local n2 = self._endValue:get(i)
			local f = n1 + (n2 - n1) * self._normalizedTime
			if self._snapping then
				f = math.round(f)
			end
			self._deltaValue:set(i, f - self._value:get(i))
			self._value:set(i, f)
		end
	end

	if self._target and self._propType then
		if type(self._propType)=='function' then
			if self._valueSize==1 then
				self._propType(self._target, self._value.x)
			elseif self._valueSize==2 then
				self._propType(self._target, self._value.x, self._value.y)
			elseif self._valueSize==3 then
				self._propType(self._target, self._value.x, self._value.y, self._value.z)
			elseif self._valueSize==4 then
				self._propType(self._target, self._value.x,  self._value.y, self._value.z, self._value.w)
			elseif self._valueSize==5 then
				self._propType(self._target, self._value:getColor())
			end
		elseif self._valueSize==5 then
			self._target[self._propType] = self._value:getColor()
		else
			self._target[self._propType] = self._value.x
		end
	end

	self:callUpdateCallback()
end

local function errHandler(e)
	print("FairyGUI: error in start callback > \n"..debug.traceback()) 
	return e
end

function GTweener:callStartCallback()
	if not self._onStart then return end

	if self._onStartTarget  then
		if GTween.catchCallbackExceptions then
			xpcall(self._onStart, errHandler, self._onStartTarget, self)
		else
			self._onStart(self._onStartTarget, self)
		end
	else
		if GTween.catchCallbackExceptions then
			xpcall(self._onStart, errHandler, self)
		else
			self._onStart(self)
		end
	end
end

function GTweener:callUpdateCallback()
	if not self._onUpdate then return end

	if self._onUpdateTarget then
		if GTween.catchCallbackExceptions then
			xpcall(self._onUpdate, errHandler, self._onUpdateTarget, self)
		else
			self._onUpdate(self._onUpdateTarget, self)
		end
	else
		if GTween.catchCallbackExceptions then
			xpcall(self._onUpdate, errHandler, self)
		else
			self._onUpdate(self)
		end
	end
end

function GTweener:callCompleteCallback()
	if not self._onComplete then return end

	if self._onCompleteTarget then
		if GTween.catchCallbackExceptions then
			xpcall(self._onComplete, errHandler, self._onCompleteTarget, self)
		else
			self._onComplete(self._onCompleteTarget, self)
		end
	else
		if GTween.catchCallbackExceptions then
			xpcall(self._onComplete, errHandler, self)
		else
			self._onComplete(self)
		end
	end
end

return GTweener