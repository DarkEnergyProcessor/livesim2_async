-- Afterglow UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")

-- Element is the thing that you see, like buttons,
-- radio checkbox and such. Note that this class is
-- just abstraction. Rest assured that user must
-- implement functions below marked as pure virtual
-- method.

---@class Glow.Element
local Element = Luaoop.class("Glow.Element")

-- Create new element (internal)
function Element:__construct(...)
	---@class Glow.ElementInternal
	local internal = Luaoop.class.data(self)
	internal.events = {}
	internal.opaque = nil

	self.captureText = false
	self.width, self.height = 0, 0
	return self:new(...)
end

-- Create new element (user override)
function Element:new(...)
	error("pure virtual method 'new'")
end

-- Render element for current frame
---@param x number Absolute X position
---@param y number Absolute Y position
function Element:render(x, y)
	error("pure virtual method 'render'")
end

---@param dt number
function Element:update(dt)
end

function Element:setData(data)
	Luaoop.class.data(self).opaque = data
end

function Element:getData()
	return Luaoop.class.data(self).opaque
end

---@param eventname string
---@param handler function
function Element:addEventListener(eventname, handler)
	---@type Glow.ElementInternal
	local internal = Luaoop.class.data(self)

	if internal.events[eventname] == nil then
		internal.events[eventname] = {handler}
	else
		internal.events[eventname][#internal.events[eventname] + 1] = handler
	end
end

---@param eventname string
---@param handler function
function Element:removeEventListener(eventname, handler)
	---@type Glow.ElementInternal
	local internal = Luaoop.class.data(self)

	if internal.events[eventname] then
		for i = 1, #internal.events[eventname] do
			if internal.events[eventname][i] == handler then
				return table.remove(internal.events[eventname], i)
			end
		end
	end
end

---@param eventname string
function Element:triggerEvent(eventname, ...)
	---@type Glow.ElementInternal
	local internal = Luaoop.class.data(self)

	if internal.events[eventname] then
		for _, v in ipairs(internal.events[eventname]) do
			if v(self, Luaoop.class.data(self).opaque, ...) then
				return
			end
		end
	end
end

function Element:getDimensions()
	return self.width, self.height
end

return Element
