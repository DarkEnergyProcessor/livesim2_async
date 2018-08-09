-- Asset cache mechanism
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local async = require("async")
local cache = require("cache")
local lily = require("libs.lily")
local assetCache = {}

local function getCacheByParam(a, b)
	local s, e = a:find(":", 1, true)
	local assetName
	local cacheName
	if s then
		cacheName = a:sub(1, s-1)
		assetName = a:sub(e+1)
	else
		cacheName = a.."_"..tostring(b)
		assetName = a
	end

	local object = cache.get(cacheName)
	if object then
		return true, object
	else
		return false, cacheName, assetName
	end
end

function assetCache.loadImage(name, settings)
	local s, a, b = getCacheByParam(name, settings)

	if s then
		return a
	else
		local image
		if coroutine.running() then
			-- Run asynchronously
			local c = async.loadImage(b, settings)
			image = c:getValues()
		else
			-- Run synchronously (discouraged)
			image = love.graphics.newImage(b, settings)
		end

		cache.set(a, image)
		return image
	end
end

local function setMultipleLilyCallback(udata, index, value)
	udata.avail[udata.need[index]] = value
end

function assetCache.loadMultipleImages(images, settings)
	local available = {}
	local needed = {}
	local lilyload = {}

	for i = 1, #images do
		local s, a, b = getCacheByParam(images[i], settings)
		if s then
			available[i] = a
		else
			needed[#needed + 1] = i
			lilyload[#lilyload + 1] = {lily.newImage, b, settings}
		end
	end

	if coroutine.running() then
		-- Run asynchronously
		local multi = lily.loadMulti(lilyload)
			:setUserData({avail = available, need = needed})
			:onLoaded(setMultipleLilyCallback)
		-- Wait
		while multi:isComplete() == false do
			async.wait()
		end
	else
		-- Run synchronously
		for i = 1, #lilyload do
			local img = love.graphics.newImage(lilyload[i][2], lilyload[i][3])
			available[needed[i]] = img
		end
	end

	return available
end

function assetCache.loadFont(name, settings)
	local s, a, b = getCacheByParam(name, settings)

	if s then
		return a
	else
		local image
		if coroutine.running() then
			-- Run asynchronously
			local c = async.loadFont(b, settings)
			image = c:getValues()
		else
			-- Run synchronously (discouraged)
			image = love.graphics.newFont(b, settings)
		end

		cache.set(a, image)
		return image
	end
end

return assetCache
