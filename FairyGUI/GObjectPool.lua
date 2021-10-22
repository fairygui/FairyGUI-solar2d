local GObjectPool = class('GObjectPool')

function GObjectPool:ctor()
end

function GObjectPool:clear()
	if not self._pool then return end

	for _, v in pairs(self._pool) do
		for _, obj in ipairs(v) do
			obj:dispose()
		end
	end
	self._pool = nil
end

function GObjectPool:getObject(url)
	url = UIPackage.normalizeURL(url)
	if url == nil then
		return nil
	end

	local arr
	if self._pool then
		arr = self._pool[url]
		if arr and #arr > 0 then
			return table.remove(arr, #arr)
		end
	end

	local obj = UIPackage.createObjectFromURL(url)
	return obj
end

function GObjectPool:returnObject(obj)
	if not self._pool then self._pool = {} end

	local url = obj.resourceURL
	local arr = self._pool[url]
	if not arr then
		arr = {}
		self._pool[url] = arr
	end

	table.insert(arr, obj)
end

return GObjectPool