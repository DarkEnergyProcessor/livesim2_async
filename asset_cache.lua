-- Asset cache mechanism
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local lily = require("lily")

local async = require("async")
local cache = require("cache")
local log = require("logging")
local util = require("util")

local assetCache = {enableSync = false}

local function getCacheByParam(a, b, nob)
	local s, e = a:find(":", 1, true)
	local assetName
	local cacheName
	if s then
		cacheName = a:sub(1, s-1)
		assetName = a:sub(e+1)
	else
		cacheName = nob and a or (a.."_"..tostring(b))
		assetName = a
	end

	local object = cache.get(cacheName)
	if object then
		log.debugf("assetCache", "got cached object of '%s'", cacheName)
		return true, object
	else
		log.debugf("assetCache", "cached object not found for '%s'", cacheName)
		return false, cacheName, assetName
	end
end

function assetCache.loadImage(name, settings, errhand)
	local s, a, b = getCacheByParam(name, settings, true)

	if s then
		return a
	else
		local image
		if assetCache.enableSync then
			-- Run synchronously (discouraged)
			assert(assetCache.enableSync, "synchronous mode is not allowed")
			image = love.graphics.newImage(b, settings)
		elseif coroutine.running() then
			-- Run asynchronously
			local c = async.loadImage(b, settings, errhand)
			image = c:getValues()
		else
			error("synchronous mode is not allowed", 2)
		end

		cache.set(a, image)
		return image
	end
end

local function setMultipleLilyCallback(udata, index, value)
	cache.set(udata.cache[index], value)
	udata.avail[udata.need[index]] = value
end

function assetCache.loadMultipleImages(images, settings)
	local available = {}
	local needed = {}
	local cachenames = {}
	local lilyload = {}

	for i = 1, #images do
		local s, a, b = getCacheByParam(images[i], settings, true)
		if s then
			available[i] = a
		else
			needed[#needed + 1] = i
			cachenames[#cachenames + 1] = a
			lilyload[#lilyload + 1] = {lily.newImage, b, settings}
		end
	end

	if #needed > 0 then
		if assetCache.enableSync then
			-- Run synchronously
			for i = 1, #lilyload do
				local img = love.graphics.newImage(lilyload[i][2], lilyload[i][3])
				available[needed[i]] = img
				cache.set(cachenames[i], img)
			end
		elseif coroutine.running() then
			-- Run asynchronously
			local multi = lily.loadMulti(lilyload)
				:setUserData({avail = available, need = needed, cache = cachenames})
				:onLoaded(setMultipleLilyCallback)
			-- Wait
			while multi:isComplete() == false do
				async.wait()
			end
		else
			error("synchronous mode is not allowed", 2)
		end
	end

	return available
end

function assetCache.loadFont(name, settings, hinting, dpi)
	hinting = hinting or "normal"
	dpi = dpi or util.getFontDPIScale()
	local s, a, b = getCacheByParam(name, tostring(settings)..hinting..dpi)

	if s then
		return a
	else
		local image
		if assetCache.enableSync then
			-- Run synchronously (discouraged)
			assert(assetCache.enableSync, "synchronous mode is not allowed")
			image = love.graphics.newFont(b, settings, hinting, util.getFontDPIScale())
		elseif coroutine.running() then
			-- Run asynchronously
			local c = async.loadFont(b, settings, hinting, util.getFontDPIScale())
			image = c:getValues()
		else
			error("synchronous mode is not allowed", 2)
		end

		cache.set(a, image)
		return image
	end
end

function assetCache.loadMultipleFonts(fonts)
	local available = {}
	local needed = {}
	local cachenames = {}
	local lilyload = {}

	for i = 1, #fonts do
		local dpi = fonts[i][4] or util.getFontDPIScale()
		local hint = fonts[i][3] or "normal"
		local s, a, b = getCacheByParam(fonts[i][1], tostring(fonts[i][2])..hint..dpi)

		if s then
			available[i] = a
		else
			needed[#needed + 1] = i
			cachenames[#cachenames + 1] = a
			lilyload[#lilyload + 1] = {lily.newFont, b, fonts[i][2], hint, dpi}
		end
	end

	if assetCache.enableSync then
		-- Run synchronously
		assert(assetCache.enableSync, "synchronous mode is not allowed")
		for i = 1, #lilyload do
			local img = love.graphics.newFont(lilyload[i][2], lilyload[i][3], lilyload[i][4], lilyload[i][5])
			available[needed[i]] = img
			cache.set(cachenames[i], img)
		end
	elseif coroutine.running() then
		-- Run asynchronously
		local multi = lily.loadMulti(lilyload)
			:setUserData({avail = available, need = needed, cache = cachenames})
			:onLoaded(setMultipleLilyCallback)
		-- Wait
		local time = love.timer.getTime()
		while multi:isComplete() == false do
			async.wait()
			if time and love.timer.getTime() - time >= 1 then
				log.warn("assetCache", "loadMultipleFonts took longer than 1 second. Is Lily okay?")
				time = nil
			end
		end
	else
		error("synchronous mode is not allowed", 2)
	end

	return available
end

return assetCache
