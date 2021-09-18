-- Live Simulator: 2 main font
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local AssetCache = require("asset_cache")
local Async = require("async")
local Cache = require("cache")
local lily = require("lily")
local log = require("logging")
local Util = require("util")

local MainFont = {}

MainFont.roboto = love.filesystem.newFileData("fonts/Roboto-Regular.ttf")
MainFont.notoSansCJK = love.filesystem.newFileData("fonts/NotoSansCJKjp-Regular.woff")
MainFont.sarabun = love.filesystem.newFileData("fonts/Sarabun-Regular.ttf")
MainFont.dpiScale = Util.getFontDPIScale()

function MainFont.get(...)
	local arg = {...}
	local result = {}
	local isNull = {}
	local fontsQueue = {}
	local j = 1

	for i = 1, #arg do
		local p = Cache.get("MainFont"..arg[i])

		if not(p) then
			if AssetCache.enableSync then
				p = love.graphics.newFont(MainFont.roboto, arg[i], "normal", MainFont.dpiScale)
				p:setFallbacks(
					love.graphics.newFont(MainFont.notoSansCJK, arg[i], "normal", MainFont.dpiScale),
					love.graphics.newFont(MainFont.sarabun, arg[i], "normal", MainFont.dpiScale)
				)
				Cache.set("MainFont"..arg[i], p)
			else
				isNull[i] = j
				j = j + 1
				fontsQueue[#fontsQueue + 1] = {
					lily.newFont,
					MainFont.roboto,
					arg[i],
					"normal",
					MainFont.dpiScale
				}
				fontsQueue[#fontsQueue + 1] = {
					lily.newFont,
					MainFont.notoSansCJK,
					arg[i],
					"normal",
					MainFont.dpiScale
				}
				fontsQueue[#fontsQueue + 1] = {
					lily.newFont,
					MainFont.sarabun,
					arg[i],
					"normal",
					MainFont.dpiScale
				}
				p = false
			end
		end

		result[i] = p
	end

	if #fontsQueue > 0 then
		local multi = lily.loadMulti(fontsQueue)
		local time = love.timer.getTime()
		while multi:isComplete() == false do
			Async.wait()
			if time and love.timer.getTime() - time >= 1 then
				log.warn("font", "font loading took longer than 1 second. Is Lily okay?")
				time = nil
			end
		end

		for i = 1, #arg do
			if isNull[i] then
				local index = isNull[i]
				local f1 = multi:getValues(index * 3 - 2)
				local f2 = multi:getValues(index * 3 - 1)
				local f3 = multi:getValues(index * 3)
				f1:setFallbacks(f2, f3)
				Cache.set("MainFont"..arg[i], f1)
				result[i] = f1
			end
		end
	end

	return unpack(result)
end

return MainFont
