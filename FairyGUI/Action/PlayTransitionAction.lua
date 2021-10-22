local ControllerAction = require('Action.ControllerAction')

local PlayTransitionAction = class('PlayTransitionAction', ControllerAction)

function PlayTransitionAction:enter(controller)
	local trans = controller.parent:getTransition(self.transitionName)
	if trans ~= nil then
		if self._currentTransition ~= nil and self._currentTransition.playing then
			trans:changePlayTimes(self.playTimes)
		else
			trans:play(self.playTimes, self.delay)
		end
		self._currentTransition = trans
	end
end

function PlayTransitionAction:leave(controller)
	if self.stopOnExit and self._currentTransition ~= nil then
		self._currentTransition:stop()
		self._currentTransition = nil
	end
end

function PlayTransitionAction:setup(buffer)
	PlayTransitionAction.super.setup(self, buffer)

	self.transitionName = buffer:readS()
	self.playTimes = buffer:readInt()
	self.delay = buffer:readFloat()
	self.stopOnExit = buffer:readBool()
end

return PlayTransitionAction