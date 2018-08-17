-- Beatmap Select Button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local gui = require("libs.fusion-ui")
local color = require("color")
local assetCache = require("asset_cache")
local beatmapSelButton = {class = nil}

local function initialize()
	local images = assetCache.loadMultipleImages({
		"assets/image/ui/s_button_03.png",
		"assets/image/ui/s_button_03se.png"
	}, {mipmaps = true})
	local fmtfont = assetCache.loadFont("fonts/MTLmr3m.ttf", 11)
	local diffont = assetCache.loadFont("fonts/MTLmr3m.ttf", 14)
	local namefont = assetCache.loadFont("fonts/MTLmr3m.ttf", 22)
	local c1 = love.graphics.newCanvas(324, 60)
	local c2 = love.graphics.newCanvas(324, 60)

	beatmapSelButton.formatTextStyle = {
		font = fmtfont,
		align = 'left',
		foregroundColor = {0, 0, 0, 255},
		backgroundColor = {0, 0, 0, 0}
	}
	beatmapSelButton.difficultyTextStyle = {
		font = diffont,
		align = 'left',
		foregroundColor = {255, 255, 255, 255},
		backgroundColor = {0, 0, 0, 0}
	}

	-- Have to resize the images
	love.graphics.push("all")
	love.graphics.setColor(color.white)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.setCanvas(c1)
	love.graphics.draw(images[1], 0, 0, 0, 0.75, 0.75)
	love.graphics.setCanvas(c2)
	love.graphics.draw(images[2], 0, 0, 0, 0.75, 0.75)
	love.graphics.pop()

	-- Main button class
	local mainPad = {8, -4, 0, 0}
	local button = gui.template.new("button", {
		backgroundImage = c1,
		font = namefont,
		padding = mainPad,
		backgroundSize = 'fit',
		foregroundColor = {255, 255, 255, 255},
		backgroundColor = {0, 0, 0, 0},
		backgroundImageColor = {255, 255, 255, 255},
		align = 'left',
	})
	button:addStyleSwitch("pressed", "released", {
		backgroundImage = c2,
		font = namefont,
		padding = mainPad,
		backgroundSize = 'fit',
		foregroundColor = {255, 255, 255, 255},
		backgroundColor = {0, 0, 0, 0},
		backgroundImageColor = {255, 255, 255, 255},
		align = 'left',
	})

	return button
end

local buttonFrameLayout = {
	button = {
		position = "absolute",
		size = "absolute",
		left = 0,
		top = 0,
		w = 324,
		h = 60
	},
	format = {
		position = "absolute",
		size = "absolute",
		left = 6,
		top = 41
	},
	difficulty = {
		position = "absolute",
		size = "absolute",
		right = -20,
		top = 5
	}
}

local buttonFrameStyle = {
	backgroundColor = {0, 0, 0, 0}
}

function beatmapSelButton.init()
	beatmapSelButton.class = beatmapSelButton.class or initialize()
end

function beatmapSelButton.new(name, format, callback, difficulty)
	beatmapSelButton.class = beatmapSelButton.class or initialize()

	local button = beatmapSelButton.class:newElement(name)
	local elems = {
		{
			element = button,
			index = "button"
		},
		{
			element = gui.element.newElement("text", format, beatmapSelButton.formatTextStyle),
			index = "format"
		}
	}

	if difficulty and #difficulty > 0 then
		elems[#elems + 1] = {
			element = gui.element.newElement("text", difficulty, beatmapSelButton.difficultyTextStyle),
			index = "difficulty"
		}
	end

	local buttonFrame = gui.element.newElement("frame", {
		elements = elems,
		layout = buttonFrameLayout
	}, buttonFrameStyle)
	buttonFrame.xoffset, buttonFrame.yoffset = -5, -5

	button:addEventListener("released", callback, buttonFrame)
	return buttonFrame
end

return beatmapSelButton
