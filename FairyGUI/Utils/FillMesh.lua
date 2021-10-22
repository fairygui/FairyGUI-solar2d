local _vertBuf_x = {}
local _vertBuf_y = {}
local _vertBufLen = 0

local function addVert(x, y)
	_vertBufLen = _vertBufLen+1
	_vertBuf_x[_vertBufLen] = x
	_vertBuf_y[_vertBufLen] = y
end

local function addQuad(x, y, w, h)
	addVert(x,y+h)
	addVert(x,y)
	addVert(x+w,y)
	addVert(x+w,y+h)
end

local function fillToPath(path, w, h)
	for i=1,_vertBufLen do
		local x = _vertBuf_x[i]
		local y = _vertBuf_y[i]
		path:setVertex(i, x, y)
		path:setUV(i, x/w, y/h)
	end
end

local function fillHorizontal(x, y, w, h, origin, amount)
	if origin == FillOrigin.Right or origin == FillOrigin.Bottom then
		x = w * (1-amount)
	end

	addQuad(x, y, w*amount, h)
end

local function fillVertical(x, y, w, h, origin, amount)
	if origin == FillOrigin.Right or origin == FillOrigin.Bottom then
		y = h * (1-amount)
	end
	
	addQuad(x, y, w, h*amount)
end

--4 vertex
local function fillRadial90(vx, vy, vw, vh, origin, amount, clockwise)
	local flipX = origin == FillOrigin.TopRight or origin == FillOrigin.BottomRight
	local flipY = origin == FillOrigin.BottomLeft or origin == FillOrigin.BottomRight
	if flipX ~= flipY then
		clockwise = not clockwise
	end

	local ratio = clockwise and amount or (1 - amount)
	local tan = math.tan(math.pi * 0.5 * ratio)
	local thresold =  false
	if ratio~=1 then
		thresold = (vh / vw - tan) > 0
	end
	if not clockwise then
		thresold = not thresold
	end

	local x = vx + (ratio == 0 and 1000000000 or (vh / tan))
	local y = vy + (ratio == 1 and 1000000000 or (vw * tan))
	local x2 = x
	local y2 = y
	if flipX then
		x2 = vw - x
	end
	if flipY then
		y2 = vh - y
	end
	local xMin = flipX and (vw - vx) or vx
	local yMin = flipY and (vh - vy) or vy
	local xMax = flipX and -vx or (vx+vw)
	local yMax = flipY and -vy or (vy+vh)

	addVert(xMin, yMin)

	if clockwise then
		addVert(xMax, yMin)
	end

	if y > vy+vh then
		if thresold then
			addVert(x2, yMax)
		else
			addVert(xMax, yMax)
		end
	else
		addVert(xMax, y2)
	end

	if x > vx+vw then
		if thresold then
			addVert(xMax, y2)
		else
			addVert(xMax, yMax)
		end
	else
		addVert(x2, yMax)
	end

	if not clockwise then
		addVert(xMin, yMax)
	end
end

--8 vertex
local function fillRadial180(vx, vy, vw, vh, origin, amount, clockwise)
	if origin==FillOrigin.Top then
		if amount <= 0.5 then
			vw = vw / 2
			if clockwise then
				vx = vx + vw
			end

			fillRadial90(vx, vy, vw, vh, clockwise and FillOrigin.TopLeft or FillOrigin.TopRight, amount / 0.5, clockwise)
			addQuad(_vertBuf_x[_vertBufLen-3], _vertBuf_y[_vertBufLen-3], 0, 0)
		else
			vw = vw / 2
			if not clockwise then
				vx = vx + vw
			end

			fillRadial90(vx, vy, vw, vh, clockwise and FillOrigin.TopRight or FillOrigin.TopLeft, (amount - 0.5) / 0.5, clockwise)

			if clockwise then
				vx = vx + vw
			else
				vx = vx - vw
			end

			addQuad(vx, vy, vw, vh)
		end
	elseif origin==FillOrigin.Bottom then
		if amount <= 0.5 then
			vw = vw / 2
			if not clockwise then
				vx = vx + vw
			end

			fillRadial90(vx, vy, vw, vh, clockwise and FillOrigin.BottomRight or FillOrigin.BottomLeft, amount / 0.5, clockwise)
			addQuad(_vertBuf_x[_vertBufLen-3], _vertBuf_y[_vertBufLen-3], 0, 0)
		else
			vw = vw / 2
			if clockwise then
				vx = vx + vw
			end

			fillRadial90(vx, vy, vw, vh, clockwise and FillOrigin.BottomLeft or FillOrigin.BottomRight, (amount - 0.5) / 0.5, clockwise)

			if clockwise then
				vx = vx - vw
			else
				vx = vx + vw
			end

			addQuad(vx, vy, vw, vh)
		end
	elseif origin==FillOrigin.Left then
		if amount <= 0.5 then
			vh = vh / 2
			if not clockwise then
				vy = vy + vh
			end

			fillRadial90(vx, vy, vw, vh, clockwise and FillOrigin.BottomLeft or FillOrigin.TopLeft, amount / 0.5, clockwise)
			addQuad(_vertBuf_x[_vertBufLen-3], _vertBuf_y[_vertBufLen-3], 0, 0)
		else
			vh = vh / 2
			if clockwise then
				vy = vy + vh
			end

			fillRadial90(vx, vy, vw, vh, clockwise and FillOrigin.TopLeft or FillOrigin.BottomLeft, (amount - 0.5) / 0.5, clockwise)

			if clockwise then
				vy = vy - vh
			else
				vy = vy + vh
			end
			addQuad(vx, vy, vw, vh)
		end
	elseif origin==FillOrigin.Right then
		if amount <= 0.5 then
			vh = vh / 2
			if clockwise then
				vy = vy + vh
			end

			fillRadial90(vx, vy, vw, vh, clockwise and FillOrigin.TopRight or FillOrigin.BottomRight, amount / 0.5, clockwise)
			addQuad(_vertBuf_x[_vertBufLen-3], _vertBuf_y[_vertBufLen-3], 0, 0)
		else
			vh = vh / 2
			if not clockwise then
				vy = vy + vh
			end

			fillRadial90(vx, vy, vw, vh, clockwise and FillOrigin.BottomRight or FillOrigin.TopRight, (amount - 0.5) / 0.5, clockwise)

			if clockwise then
				vy = vy + vh
			else
				vy = vy - vh
			end

			addQuad(vx, vy, vw, vh)
		end
	end
end

--12 vertex
local function fillRadial360(vx, vy, vw, vh, origin, amount, clockwise)
	if origin==FillOrigin.Top then
		if amount < 0.5 then
			vw = vw / 2
			if clockwise then
				vx = vx + vw
			end

			fillRadial180(vx, vy, vw, vh, clockwise and FillOrigin.Left or FillOrigin.Right, amount / 0.5, clockwise)
			
			addQuad(_vertBuf_x[_vertBufLen-7], _vertBuf_y[_vertBufLen-7], 0, 0)
		else
			vw = vw / 2
			if not clockwise then
				vx = vx + vw
			end

			fillRadial180(vx, vy, vw, vh, clockwise and FillOrigin.Right or FillOrigin.Left, (amount - 0.5) / 0.5, clockwise)

			if clockwise then
				vx = vx + vw
			else
				vx = vx - vw
			end
			addQuad(vx, vy, vw, vh)
		end
	elseif origin==FillOrigin.Bottom then
		if amount < 0.5 then
			vw = vw / 2
			if not clockwise then
				vx = vx + vw
			end

			fillRadial180(vx, vy, vw, vh, clockwise and FillOrigin.Right or FillOrigin.Left, amount / 0.5, clockwise)
			
			addQuad(_vertBuf_x[_vertBufLen-7], _vertBuf_y[_vertBufLen-7], 0, 0)
		else
			vw = vw / 2
			if clockwise then
				vx = vx + vw
			end

			fillRadial180(vx, vy, vw, vh, clockwise and FillOrigin.Left or FillOrigin.Right, (amount - 0.5) / 0.5, clockwise)

			if clockwise then
				vx = vx - vw
			else
				vx = vx + vw
			end
			addQuad(vx, vy, vw, vh)
		end
	elseif origin==FillOrigin.Left then
		if amount < 0.5 then
			vh = vh / 2
			if not clockwise then
				vy = vy + vh
			end

			fillRadial180(vx, vy, vw, vh, clockwise and FillOrigin.Bottom or FillOrigin.Top, amount / 0.5, clockwise)
			
			addQuad(_vertBuf_x[_vertBufLen-7], _vertBuf_y[_vertBufLen-7], 0, 0)
		else
			vh = vh / 2
			if clockwise then
				vy = vy + vh
			end

			fillRadial180(vx, vy, vw, vh, clockwise and FillOrigin.Top or FillOrigin.Bottom, (amount - 0.5) / 0.5, clockwise)

			if clockwise then
				vy = vy - vh
			else
				vy = vy + vh
			end

			addQuad(vx, vy, vw, vh)
		end
	elseif origin==FillOrigin.Right then
		if amount < 0.5 then
			vh = vh / 2
			if clockwise then
				vy = vy + vh
			end

			fillRadial180(vx, vy, vw, vh, clockwise and FillOrigin.Top or FillOrigin.Bottom, amount / 0.5, clockwise)
			
			addQuad(_vertBuf_x[_vertBufLen-7], _vertBuf_y[_vertBufLen-7], 0, 0)
		else
			vh = vh / 2
			if not clockwise then
				vy = vy + vh
			end

			fillRadial180(vx, vy, vw, vh, clockwise and FillOrigin.Bottom or FillOrigin.Top, (amount - 0.5) / 0.5, clockwise)

			if clockwise then
				vy = vy + vh
			else
				vy = vy - vh
			end

			addQuad(vx, vy, vw, vh)
		end
	end
end

local function gen(path, w, h, method, origin, amount, clockwise)
	_vertBufLen = 0
	amount = math.clamp(amount, 0, 1)

	if method==FillMethod.Horizontal then
		fillHorizontal(0, 0, w, h, origin, amount, clockwise)
	elseif method==FillMethod.Vertical then
		fillVertical(0, 0, w, h, origin, amount, clockwise)
	elseif method==FillMethod.Radial90 then
		fillRadial90(0, 0, w, h, origin, amount, clockwise)
	elseif method==FillMethod.Radial180 then
		fillRadial180(0, 0, w, h, origin, amount, clockwise)
	elseif method==FillMethod.Radial360 then
		fillRadial360(0, 0, w, h, origin, amount, clockwise)
	end

	fillToPath(path, w, h)
end

return gen