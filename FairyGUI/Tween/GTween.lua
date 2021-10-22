require 'Tween.EaseType'

local TweenManager = require("Tween.TweenManager")

GTween = {}

GTween.catchCallbackExceptions = false

function GTween.to(p1, p2, p3, p4, p5, p6, p7, p8, p9)
	local t = TweenManager.createTween()

	if not p4 then
		t._valueSize = 1
		t._startValue:setAll(p1)
		t._endValue:setAll(p2)
		t._value:setAll(p1)
		t:setDuration(p3)
	elseif not p6 then
		t._valueSize = 2
		t._startValue:setAll(p1,p2)
		t._endValue:setAll(p3,p4)
		t._value:setAll(p1,p2)
		t:setDuration(p5)
	elseif not p8 then
		t._valueSize = 3
		t._startValue:setAll(p1,p2,p3)
		t._endValue:setAll(p4,p5,p6)
		t._value:setAll(p1,p2,p3)
		t:setDuration(p7)
	else
		t._valueSize = 4
		t._startValue:setAll(p1,p2,p3,p4)
		t._endValue:setAll(p5,p6,p7,p8)
		t._value:setAll(p1,p2,p3,p4)
		t:setDuration(p9)
	end
	return t
end

function GTween.toColor(p1, p2, duration)
	t._valueSize = 5
	t._startValue:setColor(p1)
	t._endValue:setColor(p2)
	t._value:setColor(p1)
	t:setDuration(duration):setSnapping(true)

	return t
end

function GTween.shake(originX, originY, amplitude, duration)
	local t = TweenManager.createTween()
	
	t._valueSize = 6
	t._startValue:setAll(originX, originY, 0, amplitude)
	t._value:setAll(originX, originY)
	t:setDuration(duration):setEase(EaseType.Linear)

	return t
end

function GTween.delayedCall(delay)
	return TweenManager.createTween():setDelay(delay)
end

function GTween.isTweening(target, propType)
	return TweenManager.isTweening(target, propType)
end

function GTween.kill(target, propType, complete)
	TweenManager.killTweens(target, propType, complete)
end

function GTween.getTween(target, propType)
	return TweenManager.getTween(target, propType)
end

function GTween.clean()
	TweenManager.clean()
end