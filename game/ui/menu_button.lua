-- Main menu button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local color = require("color")
local MainFont = require("main_font")

local ImageButton = require("game.ui.image_button")
local menuButtonUI = Luaoop.class("Livesim2.MenuButtonUI", ImageButton)

function menuButtonUI:new(text)
	local font = MainFont.get(30)
	local h = font:getHeight()

	ImageButton.new(self, "assets/image/ui/s_button_03")
	self.text = love.graphics.newText(font)
	self.text:add({color.white, text}, 32, -0.5 * h + 30)
end

function menuButtonUI:render(x, y)
	ImageButton.render(self, x, y)
	love.graphics.draw(self.text, x, y)
end

return menuButtonUI
