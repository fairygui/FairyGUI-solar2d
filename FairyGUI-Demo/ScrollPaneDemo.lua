local composer = require( "composer" )

local scene = composer.newScene()

local _groot
local _view
local _list

function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/ScrollPane')

	composer.addCloseButton()

	_view = UIPackage.createObject("ScrollPane", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_list = _view:getChild("list")
	_list.itemRenderer = scene.renderListItem
	_list:setVirtual()
	_list.numItems = 1000
	_list:on("touchBegin", scene.onClickList)
end

function scene.renderListItem(index, item)
	item.title = "Item "..index
	item.scrollPane.posX = 0 --reset scroll pos

	item:getChild("b0"):onClick(scene.onClickStick)
	item:getChild("b1"):onClick(scene.onClickDelete)
end

function scene.onClickList(context)
	--点击列表时，查找是否有项目处于编辑状态， 如果有就归位
	local cnt = _list.numChildren
	for i=0,cnt-1 do
		local item = _list:getChildAt(i)
		if item.scrollPane.posX ~= 0 then
			--Check if clicked on the button
			if item:getChild("b0"):isAncestorOf(_groot.touchTarget) or item:getChild("b1"):isAncestorOf(_groot.touchTarget) then
				return
			end

			item.scrollPane:setPosX(0, true)

			--取消滚动面板可能发生的拉动。
			item.scrollPane:cancelDragging()
			_list.scrollPane:cancelDragging()
			break
		end
	end
end

function scene.onClickStick(context)
	_view:getChild("txt").text = "Stick "..context.sender.parent.text
end

function scene.onClickDelete(context)
	_view:getChild("txt").text = "Delete "..context.sender.parent.text
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('ScrollPane')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene