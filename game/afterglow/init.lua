-- Afterglow UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Glow = require("game.afterglow.dummy")
local Luaoop = require("libs.Luaoop")

Glow.Frame = require("game.afterglow.frame")
Glow.Element = require("game.afterglow.element")

local defaultFrame = Glow.Frame(0, 0, 960, 640)
local frameList = {}

--! Add frame to event handler
function Glow.addFrame(...)
	if Luaoop.class.type(select(1, ...)) then
		frameList[#frameList + 1] = select(1, ...)
		return select(1, ...)
	else
		local frame = Glow.Frame(...)
		frameList[#frameList + 1] = frame
		return frame
	end
end

function Glow.removeFrame(frame)
	for i = 1, #frameList do
		if frameList[i] == frame then
			table.remove(frameList, i)
			return
		end
	end
end

function Glow.addElement(elem, x, y, ...)
	return defaultFrame:addElement(elem, x, y, ...)
end

function Glow.addFixedElement(elem, x, y, ...)
	return defaultFrame:addFixedElement(elem, x, y, ...)
end

function Glow.removeElement(elem)
	return defaultFrame:removeElement(elem)
end

function Glow.setElementPosition(elem, x, y)
	return defaultFrame:setElementPosition(elem, x, y)
end

function Glow.handleEvents(name, a, b, c, d, e, f)
	for i = #frameList, 1, -1 do
		if frameList[i]:handleEvents(name, a, b, c, d, e, f) then
			return true
		end
	end

	return defaultFrame:handleEvents(name, a, b, c, d, e, f)
end

function Glow.clear()
	for i = #frameList, 1, -1 do
		frameList[i] = nil
	end
	return defaultFrame:clear()
end

function Glow.update(dt)
	return defaultFrame:update(dt)
end

function Glow.draw()
	return defaultFrame:draw()
end

function Glow.getDefaultFrame()
	return defaultFrame
end

return Glow
