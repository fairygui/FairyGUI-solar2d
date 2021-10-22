local GearBase = require("Gears.GearBase")

local GearColor = class('GearColor', GearBase)

function GearColor:ctor(owner)
	GearColor.super.ctor(self, owner)
end

function GearColor:init()
	self._default = { color=self._owner.color, strokeColor=self._owner.strokeColor }
	self._storage = {}
end

function GearColor:addStatus(pageId, buffer)
	local gv
	if pageId == nil then
		gv = self._default
	else
		gv = {}
		self._storage[pageId] = gv
	end

	gv.color = buffer:readColor()
	local a
	gv.strokeColor,a = buffer:readColor()
	if a==0 then gv.strokeColor = nil end
end

function GearColor:apply()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then gv = self._default end

	if self._owner.strokeColor and gv.strokeColor then
		self._owner._gearLocked = true
		self._owner.strokeColor = gv.strokeColor
		self._owner._gearLocked = false
	end

	if self.tween and UIPackage._constructing == 0 and not GearBase.disableAllTweenEffect then
		if self._owner.strokeColor and gv.strokeColor then
			self._owner._gearLocked = true
			self._owner.strokeColor = gv.strokeColor
			self._owner._gearLocked = false
		end

		if self._tweener then
			if self._tweener.endValue.x ~= gv.width or self._tweener.endValue.y ~= gv.height
				or self._tweener.endValue.z ~= gv.scaleX or self._tweener.endValue.w ~= gv.scaleY then
				self._tweener:kill(true)
				self._tweener = nil
			else
				return
			end
		end

		if self._owner.color~=gv.color then
			if self._owner:checkGearController(0, self.controller) then
				self._displayLockToken = self._owner:addDisplayLock()
			end

			self._tweener = GTween.toColor(self._owner.color, gv.color, self.duration)
				:setDelay(self.delay)
				:setEase(self.easeType)
				:setTarget(self)
				:onUpdate(self.onTweenUpdate, self)
				:onComplete(self.onTweenComplete, self)
		end
	else
		self._owner._gearLocked = true
		self._owner.color = gv.color
		self._owner._gearLocked = false
	end
end

function GearColor:onTweenUpdate(tweener)
	self._owner._gearLocked = true
	self._owner.color = tweener.value:getColor()
	self._owner._gearLocked = false
end

function GearColor:onTweenComplete(tweener)
	self._tweener = nil
	if self._displayLockToken~=0 then
		self._owner:releaseDisplayLock(self._displayLockToken);
		self._displayLockToken = 0
	end
	self._owner:emit("gearStopped")
end

function GearColor:updateState()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then
		gv = {}
		self._storage[self.controller.selectedPageId] = gv
	end
	gv.color = self._owner.color;
	if self._owner.strokeColor then
		gv.strokeColor = self._owner.strokeColor
	end
end

return GearColor