-- Image-based button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local color = require("color")
local AssetCache = require("asset_cache")
local Glow = require("game.afterglow")

local ImageButton = Luaoop.class("Livesim2.ImageButtonUI", Glow.Element)

function ImageButton:new(name, scale)
	-- name..".png"
	-- name.."se.png"
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
	self.isPressed = false

	self:addEventListener("mousepressed", ImageButton._pressed)
	self:addEventListener("mousereleased", ImageButton._released)
	self:addEventListener("mousecanceled", ImageButton._released)
end

function ImageButton:_pressed(_)
	self.isPressed = true
end

function ImageButton:_released(_)
	self.isPressed = false
end

function ImageButton:render(x, y)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.isPressed and self.imagePressed or self.imageNormal, x, y, 0, self.scale)
end

return ImageButton
