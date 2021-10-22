local GearBase = require("Gears.GearBase")

local GearLook = class('GearLook', GearBase)

function GearLook:ctor(owner)
	GearLook.super.ctor(self, owner)
end

function GearLook:init()
	self._default = { alpha=self._owner.alpha, rotation=self._owner.rotation, grayed=self._owner.grayed, touchable=self._owner.touchable}
	self._storage = {}
end

function GearLook:addStatus(pageId, buffer)
	local gv
	if pageId == nil then
		gv = self._default
	else
		gv = {}
		self._storage[pageId] = gv
	end

	gv.alpha = buffer:readFloat()
	gv.rotation = buffer:readFloat()
	gv.grayed = buffer:readBool()
	gv.touchable = buffer:readBool()
end

function GearLook:apply()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then gv = self._default end

	if self.tween and UIPackage._constructing == 0 and not GearBase.disableAllTweenEffect then
		self._owner._gearLocked = true
		self._owner.grayed = gv.grayed
		self._owner.touchable = gv.touchable
		self._owner._gearLocked = false

		if self._tweener then
			if self._tweener.endValue.x ~= gv.alpha or self._tweener.endValue.y ~= gv.rotation then
				self._tweener:kill(true)
				self._tweener = nil
			else
				return
			end
		end

		local a = gv.alpha ~= self._owner.alpha
		local b = gv.rotation ~= self._owner.rotation
		if a or b then
			if self._owner:checkGearController(0, self.controller) then
				self._displayLockToken = self._owner:addDisplayLock()
			end

			self._tweener = GTween.to(self._owner.alpha,self._owner.rotation, gv.alpha, gv.rotation, self.duration)
				:setDelay(self.delay)
				:setEase(self.easeType)
				:setUserData((a and 1 or 0) + (b and 2 or 0))
				:setTarget(self)
				:onUpdate(self.onTweenUpdate, self)
				:onComplete(self.onTweenComplete, self)
		end
	else
		self._owner._gearLocked = true
		self._owner.alpha = gv.alpha
		self._owner.rotation = gv.rotation
		self._owner.grayed = gv.grayed
		self._owner.touchable = gv.touchable
		self._owner._gearLocked = false
	end
end

function GearLook:onTweenUpdate(tweener)
	self._owner._gearLocked = true;
	local flag = tweener.userData;

	if flag==1 or flag==3 then
		self._owner.alpha = tweener.value.x
	end
	if flag==2 or flag==3 then
		self._owner.rotation = tweener.value.y
	end
	self._owner._gearLocked = false;
end

function GearLook:onTweenComplete(tweener)
	self._tweener = nil
	if self._displayLockToken~=0 then
		self._owner:releaseDisplayLock(self._displayLockToken);
		self._displayLockToken = 0;
	end
	self._owner:emit("gearStopped");
end

function GearLook:updateState()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then
		gv = {}
		self._storage[self.controller.selectedPageId] = gv
	end

	gv.alpha = self._owner.alpha
	gv.rotation = elf._owner.rotation
	gv.grayed = elf._owner.grayed
	gv.touchable = elf._owner.touchable
end

return GearLook