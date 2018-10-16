-- Image-based button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local gui = require("libs.fusion-ui")
local assetCache = require("asset_cache")

local imageButton = {class = {}}

function imageButton.new(name)
	-- name..".png"
	-- name.."se.png"
	-- all image should have 144x58 pixels size
	if imageButton.class[name] == nil then
		local images = assetCache.loadMultipleImages({
			name..".png",
			name.."se.png"
		}, {mipmaps = true})
		local button = gui.template.new("button", {
			backgroundImage = images[1],
			backgroundSize = 'fit',
			foregroundColor = {255, 255, 255, 255},
			backgroundColor = {0, 0, 0, 0},
			backgroundImageColor = {255, 255, 255, 255},
		})
		button:addStyleSwitch("pressed", "released", {
			backgroundImage = images[2],
			backgroundSize = 'fit',
			foregroundColor = {255, 255, 255, 255},
			backgroundColor = {0, 0, 0, 0},
			backgroundImageColor = {255, 255, 255, 255},
		})

		button.imgw, button.imgh = images[1]:getDimensions()
		imageButton.class[name] = button
	end

	local elem = imageButton.class[name]:newElement("")
	elem.tempimgw, elem.tempimgh = imageButton.class[name].imgw, imageButton.class[name].imgh
	return elem
end

function imageButton.draw(elem, x, y)
	return elem:draw(x, y, elem.tempimgw, elem.tempimgh)
end

return imageButton
