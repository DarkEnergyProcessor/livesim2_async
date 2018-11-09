-- Back button navigation
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local assetCache = require("asset_cache")
local mainFont = require("font")
local color = require("color")

local imageButtonUI = require("game.ui.image_button")
local backNavigation = Luaoop.class("Livesim2.BackNavigation", imageButtonUI)

function backNavigation:new(name)
	local font = mainFont.get(22)
	local images = assetCache.loadMultipleImages({
		"assets/image/ui/com_button_01.png",
		"assets/image/ui/com_button_01se.png",
		"assets/image/ui/com_win_02.png"
	}, {mipmaps = true})

	imageButtonUI.new(self, images)
	self.bar = images[3]
	self.text = love.graphics.newText(font)
	self.text:add({color.black, name}, 95, 9)
end

function backNavigation:render(x, y)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.bar, x - 98, y)
	love.graphics.draw(self.text, x, y)
	return imageButtonUI.render(self, x, y)
end

return backNavigation
