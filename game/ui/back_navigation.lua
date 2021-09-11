-- Back button navigation
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local AssetCache = require("asset_cache")
local MainFont = require("main_font")
local color = require("color")

local ImageButton = require("game.ui.image_button")
local BackNavigation = Luaoop.class("Livesim2.BackNavigation", ImageButton)

function BackNavigation:new(name)
	local font = MainFont.get(22)
	local images = AssetCache.loadMultipleImages({
		"assets/image/ui/com_button_01.png",
		"assets/image/ui/com_button_01se.png",
		"assets/image/ui/com_win_02.png"
	}, {mipmaps = true})

	ImageButton.new(self, images)
	self.bar = images[3]
	self.text = love.graphics.newText(font)
	self.text:add({color.black, name}, 95, 9)
end

function BackNavigation:render(x, y)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.bar, x - 98, y)
	love.graphics.draw(self.text, x, y)
	return ImageButton.render(self, x, y)
end

return BackNavigation
