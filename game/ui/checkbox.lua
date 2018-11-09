-- Checkbox
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local assetCache = require("asset_cache")
local glow = require("game.afterglow")

local checkbox = Luaoop.class("Livesim2.CheckboxUI", glow.element)

function checkbox:new(checked, scale)
	if not(checkbox.images) then
		checkbox.images = assetCache.loadMultipleImages({
			"assets/image/ui/com_etc_292.png",
			"assets/image/ui/com_etc_293.png"
		}, {mipmaps = true})
		checkbox.imageWidth, checkbox.imageHeight = checkbox.images[1]:getDimensions()
	end

	self.checked = not(not(checked))
	self.scale = scale or 1
	self.width, self.height = checkbox.imageWidth * self.scale, checkbox.imageHeight * self.scale
	self:addEventListener("mousereleased", checkbox._released)
end

function checkbox:_released()
	self.checked = not(self.checked)
	self:triggerEvent("changed", self.checked)
end

function checkbox:isChecked()
	return self.checked
end

function checkbox:setChecked(checked)
	self.checked = not(not(checked))
end

function checkbox:render(x, y)
	love.graphics.draw(checkbox.images[1], x, y, 0, self.scale)
	if self.checked then
		love.graphics.draw(checkbox.images[2], x, y, 0, self.scale, self.scale, 4, 0)
	end
end

return checkbox
