-- Main menu button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local color = require("color")
local mainFont = require("font")

local imageButtonUI = require("game.ui.image_button")
local menuButtonUI = Luaoop.class("Livesim2.MenuButtonUI", imageButtonUI)

function menuButtonUI:new(text)
	local font = mainFont.get(30)
	local h = font:getHeight()

	imageButtonUI.new(self, "assets/image/ui/s_button_03")
	self.text = love.graphics.newText(font)
	self.text:add({color.white, text}, 32, -0.5 * h + 30)
end

function menuButtonUI:render(x, y)
	imageButtonUI.render(self, x, y)
	love.graphics.draw(self.text, x, y)
end

return menuButtonUI
