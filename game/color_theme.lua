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
		currentColor = color.hexFF4FAE
		-- ef46a1
		currentColorDark = color.hexEF46A1
		-- c31c76
		currentColorDarker = color.hexC31C76
	elseif colid == 2 then
		-- 46baff
		currentColor = color.hex46BAFF
		-- 3bacf0
		currentColorDark = color.hex3BACF0
		-- 007ec6
		currentColorDarker = color.hex007EC6
	elseif colid == 3 then
		-- ffd83a
		currentColor = color.hexFFD83A
		-- eeca2f
		currentColorDark = color.hexEECA2F
		-- c09a00
		currentColorDarker = color.hexC09A00
	else
		error("unknown color id "..colid)
	end
end

function colorTheme.get()
	assert(currentColor, "forgot to call colorTheme.init()")
	return currentColor
end

function colorTheme.getDark()
	assert(currentColorDark, "forgot to call colorTheme.init()")
	return currentColorDark
end


function colorTheme.getDarker()
	assert(currentColorDarker, "forgot to call colorTheme.init()")
	return currentColorDarker
end

return colorTheme
