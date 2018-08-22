-- Live Simulator: 2 main font
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local cache = require("cache")
local assetCache = require("asset_cache")
local font = {}

function font.get(size)
	local setFallback = not(cache.get("RobotoMainFont"..size))
	local fonts = assetCache.loadMultipleFonts({
		{"RobotoMainFont"..size..":fonts/Roboto-Regular.ttf", size},
		{"fonts/MTLmr3m.ttf", size}
	})

	if setFallback then
		fonts[1]:setFallbacks(fonts[2])
	end

	return fonts[1]
end

return font
