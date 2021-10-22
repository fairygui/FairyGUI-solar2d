local InputProcessor = require("Event.InputProcessor")
local DragDropManager = {}

local _groot
local _sourceData

local function onDragEnd(context)
	if DragDropManager.agent.parent == nil then
		return
	end

	_groot:removeChild(DragDropManager.agent)

	local sourceData = _sourceData
	_sourceData = nil

	local obj = _groot.touchTarget
	while obj ~= nil do
		if obj:hasListener("drop") then
			obj:emit("drop", sourceData)
			return
		end
		obj = obj.parent
	end
end

function DragDropManager.startDrag(source, icon, sourceData, touchId)
	if DragDropManager.agent.parent ~= nil then
		return
	end

	assert(source, "source must not be nil")
	assert(icon, "icon must not be nil")

	_groot = source.root	
	_sourceData = sourceData
	DragDropManager.agent.url = icon
	_groot:addChild(DragDropManager.agent)
	DragDropManager.agent:setPosition(_groot:globalToLocal(InputProcessor.getTouchPos(touchId)))
	DragDropManager.agent:startDrag(touchId)
end

function DragDropManager.cancel()
	if DragDropManager.agent.parent ~= nil then
		DragDropManager.agent:stopDrag()
		_groot:removeChild(DragDropManager.agent)
		_sourceData = nil
		_groot = nil
	end
end

local agent = UIObjectFactory.newObject2(ObjectType.Loader)
DragDropManager.agent = agent

agent.touchable = false
agent.draggable = true
agent:setSize(100, 100)
agent:setPivot(0.5, 0.5, true)
agent.align = AlignType.Center
agent.verticalAlign = VertAlignType.Middle
agent.sortingOrder = 2147483647
agent:on("dragEnd", onDragEnd)

return DragDropManager