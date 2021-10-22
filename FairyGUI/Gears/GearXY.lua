local GearBase = require("Gears.GearBase")

local GearXY = class('GearXY', GearBase)

function GearXY:ctor(owner)
	GearXY.super.ctor(self, owner)
end

function GearXY:init()
	self._default = { x=self._owner.x, y=self._owner.y }
	self._storage = {}
end

function GearXY:addStatus(pageId, buffer)
	local gv;
	if pageId == nil then
		gv = self._default
	else
		gv = {}
		self._storage[pageId] = gv;
	end

	gv.x = buffer:readInt();
	gv.y = buffer:readInt();
end

function GearXY:apply()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then gv = self._default end

	if self.tween and UIPackage._constructing == 0 and not GearBase.disableAllTweenEffect then
		if self._tweener then
			if self._tweener.endValue.x ~= gv.x or self._tweener.endValue.y ~= gv.y then
				self._tweener:kill(true)
				self._tweener = nil
			else
				return
			end
		end

		if gv.x ~= self._owner.x or gv.y ~= self._owner.y then
			if self._owner:checkGearController(0, self.controller) then
				self._displayLockToken = self._owner:addDisplayLock()
			end

			self._tweener = GTween.to(self._owner.x,self._owner.y, gv.x, gv.y, self.duration)
				:setDelay(self.delay)
				:setEase(self.easeType)
				:setTarget(self)
				:onUpdate(self.onTweenUpdate, self)
				:onComplete(self.onTweenComplete, self)
		end
	else
		self._owner._gearLocked = true;
		self._owner:setPosition(gv.x, gv.y)
		self._owner._gearLocked = false;
	end
end

function GearXY:onTweenUpdate(tweener)
	self._owner._gearLocked = true;
	self._owner:setPosition(tweener.value.x, tweener.value.y);
	self._owner._gearLocked = false;
end

function GearXY:onTweenComplete(tweener)
	self._tweener = nil
	if self._displayLockToken~=0 then
		self._owner:releaseDisplayLock(self._displayLockToken);
		self._displayLockToken = 0;
	end
	self._owner:emit("gearStopped");
end

function GearXY:updateState()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then
		gv = {}
		self._storage[self.controller.selectedPageId] = gv
	end
	gv.x = self._owner.x;
	gv.y = self._owner.y;
end

function GearXY:updateFromRelations(dx, dy)
	if self.controller~=nil and self._storage~=nil then
		for _,gv in pairs(_storage) do
			gv.x = gv.x + dx;
			gv.y = gv.y + dy;
		end
		self._default.x = self._default.x + dx;
		self._default.y = self._default.y + dy;

		self:updateState();
	end
end

return GearXY