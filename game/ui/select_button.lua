-- Long select button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local gui = require("libs.fusion-ui")
local mainFont = require("font")
local color = require("color")
local assetCache = require("asset_cache")
local selectButton = {class = nil}

local function initialize()
	local images = assetCache.loadMultipleImages({
		"assets/image/ui/s_button_03.png",
		"assets/image/ui/s_button_03se.png"
	}, {mipmaps = true})
	local font = mainFont.get(16)
	local c1 = love.graphics.newCanvas(216, 40)
	local c2 = love.graphics.newCanvas(216, 40)

	-- Have to resize the images
	love.graphics.push("all")
	love.graphics.setColor(color.white)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.setCanvas(c1)
	love.graphics.draw(images[1], 0, 0, 0, 0.5, 0.5)
	love.graphics.setCanvas(c2)
	love.graphics.draw(images[2], 0, 0, 0, 0.5, 0.5)
	love.graphics.pop()

	local button = gui.template.new("button", {
		backgroundImage = c1,
		font = font,
		padding = {8, -4, 0, 0},
		backgroundSize = 'fit',
		foregroundColor = {255, 255, 255, 255},
		backgroundColor = {0, 0, 0, 0},
		backgroundImageColor = {255, 255, 255, 255},
		align = 'left',
	})
	button:addStyleSwitch("pressed", "released", {
		backgroundImage = c2,
		font = font,
		padding = {8, -4, 0, 0},
		backgroundSize = 'fit',
		foregroundColor = {255, 255, 255, 255},
		backgroundColor = {0, 0, 0, 0},
		backgroundImageColor = {255, 255, 255, 255},
		align = 'left',
	})

	return button
end

function selectButton.new(name)
	selectButton.class = selectButton.class or initialize()
	return selectButton.class:newElement(name)
end

function selectButton.draw(elem, x, y)
	return elem:draw(x, y, 216, 40)
end

setmetatable(selectButton, {__call = function(_, ...) return selectButton.new(...) end})
return selectButton
