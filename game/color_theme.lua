-- Color theme manager
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local color = require("color")
local ColorTheme = {
	[1] = {
		-- ff4fae
		currentColor = {0xff, 0x4f, 0xae, color.hexFF4FAE},
		-- ef46a1
		currentColorDark = {0xef, 0x46, 0xa1, color.hexEF46A1},
		-- c31c76
		currentColorDarker = {0xc3, 0x1c, 0x76, color.hexC31C76}
	},
	[2] = {
		-- 46baff
		currentColor = {0x46, 0xba, 0xff, color.hex46BAFF},
		-- 3bacf0
		currentColorDark = {0x3b, 0xac, 0xf0, color.hex3BACF0},
		-- 007ec6
		currentColorDarker = {0x00, 0x7e, 0xc6, color.hex007EC6}
	},
	[3] = {
		-- ffc22e
		currentColor = {0xff, 0xc2, 0x2e, color.hexFFC22E},
		-- e8b126
		currentColorDark = {0xe8, 0xb1, 0x26, color.hexE8B126},
		-- ac7b0a
		currentColorDarker = {0xac, 0x7b, 0x0a, color.hexAC7B0A}
	},
	[4] = {
		-- d684df
		currentColor = {0xd6, 0x84, 0xdf, color.hexD684DF},
		-- 8b4993
		currentColorDark = {0x8b, 0x49, 0x93, color.hex8B4993},
		-- 68366d
		currentColorDarker = {0x68, 0x36, 0x6d, color.hex68366D}
	},
	[5] = {
		-- fb9ba9
		currentColor = {0xfb, 0x9b, 0xa9, color.hexFB9BA9},
		-- fb8a9b
		currentColorDark = {0xfb, 0x8a, 0x9b, color.hexFB8A9B},
		-- fb7085
		currentColorDarker = {0xfb, 0x70, 0x85, color.hexFB7085}
	}
}

local currentColor, currentColorDark, currentColorDarker

-- colid: 1 = μ's, 2 = Aqours, 3 = NijiGaku
function ColorTheme.init(colid)
	if currentColor then return end
	return ColorTheme.set(colid)
end

function ColorTheme.set(colid)
	if ColorTheme[colid] == nil then
		error("unknown color id "..colid)
	end

	currentColor = ColorTheme[colid].currentColor
	currentColorDark = ColorTheme[colid].currentColorDark
	currentColorDarker = ColorTheme[colid].currentColorDarker
end

function ColorTheme.get(opacity)
	assert(currentColor, "forgot to call colorTheme.init()")
	if opacity then
		return color.compat(currentColor[1], currentColor[2], currentColor[3], opacity)
	else
		return currentColor[4]
	end
end

function ColorTheme.getDark(opacity)
	assert(currentColorDark, "forgot to call colorTheme.init()")
	if opacity then
		return color.compat(currentColorDark[1], currentColorDark[2], currentColorDark[3], opacity)
	else
		return currentColorDark[4]
	end
end


function ColorTheme.getDarker(opacity)
	assert(currentColorDarker, "forgot to call colorTheme.init()")
	if opacity then
		return color.compat(currentColorDarker[1], currentColorDarker[2], currentColorDarker[3], opacity)
	else
		return currentColorDarker[4]
	end
end

return ColorTheme
