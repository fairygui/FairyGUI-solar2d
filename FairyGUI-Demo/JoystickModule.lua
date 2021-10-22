local JoystickModule = {}

local _InitX
local _InitY
local _startStageX
local _startStageY
local _lastStageX
local _lastStageY
local _button
local _touchArea
local _thumb
local _center
local _touchId
local _tweener
local _curPosX
local _curPosY

JoystickModule.radius = 150

local function onTouchDown(context)
	local evt = context.inputEvent
	if not _touchId then --First touch

		_touchId = evt.touchId

		if _tweener then
			_tweener:kill()
			_tweener = nil
		end

		_curPosX, _curPosY = UIRoot:globalToLocal(evt.x, evt.y)
		local bx = _curPosX
		local by = _curPosY
		_button.selected = true

		if bx < 0 then
			bx = 0
		elseif bx > _touchArea.width then
			bx = _touchArea.width
		end

		if by > UIRoot.height then
			by = UIRoot.height
		elseif by < _touchArea.y then
			by = _touchArea.y
		end

		_lastStageX = bx
		_lastStageY = by
		_startStageX = bx
		_startStageY = by

		_center.visible = true
		_center.x = bx - _center.width / 2
		_center.y = by - _center.height / 2
		_button.x = bx - _button.width / 2
		_button.y = by - _button.height / 2

		local deltaX = bx - _InitX
		local deltaY = by - _InitY
		local degrees = math.atan2(deltaY, deltaX) * 180 / math.pi
		_thumb.rotation = degrees + 90

		context:captureTouch()
	end
end

local function onTouchMove(context)
	local evt = context.inputEvent

	if _touchId and evt.touchId == _touchId then
		local bx, by = UIRoot:globalToLocal(evt.x, evt.y)
		local moveX = bx - _lastStageX
		local moveY = by - _lastStageY
		_lastStageX = bx
		_lastStageY = by
		local buttonX = _button.x + moveX
		local buttonY = _button.y + moveY

		local offsetX = buttonX + _button.width / 2 - _startStageX
		local offsetY = buttonY + _button.height / 2 - _startStageY

		local rad = math.atan2(offsetY, offsetX)
		local degree = rad * 180 / math.pi
		_thumb.rotation = degree + 90

		local maxX = JoystickModule.radius * math.cos(rad)
		local maxY = JoystickModule.radius * math.sin(rad)
		if math.abs(offsetX) > math.abs(maxX) then
			offsetX = maxX
		end
		if math.abs(offsetY) > math.abs(maxY) then
			offsetY = maxY
		end

		buttonX = _startStageX + offsetX
		buttonY = _startStageY + offsetY
		if buttonX < 0 then
			buttonX = 0
		end
		if buttonY > UIRoot.height then
			buttonY = UIRoot.height
		end

		_button.x = buttonX - _button.width / 2
		_button.y = buttonY - _button.height / 2

		_button.parent:emit("JoystickMoving", degree)
	end
end

local function onTweenComplete()
	_tweener = nil
	_button.selected = false
	_thumb.rotation = 0
	_center.visible = true
	_center.x = _InitX - _center.width / 2
	_center.y = _InitY - _center.height / 2
end

local function onTouchEnd(context)
	local evt = context.inputEvent

	if _touchId and evt.touchId == _touchId then
		_touchId = nil
		_thumb.rotation = _thumb.rotation + 180
		_center.visible = false
		_tweener = GTween.to(_button.x, _button.y, _InitX - _button.width / 2, _InitY - _button.height / 2, 0.3)
			:setTarget(_button, _button.setPosition)
			:setEase(EaseType.CircOut)
			:onComplete(onTweenComplete)

		_button.parent:emit("JoystickUp")
	end
end

function JoystickModule.init(view)
	_button = view:getChild("joystick")
	_button.changeStateOnClick = false
	_thumb = _button:getChild("thumb")
	_touchArea = view:getChild("joystick_touch")
	_center = view:getChild("joystick_center")

	_InitX = _center.x + _center.width / 2
	_InitY = _center.y + _center.height / 2

	_touchArea:on("touchBegin", onTouchDown)
	_touchArea:on("touchMove", onTouchMove)
	_touchArea:on("touchEnd", onTouchEnd)
end

return JoystickModule