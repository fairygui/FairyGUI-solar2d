local GearBase = require("Gears.GearBase")

local GearAnimation = class('GearAnimation', GearBase)

function GearAnimation:ctor(owner)
	GearAnimation.super.ctor(self, owner)
end

function GearAnimation:init()
	self._default = { playing=self._owner.playing, frame=self._owner.frame }
	self._storage = {}
end

function GearAnimation:addStatus(pageId, buffer)
	local gv
	if pageId == nil then
		gv = self._default
	else
		gv = {playing=false, frame=0}
		self._storage[pageId] = gv
	end

	gv.playing = buffer:readBool()
	gv.frame = buffer:readInt()
end

function GearAnimation:apply()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then gv = self._default end

	self._owner._gearLocked = true
	self._owner.frame = gv.frame
	self._owner.playing = gv.playing
	self._owner._gearLocked = false
end

function GearAnimation:updateState()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then
		gv = {}
		self._storage[self.controller.selectedPageId] = gv
	end
	gv.playing = self._owner.playing
	gv.frame = self._owner.frame
end

return GearAnimation