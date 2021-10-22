local composer = require( "composer" )

local scene = composer.newScene()

local _groot
local _view
local _btn0
local _btn1

function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/Cooldown')

	composer.addCloseButton()

	_view = UIPackage.createObject("Cooldown", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_btn0 = _view:getChild("b0")
	_btn1 = _view:getChild("b1")
	_btn0:getChild("icon").icon = "Icons/k0.png"
	_btn1:getChild("icon").icon = "Icons/k1.png"

	GTween.to(0, 100, 5):setTarget(_btn0, GProgressBar.update):setRepeat(-1)
	GTween.to(10, 0, 10):setTarget(_btn1, GProgressBar.update):setRepeat(-1)
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('Cooldown')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene