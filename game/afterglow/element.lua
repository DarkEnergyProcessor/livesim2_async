-- Afterglow UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")

-- Element is the thing that you see, like buttons,
-- radio checkbox and such. Note that this class is
-- just abstraction. Rest assured that user must
-- implement functions below marked as pure virtual
-- method.

local element = Luaoop.class("Afterglow.Element")

-- Create new element (internal)
function element:__construct(...)
	local internal = Luaoop.class.data(self)
	internal.events = {}

	self.captureText = false
	self.width, self.height = 0, 0
	return self:new(...)
end

-- Create new element (user override)
function element:new(...)
	error("pure virtual method 'new'")
end

--! Render element
--! @param x Absolute X position
--! @param y Absolute Y position
--! @note This is meant to be called by frame
function element:render(x, y)
	error("pure virtual method 'render'")
end

function element:update(dt)
end

function element:setData(data)
	Luaoop.class.data(self).opaque = data
end

function element:getData()
	return Luaoop.class.data(self).opaque
end

function element:addEventListener(eventname, handler)
	local internal = Luaoop.class.data(self)

	if internal.events[eventname] == nil then
		internal.events[eventname] = {handler}
	else
		internal.events[eventname][#internal.events[eventname] + 1] = handler
	end
end

function element:removeEventListener(eventname, handler)
	local internal = Luaoop.class.data(self)

	if internal.events[eventname] then
		for i = 1, #internal.events[eventname] do
			if internal.events[eventname][i] == handler then
				return table.remove(internal.events[eventname], i)
			end
		end
	end
end

function element:triggerEvent(eventname, ...)
	local internal = Luaoop.class.data(self)

	if internal.events[eventname] then
		for _, v in ipairs(internal.events[eventname]) do
			if v(self, Luaoop.class.data(self).opaque, ...) then
				return
			end
		end
	end
end

function element:getDimensions()
	return self.width, self.height
end

return element
