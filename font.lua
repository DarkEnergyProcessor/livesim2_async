-- Live Simulator: 2 main font
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local async = require("async")
local cache = require("cache")
local lily = require("lily")
local log = require("logging")
local font = {}

font.roboto = love.filesystem.newFileData("fonts/Roboto-Regular.ttf")
font.notoSansCJK = love.filesystem.newFileData("fonts/NotoSansCJKjp-Regular.woff")

function font.get(...)
	local arg = {...}
	local result = {}
	local isNull = {}
	local fontsLoadQueue = {}
	local j = 1
	local inSync = not(coroutine.running())

	for i = 1, #arg do
		local p = cache.get("MainFont"..arg[i])
		if not(p) then
			if inSync then
				p = love.graphics.newFont(font.roboto, arg[i])
				p:setFallbacks(love.graphics.newFont(font.notoSansCJK, arg[i]))
				cache.set("MainFont"..arg[i], p)
			else
				isNull[i] = j
				j = j + 1
				fontsLoadQueue[#fontsLoadQueue + 1] = {lily.newFont, font.roboto, arg[i]}
				fontsLoadQueue[#fontsLoadQueue + 1] = {lily.newFont, font.notoSansCJK, arg[i]}
				p = false
			end
		end

		result[i] = p
	end

	if #fontsLoadQueue > 0 then
		local multi = lily.loadMulti(fontsLoadQueue)
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
				local f1 = multi:getValues(index * 2 - 1)
				local f2 = multi:getValues(index * 2)
				f1:setFallbacks(f2)
				cache.set("MainFont"..arg[i], f1)
				result[i] = f1
			end
		end
	end

	return unpack(result)
end

return font
