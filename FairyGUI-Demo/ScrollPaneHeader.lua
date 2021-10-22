local ScrollPaneHeader = class('ScrollPaneHeader', GComponent)

function ScrollPaneHeader:onConstruct()
	self._c1 = self:getController("c1")
	self:on("sizeChanged", self.onSizeChanged, self)
end

function ScrollPaneHeader:onSizeChanged()
	if self._c1.selectedIndex == 2 or self._c1.selectedIndex == 3 then
		return
	end

	if self.height > self.sourceHeight then
		self._c1.selectedIndex = 1
	else
		self._c1.selectedIndex = 0
	end
end

function ScrollPaneHeader.getters:readyToRefresh()
	return self._c1.selectedIndex == 1
end

function ScrollPaneHeader:setRefreshStatus(value)
	self._c1.selectedIndex = value
end

return ScrollPaneHeader
