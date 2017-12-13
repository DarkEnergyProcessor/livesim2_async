-- Async, callback-based download (main part)
-- Part of AquaShine loader
-- See copyright notice in AquaShine.lua

local AquaShine = ...
local class = require("30log")
local love = require("love")
local Download = class("AquaShine.Download")
local DownloadList = setmetatable({}, {__mode = "k"})

local chunk_handler = {
	RESP = function(this, data)
		this.StatusCode = data
	end,
	SIZE = function(this, data)
		this.ContentLength = data >= 0 and data or nil
	end,
	RECV = function(this, data)
		return this:recv(data)
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

function Download.DefaultErrorCallback(this, data)
	error(data)
end

function Download.Create()
	return Download()
end

function Download.init(this)
	local fmt
	
	this.thread = love.thread.newThread("AquaShine/DownloadThread.lua")
	this.channelin = love.thread.newChannel()
	this.finalizer = newproxy(true)
	this.err = Download.DefaultErrorCallback
	fmt = getmetatable(this.finalizer)
	fmt.__gc = function()
		local t = this.thread
		local cin = this.channelin
		
		cin:push("QUIT")
	end
	
	this.thread:start(this.channelin)
end

function Download.SetCallback(this, t)
	assert(not(this.downloading), "Download is in progress")
	assert(t.Error and t.Receive and t.Done, "Invalid callback")
	this.err, this.recv, this.ok = t.Error, t.Receive, t.Done
	return this
end

function Download.Download(this, url, additional_headers)
	assert(this.err and this.recv and this.ok, "No callback")
	assert(not(this.downloading), "Download is in progress")
	
	this.channelin:push(assert(url))
	this.channelin:push(additional_headers or {})
	this.downloading = true
end

function love.handlers.aqs_download(input, name, data)
	if DownloadList[input] then
		local dl = DownloadList[input]
		
		if dl.downloading then
			assert(chunk_handler[name])(dl, data)
		end
	end
end

AquaShine.Download = Download
