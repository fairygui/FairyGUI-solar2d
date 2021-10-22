local WindowA = class('WindowA', Window)

function WindowA:onInit()
	self.contentPane = UIPackage.createObject("Basics", "WindowA")
	self:center()
end

function WindowA:onShown()
	local list = self.contentPane:getChild("n6")
	list:removeChildrenToPool()

	for i=1,6 do
		local item = list:addItemFromPool()
		item.title = ""..i
		item.icon = "ui://Basics/r4"
	end
end

return WindowA