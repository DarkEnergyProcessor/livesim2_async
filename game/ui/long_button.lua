-- Long button (span the entire screen)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local MainFont = require("main_font")
local color = require("color")

local ImageButton = require("game.ui.image_button")

local longButtonUI = Luaoop.class("Livesim2.LongButtonUI", ImageButton)

function longButtonUI:new(text)
	local font = MainFont.get(30)
	local w, h = font:getWidth(text), font:getHeight()

	ImageButton.new(self, "assets/image/ui/m_button_16")
	self.text = love.graphics.newText(font)
	self.text:add({color.white, text}, 379 - 0.5 * w, 39 - 0.5 * h)
end

function longButtonUI:setText(text)
	local f = self.text:getFont()
	self.text:clear()
	self.text:add({color.white, text}, 379 - 0.5 * f:getWidth(text), 39 - 0.5 * f:getHeight())
end

function longButtonUI:render(x, y)
	ImageButton.render(self, x, y)
	love.graphics.draw(self.text, x, y)
end

return longButtonUI
