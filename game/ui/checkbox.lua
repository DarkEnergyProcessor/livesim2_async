-- Checkbox
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local AssetCache = require("asset_cache")
local Glow = require("game.afterglow")

local Checkbox = Luaoop.class("Livesim2.CheckboxUI", Glow.Element)

function Checkbox:new(checked, scale)
	if not(Checkbox.images) then
		Checkbox.images = AssetCache.loadMultipleImages({
			"assets/image/ui/com_etc_292.png",
			"assets/image/ui/com_etc_293.png"
		}, {mipmaps = true})
		Checkbox.imageWidth, Checkbox.imageHeight = Checkbox.images[1]:getDimensions()
	end

	self.checked = not(not(checked))
	self.scale = scale or 1
	self.width, self.height = Checkbox.imageWidth * self.scale, Checkbox.imageHeight * self.scale
	self:addEventListener("mousereleased", Checkbox._released)
end

function Checkbox:_released()
	self.checked = not(self.checked)
	self:triggerEvent("changed", self.checked)
end

function Checkbox:isChecked()
	return self.checked
end

function Checkbox:setChecked(checked)
	self.checked = not(not(checked))
end

function Checkbox:render(x, y)
	love.graphics.draw(Checkbox.images[1], x, y, 0, self.scale)
	if self.checked then
		love.graphics.draw(Checkbox.images[2], x, y, 0, self.scale, self.scale, 4, 0)
	end
end

return Checkbox
