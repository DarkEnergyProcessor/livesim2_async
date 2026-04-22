-- Color theme manager
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local color = require("color")
local ColorTheme = {
	[1] = {	-- µ's
		-- ff4fae
		currentColor = {0xff, 0x4f, 0xae, color.hexFF4FAE},
		-- ef46a1
		currentColorDark = {0xef, 0x46, 0xa1, color.hexEF46A1},
		-- c31c76
		currentColorDarker = {0xc3, 0x1c, 0x76, color.hexC31C76}
	},
	[2] = {	-- Aqours
		-- 46baff
		currentColor = {0x46, 0xba, 0xff, color.hex46BAFF},
		-- 3bacf0
		currentColorDark = {0x3b, 0xac, 0xf0, color.hex3BACF0},
		-- 007ec6
		currentColorDarker = {0x00, 0x7e, 0xc6, color.hex007EC6}
	},
	[3] = { -- NijiGaku
		-- ffc22e
		currentColor = {0xff, 0xc2, 0x2e, color.hexFFC22E},
		-- e8b126
		currentColorDark = {0xe8, 0xb1, 0x26, color.hexE8B126},
		-- ac7b0a
		currentColorDarker = {0xac, 0x7b, 0x0a, color.hexAC7B0A}
	},
	[4] = { -- Liella
		-- d991d8
		currentColor = {0xd9, 0x91, 0xd8, color.hexD991D8},
		-- cc6bcb
		currentColorDark = {0xcc, 0x6b, 0xcb, color.hexCC6BCB},
		-- bf45bd
		currentColorDarker = {0xbf, 0x45, 0xbd, color.hexBF45BD}
	},
	[5] = {	-- Hasunosora
		-- fb9ba9
		currentColor = {0xfb, 0x9b, 0xa9, color.hexFB9BA9},
		-- fb8a9b
		currentColorDark = {0xfb, 0x8a, 0x9b, color.hexFB8A9B},
		-- fb7085
		currentColorDarker = {0xfb, 0x70, 0x85, color.hexFB7085}
	},
	[6] = {	-- (School Idol) Musical
		-- f70042
		currentColor = {0xf7, 0x09, 0x42, color.hexF70042},
		-- de003b
		currentColorDark = {0xde, 0x00, 0x3b, color.hexDE003B},
		-- c40035
		currentColorDarker = {0xc4, 0x00, 0x35, color.hexC40035}
	},
	[7] = {	-- YTP (Yohane the Parhelion)
		-- 23a2b0
		currentColor = {0x23, 0xa2, 0xb0, color.hex23A2B0},
		-- 1e8a96
		currentColorDark = {0x1e, 0x8a, 0x96, color.hex1E8A96},
		-- 19737d
		currentColorDarker = {0x19, 0x73, 0x7d, color.hex19737D}
	},
	[8] = { -- Bluebird
		-- ff7500
		currentColor = {0xff, 0x75, 0x00, color.hexFF7500},
		-- ed6d00
		currentColorDark = {0xed, 0x6d, 0x00, color.hexED6D00},
		-- db6500
		currentColorDarker = {0xdb, 0x65, 0x00, color.hexDB6500}
	}
}

local currentColor, currentColorDark, currentColorDarker

-- colid: 1 = μ's, 2 = Aqours, 3 = NijiGaku, 4 = Liella, 5 = Hasunosora
-- 6 = Musical, 7 = Yohane
---@param colid integer
function ColorTheme.init(colid)
	if currentColor then return end
	return ColorTheme.set(colid)
end

---@param colid integer
function ColorTheme.set(colid)
	if ColorTheme[colid] == nil then
		error("unknown color id "..colid)
	end

	currentColor = ColorTheme[colid].currentColor
	currentColorDark = ColorTheme[colid].currentColorDark
	currentColorDarker = ColorTheme[colid].currentColorDarker
end

---@param opacity number
function ColorTheme.get(opacity)
	assert(currentColor, "forgot to call colorTheme.init()")
	if opacity then
		return color.compat(currentColor[1], currentColor[2], currentColor[3], opacity)
	else
		return currentColor[4]
	end
end

---@param opacity number
function ColorTheme.getDark(opacity)
	assert(currentColorDark, "forgot to call colorTheme.init()")
	if opacity then
		return color.compat(currentColorDark[1], currentColorDark[2], currentColorDark[3], opacity)
	else
		return currentColorDark[4]
	end
end

---@param opacity number
function ColorTheme.getDarker(opacity)
	assert(currentColorDarker, "forgot to call colorTheme.init()")
	if opacity then
		return color.compat(currentColorDarker[1], currentColorDarker[2], currentColorDarker[3], opacity)
	else
		return currentColorDarker[4]
	end
end

return ColorTheme
