-- Ripple object
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local cubicBezier = require("libs.cubic_bezier")

local color = require("color")

local ripple = Luaoop.class("Livesim2.RippleEffect")
local interpolation = cubicBezier(0.4, 0, 0.2, 1):getFunction()

function ripple:__construct(radius)
	self.radius = radius
	self.timeIn = 0.25
	self.timeOut = 0.25
	self.x = 0
	self.y = 0
	self.pressedFlag = false
end

function ripple:update(dt)
	if self.timeIn < 0.25 then
		self.timeIn = self.timeIn + dt
	end

	if not(self.pressedFlag) and self.timeOut < 0.25 then
		self.timeOut = self.timeOut + dt
	end
end

function ripple:pressed(x, y)
	self.x, self.y = assert(x), assert(y)
	self.timeIn, self.timeOut = 0, 0
	self.pressedFlag = true
end

function ripple:released()
	self.pressedFlag = false
end

function ripple:reset()
	self.timeIn, self.timeOut = 0.25, 0.25
	self.pressedFlag = false
end

function ripple:isActive()
	return self.timeOut < 0.25
end

-- User must setup the stencil buffer for this operation.
-- Otherwise the circle can go out of control
function ripple:draw(r, g, b, x, y)
	if self.timeOut < 0.2 then
		local opacity = interpolation(1 - self.timeOut * 4)
		local radius = interpolation(self.timeIn * 4) * self.radius
		x = x or 0 y = y or 0
		love.graphics.setColor(color.compat(r, g, b, opacity * 0.5))
		love.graphics.circle("line", x + self.x, y + self.y, radius)
		love.graphics.circle("fill", x + self.x, y + self.y, radius)
	end
end

return ripple
