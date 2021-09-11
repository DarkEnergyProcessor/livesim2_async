-- Beatmap Select Button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local MainFont = require("main_font")
local color = require("color")

local ImageButton = require("game.ui.image_button")
local beatmapSelButton = Luaoop.class("Livesim2.BeatmapSelectButtonUI", ImageButton)

function beatmapSelButton:new(name, format, difficulty)
	ImageButton.new(self, "assets/image/ui/s_button_03", 0.75)
	local fmtfont, difffont, namefont = MainFont.get(11, 14, 20)

	self.formatText = love.graphics.newText(fmtfont)
	self.formatText:add({color.black, format}, 6, 41)
	self.nameText = love.graphics.newText(namefont)
	self.nameText:add({color.white, name}, 8, 12)

	if difficulty and #difficulty > 0 then
		self.difficultyText = love.graphics.newText(difffont)
		self.difficultyText:add({color.white, difficulty}, 314 - difffont:getWidth(difficulty), 5)
	end
end

function beatmapSelButton:render(x, y)
	ImageButton.render(self, x, y)
	love.graphics.draw(self.nameText, x, y)
	love.graphics.draw(self.formatText, x, y)
	if self.difficultyText then
		love.graphics.draw(self.difficultyText, x, y)
	end
end

return beatmapSelButton
