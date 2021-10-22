local composer = require( "composer" )

local scene = composer.newScene()

local _groot
local _view
local _bagWindow

local BagWindow = class('BagWindow', Window)
function BagWindow:onInit()
	self.contentPane = UIPackage.createObject("Bag", "BagWin")
	self:center()
end

function BagWindow:onShown()
	local list = self.contentPane:getChild("list")
	list:on("clickItem", self.onClickItem, self)
	local this = self
	list.itemRenderer = function(index, obj) this:renderListItem(index, obj) end
	list:setVirtual()
	list.numItems = 45
end

function BagWindow:renderListItem(index, obj)
	obj.icon = "Icons/i"..(math.floor(math.random(10))-1)..".png"
	obj.text = "" ..math.floor(math.random(100))
end

function BagWindow:onClickItem(context)
	local item = context.data
	self.contentPane:getChild("n11").url = item.icon
	self.contentPane:getChild("n13").text = item.icon
end

function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/Bag')

	composer.addCloseButton()

	_view = UIPackage.createObject("Bag", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_bagWindow = BagWindow.new()
	_view:getChild("bagBtn"):onClick(function() _bagWindow:show() end);
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('Bag')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene