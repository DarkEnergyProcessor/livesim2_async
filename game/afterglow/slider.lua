-- Afterglow UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local Util = require("util")
local ColorTheme = require("game.color_theme")
local Element = require("game.afterglow.element")

---@class Glow.Slider: Glow.Element
local Slider = Luaoop.class("Glow.Slider", Element)
local desiredType = {horizontal = "horizontal", vertical = "vertical"}

---@param type '"horizontal"' | '"vertical"'
---@param length number
---@param maxValue number
function Slider:new(type, length, maxValue)
	self.sliderType = assert(desiredType[type], "invalid type")
	self.sliderLength = length
	self.sliderMaxValue = maxValue
	self.sliderValue = 0
	self.sliderColor = ColorTheme.get()
	self.sliderHandleColor = color.white

	if self.sliderType == "horizontal" then
		self.width, self.height = length, 30
	elseif self.sliderType == "vertical" then
		self.width, self.height = 30, length
	end

	self:addEventListener("mousepressed", Slider._pressed)
	self:addEventListener("mousemoved", Slider._pressed)
end

function Slider:_pressed(_, x, y)
	local pos = -36

	if self.sliderType == "horizontal" then
		pos = pos + x
	elseif self.sliderType == "vertical" then
		pos = pos + y
	end

	self.sliderValue = Util.clamp(pos / (self.sliderLength - 72), 0, 1) * self.sliderMaxValue
end

function Slider:render(x, y)
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

function Slider:setMaxValue(maxval)
	self.sliderMaxValue = maxval
	self.sliderValue = math.min(self.sliderValue, maxval)
end

function Slider:setValue(value)
	self.sliderValue = Util.clamp(value, 0, self.sliderMaxValue)
end

function Slider:getValue()
	return self.sliderValue
end

function Slider:setSliderColor(col)
	self.sliderColor = assert(col)
end

function Slider:setHandleColor(col)
	self.sliderHandleColor = assert(col)
end

return Slider
