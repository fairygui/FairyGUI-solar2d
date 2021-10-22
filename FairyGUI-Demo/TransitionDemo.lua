local composer = require( "composer" )

local scene = composer.newScene()

local _groot
local _view

local _btnGroup
local _g1
local _g2
local _g3
local _g4
local _g5

function scene:create( event )
	_groot = GRoot.create(self)
	UIPackage.addPackage('UI/Transition')

	composer.addCloseButton()

	_view = UIPackage.createObject("Transition", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_btnGroup = _view:getChild("g0")

	_g1 = UIPackage.createObject("Transition", "BOSS")
	_g2 = UIPackage.createObject("Transition", "BOSS_SKILL")
	_g3 = UIPackage.createObject("Transition", "TRAP")
	_g4 = UIPackage.createObject("Transition", "GoodHit")
	_g5 = UIPackage.createObject("Transition", "PowerUp")
	--play_num_now是在编辑器里设定的名称，这里表示播放到'play_num_now'这个位置时才开始播放数字变化效果
	_g5:getTransition("t0"):setHook("play_num_now", scene._playNum)

	_view:getChild("btn0"):onClick(function () scene._play(_g1) end)
	_view:getChild("btn1"):onClick(function () scene._play(_g2) end)
	_view:getChild("btn2"):onClick(function () scene._play(_g3) end)
	_view:getChild("btn3"):onClick(scene._play4)
	_view:getChild("btn4"):onClick(scene._play5)
 end

function scene._play(target)
	_btnGroup.visible = false
	_groot:addChild(target)
	local t = target:getTransition("t0")
	t:play(function()
		_btnGroup.visible = true
		_groot:removeChild(target)
	end)
end

function scene._play4()
	_btnGroup.visible = false
	_g4.x = _groot.width - _g4.width - 20
	_g4.y = 100
	_groot:addChild(_g4)
	local t = _g4:getTransition("t0")
	--播放3次
	t:play(3, 0, function()
		_btnGroup.visible = true
		_groot:removeChild(_g4)
	end)
end

local _startValue
local _endValue

function scene._play5()
	_btnGroup.visible = false
	_g5.x = 20
	_g5.y = _groot.height - _g5.height - 100
	_groot:addChild(_g5)
	local t = _g5:getTransition("t0")
	_startValue = 10000
	local add = math.ceil(math.random(1000, 3000))
	_endValue = _startValue + add
	_g5:getChild("value").text = "".._startValue
	_g5:getChild("add_value").text = "+"..add
	t:play(function()
		_btnGroup.visible = true
		_groot:removeChild(_g5)
	end)
end

function scene._playNum()
	--这里演示了一个数字变化的过程
	GTween.to(_startValue, _endValue, 0.3)
		:setEase(EaseType.Linear)
		:onUpdate(function (tweener)
			_g5:getChild("value").text = ''..math.floor(tweener.value.x)
		end)
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('Transition')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene