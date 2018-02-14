-- Async, callback-based download (main part)
-- Part of AquaShine loader
-- See copyright notice in AquaShine.lua

local AquaShine = ...
local class = AquaShine.Class
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
		this.downloading = false
		DownloadList[this.channelin] = nil
		this:ok()
		this.StatusCode = nil
		this.ContentLength = nil
		this.HeaderData = nil
	end,
	["ERR "] = function(this, data)
		this.downloading = false
		DownloadList[this.channelin] = nil
		this:err(data)
		this.StatusCode = nil
		this.ContentLength = nil
		this.HeaderData = nil
	end
}

local function createFinalizer(this)
	local x = newproxy(true)
	local y = getmetatable(x)
	local gccall = false
	y.__gc = function()
		if gccall then return end
		
		local t = this.thread
		local cin = this.channelin
		DownloadList[cin] = nil
		cin:push("QUIT")
	end
	y.__call = function()
		gccall = true
		return y.__gc()
	end
	
	return x
end

local function reInitDownload(this)
	this.thread = love.thread.newThread("AquaShine/DownloadThread.lua")
	this.channelin = assert(love.thread.newChannel())
	this.finalizer = createFinalizer(this)
	
	this.thread:start(this.channelin)
end

function Download.DefaultErrorCallback(this, data)
	error(data)
end

function Download.Create()
	return Download()
end

function Download.init(this)
	this.err = Download.DefaultErrorCallback
	return reInitDownload(this)
end

function Download.SetCallback(this, t)
	assert(not(this.downloading), "Download is in progress")
	assert(t.Error and t.Receive and t.Done, "Invalid callback")
	this.err, this.recv, this.ok = t.Error, t.Receive, t.Done
	return this
end

function Download.SetErrorCallback(this, err)
	assert(not(this.downloading), "Download is in progress")
	this.err = assert(err, "Invalid callback")
	return this
end

function Download.SetReceiveCallback(this, recv)
	assert(not(this.downloading), "Download is in progress")
	this.recv = assert(recv, "Invalid callback")
	return this
end

function Download.SetDoneCallback(this, done)
	assert(not(this.downloading), "Download is in progress")
	this.ok = done
	return this
end

function Download.Download(this, url, additional_headers)
	assert(this.err and this.recv and this.ok, "No callback")
	assert(not(this.downloading), "Download is in progress")
	
	this.channelin:push(assert(url))
	this.channelin:push(additional_headers or {})
	this.downloading = true
	DownloadList[this.channelin] = this
end

function Download.Cancel(this)
	assert(this.downloading, "No download in progress")
	this.finalizer()
	return reInitDownload(this)
end

function Download.IsDownloading(this)
	return this.downloading
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
