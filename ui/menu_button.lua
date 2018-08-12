-- Main menu button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local gui = require("libs.fusion-ui")
local assetCache = require("asset_cache")
local menuButtonUI = {class = nil}

local function initialize()
	local buttonImages = assetCache.loadMultipleImages({
		"assets/image/ui/s_button_03.png",
		"assets/image/ui/s_button_03se.png"
	})
	local font = assetCache.loadFont("fonts/MTLmr3m.ttf", 30)
	local button = gui.template.new("button", {
		backgroundImage = buttonImages[1],
		font = font,
		padding = {32, -8, 0, 0}, -- padding order: {left, top, right, botton}
		backgroundSize = 'fit',
		foregroundColor = {255, 255, 255, 255},
		backgroundColor = {0, 0, 0, 0},
		backgroundImageColor = {255, 255, 255, 255},
		align = 'left',
	})
	button:addStyleSwitch("pressed", "released", {
		backgroundImage = buttonImages[2],
		font = font,
		padding = {32, -8, 0, 0},
		backgroundSize = 'fit',
		foregroundColor = {255, 255, 255, 255},
		backgroundColor = {0, 0, 0, 0},
		backgroundImageColor = {255, 255, 255, 255},
		align = 'left',
	})
	return button
end

function menuButtonUI.new(name)
	menuButtonUI.class = menuButtonUI.class or initialize()
	return menuButtonUI.class:newElement(name)
end

function menuButtonUI.draw(elem, x, y)
	return elem:draw(x, y, 432, 80)
end

setmetatable(menuButtonUI, {__call = function(_, ...) return menuButtonUI.new(...) end})
return menuButtonUI
