-- Long select button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local MainFont = require("main_font")
local color = require("color")

local ImageButton = require("game.ui.image_button")

local SelectButton = Luaoop.class("Livesim2.SelectButtonUI", ImageButton)

function SelectButton:new(text)
	local font = MainFont.get(16)
	local h = font:getHeight()

	ImageButton.new(self, "assets/image/ui/s_button_03", 0.5)
	self.text = love.graphics.newText(font)
	self.text:add({color.white, text}, 8, 16 - 0.5 * h)
end

function SelectButton:setText(text)
	local h = self.text:getFont():getHeight()
	self.text:clear()
	self.text:add({color.white, text}, 8, 16 - 0.5 * h)
end

function SelectButton:render(x, y)
	ImageButton.render(self, x, y)
	love.graphics.draw(self.text, x, y)
end

return SelectButton
