-- LOVE compatibility layer
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- Some notes:
-- 1. Colors arein 0...255 range
-- 2. Function uses LOVE 0.10.2 names
-- 3. love.mouse and love.keyboard is turned into optimized access
-- Note that LOVE compatibility layer has
-- some limitation regarding variants.

local love = require("love")
local oTenO = love._version < "11.0"
local lovec = {
	graphics = {},
	mouse = {},
	keyboard = {},
}

-- Optimization
local internalState = {
	mouse = {},
	keyboard = {},
}

-- love.graphics.setColor
if oTenO then
	lovec.graphics.setColor = love.graphics.setColor
else
	local per255 = 1/255
	function lovec.graphics.setColor(r, g, b, a)
		return love.graphics.setColor(r * per255, g * per255, g * per255, (a or 255) * per255)
	end
end

return lovec
