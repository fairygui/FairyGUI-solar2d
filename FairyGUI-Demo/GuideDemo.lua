local composer = require( "composer" )

local scene = composer.newScene()

local _groot
local _view

local _guideLayer
local _bagBtn

function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/Guide')

	composer.addCloseButton()

	_view = UIPackage.createObject("Guide", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_guideLayer = UIPackage.createObject("Guide", "GuideLayer")
	_guideLayer:makeFullScreen()
	_guideLayer:addRelation(_groot, RelationType.Size)
		
	_bagBtn = _view:getChild("bagBtn")
	_bagBtn:onClick(function()
		_guideLayer:removeFromParent()
	end)

	_view:getChild("n2"):onClick(scene.onClick)
end

function scene.onClick()
	_groot:addChild(_guideLayer)
	local rect = _bagBtn:localToGlobalRect(0, 0, _bagBtn.width, _bagBtn.height)
	_guideLayer:globalToLocalRect(rect.x, rect.y, rect.width, rect.height, rect)

	local window = _guideLayer:getChild("window")
	window:setSize(rect.width, rect.height)
	GTween.to(window.x, window.y, rect.x, rect.y, 0.5):setTarget(window, window.setPosition)
end

function scene:destroy( event )
	_guideLayer:dispose()
	_groot:dispose()
	UIPackage.removePackage('Guide')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene