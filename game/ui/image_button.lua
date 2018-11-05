-- Image-based button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local color = require("color")
local assetCache = require("asset_cache")
local glow = require("game.afterglow")

local imageButton = Luaoop.class("Livesim2.ImageButtonUI", glow.element)

function imageButton:new(name, scale)
	-- name..".png"
	-- name.."se.png"
	local images = assetCache.loadMultipleImages({
		name..".png",
		name.."se.png"
	}, {mipmaps = true})

	self.scale = scale or 1
	self.width, self.height = images[1]:getDimensions()
	self.width = self.width * scale
	self.height = self.height * scale
	self.imageNormal = images[1]
	self.imagePressed = images[2]
	self.isPressed = false

	self:addEventListener("mousepressed", imageButton._pressed)
	self:addEventListener("mousereleased", imageButton._released)
	self:addEventListener("mousecanceled", imageButton._released)
end

function imageButton:_pressed(_)
	self.isPressed = true
end

function imageButton:_released(_)
	self.isPressed = false
end

function imageButton:render(x, y)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.isPressed and self.imagePressed or self.imageNormal, x, y, 0, self.scale)
end

return imageButton
