-- SIF Beatmap Download
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local JSON = require("JSON")
local ls2 = require("ls2")
local md5 = require("md5hash")
local love = love
local BackgroundImage = AquaShine.LoadModule("uielement.background_image")
local SimpleButton = AquaShine.LoadModule("uielement.simple_button")
local BackNavigation = AquaShine.LoadModule("uielement.backnavigation")
local BeatmapInfoDL = AquaShine.LoadModule("uielement.beatmap_info_download")
local DLBeatmap = {}
local address = "http://r.llsif.win/"

-- Cover art downloader
DLBeatmap.DLArt = {
	Response = {},
	RespLen = 0,
	Error = function(this, msg)
		DLBeatmap.SetStatus("Error: "..msg)
		-- Retry
		DLBeatmap.DLArt.Start()
	end,
	Receive = function(this, msg)
		DLBeatmap.DLArt.RespLen = DLBeatmap.DLArt.RespLen + #msg
		DLBeatmap.DLArt.Response[#DLBeatmap.DLArt.Response + 1] = msg
		
		if this.ContentLength then
			DLBeatmap.SetStatus(string.format("Downloading Cover Art... (%d%%)", DLBeatmap.DLArt.RespLen / this.ContentLength * 100))
		end
	end,
	Done = function(this, msg)
		if this.StatusCode ~= 200 then
			DLBeatmap.SetStatus("Error: Unknown error")
			DLBeatmap.DLArt.Start()
		else
			DLBeatmap.CoverArt = love.filesystem.newFileData(table.concat(DLBeatmap.DLArt.Response), "")
			DLBeatmap.CoverArtDraw = love.graphics.newImage(DLBeatmap.CoverArt)
			DLBeatmap.DLArt.Response = {}
			DLBeatmap.DLArt.RespLen = 0
			DLBeatmap.SetStatus("Ready...")
			AquaShine.CacheTable[DLBeatmap.TrackData.icon] = DLBeatmap.CoverArt
			love.filesystem.write(DLBeatmap.GetLiveIconPath(DLBeatmap.TrackData), DLBeatmap.CoverArt)
			--[[
			DLBeatmap.CoverArtLoading:setImage(DLBeatmap.CoverArtDraw)
			DLBeatmap.DLButton:enable()
			DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
			]]
		end
	end,
	Start = function()
		if not(DLBeatmap.Trigger) then
			DLBeatmap.CoverArt = AquaShine.GetCachedData(DLBeatmap.TrackData.icon)
			
			if not(DLBeatmap.CoverArt) then
				-- Find in live_icon path first
				local cover_path = DLBeatmap.GetLiveIconPath(DLBeatmap.TrackData)
				
				if love.filesystem.getInfo(cover_path) then
					DLBeatmap.CoverArt = love.graphics.newImage(cover_path)
					AquaShine.CacheTable[DLBeatmap.TrackData.icon] = DLBeatmap.CoverArt
				else
					-- Download
					DLBeatmap.DLButton:disable()
					DLBeatmap.DLButton:setTextColor(0, 0, 0, 0)
					DLBeatmap.Download:SetCallback(DLBeatmap.DLArt)
					DLBeatmap.Download:Download(address..DLBeatmap.TrackData.icon)
					DLBeatmap.SetStatus("Downloading Cover Art...")
				end
			end
			
			if DLBeatmap.CoverArt then
				DLBeatmap.CoverArtDraw = love.graphics.newImage(DLBeatmap.CoverArt)
				DLBeatmap.CoverArtLoading:setImage(DLBeatmap.CoverArtDraw)
			end
		end
	end,
}

-- MP3 downloader
DLBeatmap.DLMP3 = {
	Response = {},
	RespLen = 0,
	Error = function(this, msg)
		DLBeatmap.SetStatus("Error: "..msg)
		DLBeatmap.DLButton:enable()
		DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
	end,
	Receive = function(this, msg)
		DLBeatmap.DLMP3.RespLen = DLBeatmap.DLMP3.RespLen + #msg
		DLBeatmap.DLMP3.Response[#DLBeatmap.DLMP3.Response + 1] = msg
		
		if this.ContentLength then
			DLBeatmap.SetStatus(string.format("Downloading Song... (%d%%)", DLBeatmap.DLMP3.RespLen / this.ContentLength * 100))
		end
	end,
	Done = function(this, msg)
		if this.StatusCode ~= 200 then
			DLBeatmap.SetStatus("Error: Unknown error")
			DLBeatmap.DLButton:enable()
			DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
		else
			DLBeatmap.MP3File = table.concat(DLBeatmap.DLMP3.Response)
			DLBeatmap.DLMP3.Response = {}
			DLBeatmap.DLMP3.RespLen = 0
			return DLBeatmap.DLBG.Start()
		end
	end,
	Start = function()
		local audiopath = DLBeatmap.GetAudioPath(DLBeatmap.TrackData)
		
		if love.filesystem.getInfo(audiopath) then
			DLBeatmap.MP3File = love.audio.newSource(audiopath, "stream")
			return DLBeatmap.DLBM.Start()
		else
			DLBeatmap.SetStatus("Downloading Song...")
			DLBeatmap.Download:SetCallback(DLBeatmap.DLMP3)
			DLBeatmap.Download:Download(address..DLBeatmap.TrackData.song)
		end
	end,
}

-- Beatmap downloader
DLBeatmap.DLBM = {
	Response = {},
	Error = function(this, msg)
		DLBeatmap.SetStatus("Error: "..msg)
		DLBeatmap.DLButton:enable()
		DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
	end,
	Receive = function(this, msg)
		DLBeatmap.DLBM.Response[#DLBeatmap.DLBM.Response + 1] = msg
	end,
	Done = function(this, msg)
		if this.StatusCode ~= 200 then
			DLBeatmap.SetStatus("Error: Unknown error")
			DLBeatmap.DLButton:enable()
			DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
		else
			local json = JSON:decode(table.concat(DLBeatmap.DLBM.Response))
			return DLBeatmap.ToLS2(json)
		end
	end,
	Start = function(diff)
		DLBeatmap.SetStatus("Downloading Beatmap...")
		DLBeatmap.Download:SetCallback(DLBeatmap.DLBM)
		DLBeatmap.Download:Download(address..DLBeatmap.TrackData.live[diff].livejson)
	end,
}

function DLBeatmap.GetLS2Name(difficulty)
	local hashedname = DLBeatmap.GetHashedName(DLBeatmap.TrackData.live[difficulty].livejson)
	return hashedname:sub(1, -#DLBeatmap.TrackData.live[difficulty].livejson - 1).."."..difficulty..".ls2"
end

function DLBeatmap.GetHashedName(path)
	local keyhash = md5("The quick brown fox jumps over the lazy dog"..path)
	local filehash = md5(path)
	local strb = {}
	local seed = tonumber(keyhash:sub(1, 8), 16) % 2147483648
	
	for i = 1, 20 do
		local chr = math.floor(seed / 33) % 32
		local sel = chr >= 16 and keyhash or filehash
		chr = (chr % 16) + 1
		strb[#strb + 1] = sel:sub(2 * chr - 1, 2 * chr)
		seed = (1103515245 * seed + 12345) % 2147483648
	end
	
	strb[#strb + 1] = path
	return table.concat(strb)
end

function DLBeatmap.GetAudioPath(track_data)
	return "audio/"..DLBeatmap.GetHashedName(AquaShine.Basename(track_data.song))
end

function DLBeatmap.GetLiveIconPath(track_data)
	return "live_icon/"..DLBeatmap.GetHashedName(AquaShine.Basename(track_data.icon))
end

function DLBeatmap.Start(arg)
	DLBeatmap.TrackData = arg[1][arg[2]]
end