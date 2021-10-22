local ControllerAction = class('ControllerAction')
local tools = require('Utils.ToolSet')

function ControllerAction:run(controller, prevPage, curPage)
	if (self.fromPage == nil or #self.fromPage == 0 or tools.indexOf(self.fromPage, prevPage) ~= 0) 
		and (self.toPage == nil or #self.toPage == 0 or tools.indexOf(self.toPage, curPage) ~= 0) then
		self:enter(controller)
	else
		self:leave(controller)
	end
end

function ControllerAction:enter(controller)
end

function ControllerAction:leave(controller)
end


function ControllerAction:setup(buffer)
	local cnt

	cnt = buffer:readShort()
	self.fromPage = {}

	for i=1,cnt do
		table.insert(self.fromPage, buffer:readS())
	end

	cnt = buffer:readShort()
	self.toPage = {}

	for i=1,cnt do
		table.insert(self.toPage, buffer:readS())
	end
end

return ControllerAction