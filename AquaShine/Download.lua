-- Async, callback-based download (main part)
-- Part of Live Simulator: 2
-- See copyright notice in AquaShine.lua

local AquaShine = ...
local class = require("30log")
local love = require("love")
local Download = class("AquaShine.Download")

local chunk_handler = {
	RESP = function(this, data)
		this.StatusCode = data
	end,
	SIZE = function(this, data)
		this.ContentLength = data >= 0 and data or nil
	end,
	RECV = function(this, data)
		this:recv(data)
	end,
	HEDR = function(this, headers)
		this.HeaderData = headers
	end,
	DONE = function(this, data)
		this:ok()
		this.downloading = false
		this.StatusCode = nil
		this.ContentLength = nil
		this.HeaderData = nil
	end,
	["ERR "] = function(this, data)
		this:err(data)
		this.downloading = false
		this.StatusCode = nil
		this.ContentLength = nil
		this.HeaderData = nil
	end
}

function Download.Create()
	return Download()
end

function Download.init(this)
	local fmt
	
	this.thread = love.thread.newThread("AquaShine/DownloadThread.lua")
	this.channelin = love.thread.newChannel()
	this.channelout = love.thread.newChannel()
	this.finalizer = newproxy(true)
	fmt = getmetatable(this.finalizer)
	fmt.__gc = function()
		local t = this.thread
		local cin, cout = this.channelin, this.channelout
		
		cin:push("QUIT")
	end
	
	this.thread:start(this.channelin, this.channelout)
end

function Download.SetCallback(this, t)
	assert(t.Error and t.Receive and t.Done, "Invalid callback")
	this.err, this.recv, this.ok = t.Error, t.Receive, t.Done
	return this
end

function Download.Update(this)
	while this.downloading and math.floor(this.channelout:getCount() * 0.5) > 0 do
		local chunk = this.channelout:pop()
		local data = this.channelout:pop()
		
		assert(chunk_handler[chunk])(this, data)
	end
end

function Download.Download(this, url, additional_headers)
	assert(not(this.downloading), "Download is in progress")
	
	this.channelin:push(assert(url))
	this.channelin:push(additional_headers or {})
	this.downloading = true
end

AquaShine.Download = Download
