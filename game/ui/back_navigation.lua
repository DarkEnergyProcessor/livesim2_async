-- Back button navigation
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local gui = require("libs.fusion-ui")
local assetCache = require("asset_cache")
local backNavigation = {init = false}

local function initialize()
	if backNavigation.init then return end

	local images = assetCache.loadMultipleImages({
		"assets/image/ui/com_win_02.png",
		"assets/image/ui/com_button_01.png",
		"assets/image/ui/com_button_01se.png"
	})
	backNavigation.backImage = images[1]
	local font = assetCache.loadFont("fonts/MTLmr3m.ttf", 22)
	backNavigation.staticClass = gui.template.new("button", {
		backgroundImage = images[1],
		font = font,
		padding = {193, 0, 0, 0},
		backgroundSize = 'fit',
		foregroundColor = {0, 0, 0, 255},
		backgroundColor = {0, 0, 0, 0},
		backgroundImageColor = {255, 255, 255, 255},
		align = 'left',
	})
	backNavigation.buttonClass = gui.template.new("button", {
		backgroundImage = images[2],
		backgroundSize = 'fit',
		foregroundColor = {255, 255, 255, 255},
		backgroundColor = {0, 0, 0, 0},
		backgroundImageColor = {255, 255, 255, 255},
	})
	backNavigation.buttonClass:addStyleSwitch("pressed", "released", {
		backgroundImage = images[3],
		backgroundSize = 'fit',
		foregroundColor = {255, 255, 255, 255},
		backgroundColor = {0, 0, 0, 0},
		backgroundImageColor = {255, 255, 255, 255},
	})
end

local frameLayout = {
	static = {
		position = 'absolute',
		left = 0,
		top = 0,
		size = 'absolute',
		w = 504,
		h = 40
	},
	button = {
		position = 'absolute',
		left = 98,
		top = 0,
		size = 'absolute',
		w = 86,
		h = 58
	}
}

local defaultFrameLayout = {
	backgroundColor = {0, 0, 0, 0},
	margin = {0, 0, 0, 0},
	padding = {0, 0, 0, 0},
}

function backNavigation.new(statename, target)
	initialize()

	local static = backNavigation.staticClass:newElement(statename)
	local button = backNavigation.buttonClass:newElement("")
	button:addEventListener("released", target)
	local frame = gui.element.newElement("frame", {
		elements = {
			{element = static, index = "static"},
			{element = button, index = "button"}
		},
		layout = frameLayout
	}, defaultFrameLayout)
	frame.xoffset, frame.yoffset = -5, -5

	return frame
end

function backNavigation.draw(elem)
	return elem:draw(-98, 0, 508, 58)
end

setmetatable(backNavigation, {__call = function(_, ...) return backNavigation.new(...) end})
return backNavigation
