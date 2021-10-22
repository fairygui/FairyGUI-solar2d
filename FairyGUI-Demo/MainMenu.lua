local composer = require( "composer" )

local scene = composer.newScene()

local _groot
local _view

local function startDemo(sceneName)
	composer.removeScene("MainMenu")
	composer.gotoScene(sceneName)
end
 
function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/MainMenu')

	_view = UIPackage.createObject("MainMenu", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_view:getChild("n1"):onClick(function () 
		startDemo('BasicsDemo')
	end)
	_view:getChild("n2"):onClick(function () 
		startDemo('TransitionDemo')
	end)
	_view:getChild("n4"):onClick(function () 
		startDemo('VirtualListDemo')
	end)
	_view:getChild("n5"):onClick(function () 
		startDemo('LoopListDemo')
	end)
	_view:getChild("n6"):onClick(function () 
		startDemo('HitTestDemo')
	end)
	_view:getChild("n7"):onClick(function () 
		startDemo('PullToRefreshDemo')
	end)
	_view:getChild("n8"):onClick(function () 
		startDemo('ModalWaitingDemo')
	end)
	_view:getChild("n9"):onClick(function () 
		startDemo('JoystickDemo')
	end)
	_view:getChild("n10"):onClick(function () 
		startDemo('BagDemo')
	end)
	_view:getChild("n11"):onClick(function () 
		startDemo('ChatDemo')
	end)
	_view:getChild("n12"):onClick(function () 
		startDemo('ListEffectDemo')
	end)
	_view:getChild("n13"):onClick(function () 
		startDemo('ScrollPaneDemo')
	end)
	_view:getChild("n14"):onClick(function () 
		startDemo('TreeViewDemo')
	end)
	_view:getChild("n15"):onClick(function () 
		startDemo('GuideDemo')
	end)
	_view:getChild("n16"):onClick(function () 
		startDemo('CooldownDemo')
	end)
end 

function scene:destroy( event )
	_view:dispose()
	_groot:dispose()
end
 
scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene