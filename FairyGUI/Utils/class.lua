function class(classname, super, initGetSet)
	if type(super)=='boolean' then
		initGetSet = super
		super = nil
	end

	local cls = {}
	cls.__cname = classname
	cls.super = super
	if super then
		-- copy super method
		for key, value in pairs(super) do
			if type(value) == "function" then
				cls[key] = value
			end
		end
	else
		cls.ctor = function() end
	end

	local getters
	local setters
	if initGetSet==nil or initGetSet==true or (super and super.getters) then
		getters = {}
		setters = {}
		if super then
			if super.getters then
				for key, value in pairs(super.getters) do
					getters[key] = value
				end
			end
	 
			if super.setters then
				for key, value in pairs(super.setters) do
					setters[key] = value
				end
			end
		end

		cls.getters = getters
		cls.setters = setters
		cls.__index = function(self, key)
			local getter = getters[key]
			if getter then
				return getter(self)
			else
				return cls[key]
			end
		end
		cls.__newindex = function(self, key, value)
			local setter = setters[key]
			if setter then
				setter(self, value)
			elseif getters[key] then
				assert(false, key.."is readonly")
			else
				rawset(self, key, value )
			end
		end
	else
		cls.__index = cls
	end

	function cls.new(...)
		local instance = setmetatable({}, cls)
		instance.class = cls
		instance:ctor(...)
		return instance
	end 

	return cls
end

function typeof(obj, cls)
	assert(cls, 'class cant be nil')
	
	if not obj then return end
	local cls2 = obj.class
	while cls2~=nil do
		if cls2==cls then return obj end
		cls2 = cls2.super
	end
end
