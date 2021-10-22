local GearBase = require("Gears.GearBase")

local GearText = class('GearText', GearBase)

function GearText:ctor(owner)
	GearText.super.ctor(self, owner)
end

function GearText:init()
	self._default = self._owner.icon
	self._storage = {}
end

function GearText:addStatus(pageId, buffer)
	if pageId == nil then
		self._default = buffer:readS()
	else
		self._storage[pageId] = buffer:readS()
	end
end

function GearText:apply()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then gv = self._default end

	self._owner._gearLocked = true
	self._owner.icon = gv
	self._owner._gearLocked = false
end

function GearText:updateState()
	self._storage[self.controller.selectedPageId] = self._owner.icon
end

return GearText