-- Long select button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local mainFont = require("font")
local color = require("color")

local imageButtonUI = require("game.ui.image_button")

local selectButton = Luaoop.class("Livesim2.SelectButtonUI", imageButtonUI)

function selectButton:new(text)
	local font = mainFont.get(16)
	local h = font:getHeight()

	imageButtonUI.new(self, "assets/image/ui/s_button_03", 0.5)
	self.text = love.graphics.newText(font)
	self.text:add({color.white, text}, 8, 40 - 0.5 * h)
end

function selectButton:render(x, y)
	imageButtonUI.render(self, x, y)
	love.graphics.draw(self.text, x, y)
end

return selectButton
