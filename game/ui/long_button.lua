-- Long button (span the entire screen)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local gui = require("libs.fusion-ui")
local mainFont = require("font")
local assetCache = require("asset_cache")
local longButtonUI = {class = nil}

local function initialize()
	local buttonImages = assetCache.loadMultipleImages({
		"assets/image/ui/m_button_16.png",
		"assets/image/ui/m_button_16se.png"
	})
	local font = mainFont.get(30)
	local button = gui.template.new("button", {
		backgroundImage = buttonImages[1],
		font = font,
		padding = {0, 0, 0, 0}, -- padding order: {left, top, right, botton}
		backgroundSize = 'fit',
		foregroundColor = {255, 255, 255, 255},
		backgroundColor = {0, 0, 0, 0},
		backgroundImageColor = {255, 255, 255, 255},
		align = 'center',
	})
	button:addStyleSwitch("pressed", "released", {
		backgroundImage = buttonImages[2],
		font = font,
		padding = {0, 0, 0, 0},
		backgroundSize = 'fit',
		foregroundColor = {255, 255, 255, 255},
		backgroundColor = {0, 0, 0, 0},
		backgroundImageColor = {255, 255, 255, 255},
		align = 'center',
	})
	return button
end

function longButtonUI.new(name)
	longButtonUI.class = longButtonUI.class or initialize()
	return longButtonUI.class:newElement(name)
end

function longButtonUI.draw(elem, x, y)
	return elem:draw(x, y, 758, 78)
end

return longButtonUI
