local composer = require( "composer" )
local Joystick = require( "JoystickModule" )
local scene = composer.newScene()

local _groot
local _view
local _text

function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/Joystick')

	composer.addCloseButton()

	_view = UIPackage.createObject("Joystick", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_text = _view:getChild("n9")

	Joystick.init(_view)
	_view:on("JoystickMoving", scene.onJoystickMoving)
	_view:on("JoystickUp", scene.onJoystickUp)
end

function scene.onJoystickMoving(context)
	_text.text = ""..context.data
end

function scene.onJoystickUp()
	_text.text = ""
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('Joystick')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene