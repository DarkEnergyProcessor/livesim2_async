-- Live Simulator: 2 main font
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local async = require("async")
local cache = require("cache")
local lily = require("lily")
local log = require("logging")
local util = require("util")

local font = {}

font.roboto = love.filesystem.newFileData("fonts/Roboto-Regular.ttf")
font.notoSansCJK = love.filesystem.newFileData("fonts/NotoSansCJKjp-Regular.woff")
font.sarabun = love.filesystem.newFileData("fonts/Sarabun-Regular.ttf")
font.dpiScale = util.getFontDPIScale()

function font.get(...)
	local arg = {...}
	local result = {}
	local isNull = {}
	local fontsQueue = {}
	local j = 1
	local inSync = not(coroutine.running())

	for i = 1, #arg do
		local p = cache.get("MainFont"..arg[i])

		if not(p) then
			if inSync then
				p = love.graphics.newFont(font.roboto, arg[i], "normal", font.dpiScale)
				p:setFallbacks(
					love.graphics.newFont(font.notoSansCJK, arg[i], "normal", font.dpiScale),
					love.graphics.newFont(font.sarabun, arg[i], "normal", font.dpiScale)
				)
				cache.set("MainFont"..arg[i], p)
			else
				isNull[i] = j
				j = j + 1
				fontsQueue[#fontsQueue + 1] = {
					lily.newFont,
					font.roboto,
					arg[i],
					"normal",
					font.dpiScale
				}
				fontsQueue[#fontsQueue + 1] = {
					lily.newFont,
					font.notoSansCJK,
					arg[i],
					"normal",
					font.dpiScale
				}
				fontsQueue[#fontsQueue + 1] = {
					lily.newFont,
					font.sarabun,
					arg[i],
					"normal",
					font.dpiScale
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
			async.wait()
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
				cache.set("MainFont"..arg[i], f1)
				result[i] = f1
			end
		end
	end

	return unpack(result)
end

return font
