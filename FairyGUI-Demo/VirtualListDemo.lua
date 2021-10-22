local composer = require( "composer" )
local MailItem = require( "MailItem" )

local scene = composer.newScene()

local _groot
local _view
local _list

function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/VirtualList')

	composer.addCloseButton()

	_view = UIPackage.createObject("VirtualList", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	UIObjectFactory.setExtension("ui://VirtualList/mailItem", MailItem)

	_view:getChild("n6"):onClick(function () _list:addSelection(500, true) end)
	_view:getChild("n7"):onClick(function () _list.scrollPane:scrollTop() end)
	_view:getChild("n8"):onClick(function ()  _list.scrollPane:scrollBottom() end)

	_list = _view:getChild("mailList")
	_list:setVirtual()

	_list.itemRenderer = scene.renderListItem
	_list.numItems = 1000
end

function scene.renderListItem(index, item)
	item:setFetched(index % 3 == 0)
	item:setRead(index % 2 == 0)
	item:setTime("5 Nov 2015 16:24:33")
	item.title = index.." Mail title here"
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('VirtualList')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene