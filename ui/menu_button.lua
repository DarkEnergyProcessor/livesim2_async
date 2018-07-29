-- Main menu button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local gui = require("libs.fusion-ui")
local assetCache = require("asset_cache")
local menuButtonUI = {class = nil, w = nil, h = nil}

local buttonStyleNormal = {
	backgroundImage = nil,
	font = nil,
	margins = {16, 16, 16, 32}, -- assume CSS order
	backgroundSize = 'fit',
	foregroundColor = {255, 255, 255, 255},
}

local function initialize()
	local buttonImages = assetCache.loadMultipleImages({
		"assets/image/ui/s_button_03.png",
		"assets/image/ui/s_button_03se.png"
	})
	local font = assetCache.loadFont("fonts/MTLmr3m.ttf", 30)
	local button = gui.template.new("button", {
		backgroundImage = buttonImages[1],
		font = font,
		padding = {32, -8, 0, 0},
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
	local v = menuButtonUI.class:newElement(name)
	return v
end

setmetatable(menuButtonUI, {__call = function(_, name) return menuButtonUI.new(name) end})
return menuButtonUI
