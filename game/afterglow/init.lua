-- Afterglow UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local glow = require("game.afterglow.dummy")

glow.frame = require("game.afterglow.frame")
glow.element = require("game.afterglow.element")

local defaultFrame = glow.frame(0, 0, 960, 640)

function glow.addElement(elem, x, y, ...)
	return defaultFrame:addElement(elem, x, y, ...)
end

function glow.removeElement(elem)
	return defaultFrame:removeElement(elem)
end

function glow.handleEvents(name, a, b, c, d, e, f)
	--if name == "resize" then
		--defaultFrame:resize(a, b)
	--end

	return defaultFrame:handleEvents(name, a, b, c, d, e, f)
end

function glow.clear()
	return defaultFrame:clear()
end

function glow.update(dt)
	return defaultFrame:update(dt)
end

function glow.draw()
	return defaultFrame:draw()
end

return glow
