-- Strip Text Divider
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local color = require("color")

local Glow = require("game.afterglow")
local ColorTheme = require("game.color_theme")

---@class Livesim2.StripeText: Glow.Element
local StripeText = Luaoop.class("Livesim2.StripeText", Glow.Element)

---@param font love.Font
function StripeText:new(font, text, padding, width)
	self.height = font:getHeight() + padding * 2
	self.width = width or font:getWidth(text) + padding * 2

	self.color = ColorTheme.get()
	self.text = love.graphics.newText(font)
	self.text:add({color.white, text}, padding, padding)
end

function StripeText:render(x, y)
	love.graphics.setColor(self.color)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.text, x, y)
end

return StripeText
