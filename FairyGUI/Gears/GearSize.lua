local GearBase = require("Gears.GearBase")

local GearSize = class('GearSize', GearBase)

function GearSize:ctor(owner)
	GearSize.super.ctor(self, owner)
end

function GearSize:init()
	self._default = { width=self._owner.width, height=self._owner.height, scaleX=self._owner.scaleX, scaleY=self._owner.scaleY }
	self._storage = {}
end

function GearSize:addStatus(pageId, buffer)
	local gv;
	if pageId == nil then
		gv = self._default
	else
		gv = {}
		self._storage[pageId] = gv;
	end

	gv.width = buffer:readInt();
	gv.height = buffer:readInt();
	gv.scaleX = buffer:readFloat();
	gv.scaleY = buffer:readFloat();
end

function GearSize:apply()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then gv = self._default end

	if self.tween and UIPackage._constructing == 0 and not GearBase.disableAllTweenEffect then
		if self._tweener then
			if self._tweener.endValue.x ~= gv.width or self._tweener.endValue.y ~= gv.height
				or self._tweener.endValue.z ~= gv.scaleX or self._tweener.endValue.w ~= gv.scaleY then
				self._tweener:kill(true)
				self._tweener = nil
			else
				return
			end
		end

		local a = gv.width ~= self._owner.width or gv.height ~= self._owner.height
		local b = gv.scaleX ~= self._owner.scaleX or gv.scaleY ~= self._owner.scaleY
		if a or b then
			if self._owner:checkGearController(0, self.controller) then
				self._displayLockToken = self._owner:addDisplayLock()
			end

			self._tweener = GTween.to(self._owner.width,self._owner.height, self._owner.scaleX, self._owner.scaleY,
					gv.width, gv.height, gv.scaleX, gv.scaleY, self.duration)
				:setDelay(self.delay)
				:setEase(self.easeType)
				:setUserData((a and 1 or 0) + (b and 2 or 0))
				:setTarget(self)
				:onUpdate(self.onTweenUpdate, self)
				:onComplete(self.onTweenComplete, self)
		end
	else
		self._owner._gearLocked = true;
		self._owner:setSize(gv.width, gv.height, self._owner:checkGearController(1, self.controller));
		self._owner:setScale(gv.scaleX, gv.scaleY);
		self._owner._gearLocked = false;
	end
end

function GearSize:onTweenUpdate(tweener)
	self._owner._gearLocked = true;
	local flag = tweener.userData;
	if flag==1 or flag==3 then
		self._owner:setSize(tweener.value.x, tweener.value.y, self._owner:checkGearController(1, self.controller));
	end
	if flag==2 or flag==3 then
		self._owner:setScale(tweener.value.z, tweener.value.w);
	end
	self._owner._gearLocked = false;
end

function GearSize:onTweenComplete(tweener)
	self._tweener = nil
	if self._displayLockToken~=0 then
		self._owner:releaseDisplayLock(self._displayLockToken);
		self._displayLockToken = 0;
	end
	self._owner:emit("gearStopped");
end

function GearSize:updateState()
	local gv = self._storage[self.controller.selectedPageId]
	if not gv then
		gv = {}
		self._storage[self.controller.selectedPageId] = gv
	end
	gv.width = self._owner.width;
	gv.height = self._owner.height;
	gv.scaleX = self._owner.scaleX;
	gv.scaleY = self._owner.scaleY;
end

function GearSize:updateFromRelations(dx, dy)
	if self.controller~=nil and self._storage~=nil then
		for _,gv in pairs(_storage) do
			gv.width = gv.width + dx;
			gv.height = gv.height + dy;
		end
		self._default.width = self._default.width + dx;
		self._default.height = self._default.height + dy;

		self:updateState();
	end
end

return GearSize