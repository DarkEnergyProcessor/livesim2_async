-- Afterglow UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")

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
	--self.framebuffer = love.graphics.newCanvas(w, h)

	internal.mouseBuffer = {
		pressed = false,
		x = 0,
		y = 0,
		targetElement = nil
	}
	internal.elementList = {}
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
		x = x,
		y = y
	}
	return elem
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

		for i = #internal.elementList, 1, -1 do
			local info = internal.elementList[i]
			local w, h = info.element:getDimensions()
			if a >= info.x and b >= info.y and a < info.x + w and b < info.y + h then
				-- enter
				info.element:triggerEvent("mousepressed", a - info.x, b - info.y)
				internal.mouseBuffer.pressed = true
				internal.mouseBuffer.targetElement = info
				internal.mouseBuffer.x, internal.mouseBuffer.y = a, b

				return true
			end
		end
	elseif name == "mousemoved" and internal.mouseBuffer.pressed then
		local info = internal.mouseBuffer.targetElement
		local w, h = info.element:getDimensions()

		if a < info.x or b < info.y or a >= info.x + w or b >= info.y + h then
			info.element:triggerEvent("mousecanceled")
			internal.mouseBuffer.pressed = false
			internal.mouseBuffer.targetElement = nil
		else
			info.element:triggerEvent("mousemoved", a - info.x, b - info.y)
		end

		return true
	elseif name == "mousereleased" and internal.mouseBuffer.pressed then
		internal.mouseBuffer.targetElement.element:triggerEvent("mousereleased")
		internal.mouseBuffer.pressed = false
		internal.mouseBuffer.targetElement = nil
		return true
	elseif name == "textinput" then
		for i = #internal.elementList, 1, -1 do
			local info = internal.elementList[i]

			if info.element.captureText then
				info.element:triggerEvent("textinput", a)
				return true
			end
		end
	end

	return false
end

--! Removes all elements, effectively clear it
function frame:clear()
	local internal = Luaoop.class.data(self)

	for i = #internal.elementList, 1, -1 do
		self:removeElement(internal.elementList[i].element)
	end
end

--! Resize frame size
function frame:resize(w, h)
	self.width, self.height = w, h
	self.framebuffer = love.graphics.newCanvas(w, h)
end

local temp = {nil, stencil = true}
--! Update elements
function frame:update(dt)
	local internal = Luaoop.class.data(self)
	love.graphics.push("all") temp[1] = self.framebuffer
	love.graphics.setCanvas(temp)
	for _, v in ipairs(internal.elementList) do
		v.element:update(dt)
	end
	love.graphics.pop()
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

	love.graphics.pop()
	singleton = nil
end

return frame
