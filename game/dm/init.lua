-- Download Manager
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local path = ...
local TAG = "download"
local love = require("love")
local Luaoop = require("libs.Luaoop")
local log = require("logging")
local postExit = require("post_exit")
local downloadObject = Luaoop.class("Livesim2.Download")
local download = {list = {}}

local function dummy() end
local function errhand(_, msg)
	error(msg)
end

local filename = path:gsub("%.", "/").."/thread.lua"

function downloadObject:__construct()
	assert(love.thread, "love.thread missing")
	local internal = Luaoop.class.data(self)
	internal.chan = love.thread.newChannel()
	internal.thread = love.thread.newThread(filename)
	internal.thread:start(TAG, internal.chan)
	internal.responseCallback = dummy
	internal.receiveCallback = dummy
	internal.finishCallback = dummy
	internal.errorCallback = errhand
	internal.opaque = nil
	internal.downloading = false
	internal.dead = false
	download.list[tostring(internal.chan)] = self
end

function downloadObject:release()
	local internal = Luaoop.class.data(self)
	if not(internal.dead) then
		-- drain chan
		while internal.chan:getCount() > 0 do
			internal.chan:pop()
		end
		internal.chan:push("quit://")
		download.list[internal.chan] = nil
		internal.dead = true
	end
end

local function sendRequest(chan, url, headers)
	chan:push(url)
	if headers then
		for k, v in pairs(headers) do
			chan:push(true)
			chan:push(k)
			chan:push(v)
		end
	end

	chan:push(false)
end

function downloadObject:download(url, headers)
	local internal = Luaoop.class.data(self)
	assert(internal.dead == false, "object is already released")
	assert(internal.downloading == false, "download is in progress")

	log.debugf(TAG, "downloading %s", url)
	internal.chan:performAtomic(sendRequest, url, headers)
	return self
end

function downloadObject:isDownloading()
	assert(internal.dead == false, "object is already released")
	return Luaoop.class.data(self).downloading
end

function downloadObject:setData(data)
	local internal = Luaoop.class.data(self)
	assert(internal.dead == false, "object is already released")
	assert(internal.downloading == false, "download is in progress")
	internal.opaque = data
	return self
end

function downloadObject:setResponseCallback(func)
	local internal = Luaoop.class.data(self)
	assert(internal.dead == false, "object is already released")
	assert(internal.downloading == false, "download is in progress")
	internal.responseCallback = func
	return self
end

function downloadObject:setReceiveCallback(func)
	local internal = Luaoop.class.data(self)
	assert(internal.dead == false, "object is already released")
	assert(internal.downloading == false, "download is in progress")
	internal.receiveCallback = func
	return self
end

function downloadObject:setFinishCallback(func)
	local internal = Luaoop.class.data(self)
	assert(internal.dead == false, "object is already released")
	assert(internal.downloading == false, "download is in progress")
	internal.finishCallback = func
	return self
end

function downloadObject:setErrorCallback(func)
	local internal = Luaoop.class.data(self)
	assert(internal.dead == false, "object is already released")
	assert(internal.downloading == false, "download is in progress")
	internal.errorCallback = func
	return self
end

function downloadObject:cancel()
	local internal = Luaoop.class.data(self)
	assert(internal.dead == false, "object is already released")

	if internal.downloading then
		log.debugf(TAG, "cancelling download")
		internal.chan:push("cancel")
	end
end

love.handlers[TAG] = function(input, message, a, b, c)
	local obj = download.list[tostring(input)]
	if obj then
		local internal = Luaoop.class.data(obj)

		if message == "error" then
			-- Parameters: opaque, message
			local errmsg = a:match(":%d+:%s(.+)")
			internal.downloading = false
			internal.errorCallback(internal.opaque, errmsg or a, a)
		elseif message == "response" then
			local headers = {}
			while b:getCount() > 0 do
				local k = b:pop()
				local v = b:pop()
				headers[k] = v
			end

			-- Parameters: opaque, status code, response headers[, content length]
			internal.responseCallback(internal.opaque, a, headers, c)
		elseif message == "receive" then
			-- Parameters: opaque, data
			internal.receiveCallback(internal.opaque, a)
		elseif message == "done" then
			-- Parameters: opaque
			internal.downloading = false
			internal.finishCallback(internal.opaque)
		end
	end
end

postExit.add(function()
	local threadList = {}
	for _, v in pairs(download.list) do
		local internal = Luaoop.class.data(v)
		threadList[#threadList + 1] = internal.thread
		v:release()
	end

	for _, v in ipairs(threadList) do
		while v:isRunning() do
			love.timer.sleep(0.005)
		end
	end
end)

download.new = downloadObject
setmetatable(download, {__call = function(_, ...) return downloadObject(...) end})

return download
