local composer = require( "composer" )
local MailItem = require( "MailItem" )

local scene = composer.newScene()

local _groot
local _view
local _list

function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/ListEffect')
	UIObjectFactory.setExtension("ui://ListEffect/mailItem", MailItem)

	composer.addCloseButton()

	_view = UIPackage.createObject("ListEffect", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_list = _view:getChild("mailList")
	for i=1,10 do
		local item = _list:addItemFromPool()
		item:setFetched(i % 3 == 0)
		item:setRead(i % 2 == 0)
		item:setTime("5 Nov 2015 16:24:33")
		item.title = "Mail title here"
	end

	_list:ensureBoundsCorrect()
	local delay = 0
	for i=0,9 do
		local item = _list:getChildAt(i)
		if _list:isChildInView(item) then
			item:playEffect(delay)
			delay = delay + 0.2
		else
			break
		end
	end
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('ListEffect')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene