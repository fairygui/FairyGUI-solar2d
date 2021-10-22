local bitLib = require("plugin.bit" )
local band = bitLib.band

local Transition = class('Transition')

local getters = Transition.getters
local setters = Transition.setters

local OPTION_IGNORE_DISPLAY_CONTROLLER = 1
local OPTION_AUTO_STOP_DISABLED = 2
local OPTION_AUTO_STOP_AT_END = 4

function Transition:ctor(owner)
	self._owner = owner
	self._timeScale = 1
	self._ignoreEngineTimeScale = true
	self._totalDuration = 0
end

function Transition:play(times, delay, startTime, endTime, onComplete)
	if type(times)=='function' then
		self:_play(1, 0, 0, -1, times, false)
	elseif type(startTime)=='function' then
		self:_play(times, delay, 0, -1, startTime, false)
	else
		self:_play(times, delay, startTime, endTime, onComplete, false)
	end
end

function Transition:playReverse(times, delay, onComplete)
	if type(times)=='function' then
		self:_play(1, 0, 0, -1, times, true)
	else
		self:_play(times, delay, 0, - 1, onComplete, true)
	end
end

function Transition:changePlayTimes(value)
	self._totalTimes = value
end

function Transition:setAutoPlay(autoPlay, times, delay)
	if self._autoPlay ~= autoPlay then
		self._autoPlay = autoPlay
		self._autoPlayTimes = times
		self._autoPlayDelay = delay
		if self._autoPlay then
			if self._owner.onStage then
				self:play(times, delay)
			end
		else
			if not self._owner.onStage then
				self:stop(false, true)
			end
		end
	end
end

function Transition:_play(times, delay, startTime, endTime, onComplete, reverse)
	self:stop(true, true)

	self._totalTimes = times or 1
	self._reversed = reverse
	self._startTime = startTime or 0
	self._endTime = endTime or -1
	self._playing = true
	self._paused = false
	self._onComplete = onComplete

	local cnt = #self._items
	for i=1,cnt do
		local item = self._items[i]
		if item.target == nil then
			if #item.targetId > 0 then
				item.target = self._owner:getChildById(item.targetId)
			else
				item.target = self._owner
			end
		elseif item.target ~= self._owner and item.target.parent ~= self._owner then
			item.target = nil
		end

		if item.target ~= nil and item.type == TransitionActionType.Transition then
			local value = item.value
			local trans = item.target:getTransition(value.transName)
			if trans == this then
				trans = nil
			end
			if trans ~= nil then
				if value.playTimes == 0 then
					local j = i - 1
					while j >= 1 do
						local item2 = self._items[j]
						if item2.type == TransitionActionType.Transition then
							local value2 = item2.value
							if value2.trans == trans then
								value2.stopTime = item.time - item2.time
								break
							end
						end
						j = j - 1
					end
					if j < 0 then
						value.stopTime = 0
					else
						trans = nil
					end
					--no need to handle stop anymore
				else
					value.stopTime = - 1
				end
			end
			value.trans = trans
		end
		i = i + 1
	end

	if not delay or delay == 0 then
		self:onDelayedPlay()
	else
		GTween.delayedCall(delay):setTarget(self):onComplete(self.onDelayedPlay, self)
	end
end

function Transition:stop(setToComplete, processCallback)
	if not self._playing then
		return
	end

	self._playing = false
	self._totalTasks = 0
	self._totalTimes = 0
	local func = self._onComplete
	self._onComplete = nil

	GTween.kill(self)
	--delay start

	local cnt = #self._items
	if self._reversed then
		for i = cnt, 1, -1 do
			local item = self._items[i]
			if item.target ~= nil then
				self:stopItem(item, setToComplete)
			end
		end
	else
		for i=1,cnt do
			local item = self._items[i]
			if item.target ~= nil then
				self:stopItem(item, setToComplete)
			end
		end
	end

	if processCallback and func ~= nil then
		func()
	end
end

function Transition:stopItem(item, setToComplete)
	if item.displayLockToken ~= 0 then
		item.target:releaseDisplayLock(item.displayLockToken)
		item.displayLockToken = 0
	end

	if item.tweener ~= nil then
		item.tweener:kill(setToComplete)
		item.tweener = nil

		if item.type == TransitionActionType.Shake and not setToComplete then
			item.target._gearLocked = true
			item.target:setPosition(item.target.x - item.value.lastOffset.x, item.target.y - item.value.lastOffset.y)
			item.target._gearLocked = false
		end
	end

	if item.type == TransitionActionType.Transition then
		local value = item.value
		if value.trans ~= nil then
			value.trans:stop(setToComplete, false)
		end
	end
end

function Transition:setPaused(paused)
	if not self._playing or self._paused == paused then
		return
	end

	self._paused = paused
	local tweener = GTween.getTween(this)
	if tweener ~= nil then
		tweener:setPaused(paused)
	end

	local cnt = #self._items
	for i=1,cnt do
		local item = self._items[i]
		if item.target ~= nil then
			if item.type == TransitionActionType.Transition then
				if item.value.trans ~= nil then
					item.value.trans:setPaused(paused)
				end
			elseif item.type == TransitionActionType.Animation then
				if paused then
					item.value.flag = item.target.playing
					item.target.playing = false
				else
					item.target.playing = item.value.flag
				end
			end

			if item.tweener ~= nil then
				item.tweener:setPaused(paused)
			end
		end
	end
end

function Transition:dispose()
	if self._playing then
		GTween.kill(self)
	end
	--delay start

	local cnt = #self._items
	for i=1,cnt do
		local item = self._items[i]
		if item.tweener ~= nil then
			item.tweener:kill(false)
			item.tweener = nil
		end

		item.target = nil
		item.hook = nil
		if item.tweenConfig ~= nil then
			item.tweenConfig.endHook = nil
		end
	end
	self._playing = false
	self._onComplete = nil
end

function getters:playing()
	return self._playing
end

-- <param name="aParams"></param>
function Transition:setValue(label, ...)
	local args = {...}
	local cnt = #self._items
	local value
	local found = false
	for i=1,cnt do
		local item = self._items[i]
		local continue = false
		if item.label == label then
			if item.tweenConfig ~= nil then
				value = item.tweenConfig.startValue
			else
				value = item.value
			end
			found = true
		elseif item.tweenConfig ~= nil and item.tweenConfig.endLabel == label then
			value = item.tweenConfig.endValue
			found = true
		else
			continue = true
			break
		end

		if not continue then
			local default = item.type
			if default == TransitionActionType.XY or default == TransitionActionType.Size 
					or default == TransitionActionType.Pivot or default == TransitionActionType.Scale or default == TransitionActionType.Skew then
				value.b1 = true
				value.b2 = true
				value.f1 = args[1]
				value.f2 = args[2]
			elseif default == TransitionActionType.Alpha then
				value.f1 = args[1]
				break
			elseif default == TransitionActionType.Rotation then
				value.f1 = args[1]
				break
			elseif default == TransitionActionType.Color then
				value.color = args[1]
				break
			elseif default == TransitionActionType.Animation then
				value.frame = args[1]
				if #args>1 then
					value.playing = args[2]
				end
			elseif default == TransitionActionType.Visible then
				value.visible = args[1]
				break
			elseif default == TransitionActionType.Sound then
				value.sound = args[1]
				if #args > 1 then
					value.volume = args[2]
				end
			elseif default == TransitionActionType.Transition then
				value.transName = args[1]
				if #args > 1 then
					value.playTimes = args[2]
				end
			elseif default == TransitionActionType.Shake then
				value.amplitude = args[1]
				if #args > 1 then
					value.duration = args[2]
				end
			elseif default == TransitionActionType.ColorFilter then
				value.f1 = args[1]
				value.f2 = args[2]
				value.f3 = args[3]
				value.f4 = args[4]
			elseif default == TransitionActionType.Text or default == TransitionActionType.Icon then
				value.text = args[1]
			end
		end
	end

	assert(found, "label not exists")
end

function Transition:setHook(label, callback)
	local cnt = #self._items
	local found = false
	for i=1,cnt do
		local item = self._items[i]
		if item.label == label then
			item.hook = callback
			found = true
			break
		elseif item.tweenConfig ~= nil and item.tweenConfig.endLabel == label then
			item.tweenConfig.endHook = callback
			found = true
			break
		end
	end

	assert(found, "label not exists")
end

function Transition:clearHooks()
	local cnt = #self._items
	for i=1,cnt do
		local item = self._items[i]
		item.hook = nil
		if item.tweenConfig ~= nil then
			item.tweenConfig.endHook = nil
		end
	end
end

function Transition:setTarget(label, newTarget)
	local cnt = #self._items
	local found = false
	for i=1,cnt do
		local item = self._items[i]
		if item.label == label then
			item.targetId = (newTarget == self._owner or newTarget == nil) and "" or newTarget.id
			if self._playing then
				if #item.targetId > 0 then
					item.target = self._owner:getChildById(item.targetId)
				else
					item.target = self._owner
				end
			else
				item.target = nil
			end
			found = true
		end
	end

	assert(found, "label not exists")
end

function Transition:setDuration(label, value)
	local cnt = #self._items
	local found = false
	for i=1,cnt do
		local item = self._items[i]
		if item.tweenConfig ~= nil and item.label == label then
			item.tweenConfig.duration = value
			found = true
		end
	end

	assert(found, "label not exists or not a tween label")
end

function Transition:getLabelTime(label)
	local cnt = #self._items
	for i=1,cnt do
		local item = self._items[i]
		if item.label == label then
			return item.time
		elseif item.tweenConfig ~= nil and item.tweenConfig.endLabel == label then
			return item.time + item.tweenConfig.duration
		end
	end
end

function getters:timeScale()
	return self._timeScale
end

function setters:timeScale(value)
	if self._timeScale ~= value then
		self._timeScale = value

		local cnt = #self._items
		for i=1,cnt do
			local item = self._items[i]
			if item.tweener ~= nil then
				item.tweener:setTimeScale(value)
			elseif item.type == TransitionActionType.Transition then
				if item.value.trans ~= nil then
					item.value.trans.timeScale = value
				end
			elseif item.type == TransitionActionType.Animation then
				if item.target ~= nil then
					item.target.timeScale = value
				end
			end
		end
	end
end

function getters:ignoreEngineTimeScale()
	return self._ignoreEngineTimeScale
end

function setters:ignoreEngineTimeScale(value)
	if self._ignoreEngineTimeScale ~= value then
		self._ignoreEngineTimeScale = value

		local cnt = #self._items
		for i=1,cnt do
			local item = self._items[i]
			if item.tweener ~= nil then
				item.tweener:SetIgnoreEngineTimeScale(value)
			elseif item.type == TransitionActionType.Transition then
				if item.value.trans ~= nil then
					item.value.trans.ignoreEngineTimeScale = value
				end
			elseif item.type == TransitionActionType.Animation then
				if item.target ~= nil then
					item.target.ignoreEngineTimeScale = value
				end
			end
		end
	end
end

function Transition:updateFromRelations(targetId, dx, dy)
	local cnt = #self._items
	if cnt == 0 then
		return
	end

	for i=1,cnt do
		local item = self._items[i]
		if item.type == TransitionActionType.XY and item.targetId == targetId then
			if item.tweenConfig ~= nil then
				item.tweenConfig.startValue.f1 = item.tweenConfig.startValue.f1 + dx
				item.tweenConfig.startValue.f2 = item.tweenConfig.startValue.f2 + dy
				item.tweenConfig.endValue.f1 = item.tweenConfig.endValue.f1 + dx
				item.tweenConfig.endValue.f2 = item.tweenConfig.endValue.f2 + dy
			else
				item.value.f1 = item.value.f1 + dx
				item.value.f2 = item.value.f2 + dy
			end
		end
	end
end

function Transition:onOwnerAddedToStage()
	if self._autoPlay and not self._playing then
		self:play(self._autoPlayTimes, self._autoPlayDelay)
	end
end

function Transition:onOwnerRemovedFromStage()
	if band(self._options, OPTION_AUTO_STOP_DISABLED) == 0 then
		self:stop(band(self._options, OPTION_AUTO_STOP_AT_END) ~= 0 and true or false, false)
	end
end

function Transition:onDelayedPlay()
	self:internalPlay()

	self._playing = self._totalTasks > 0
	if self._playing then
		if band(self._options, OPTION_IGNORE_DISPLAY_CONTROLLER) ~= 0 then
			local cnt = #self._items
			for i=1,cnt do
				local item = self._items[i]
				if item.target ~= nil and item.target ~= self._owner then
					item.displayLockToken = item.target:addDisplayLock()
				end
			end
		end
	elseif self._onComplete ~= nil then
		local func = self._onComplete
		self._onComplete = nil
		func()
	end
end

function Transition:internalPlay()
	self._ownerBaseX = self._owner.x
	self._ownerBaseY = self._owner.y

	self._totalTasks = 0

	local needSkipAnimations = false
	local cnt = #self._items
	if not self._reversed then
		for i=1,cnt do
			local item = self._items[i]
			if item.target ~= nil then
				if item.type == TransitionActionType.Animation and self._startTime ~= 0 and item.time <= self._startTime then
					needSkipAnimations = true
					item.value.flag = false
				else
					self:playItem(item)
				end
			end
		end
	else
		for i = cnt, 1, -1 do
			local item = self._items[i]
			if item.target ~= nil then
				self:playItem(item)
			end
		end
	end

	if needSkipAnimations then
		self:skipAnimations()
	end
end

function Transition:playItem(item)
	local time
	if item.tweenConfig ~= nil then
		if self._reversed then
			time = (self._totalDuration - item.time - item.tweenConfig.duration)
		else
			time = item.time
		end

		if self._endTime == - 1 or time <= self._endTime then
			local startValue
			local endValue

			if self._reversed then
				startValue = item.tweenConfig.endValue
				endValue = item.tweenConfig.startValue
			else
				startValue = item.tweenConfig.startValue
				endValue = item.tweenConfig.endValue
			end

			item.value.b1 = startValue.b1 or endValue.b1
			item.value.b2 = startValue.b2 or endValue.b2

			local default = item.type
			if default == TransitionActionType.XY or default == TransitionActionType.Size 
				or default == TransitionActionType.Scale or default == TransitionActionType.Skew then
				item.tweener = GTween.to(startValue.f1, startValue.f2, endValue.f1, endValue.f2, item.tweenConfig.duration)
			elseif default == TransitionActionType.Alpha or default == TransitionActionType.Rotation then
				item.tweener = GTween.to(startValue.f1, endValue.f1, item.tweenConfig.duration)
			elseif default == TransitionActionType.Color then
				item.tweener = GTween.toColor(startValue.color, endValue.color, item.tweenConfig.duration)
			elseif default == TransitionActionType.ColorFilter then
				item.tweener = GTween.to(startValue.f1, startValue.f2, startValue.f3, startValue.f4,
					endValue.f1, endValue.f2, endValue.f3, endValue.f4, item.tweenConfig.duration)
			end

			item.tweener:setDelay(time):setEase(item.tweenConfig.easeType):setRepeat(item.tweenConfig.loop, item.tweenConfig.yoyo)
				:setTimeScale(self._timeScale):setIgnoreEngineTimeScale(self._ignoreEngineTimeScale):setTarget(item)
				:onStart(self.onTweenStart, self):onUpdate(self.onTweenUpdate, self):onComplete(self.onTweenComplete, self)

			if self._endTime >= 0 then
				item.tweener:setBreakpoint(self._endTime - time)
			end

			self._totalTasks = self._totalTasks + 1
		end
	elseif item.type == TransitionActionType.Shake then
		local value = item.value

		if self._reversed then
			time = (self._totalDuration - item.time - value.duration)
		else
			time = item.time
		end

		if self._endTime == - 1 or time <= self._endTime then
			value.lastOffsetX = 0
			value.lastOffsetY = 0
			value.offsetX = 0
			value.offsetY = 0
			item.tweener = GTween.shake(0, 0, value.amplitude, value.duration):setDelay(time):setTimeScale(self._timeScale)
				:setIgnoreEngineTimeScale(self._ignoreEngineTimeScale):setTarget(item)
				:onStart(self.onTweenStart, self):onUpdate(self.onTweenUpdate, self):onComplete(self.onTweenComplete, self)

			if self._endTime >= 0 then
				item.tweener:setBreakpoint(self._endTime - item.time)
			end

			self._totalTasks = self._totalTasks + 1
		end
	else
		if self._reversed then
			time = (self._totalDuration - item.time)
		else
			time = item.time
		end

		if time <= self._startTime then
			self:applyValue(item)
			self:callHook(item, false)
		elseif self._endTime == - 1 or time <= self._endTime then
			self._totalTasks = self._totalTasks + 1
			item.tweener = GTween.delayedCall(time):setTimeScale(self._timeScale):setIgnoreEngineTimeScale(self._ignoreEngineTimeScale)
				:setTarget(item):onComplete(self.onDelayedPlayItem, self)
		end
	end

	if item.tweener ~= nil then
		item.tweener:seek(self._startTime)
	end
end

function Transition:skipAnimations()
	local frame
	local playStartTime
	local playTotalTime
	local value
	local target
	local item

	local cnt = #self._items
	for i=1,cnt do
		item = self._items[i]
		if item.type == TransitionActionType.Animation and item.time <= self._startTime and not item.value.flag then
			value = item.value
			target = item.target
			frame = target.frame
			playStartTime = target.playing and 0 or - 1
			playTotalTime = 0

			for j=i,cnt do
				item = self._items[j]
				if item.type == TransitionActionType.Animation and item.target == target and item.time <= self._startTime then
					value = item.value
					value.flag = true

					if value.frame ~= - 1 then
						frame = value.frame
						if value.playing then
							playStartTime = item.time
						else
							playStartTime = - 1
						end
						playTotalTime = 0
					else
						if value.playing then
							if playStartTime < 0 then
								playStartTime = item.time
							end
						else
							if playStartTime >= 0 then
								playTotalTime = playTotalTime + (item.time - playStartTime)
							end
							playStartTime = - 1
						end
					end

					self:callHook(item, false)
				end
			end

			if playStartTime >= 0 then
				playTotalTime = playTotalTime + (self._startTime - playStartTime)
			end

			target.playing = playStartTime >= 0
			target.frame = frame
			if playTotalTime > 0 then
				target:advance(playTotalTime)
			end
		end
	end
end

function Transition:onDelayedPlayItem(tweener)
	local item = tweener.target
	item.tweener = nil
	self._totalTasks = self._totalTasks - 1

	self:applyValue(item)
	self:callHook(item, false)

	self:checkAllComplete()
end

function Transition:onTweenStart(tweener)
	local item = tweener.target

	if item.type == TransitionActionType.XY or item.type == TransitionActionType.Size then
		local startValue
		local endValue

		if self._reversed then
			startValue = item.tweenConfig.endValue
			endValue = item.tweenConfig.startValue
		else
			startValue = item.tweenConfig.startValue
			endValue = item.tweenConfig.endValue
		end

		if item.type == TransitionActionType.XY then
			if item.target ~= self._owner then
				if not startValue.b1 then
					startValue.f1 = item.target.x
				end
				if not startValue.b2 then
					startValue.f2 = item.target.y
				end
			else
				if not startValue.b1 then
					startValue.f1 = item.target.x - self._ownerBaseX
				end
				if not startValue.b2 then
					startValue.f2 = item.target.y - self._ownerBaseY
				end
			end
		else
			if not startValue.b1 then
				startValue.f1 = item.target.width
			end
			if not startValue.b2 then
				startValue.f2 = item.target.height
			end
		end

		if not endValue.b1 then
			endValue.f1 = startValue.f1
		end
		if not endValue.b2 then
			endValue.f2 = startValue.f2
		end

		tweener.startValue:setAll(startValue.f1, startValue.f2)
		tweener.endValue:setAll(endValue.f1, endValue.f2)
	end

	self:callHook(item, false)
end

function Transition:onTweenUpdate(tweener)
	local item = tweener.target
	local default = item.type
	if default == TransitionActionType.XY or default == TransitionActionType.Size or default == TransitionActionType.Scale or default == TransitionActionType.Skew then
		item.value.f1 = tweener.value.x
		item.value.f2 = tweener.value.y
	elseif default == TransitionActionType.Alpha or default == TransitionActionType.Rotation then
		item.value.f1 = tweener.value.x
	elseif default == TransitionActionType.Color then
		item.value.color = tweener.value:getColor()
	elseif default == TransitionActionType.ColorFilter then
		item.value.f1 = tweener.value.x
		item.value.f2 = tweener.value.y
		item.value.f3 = tweener.value.z
		item.value.f4 = tweener.value.w
	elseif default == TransitionActionType.Shake then
		item.value.offsetX = tweener.value.x
		item.value.offsetY = tweener.value.y
	end
	self:applyValue(item)
end

function Transition:onTweenComplete(tweener)
	local item = tweener.target
	item.tweener = nil
	self._totalTasks = self._totalTasks - 1

	if tweener.allCompleted then
		self:callHook(item, true)
	end

	self:checkAllComplete()
end

function Transition:onPlayTransCompleted(item)
	self._totalTasks = self._totalTasks - 1

	self:checkAllComplete()
end

function Transition:callHook(item, tweenEnd)
	if tweenEnd then
		if item.tweenConfig ~= nil and item.tweenConfig.endHook ~= nil then
			item.tweenConfig.endHook()
		end
	else
		if item.time >= self._startTime and item.hook ~= nil then
			item.hook()
		end
	end
end

function Transition:checkAllComplete()
	if self._playing and self._totalTasks == 0 then
		if self._totalTimes < 0 then
			self:internalPlay()
		else
			self._totalTimes = self._totalTimes - 1
			if self._totalTimes > 0 then
				self:internalPlay()
			else
				self._playing = false

				local cnt = #self._items
				for i=1,cnt do
					local item = self._items[i]
					if item.target ~= nil and item.displayLockToken ~= 0 then
						item.target:releaseDisplayLock(item.displayLockToken)
						item.displayLockToken = 0
					end
				end

				if self._onComplete ~= nil then
					local func = self._onComplete
					self._onComplete = nil
					func()
				end
			end
		end
	end
end

function Transition:applyValue(item)
	item.target._gearLocked = true

	local default = item.type
	if default == TransitionActionType.XY then
		local value = item.value
		if item.target == self._owner then
			local f1, f2
			if not value.b1 then
				f1 = item.target.x
			else
				f1 = value.f1 + self._ownerBaseX
			end
			if not value.b2 then
				f2 = item.target.y
			else
				f2 = value.f2 + self._ownerBaseY
			end
			item.target:setPosition(f1, f2)
		else
			if not value.b1 then
				value.f1 = item.target.x
			end
			if not value.b2 then
				value.f2 = item.target.y
			end
			item.target:setPosition(value.f1, value.f2)
		end
	elseif default == TransitionActionType.Size then
		local value = item.value
		if not value.b1 then
			value.f1 = item.target.width
		end
		if not value.b2 then
			value.f2 = item.target.height
		end
		item.target:setSize(value.f1, value.f2)
	elseif default == TransitionActionType.Pivot then
		item.target:setPivot(item.value.f1, item.value.f2, item.target.pivotAsAnchor)
	elseif default == TransitionActionType.Alpha then
		item.target.alpha = item.value.f1
	elseif default == TransitionActionType.Rotation then
		item.target.rotation = item.value.f1
	elseif default == TransitionActionType.Scale then
		item.target:setScale(item.value.f1, item.value.f2)
	elseif default == TransitionActionType.Skew then
		item.target:setskew(item.value.f1, item.value.f2)
	elseif default == TransitionActionType.Color then
		item.target.color = item.value.color
	elseif default == TransitionActionType.Animation then
		local value = item.value
		if value.frame >= 0 then
			item.target.frame = value.frame
		end
		item.target.playing = value.playing
		item.target.timeScale = self._timeScale
		item.target.ignoreEngineTimeScale = self._ignoreEngineTimeScale
	elseif default == TransitionActionType.Visible then
		item.target.visible = item.value.visible
	elseif default == TransitionActionType.Shake then
		local value = item.value
		item.target:setPosition(item.target.x - value.lastOffsetX + value.offsetX, item.target.y - value.lastOffsetY + value.offsetY)
		value.lastOffsetX = value.offsetX
		value.lastOffsetY = value.offsetY
	elseif default == TransitionActionType.Transition then
		if self._playing then
			local value = item.value
			if value.trans ~= nil then
				self._totalTasks = self._totalTasks + 1

				local startTime = self._startTime > item.time and (self._startTime - item.time) or 0
				local endTime = self._endTime >= 0 and (self._endTime - item.time) or - 1
				if value.stopTime >= 0 and (endTime < 0 or endTime > value.stopTime) then
					endTime = value.stopTime
				end
				value.trans.timeScale = self._timeScale
				value.trans.ignoreEngineTimeScale = self._ignoreEngineTimeScale
				value.trans:_play(value.playTimes, 0, startTime, endTime, value.playCompleteDelegate, self._reversed)
			end
		end
	elseif default == TransitionActionType.Sound then
		if self._playing and item.time >= self._startTime then
			local value = item.value
			if value.audioClip == nil then
				value.audioClip = UIPackage.getItemAssetByURL(value.sound)
			end

			if value.audioClip ~= nil then
				UIRoot:playOneShotSound(value.audioClip, value.volume)
			end
		end
	elseif default == TransitionActionType.ColorFilter then
		--[[local value = item.value
		local cf = item.target.filter
		if cf == nil then
			cf = ColorFilter()
			item.target:setfilter(cf)
		else
			cf:Reset()
		end

		cf:AdjustBrightness(value.f1)
		cf:AdjustContrast(value.f2)
		cf:AdjustSaturation(value.f3)
		cf:AdjustHue(value.f4)]]
	elseif default == TransitionActionType.Text then
		item.target.text = item.value.text
	elseif default == TransitionActionType.Icon then
		item.target.icon = item.value.text
	end

	item.target._gearLocked = false
end

function Transition:setup(buffer)
	self.name = buffer:readS()
	self._options = buffer:readInt()
	self._autoPlay = buffer:readBool()
	self._autoPlayTimes = buffer:readInt()
	self._autoPlayDelay = buffer:readFloat()

	local cnt = buffer:readShort()
	self._items = {}
	for i=1,cnt do
		local dataLen = buffer:readShort()
		local curPos = buffer.pos

		buffer:seek(curPos, 0)

		local item = {
			type = buffer:readByte(),
			value = {}
		}
		table.insert(self._items, item)

		item.time = buffer:readFloat()
		local targetId = buffer:readShort()
		if targetId < 0 then
			item.targetId = ""
		else
			item.targetId = self._owner:getChildAt(targetId).id
		end
		item.label = buffer:readS()

		if buffer:readBool() then
			buffer:seek(curPos, 1)

			item.tweenConfig = {
				startValue = {},
				endValue = {}
			}
			item.tweenConfig.duration = buffer:readFloat()
			if item.time + item.tweenConfig.duration > self._totalDuration then
				self._totalDuration = item.time + item.tweenConfig.duration
			end
			item.tweenConfig.easeType = buffer:readByte()
			item.tweenConfig.loop = buffer:readInt()
			item.tweenConfig.yoyo = buffer:readBool()
			item.tweenConfig.endLabel = buffer:readS()

			buffer:seek(curPos, 2)

			self:decodeValue(item, buffer, item.tweenConfig.startValue)

			buffer:seek(curPos, 3)

			self:decodeValue(item, buffer, item.tweenConfig.endValue)
		else
			if item.time > self._totalDuration then
				self._totalDuration = item.time
			end

			buffer:seek(curPos, 2)

			self:decodeValue(item, buffer, item.value)
		end

		buffer.pos = curPos + dataLen
	end
end

function Transition:decodeValue(item, buffer, value)
	local default = item.type
	if default == TransitionActionType.XY or default == TransitionActionType.Size or default == TransitionActionType.Pivot or default == TransitionActionType.Skew then
		value.b1 = buffer:readBool()
		value.b2 = buffer:readBool()
		value.f1 = buffer:readFloat()
		value.f2 = buffer:readFloat()
	elseif default == TransitionActionType.Alpha or default == TransitionActionType.Rotation then
		value.f1 = buffer:readFloat()
	elseif default == TransitionActionType.Scale then
		value.f1 = buffer:readFloat()
		value.f2 = buffer:readFloat()
	elseif default == TransitionActionType.Color then
		value.color = buffer:readColor()
	elseif default == TransitionActionType.Animation then
		value.playing = buffer:readBool()
		value.frame = buffer:readInt()
	elseif default == TransitionActionType.Visible then
		value.visible = buffer:readBool()
	elseif default == TransitionActionType.Sound then
		value.sound = buffer:readS()
		value.volume = buffer:readFloat()
	elseif default == TransitionActionType.Transition then
		value.transName = buffer:readS()
		value.playTimes = buffer:readInt()
	elseif default == TransitionActionType.Shake then
		value.amplitude = buffer:readFloat()
		value.duration = buffer:readFloat()
	elseif default == TransitionActionType.ColorFilter then
		value.f1 = buffer:readFloat()
		value.f2 = buffer:readFloat()
		value.f3 = buffer:readFloat()
		value.f4 = buffer:readFloat()
	elseif default == TransitionActionType.Text or default == TransitionActionType.Icon then
		value.text = buffer:readS()
	end
end

return Transition