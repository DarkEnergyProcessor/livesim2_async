-- Afterglow UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local util = require("util")
local element = require("game.afterglow.element")

local slider = Luaoop.class("Afterglow.Slider", element)
local desiredType = {horizontal = "horizontal", vertical = "vertical"}

function slider:new(type, length, maxValue)
	self.sliderType = assert(desiredType[type], "invalid type")
	self.sliderLength = length
	self.sliderMaxValue = maxValue
	self.sliderValue = 0
	self.sliderColor = color.hexFF4FAE
	self.sliderHandleColor = color.white

	if self.sliderType == "horizontal" then
		self.width, self.height = length, 30
	elseif self.sliderType == "vertical" then
		self.width, self.height = 30, length
	end

	self:addEventListener("mousepressed", slider._pressed)
	self:addEventListener("mousemoved", slider._pressed)
end

function slider:_pressed(_, x, y)
	local pos = -36

	if self.sliderType == "horizontal" then
		pos = pos + x
	elseif self.sliderType == "vertical" then
		pos = pos + y
	end

	self.sliderValue = util.clamp(pos / (self.sliderLength - 72), 0, 1) * self.sliderMaxValue
end

function slider:render(x, y)
	local percentage = self.sliderValue / self.sliderMaxValue
	-- slider thickness is 30
	-- slider handle thickness is 24 with length of 72
	if self.sliderType == "horizontal" then
		love.graphics.setColor(self.sliderColor)
		love.graphics.rectangle("fill", x, y, self.sliderLength, 30)
		love.graphics.rectangle("line", x, y, self.sliderLength, 30)
		love.graphics.setColor(self.sliderHandleColor)
		love.graphics.rectangle("fill", x + 3 + percentage * (self.sliderLength - 72 - 6), y + 3, 72, 24)
		love.graphics.rectangle("line", x + 3 + percentage * (self.sliderLength - 72 - 6), y + 3, 72, 24)
	elseif self.sliderType == "vertical" then
		love.graphics.setColor(self.sliderColor)
		love.graphics.rectangle("fill", x, y, 30, self.sliderLength)
		love.graphics.rectangle("line", x, y, 30, self.sliderLength)
		love.graphics.setColor(self.sliderHandleColor)
		love.graphics.rectangle("fill", x + 3, y + 3 + percentage * (self.sliderLength - 72 - 6), 24, 72)
		love.graphics.rectangle("line", x + 3, y + 3 + percentage * (self.sliderLength - 72 - 6), 24, 72)
	end
end

function slider:setMaxValue(maxval)
	self.sliderMaxValue = maxval
	self.sliderValue = math.min(self.sliderValue, maxval)
end

function slider:setValue(value)
	self.sliderValue = util.clamp(value, 0, self.sliderMaxValue)
end

function slider:getValue()
	return self.sliderValue
end

function slider:setSliderColor(col)
	self.sliderColor = assert(col)
end

function slider:setHandleColor(col)
	self.sliderHandleColor = assert(col)
end

return slider
