-- Afterglow UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local glow = require("game.afterglow.dummy")
local Luaoop = require("libs.Luaoop")

glow.frame = require("game.afterglow.frame")
glow.element = require("game.afterglow.element")

local defaultFrame = glow.frame(0, 0, 960, 640)
local frameList = {}

--! Add frame to event handler
function glow.addFrame(...)
	if Luaoop.class.type(select(1, ...)) then
		frameList[#frameList + 1] = select(1, ...)
		return select(1, ...)
	else
		local frame = glow.frame(...)
		frameList[#frameList + 1] = frame
		return frame
	end
end

function glow.removeFrame(frame)
	for i = 1, #frameList do
		if frameList[i] == frame then
			table.remove(frameList, i)
			return
		end
	end
end

function glow.addElement(elem, x, y, ...)
	return defaultFrame:addElement(elem, x, y, ...)
end

function glow.addFixedElement(elem, x, y, ...)
	return defaultFrame:addFixedElement(elem, x, y, ...)
end

function glow.removeElement(elem)
	return defaultFrame:removeElement(elem)
end

function glow.setElementPosition(elem, x, y)
	return defaultFrame:setElementPosition(elem, x, y)
end

function glow.handleEvents(name, a, b, c, d, e, f)
	for i = #frameList, 1, -1 do
		if frameList[i]:handleEvents(name, a, b, c, d, e, f) then
			return true
		end
	end

	return defaultFrame:handleEvents(name, a, b, c, d, e, f)
end

function glow.clear()
	for i = #frameList, 1, -1 do
		frameList[i] = nil
	end
	return defaultFrame:clear()
end

function glow.update(dt)
	return defaultFrame:update(dt)
end

function glow.draw()
	return defaultFrame:draw()
end

function glow.getDefaultFrame()
	return defaultFrame
end

return glow
