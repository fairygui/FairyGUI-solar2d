local GearBase = require("Gears.GearBase")

local GearDisplay = class('GearDisplay', GearBase)

function GearDisplay:ctor(owner)
	GearDisplay.super.ctor(self, owner)

	self._displayLockToken = 1
	self._visible = 0
end

function GearDisplay:init()
	self.pages = nil
end

function GearDisplay:apply()
	self._displayLockToken = self._displayLockToken+1
	if self._displayLockToken == 0 then
		self._displayLockToken = 1;
	end

	if self.pages == nil or #self.pages == 0 then
		self._visible = 1;
	else
		local cnt = #self.pages
		for i=1,cnt do
			if self.pages[i]==self.controller.selectedPageId then
				self._visible = 1
				return
			end
		end

		self._visible = 0;
	end
end

function GearDisplay:addLock()
	self._visible = self._visible+1
	return self._displayLockToken;
end

function GearDisplay:releaseLock(token)
	if token == self._displayLockToken then
		self._visible = self._visible-1
	end
end

function GearDisplay:isConnected()
	return self.controller == nil or self._visible > 0
end

return GearDisplay