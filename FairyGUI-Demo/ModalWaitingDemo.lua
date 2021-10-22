local composer = require( "composer" )

local scene = composer.newScene()

local _groot
local _view

local _testWin

local TestWin = class('TestWin', Window)
function TestWin:onInit()
	self.contentPane = UIPackage.createObject("ModalWaiting", "TestWin")
	self.contentPane:getChild("n1"):onClick(self.onClickStart, self)
	self:center()
end

function TestWin:onClickStart()
	--这里模拟一个要锁住当前窗口的过程，在锁定过程中，窗口仍然是可以移动和关闭的
	self:showModalWait()
	GTween.delayedCall(3):onComplete(function () self:closeModalWait() end, self)
end

--其实用动效做就行了，这里只是演示了怎样扩展一个组件
local GlobalWaiting = class('GlobalWaiting', GComponent)

function GlobalWaiting:onConstruct()
	self._obj = self:getChild("n1")
	self:frameLoop(self.onUpdate, self)
end

function GlobalWaiting:onUpdate()
	local i = self._obj.rotation
	i = i + 10
	if i > 360 then
		i = i % 360
	end
	self._obj.rotation = i
end

function scene:create( event )
	_groot = GRoot.create(self)

	UIConfig.globalModalWaiting = "ui://ModalWaiting/GlobalModalWaiting"
    UIConfig.windowModalWaiting = "ui://ModalWaiting/WindowModalWaiting"
	UIObjectFactory.setExtension("ui://ModalWaiting/GlobalModalWaiting", GlobalWaiting)

	UIPackage.addPackage('UI/ModalWaiting')

	composer.addCloseButton()

	_view = UIPackage.createObject("ModalWaiting", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_testWin = TestWin.new()

	_view:getChild("n0"):onClick( function() _testWin:show() end )
		
	--这里模拟一个要锁住全屏的等待过程
	_groot:showModalWait()

	GTween.delayedCall(3):onComplete(function() _groot:closeModalWait() end):setTarget(_view)
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('ModalWaiting')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene