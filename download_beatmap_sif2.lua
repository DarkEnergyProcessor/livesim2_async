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
			DLBeatmap.InfoDL:setOKButtonCallback(DLBeatmap.DLArt.Start)
		else
			local coverArt = love.filesystem.newFileData(table.concat(DLBeatmap.DLArt.Response), "")
			DLBeatmap.CoverArtDraw = love.graphics.newImage(coverArt)
			DLBeatmap.DLArt.Response = {}
			DLBeatmap.DLArt.RespLen = 0
			DLBeatmap.SetStatus("Ready...")
			AquaShine.CacheTable[DLBeatmap.TrackData.icon] = DLBeatmap.CoverArtDraw
			love.filesystem.write(DLBeatmap.GetLiveIconPath(DLBeatmap.TrackData), coverArt)
			DLBeatmap.InfoDL:setLiveIconImage(DLBeatmap.CoverArtDraw)
			DLBeatmap.InfoDL:setOKButtonCallback(DLBeatmap.DLMP3.Start)
		end
	end,
	Start = function()
		DLBeatmap.CoverArtDraw = AquaShine.GetCachedData(DLBeatmap.TrackData.icon)
		
		if not(DLBeatmap.CoverArtDraw) then
			-- Find in live_icon path first
			local cover_path = DLBeatmap.GetLiveIconPath(DLBeatmap.TrackData)
			
			if love.filesystem.getInfo(cover_path) then
				DLBeatmap.CoverArtDraw = love.graphics.newImage(cover_path)
				AquaShine.CacheTable[DLBeatmap.TrackData.icon] = DLBeatmap.CoverArt
				DLBeatmap.InfoDL:setLiveIconImage(DLBeatmap.CoverArtDraw)
			else
				-- Download
				DLBeatmap.Download:SetCallback(DLBeatmap.DLArt)
				DLBeatmap.Download:Download(address..DLBeatmap.TrackData.icon)
				DLBeatmap.InfoDL:setOKButtonCallback(nil)
				DLBeatmap.SetStatus("Downloading Cover Art...")
			end
		else
			DLBeatmap.SetStatus("Ready...")
			DLBeatmap.InfoDL:setLiveIconImage(DLBeatmap.CoverArtDraw)
			DLBeatmap.InfoDL:setOKButtonCallback(DLBeatmap.DLMP3.Start)
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
			DLBeatmap.InfoDL:setOKButtonCallback(DLBeatmap.DLMP3.Start)
		else
			local mp3Path = DLBeatmap.GetAudioPath(DLBeatmap.TrackData)
			assert(love.filesystem.write(mp3Path, table.concat(DLBeatmap.DLMP3.Response)))
			DLBeatmap.DLMP3.Response = {}
			DLBeatmap.DLMP3.RespLen = 0
			return DLBeatmap.DLBG.Start()
		end
	end,
	Start = function()
		local audiopath = DLBeatmap.GetAudioPath(DLBeatmap.TrackData)
		
		if love.filesystem.getInfo(audiopath) then
			--DLBeatmap.MP3File = love.audio.newSource(audiopath, "stream")
			return DLBeatmap.DLBM.Start()
		else
			DLBeatmap.SetStatus("Downloading Song...")
			DLBeatmap.Download:SetCallback(DLBeatmap.DLMP3)
			DLBeatmap.Download:Download(address..DLBeatmap.TrackData.song)
			DLBeatmap.InfoDL:setOKButtonCallback(nil)
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
			DLBeatmap.ToLS2(json)
			DLBeatmap.SetStatus("Play!")
			DLBeatmap.InfoDL:setOKButtonCallback(DLBeatmap.StartPlay)
		end
	end,
	Start = function()
		DLBeatmap.SetStatus("Downloading Beatmap...")
		DLBeatmap.Download:SetCallback(DLBeatmap.DLBM)
		DLBeatmap.Download:Download(address..DLBeatmap.TrackData.live[DLBeatmap.SelectedDifficulty].livejson)
		DLBeatmap.InfoDL:setOKButtonCallback(nil)
	end,
}

function DLBeatmap.GetLS2Name(difficulty)
	local hashedname = DLBeatmap.GetHashedName(DLBeatmap.TrackData.live[difficulty].livejson)
	return "beatmap/"..hashedname:sub(1, -#DLBeatmap.TrackData.live[difficulty].livejson - 1).."."..difficulty..".ls2"
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
		seed = (214013 * seed + 2531011) % 2147483648
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

function DLBeatmap.SetStatus(msg)
	return DLBeatmap.InfoDL:setStatus(msg)
end

function DLBeatmap.ToLS2(beatmap)
	local path = DLBeatmap.GetLS2Name(DLBeatmap.SelectedDifficulty)
	local cover = love.filesystem.read(DLBeatmap.GetLiveIconPath(DLbeatmap.TrackData))
	local cur = DLBeatmap.TrackData.live[DLBeatmap.SelectedDifficulty]
	local out = assert(love.filesystem.newFile(path, "w"))
	ls2.encoder.new(out, {
		name = DLBeatmap.TrackData.name,
		song_file = AquaShine.Basename(DLBeatmap.GetAudioPath(DLBeatmap.TrackData)),
		star = cur.star,
		score = cur.score,
		combo = cur.combo
	})
	-- Add beatmap
	:add_beatmap(beatmap)
	-- Add cover art
	:add_cover_art({
		image = cover,
		title = DLBeatmap.TrackData.name
	})
	-- Write
	:write()
end

function DLBeatmap.Start(arg)
	DLBeatmap.TrackData = arg[1][arg[2]]
	DLBeatmap.MainNode = BackgroundImage(13)
	DLBeatmap.InfoDL = BeatmapInfoDL(DLBeatmap.TrackData)
end
