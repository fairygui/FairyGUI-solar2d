local composer = require( "composer" )
local DragDropManager = require("DragDropManager")
local WindowA = require("WindowA")
local WindowB = require("WindowB")

local scene = composer.newScene()

local _groot
local _view
local _backBtn
local _demoContainer
local _demoObjects = {}
local _cc
 
function scene:create( event )
	_groot = GRoot.create(self)

	UIConfig.verticalScrollBar = "ui://Basics/ScrollBar_VT"
	UIConfig.horizontalScrollBar = "ui://Basics/ScrollBar_HZ"
	UIConfig.popupMenu = "ui://Basics/PopupMenu"
	UIConfig.buttonSound = "ui://Basics/click"

	UIPackage.addPackage('UI/Basics')

	composer.addCloseButton()

	_view = UIPackage.createObject("Basics", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_backBtn = _view:getChild("btn_Back")
	_backBtn.visible = false
	_backBtn:onClick(self.onClickBack, self)

	_demoContainer = _view:getChild("container")
	_cc = _view:getController("c1")

	local cnt = _view.numChildren
	for i=0,cnt-1 do
		local obj = _view:getChildAt(i)
		if obj.group and obj.group.name == "btns" then
			obj:onClick(self.runDemo, self)
		end
	end

	_demoObjects = {}
end

function scene:runDemo(context)
	local type = string.sub(context.sender.name, 5)
	local obj = _demoObjects[type]
	if obj == nil then
		obj = UIPackage.createObject("Basics", "Demo_"..type)
		assert(obj, 'create failed '..type)
		_demoObjects[type] = obj
	end

	_demoContainer:removeChildren()
	_demoContainer:addChild(obj)
	_cc.selectedIndex = 1
	_backBtn.visible = true

	if type=="Button" then
		self:playButton()
	elseif type=="Text" then
		self:playText()
	 elseif type=="Window" then
		self:playWindow()
	 elseif type=="Popup" then
		self:playPopup()
	elseif type=="Drag&Drop" then
		self:playDragDrop()
	elseif type=="Depth" then
		self:playDepth()
	 elseif type=="Grid" then
		self:playGrid()
	 elseif type=="ProgressBar" then
		self:playProgressBar()
	 end
end

function scene:onClickBack()
	_cc.selectedIndex = 0
	_backBtn.visible = false
end

--------------------------------
function scene:playButton()
	local obj = _demoObjects["Button"]
	obj:getChild("n34"):onClick(self._clickButton, self)
end

function scene:_clickButton()
	print("click button")
end

-------------------------------
function scene:playText()
	local obj = _demoObjects["Text"]
	obj:getChild("n12"):on("link", self._clickLink, self)
	obj:getChild("n25"):onClick(self._clickGetInput, self)
end

function scene:_clickLink(context)
	local obj = _demoObjects["Text"]
	obj:getChild("n12").text = "[img]ui://9leh0eyft9fj5f[/img][color=#FF0000]你点击了链接[/color]："..context.data
end

function scene:_clickGetInput()
	local obj = _demoObjects["Text"]
	obj:getChild("n24").text = obj:getChild("n22").text
end

-------------------------------
local _winA
local _winB

function scene:playWindow()
	local obj = _demoObjects["Window"]
	obj:getChild("n0"):onClick(self._clickWindowA, self)
	obj:getChild("n1"):onClick(self._clickWindowB, self)
end

function scene:_clickWindowA()
	if _winA == nil then
		_winA = WindowA.new()
	end
	_winA:show()
end

function scene:_clickWindowB()
	if _winB == nil then
		_winB = WindowB.new()
	end
	_winB:show()
end

-------------------------------
local _pm
local _popupCom

function scene:playPopup()
	if _pm == nil then
		_pm = PopupMenu.new()
		_pm:addItem("Item 1")
		_pm:addItem("Item 2")
		_pm:addItem("Item 3")
		_pm:addItem("Item 4")

		if _popupCom == nil then
			_popupCom = UIPackage.createObject("Basics", "Component12")
			_popupCom:center()
		end
	end

	local obj = _demoObjects["Popup"]
	local btn = obj:getChild("n0")
	btn:onClick(self._clickPopup1, self)

	local btn2 = obj:getChild("n1")
	btn2:onClick(self._clickPopup2, self)
end

function scene:_clickPopup1(context)
	_pm:show(context.sender, true)
end

function scene:_clickPopup2()
	_groot:showPopup(_popupCom)
end

-------------------------------
function scene:playDragDrop()
	local obj = _demoObjects["Drag&Drop"]
	local btnA = obj:getChild("a")
	btnA.draggable = true

	local btnB = obj:getChild("b")
	btnB.draggable = true
	btnB:on("dragStart", self._onDragStart, self)

	local btnC = obj:getChild("c")
	btnC.icon = nil
	btnC:on("drop", self._onDrop, self)

	local btnD = obj:getChild("d")
	btnD.draggable = true
	local bounds = obj:getChild("bounds")
	local rect = bounds:localToGlobalRect(0, 0, bounds.width, bounds.height)

	--因为这时候面板还在从右往左动，所以rect不准确，需要用相对位置算出最终停下来的范围
	rect.x = rect.x - obj.parent.x

	btnD.dragBounds = rect
end

function scene:_onDragStart(context)
	local btn = context.sender
	context:preventDefault() --取消对原目标的拖动，换成一个替代品

	DragDropManager.startDrag(btn, btn.icon, btn.icon, context.inputEvent.touchId)
end

function scene:_onDrop(context)
	context.sender.icon = context.data
end

-------------------------------
local _startPos = {x=0,y=0}

function scene:playDepth()
	local obj = _demoObjects["Depth"]
	local testContainer = obj:getChild("n22")
	local fixedObj = testContainer:getChild("n0")
	fixedObj.sortingOrder = 100
	fixedObj.draggable = true

	local numChildren = testContainer.numChildren
	local i = 0
	while i < numChildren do
		local child = testContainer:getChildAt(i)
		if child ~= fixedObj then
			testContainer:removeChildAt(i)
			numChildren = numChildren - 1
		else
			i = i + 1
		end
	end
	_startPos.x = fixedObj.x
	_startPos.y = fixedObj.y

	obj:getChild("btn0"):onClick(self._click1, self)
	obj:getChild("btn1"):onClick(self._click2, self)
end

function scene:_click1()
	local graph = GGraph.new()
	_startPos.x = _startPos.x + 10
	_startPos.y = _startPos.y + 10
	graph:setPosition(_startPos.x, _startPos.y)
	graph:setSize(150, 150)
	graph:drawRect(1, 0x000000, 1, 0xFF0000, 1)

	local obj = _demoObjects["Depth"]
	obj:getChild("n22"):addChild(graph)
end

function scene:_click2()
	local graph = GGraph.new()
	_startPos.x = _startPos.x + 10
	_startPos.y = _startPos.y + 10
	graph:setPosition(_startPos.x, _startPos.y)
	graph:setSize(150, 150)
	graph:drawRect(1, 0x000000, 1, 0x00FF00, 1)
	graph.sortingOrder = 200

	local obj = _demoObjects["Depth"]
	obj:getChild("n22"):addChild(graph)
end

-------------------------------
function scene:playGrid()
	local obj = _demoObjects["Grid"]
	local list1 = obj:getChild("list1")
	list1:removeChildrenToPool()
	local testNames = {"苹果手机操作系统", "安卓手机操作系统", "微软手机操作系统", "微软桌面操作系统", "苹果桌面操作系统", "未知操作系统"}
	local testColors = { 0xFFFF00, 0xFF0000, 0xFFFFFF, 0x0000FF }
	local cnt = #testNames
	for i=1,cnt do
		local item = list1:addItemFromPool()
		item:getChild("t0").text = ""..i
		item:getChild("t1").text = testNames[i]
		item:getChild("t2").color = testColors[math.random(4)]
		item:getChild("star").value = math.random(3) / 3 * 100
	end

	local list2 = obj:getChild("list2")
	list2:removeChildrenToPool()
	for i=1,cnt do
		local item = list2:addItemFromPool()
		item:getChild("cb").selected = false
		item:getChild("t1").text = testNames[i]
		item:getChild("mc").playing = (i % 2) == 0
		item:getChild("t3").text = ""..math.random(10000)
	end
end

----------------------------------------------
function scene:playProgressBar()
	local obj = _demoObjects["ProgressBar"]
	_view:frameLoop(self._playProgress, self)
end

function scene:_playProgress()
	local obj = _demoObjects["ProgressBar"]
	local cnt = obj.numChildren
	for i=0,cnt-1 do
		local child = typeof(obj:getChildAt(i), GProgressBar)
		if child then
			child.value = child.value + 1
			if child.value > child.max then
				child.value = 0
			end
		end
	end
end

function scene:destroy( event )
	for k,v in pairs(_demoObjects) do
		v:dispose()
	end
	_groot:dispose()

	UIConfig.verticalScrollBar = "";
	UIConfig.horizontalScrollBar = "";
	UIConfig.popupMenu = "";
	UIConfig.buttonSound = "";
	UIPackage.removePackage('Basics')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene