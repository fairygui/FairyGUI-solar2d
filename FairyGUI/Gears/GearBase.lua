local GearBase = class('GearBase')
GearBase.disableAllTweenEffect = false

function GearBase:ctor(owner)
	self._owner = owner
end

function GearBase:dispose()
	if self._tweener then
		self._tweener:kill();
		self._tweener = nil
	end
end

function GearBase:setController(value)
	if value ~= self.controller then
		self.controller = value;
		if self.controller then
			self:init();
		end
	end	
end

function GearBase:setup(buffer)
	self.controller = self._owner.parent:getControllerAt(buffer:readShort())
	self:init()

	if self.isConnected~=nil then --GearDisplay
		local cnt = buffer:readShort()
		local pages = {}
		for i=1,cnt do
			pages[i] = buffer:readS()
		end
		self.pages = pages
	else
		local cnt = buffer:readShort()
		for i=1,cnt do
			local page = buffer:readS()
			if page ~= nil then
				self:addStatus(page, buffer)
			end
		end

		if buffer:readBool() then
			self:addStatus(nil, buffer)
		end
	end

	if buffer:readBool() then
		self.tween = true
		self.easeType = buffer:readByte()
		self.duration = buffer:readFloat()
		self.delay = buffer:readFloat()
	end
end

function GearBase:updateFromRelations(dx, dy)
end

function GearBase:addStatus(pageId, buffer)
end

function GearBase:init()
end

function GearBase:apply()
end

function GearBase:updateState()
end

return GearBase