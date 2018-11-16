-- Afterglow UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local util = require("util")
local slider = require("game.afterglow.slider")

-- You definely need a "Frame" object to store all your GUIs
-- because Frame is responsible of rendering it.
-- Frane also responsible of handling the position

local frame = Luaoop.class("Afterglow.Frame")

--! Create new frame
--! @param x position
--! @param y position
--! @param w viewport width
--! @param h viewport height
function frame:__construct(x, y, w, h)
	local internal = Luaoop.class.data(self)

	self.width, self.height = assert(w), assert(h)
	self.x, self.y = assert(x), assert(y)
	self.offsetX, self.offsetY = 0, 0
	self.sliderH, self.sliderV = nil, nil

	internal.mouseBuffer = {
		pressed = false,
		x = 0,
		y = 0,
		scroll = false,
		sX = 0,
		sY = 0,
		scX = 0,
		scY = 0,
		targetElement = nil
	}
	internal.elementList = {}
	internal.fixedElementList = {}
end

--! Add new element to frame
--! @param element Element constructor function
--! @param x element x position
--! @param y element y position
--! @return Created element
function frame:addElement(element, x, y, ...)
	local internal = Luaoop.class.data(self)
	local elem
	if Luaoop.class.type(element) then
		elem = element
	else
		elem = element(...)
	end

	internal.elementList[#internal.elementList + 1] = {
		element = elem,
		x = assert(x),
		y = assert(y)
	}
	return elem
end

--! Add new fixed element
--!
--! Fixed element doesn't affected by scroll
--! @param element Element constructor function
--! @param x element x position
--! @param y element y position
--! @return Created element
function frame:addFixedElement(element, x, y, ...)
	local internal = Luaoop.class.data(self)
	local elem
	if Luaoop.class.type(element) then
		elem = element
	else
		elem = element(...)
	end

	internal.fixedElementList[#internal.fixedElementList + 1] = {
		element = elem,
		x = x,
		y = y,
		fixed = true
	}
	return elem
end

--! Set element position
--! @param element Existing element
--! @param x New X position
--! @param y New Y position
function frame:setElementPosition(element, x, y)
	local internal = Luaoop.class.data(self)

	for i = 1, #internal.fixedElementList do
		local info = internal.fixedElementList[i]
		if info.element == element then
			info.x, info.y = x, y
			return true
		end
	end

	for i = 1, #internal.elementList do
		local info = internal.elementList[i]
		if info.element == element then
			info.x, info.y = x, y
			return true
		end
	end

	return false
end

--! Remove element from frame
--! @param element Element object
function frame:removeElement(element)
	local internal = Luaoop.class.data(self)

	for i = 1, #internal.elementList do
		if internal.elementList[i].element == element then
			local target = internal.mouseBuffer.targetElement
			if target and target.element == element then
				element:triggerEvent("mousecancel")
				internal.mouseBuffer.pressed = false
				internal.mouseBuffer.targetElement = nil
			end

			return table.remove(internal.elementList, i)
		end
	end

	for i = 1, #internal.fixedElementList do
		if internal.fixedElementList[i].element == element then
			local target = internal.mouseBuffer.targetElement
			if target and target.element == element then
				element:triggerEvent("mousecancel")
				internal.mouseBuffer.pressed = false
				internal.mouseBuffer.targetElement = nil
			end

			return table.remove(internal.fixedElementList, i)
		end
	end
end

local function checkMousepressed(self, internal, info, a, b)
	local w, h = info.element:getDimensions()
	local c, d = a - self.x, b - self.y

	if not(info.fixed) then
		c, d = c + self.offsetX, d + self.offsetY
	end

	if c >= info.x and d >= info.y and c < info.x + w and d < info.y + h then
		-- enter
		info.element:triggerEvent("mousepressed",
			a - info.x + (info.fixed and 0 or self.offsetX) - self.x,
			b - info.y + (info.fixed and 0 or self.offsetY) - self.y
		)
		internal.mouseBuffer.pressed = true
		internal.mouseBuffer.targetElement = info
		internal.mouseBuffer.x, internal.mouseBuffer.y = a, b

		return true
	end

	return false
end

--! Handle frame events
--! @param name Event name
--! @param ... event params
function frame:handleEvents(name, a, b, c, d, e, f)
	local internal = Luaoop.class.data(self)

	if name == "mousepressed" and internal.mouseBuffer.pressed == false then
		if not(a >= self.x and b >= self.y and a < self.x + self.width and b < self.y + self.height) then
			return false
		end

		internal.mouseBuffer.x, internal.mouseBuffer.y = a - self.x, b - self.y
		internal.mouseBuffer.sX, internal.mouseBuffer.sY = a - self.x, b - self.y

		-- Fixed element first
		for i = #internal.fixedElementList, 1, -1 do
			if checkMousepressed(self, internal, internal.fixedElementList[i], a, b) then
				return true
			end
		end

		-- Then slider
		if self.sliderV and checkMousepressed(self, internal, self.sliderV, a, b) then
			return true
		end
		if self.sliderH and checkMousepressed(self, internal, self.sliderH, a, b) then
			return true
		end

		-- Then normal element list
		for i = #internal.elementList, 1, -1 do
			if checkMousepressed(self, internal, internal.elementList[i], a, b) then
				return true
			end
		end

		if self.sliderH or self.sliderV then
			internal.mouseBuffer.pressed = true
			return true
		end
	elseif name == "mousemoved" then
		local mbuf = internal.mouseBuffer
		mbuf.x, mbuf.y = a - self.x, b - self.y

		if mbuf.pressed then
			local info = mbuf.targetElement

			if self.sliderV or self.sliderH then
				if mbuf.scroll then
					mbuf.scX, mbuf.scY = c, d

					if self.sliderH then
						self.sliderH.element:setValue(self.sliderH.element:getValue() - c)
					end
					if self.sliderV then
						self.sliderV.element:setValue(self.sliderV.element:getValue() - d)
					end

					return true
				-- treshold is 40px
				elseif util.distance(mbuf.x, mbuf.y, mbuf.sX, mbuf.sY) >= 40 then
					if info then
						if not(info.fixed) then
							info.element:triggerEvent("mousecanceled")
							mbuf.targetElement = nil
							mbuf.scroll = true
							return true
						end
					else
						mbuf.scroll = true
						return true
					end
				end
			end

			if info then
				local w, h = info.element:getDimensions()

				if info.fixed then
					if
						a - self.x < (info == self.sliderV and -100 or 0) + info.x or
						b - self.y < (info == self.sliderH and -100 or 0) + info.y or
						a - self.x >= info.x + w or
						b - self.y >= info.y + h
					then
						info.element:triggerEvent("mousecanceled")
						internal.mouseBuffer.targetElement = nil
					else
						info.element:triggerEvent("mousemoved", a - info.x - self.x, b - info.y - self.y)
					end
				elseif
					a + self.offsetX - self.x < info.x or
					b + self.offsetY - self.y < info.y or
					a + self.offsetX - self.x >= info.x + w or
					b + self.offsetY - self.y >= info.y + h
				then
					info.element:triggerEvent("mousecanceled")
					internal.mouseBuffer.targetElement = nil
				else
					info.element:triggerEvent("mousemoved",
						a - info.x + self.offsetX - self.x,
						b - info.y + self.offsetY - self.y
					)
				end

				return true
			end
		end
	elseif name == "mousereleased" and internal.mouseBuffer.pressed then
		if internal.mouseBuffer.targetElement then
			internal.mouseBuffer.targetElement.element:triggerEvent("mousereleased")
			internal.mouseBuffer.targetElement = nil
		end

		internal.mouseBuffer.pressed = false
		internal.mouseBuffer.scroll = false

		return true
	elseif name == "textinput" then
		for i = #internal.elementList, 1, -1 do
			local info = internal.elementList[i]

			if info.element.captureText then
				info.element:triggerEvent("textinput", a)
				return true
			end
		end
	elseif name == "wheelmoved" then
		local handled = false
		if a ~= 0 and self.sliderH then
			self.sliderH.element:setValue(self.sliderH.element:getValue() - a * 10)
			handled = true
		end
		if b ~= 0 and self.sliderV then
			self.sliderV.element:setValue(self.sliderV.element:getValue() - b * 10)
			handled = true
		end

		if handled then
			return true
		end
	end

	return false
end

--! Removes all elements, effectively clear it
function frame:clear()
	local internal = Luaoop.class.data(self)

	for i = math.max(#internal.elementList, #internal.fixedElementList), 1, -1 do
		if internal.fixedElementList[i] then
			self:removeElement(internal.fixedElementList[i].element)
		end
		if internal.elementList[i] then
			self:removeElement(internal.elementList[i].element)
		end
	end
end

--! Resize frame size
function frame:resize(w, h)
	self.width, self.height = w, h
end

--! Update elements
function frame:update(dt)
	local internal = Luaoop.class.data(self)
	local maxX, maxY = 0, 0
	for _, v in ipairs(internal.fixedElementList) do
		v.element:update(dt)
	end
	for _, v in ipairs(internal.elementList) do
		v.element:update(dt)
		local w, h = v.element:getDimensions()

		maxX = math.max(v.x + w, maxX)
		maxY = math.max(v.y + h, maxY)
	end

	local sliderOffCompX = self.sliderV and 30 or 0
	local sliderOffCompY = self.sliderH and 30 or 0
	-- if it's beyond the viewport size
	if maxX > self.width - sliderOffCompX then
		if not(self.sliderH) then
			self.sliderH = {
				element = slider("horizontal", self.width - 30, maxX - self.width + sliderOffCompX),
				x = 0,
				y = self.height - 30,
				fixed = true
			}
		else
			self.sliderH.element:setMaxValue(maxX - self.width)
		end

		self.offsetX = self.sliderH.element:getValue()
	elseif self.sliderH then
		self.sliderH = nil
		self.offsetX = 0
	end

	if maxY > self.height - sliderOffCompY then
		if not(self.sliderV) then
			self.sliderV = {
				element = slider("vertical", self.height - 30, maxY - self.height + sliderOffCompY),
				x = self.width - 30,
				y = 0,
				fixed = true
			}
		else
			self.sliderV.element:setMaxValue(maxY - self.height)
		end

		self.offsetY = self.sliderV.element:getValue()
	elseif self.sliderV then
		self.sliderV = nil
		self.offsetY = 0
	end

	local mbuf = internal.mouseBuffer
	mbuf.scX = math.max(math.abs(mbuf.scX) - dt * 20, 0) * util.sign(mbuf.scX)
	mbuf.scY = math.max(math.abs(mbuf.scY) - dt * 20, 0) * util.sign(mbuf.scY)

	if self.sliderH then
		self.sliderH.element:setValue(self.sliderH.element:getValue() - mbuf.scX)
	end
	if self.sliderV then
		self.sliderV.element:setValue(self.sliderV.element:getValue() - mbuf.scY)
	end
end

local singleton = nil
local function frameViewportDraw()
	return love.graphics.rectangle("fill", singleton.x, singleton.y, singleton.width, singleton.height)
end

--! Draw elemenets
function frame:draw()
	local internal = Luaoop.class.data(self)

	singleton = self
	love.graphics.push("all")
	love.graphics.setStencilTest("greater", 0)
	love.graphics.stencil(frameViewportDraw, "replace", 1)

	for _, v in ipairs(internal.elementList) do
		-- Only render elements that are in screen using AABB
		-- First rectangle is the object, second rectangle is
		-- the whole frame viewport size
		local w, h = v.element:getDimensions()
		if
			v.x < self.offsetX + self.width and
			v.x + w > self.offsetX and
			v.y < self.offsetY + self.height and
			v.y + h > self.offsetY
		then
			v.element:render(self.x + v.x - self.offsetX, self.y + v.y - self.offsetY)
		end
	end

	if self.sliderH then
		self.sliderH.element:render(self.x, self.sliderH.y + self.y)
	end
	if self.sliderV then
		self.sliderV.element:render(self.x + self.sliderV.x, self.y)
	end

	love.graphics.pop()
	singleton = nil

	for _, v in ipairs(internal.fixedElementList) do
		-- Render regardless
		v.element:render(self.x + v.x, self.y + v.y)
	end
end

return frame
