-- Animated Progress Bar
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local Util = require("util")

local Glow = require("game.afterglow")
local ColorTheme = require("game.color_theme")

local ProgressBar = Luaoop.class("Livesim2.ProgressBar", Glow.Element)

---@param width number
---@param height number
---@param maxvalue number
---@param value number
function ProgressBar:new(width, height, maxvalue, value)
	if ProgressBar.emptyCanvas == nil then
		ProgressBar.emptyCanvas = Util.newCanvas(128, 128)
		ProgressBar.emptyCanvas:setWrap("repeat", "repeat")
	end

	if ProgressBar.shader == nil then
		ProgressBar.shader = love.graphics.newShader("assets/shader/progress.fs")
	end

	self.backgroundColor = ColorTheme.getDarker()
	self.foregroundColor = ColorTheme.get()

	local a, b, c = color.compat(255, 255, 255)
	self.mesh = love.graphics.newMesh({
		{0, 0, 0, 0, a, b, c},
		{width, 0, width / 128, 0, a, b, c},
		{0, height, 0, height / 128, a, b, c},
		{width, height, width / 128, height / 128, a, b, c},
	}, "strip", "static")

	self.width, self.height = width, height
	self.maxValue, self.value = maxvalue or 1, value or 0
	self.time = 0
end

function ProgressBar:update(dt)
	self.time = (self.time + dt) % 1
end

function ProgressBar:render(x, y)
	local shader = love.graphics.getShader()
	local usedColor = color.white
	local v = 0

	ProgressBar.shader:send("time", self.time)
	ProgressBar.shader:sendColor("backgroundColor", self.backgroundColor)

	if math.abs(self.value) == math.huge then
		self.usedColor = self.foregroundColor
	else
		v = Util.clamp(self.value, 0, self.maxValue)
	end

	love.graphics.setShader(ProgressBar.shader)
	love.graphics.setColor(usedColor)
	love.graphics.draw(self.mesh, x, y)
	love.graphics.setShader(shader)

	if v > 0 then
		love.graphics.setColor(self.foregroundColor)
		love.graphics.rectangle("fill", x, y, v * self.width / self.maxValue, self.height)
	end
end

function ProgressBar:setMaxValue(maxvalue)
	self.maxValue = maxvalue
end

function ProgressBar:setValue(value)
	self.value = value
end

return ProgressBar
