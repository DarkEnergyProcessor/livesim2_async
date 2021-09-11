-- Toggle Button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local color = require("color")
local AssetCache = require("asset_cache")
local Glow = require("game.afterglow")

local toggleButton = Luaoop.class("Livesim2.ImageButtonUI", Glow.Element)

function toggleButton:new(name, scale)
	local images
	if type(name) == "table" then
		images = name
	else
		images = AssetCache.loadMultipleImages({
			name..".png",
			name.."se.png"
		}, {mipmaps = true})
	end

	self.scale = scale or 1
	self.width, self.height = images[1]:getDimensions()
	self.width = self.width * self.scale
	self.height = self.height * self.scale
	self.imageNormal = assert(images[1])
	self.imagePressed = assert(images[2])
	self.active = false

	self:addEventListener("mousereleased", toggleButton._released)
end

function toggleButton:_released(_)
	self.active = not(self.active)
end

function toggleButton:render(x, y)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.active and self.imagePressed or self.imageNormal, x, y, 0, self.scale)
end

return toggleButton
