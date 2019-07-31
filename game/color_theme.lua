-- Color theme manager
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local color = require("color")
local colorTheme = {}
local currentColor, currentColorDark, currentColorDarker

-- colid: 1 = μ's, 2 = Aqours, 3 = NijiGaku
function colorTheme.init(colid)
	if currentColor then return end
	return colorTheme.set(colid)
end

function colorTheme.set(colid)
	if colid == 1 then
		-- ff4fae
		currentColor = {0xff, 0x4f, 0xae, color.hexFF4FAE}
		-- ef46a1
		currentColorDark = {0xef, 0x46, 0xa1, color.hexEF46A1}
		-- c31c76
		currentColorDarker = {0xc3, 0x1c, 0x76, color.hexC31C76}
	elseif colid == 2 then
		-- 46baff
		currentColor = {0x46, 0xba, 0xff, color.hex46BAFF}
		-- 3bacf0
		currentColorDark = {0x3b, 0xac, 0xf0, color.hex3BACF0}
		-- 007ec6
		currentColorDarker = {0x00, 0x7e, 0xc6, color.hex007EC6}
	elseif colid == 3 then
		-- ffc22e
		currentColor = {0xff, 0xc2, 0x2e, color.hexFFC22E}
		-- e8b126
		currentColorDark = {0xe8, 0xb1, 0x26, color.hexE8B126}
		-- ac7b0a
		currentColorDarker = {0xac, 0x7b, 0x0a, color.hexAC7B0A}
	else
		error("unknown color id "..colid)
	end
end

function colorTheme.get(opacity)
	assert(currentColor, "forgot to call colorTheme.init()")
	if opacity then
		return color.compat(currentColor[1], currentColor[2], currentColor[3], opacity)
	else
		return currentColor[4]
	end
end

function colorTheme.getDark(opacity)
	assert(currentColorDark, "forgot to call colorTheme.init()")
	if opacity then
		return color.compat(currentColorDark[1], currentColorDark[2], currentColorDark[3], opacity)
	else
		return currentColorDark[4]
	end
end


function colorTheme.getDarker(opacity)
	assert(currentColorDarker, "forgot to call colorTheme.init()")
	if opacity then
		return color.compat(currentColorDarker[1], currentColorDarker[2], currentColorDarker[3], opacity)
	else
		return currentColorDarker[4]
	end
end

return colorTheme
