local GTweener = require("Tween.GTweener")

local TweenManager = {}

local _activeTweens = {}
local _pool = {}
local _poolSize = 0
local _totalActiveTweens = 0
local _inited = false
local _lastTime

function TweenManager.createTween()
	if not _inited then
		Runtime:addEventListener("enterFrame", TweenManager)
		_inited = true
	end

	local tweener
	if _poolSize > 0 then
		tweener = _pool[_poolSize]
		_poolSize = _poolSize-1
	else
		tweener = GTweener.new()
	end

	tweener:_init()
	_totalActiveTweens = _totalActiveTweens+1
	_activeTweens[_totalActiveTweens] = tweener

	return tweener
end

function TweenManager.isTweening(target, propType)
	if not target then return false end

	for i=1,_totalActiveTweens do
		local tweener = _activeTweens[i]
		if tweener and tweener._target == target and not tweener._killed
			and (not props or tweener._propType == propType) then
			return true
		end
	end

	return false
end

function TweenManager.killTweens(target, propType, completed)
	if not target then return false end

	local flag = false
	for i=1,_totalActiveTweens do
		local tweener = _activeTweens[i]
		if tweener and tweener._target == target and not tweener._killed
			and (not propType or tweener._propType == propType) then
			tweener:kill(completed)
			flag = true
		end
	end

	return flag
end

function TweenManager.getTween(target, propType)
	if not target then return end

	local flag = false
	for i=1,_totalActiveTweens do
		local tweener = _activeTweens[i]
		if tweener and tweener._target == target and not tweener._killed
			and (not propType or tweener._propType == propType) then
			return tweener
		end
	end
end

function TweenManager.enterFrame(event)
	local dt = _lastTime and (event.time - _lastTime) or (1000/display.fps)
	_lastTime = event.time
	dt = dt/1000

	local cnt = _totalActiveTweens
	local freePosStart = 0
	for i=1,cnt do
		local tweener = _activeTweens[i]
		if not tweener then
			if freePosStart == 0 then
				freePosStart = i
			end
		elseif tweener._killed then
			tweener:_reset()
			_poolSize = _poolSize + 1
			_pool[_poolSize] = tweener
			_activeTweens[i] = nil

			if freePosStart == 0 then
				freePosStart = i
			end
		else
			if tweener._target and tweener._target._disposed then
				tweener._killed = true
			elseif not tweener._paused then
				tweener:_update(dt)
			end

			if freePosStart ~= 0 then
				_activeTweens[freePosStart] = tweener
				_activeTweens[i] = nil
				freePosStart = freePosStart+1
			end
		end
	end

	if freePosStart > 0 then
		if _totalActiveTweens ~= cnt then --new tweens added
			local j = cnt + 1
			cnt = _totalActiveTweens - cnt
			for i=1,cnt do
				_activeTweens[freePosStart] = _activeTweens[j]
				freePosStart = freePosStart+1
				_activeTweens[j] = nil
				j = j + 1
			end
		end
		_totalActiveTweens = freePosStart-1
	end
end

function TweenManager.clean()
	_poolSize = 0
	while #_pool>0 do table.remove(_pool, 1) end
end

return TweenManager