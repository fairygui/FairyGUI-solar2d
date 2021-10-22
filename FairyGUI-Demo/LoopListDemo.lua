local composer = require( "composer" )

local scene = composer.newScene()

local _groot
local _view
local _list

function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/LoopList')

	composer.addCloseButton()

	_view = UIPackage.createObject("LoopList", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_list = _view:getChild("list")
	_list:setVirtualAndLoop()

	_list.itemRenderer = scene.renderListItem
	_list.numItems = 5
	_list:on("scroll", scene.doSpecialEffect)

	scene.doSpecialEffect()
end
	
function scene.doSpecialEffect()
	--change the scale according to the distance to the middle
	local midX = _list.scrollPane.posX + _list.viewWidth / 2
	local cnt = _list.numChildren
	for i=0,cnt-1 do
		local obj = _list:getChildAt(i)
		local dist = math.abs(midX - obj.x - obj.width / 2)
		if dist > obj.width then --no intersection
			obj:setScale(1, 1)
		else
			local ss = 1 + (1 - dist / obj.width) * 0.24
			obj:setScale(ss, ss)
		end
	end
	
	_view:getChild("n3").text = ""..((_list:getFirstChildInView() + 1) % _list.numItems)
end

function scene.renderListItem(index, item)
	item:setPivot(0.5, 0.5)
	item.icon = UIPackage.getItemURL("LoopList", "n"..(index + 1))
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('LoopList')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene