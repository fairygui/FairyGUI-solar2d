local ControllerAction = require('Action.ControllerAction')
local ChangePageAction = class('ChangePageAction', ControllerAction)

function ChangePageAction:enter(controller)
	if not self.controllerName or #self.controllerName==0 then
		return
	end

	local gcom
	if self.objectId and #self.objectId then
		gcom = controller.parent:getChildById(self.objectId)
	else
		gcom = controller.parent
	end
	if gcom ~= nil then
		local cc = gcom:getController(self.controllerName)
		if cc ~= nil and cc ~= controller and not cc._changing then
			cc.selectedPageId = self.targetPage
		end
	end
end

function ChangePageAction:setup(buffer)
	ChangePageAction.super.setup(self, buffer)

	self.objectId = buffer:readS()
	self.controllerName = buffer:readS()
	self.targetPage = buffer:readS()
end

return ChangePageAction