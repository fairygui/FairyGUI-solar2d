local MailItem = class('MailItem', GButton)

function MailItem:onConstruct()
	self._timeText = self:getChild("timeText")
	self._readController = self:getController("IsRead")
	self._fetchController = self:getController("c1")
	self._trans = self:getTransition("t0")
end

function MailItem:setTime(value)
	self._timeText.text = value
end

function MailItem:setRead(value)
	self._readController.selectedIndex = value and 1 or 0
end

function MailItem:setFetched(value)
	self._fetchController.selectedIndex = value and 1 or 0
end

function MailItem:playEffect(delay)
	self.visible = false
	self._trans:play(1, delay)
end

return MailItem

