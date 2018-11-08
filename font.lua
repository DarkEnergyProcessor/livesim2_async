-- Live Simulator: 2 main font
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local cache = require("cache")
local assetCache = require("asset_cache")
local font = {}

function font.get(...)
	local arg = {...}
	local isFallback = {}
	local fontsLoadQueue = {}

	for i = 1, #arg do
		isFallback[i] = not(cache.get("RobotoMainFont"..arg[i]))
		fontsLoadQueue[i * 2 - 1] = {"RobotoMainFont"..arg[i]..":fonts/Roboto-Regular.ttf", arg[i]}
		fontsLoadQueue[i * 2] = {"fonts/MTLmr3m.ttf", arg[i]}
	end

	local fontsData = assetCache.loadMultipleFonts(fontsLoadQueue)
	local result = {}

	for i = 1, #arg do
		result[i] = fontsData[i * 2 - 1]
		if isFallback[i] then
			fontsData[i * 2 - 1]:setFallbacks(fontsData[i * 2])
		end
	end

	return unpack(result)
end

return font
