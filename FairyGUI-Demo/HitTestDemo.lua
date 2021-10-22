local composer = require( "composer" )

local scene = composer.newScene()

local _groot
local _view

function scene:create( event )
	_groot = GRoot.create(self)
	
	UIPackage.addPackage('UI/HitTest')

	composer.addCloseButton()

	_view = UIPackage.createObject("HitTest", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('UI/HitTest')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene