local composer = require( "composer" )
local ScrollPaneHeader = require( "ScrollPaneHeader" )

local scene = composer.newScene()

local _groot
local _view

local _list1
local _list2

function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/PullToRefresh')
	UIObjectFactory.setExtension("ui://PullToRefresh/Header", ScrollPaneHeader)

	composer.addCloseButton()

	_view = UIPackage.createObject("PullToRefresh", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_list1 = _view:getChild("list1")
	_list1.itemRenderer = scene.renderListItem1
	_list1:setVirtual()
	_list1.numItems = 1
	_list1:on("pullDownRelease", scene.onPullDownToRefresh)

	_list2 = _view:getChild("list2")
	_list2.itemRenderer = scene.renderListItem2
	_list2:setVirtual()
	_list2.numItems = 1
	_list2:on("pullUpRelease", scene.onPullUpToRefresh)
end

function scene.renderListItem1(index, item)
	item.text = "Item "..(_list1.numItems - index - 1)
end

function scene.renderListItem2(index, item)
	item.text = "Item "..index
end

function scene.onPullDownToRefresh()
	local header = _list1.scrollPane.header
	if header.readyToRefresh then
		header:setRefreshStatus(2)
		_list1.scrollPane:lockHeader(header.sourceHeight)

		--Simulate a async resquest
		GTween.delayedCall(2):onComplete(scene.simulateAsynWorkFinished):setTarget(_view)
	end
end

function scene.onPullUpToRefresh()
	local footer = _list2.scrollPane.footer

	footer:getController("c1").selectedIndex = 1
	_list2.scrollPane:lockFooter(footer.sourceHeight)

	--Simulate a async resquest
	GTween.delayedCall(2):onComplete(scene.simulateAsynWorkFinished2):setTarget(_view)
end

function scene.simulateAsynWorkFinished()
	_list1.numItems = _list1.numItems + 5

	--Refresh completed
	local header = _list1.scrollPane.header
	header:setRefreshStatus(3)
	_list1.scrollPane:lockHeader(35)

	GTween.delayedCall(2):onComplete(scene.simulateHintFinished):setTarget(_view)
end

function scene.simulateHintFinished()
	local header = _list1.scrollPane.header
	header:setRefreshStatus(0)
	_list1.scrollPane:lockHeader(0)
end

function scene.simulateAsynWorkFinished2()
	_list2.numItems = _list2.numItems + 5

	--Refresh completed
	local footer = _list2.scrollPane.footer
	footer:getController("c1").selectedIndex = 0
	_list2.scrollPane:lockFooter(0)
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('UI/PullToRefresh')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene