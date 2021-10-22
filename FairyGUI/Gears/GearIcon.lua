local GearBase = require("Gears.GearBase")

local GearIcon = class('GearIcon', GearBase)

function GearIcon:ctor(owner)
	GearIcon.super.ctor(self, owner)
end

function GearIcon:init()
	self._default = self._owner.icon
	self._storage = {}
end

function GearIcon:addStatus(pageId, buffer)
	if pageId == nil then
		self._default = buffer:readS()
	else
		self._storage[pageId] = buffer:readS()
	end
end

function GearIcon:apply()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then gv = self._default end

	self._owner._gearLocked = true
	self._owner.icon = gv
	self._owner._gearLocked = false
end

function GearIcon:updateState()
	self._storage[self.controller.selectedPageId] = self._owner.icon
end

return GearIcon