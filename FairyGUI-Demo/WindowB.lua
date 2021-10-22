local WindowB = class('WindowB', Window)

function WindowB:onInit()
	self.contentPane = UIPackage.createObject("Basics", "WindowB")
	self:center()

	self:setPivot(0.5, 0.5)
end

function WindowB:doShowAnimation()
	self:setScale(0.1, 0.1)
	GTween.to(0.1, 0.1, 1, 1, 0.3)
		:setTarget(self, self.setScale)
		:setEase(EaseType.QuadOut)
		:onComplete(self.onShown, self)
end

function WindowB:doHideAnimation()
	GTween.to(1, 1, 0.1, 0.1, 0.3)
		:setTarget(self, self.setScale)
		:setEase(EaseType.QuadOut)
		:onComplete(self.hideImmediately, self)
end

function WindowB:onShown()
	self.contentPane:getTransition("t1"):play()
end

function WindowB:onHide()
	self.contentPane:getTransition("t1"):stop()
end

return WindowB