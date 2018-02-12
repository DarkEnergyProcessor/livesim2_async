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
local difficultyString = {"EASY", "NORMAL", "HARD", "EXPERT", "MASTER", "SIFAC"}

-- Cover art downloader
DLBeatmap.DLArt = {
	Response = {},
	RespLen = 0,
	Error = function(this, msg)
		DLBeatmap.SetStatus("Error: "..msg)
		DLBeatmap.DLArt.RespLen = 0
		table.clear(DLBeatmap.DLArt.Response)
		DLBeatmap.InfoDL:setOKButtonCallback(DLBeatmap.DLArt.Start)
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
			DLBeatmap.DLArt.RespLen = 0
			table.clear(DLBeatmap.DLArt.Response)
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
		-- Retrieve already-loaded cover art image
		DLBeatmap.CoverArtDraw = AquaShine.GetCachedData(DLBeatmap.TrackData.icon)
		
		if not(DLBeatmap.CoverArtDraw) then
			-- Find in live_icon path first
			local cover_path = DLBeatmap.GetLiveIconPath(DLBeatmap.TrackData)
			
			if love.filesystem.getInfo(cover_path) then
				-- Found one in liveicon/ path. Use that.
				DLBeatmap.CoverArtDraw = love.graphics.newImage(cover_path)
				AquaShine.CacheTable[DLBeatmap.TrackData.icon] = DLBeatmap.CoverArtDraw
				
				DLBeatmap.SetStatus("Ready...")
				DLBeatmap.InfoDL:setLiveIconImage(DLBeatmap.CoverArtDraw)
				DLBeatmap.InfoDL:setOKButtonCallback(DLBeatmap.DLMP3.Start)
			else
				-- Download
				DLBeatmap.Download:SetCallback(DLBeatmap.DLArt)
				DLBeatmap.Download:Download(address..DLBeatmap.TrackData.icon)
				DLBeatmap.InfoDL:setOKButtonCallback(nil)
				DLBeatmap.SetStatus("Downloading Cover Art...")
			end
		else
			-- Found one in cache. Use that.
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
		DLBeatmap.InfoDL:setOKButtonCallback(DLBeatmap.DLMP3.Start)
		table.clear(DLBeatmap.DLMP3.Response)
		DLBeatmap.DLMP3.RespLen = 0
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
			table.clear(DLBeatmap.DLMP3.Response)
			DLBeatmap.DLMP3.RespLen = 0
		else
			local mp3Path = DLBeatmap.GetAudioPath(DLBeatmap.TrackData)
			assert(love.filesystem.write(mp3Path, table.concat(DLBeatmap.DLMP3.Response)))
			table.clear(DLBeatmap.DLMP3.Response)
			DLBeatmap.DLMP3.RespLen = 0
			return DLBeatmap.DLBM.Start()
		end
	end,
	Start = function()
		local audiopath = DLBeatmap.GetAudioPath(DLBeatmap.TrackData)
		
		-- If there's one in audio/ path, use that.
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
		DLBeatmap.InfoDL:setOKButtonCallback(DLBeatmap.DLBM.Start)
		table.clear(DLBeatmap.DLBM.Response)
	end,
	Receive = function(this, msg)
		DLBeatmap.DLBM.Response[#DLBeatmap.DLBM.Response + 1] = msg
	end,
	Done = function(this, msg)
		if this.StatusCode ~= 200 then
			DLBeatmap.SetStatus("Error: Unknown error")
			DLBeatmap.InfoDL:setOKButtonCallback(DLBeatmap.DLBM.Start)
			table.clear(DLBeatmap.DLBM.Response)
		else
			local json = JSON:decode(table.concat(DLBeatmap.DLBM.Response))
			DLBeatmap.ToLS2(json)
			DLBeatmap.SetStatus("Ready...")
			DLBeatmap.InfoDL:setOKButtonCallback(DLBeatmap.DLBM.Start)
		end
		
		table.clear(DLBeatmap.DLBM.Response)
	end,
	Start = function()
		if #DLBeatmap.SelectedDifficulty == 0 then
			return DLBeatmap.SetStatus("Warning: Difficulty not selected!")
		end
		
		local beatmap_name = DLBeatmap.GetLS2Name(DLBeatmap.SelectedDifficulty)
		if love.filesystem.getInfo(beatmap_name) then
			AquaShine.LoadEntryPoint(":livesim", {beatmap_name, Absolute = true})
			return
		end
		DLBeatmap.SetStatus("Downloading Beatmap...")
		DLBeatmap.Download:SetCallback(DLBeatmap.DLBM)
		DLBeatmap.Download:Download(address..DLBeatmap.TrackData.live[DLBeatmap.SelectedDifficulty].livejson)
		DLBeatmap.InfoDL:setOKButtonCallback(nil)
	end,
}

function DLBeatmap.GetLS2Name(difficulty)
	local hashedname = DLBeatmap.GetHashedName(DLBeatmap.TrackData.live[difficulty].livejson)
	return "beatmap/"..hashedname:sub(1, -#DLBeatmap.TrackData.live[difficulty].livejson - 1)..".sif."..difficulty..".ls2"
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
	local cover = love.filesystem.read(DLBeatmap.GetLiveIconPath(DLBeatmap.TrackData))
	local cur = DLBeatmap.TrackData.live[DLBeatmap.SelectedDifficulty]
	local out = assert(love.filesystem.newFile(path, "w"))
	
	-- There are some -40ms offset, so decrease it.
	for i = 1, #beatmap do
		beatmap[i].timing_sec = beatmap[i].timing_sec - 0.04
	end
	
	-- New LS2 writer
	ls2.encoder.new(out, {
		name = DLBeatmap.TrackData.name,
		song_file = AquaShine.Basename(DLBeatmap.GetAudioPath(DLBeatmap.TrackData)),
		star = cur.star,
		score = cur.score,
		combo = cur.combo
	})
	-- Set background image
	:set_background_id(cur.star)
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

function DLBeatmap.SetBeatmap(diff)
	if DLBeatmap.Download:IsDownloading() then return end
	
	DLBeatmap.SelectedDifficulty = diff
		
	return DLBeatmap.InfoDL:setBeatmapIndex(diff)
end

function DLBeatmap.Start(arg)
	DLBeatmap.TrackData = arg[1][arg[2]]
	DLBeatmap.SelectedDifficulty = ""
	DLBeatmap.Download = AquaShine.GetCachedData("BeatmapDLHandle", AquaShine.Download)
	if DLBeatmap.Download:IsDownloading() then
		DLBeatmap.Download:Cancel()
	end
	
	DLBeatmap.MainNode = BackgroundImage(13)
		:addChild(BackNavigation("SIF Beatmap Info", "download_beatmap_sif.lua"))
	DLBeatmap.InfoDL = BeatmapInfoDL(DLBeatmap.TrackData)
	DLBeatmap.DiffSelect = AquaShine.Node()
	AquaShine.SetWindowTitle(DLBeatmap.TrackData.name)
	
	local index = 0
	for i = 1, #difficultyString do
		local diff = difficultyString[i]
		
		if DLBeatmap.TrackData.live[diff] then
			index = index + 1
			
			DLBeatmap.DiffSelect:addChild(
				SimpleButton(
					AquaShine.LoadImage("assets/image/ui/s_button_03.png"),
					AquaShine.LoadImage("assets/image/ui/s_button_03se.png"),
					function()
						return DLBeatmap.SetBeatmap(diff)
					end,
					0.75
				)
				:setPosition(60, index * 60 + 20)
				:initText(
					AquaShine.LoadFont("MTLmr3m.ttf", 22),
					string.format("%s (%d\226\152\134)", diff, DLBeatmap.TrackData.live[diff].star)
				)
				:setTextPosition(16, 10)
			)
		end
	end
	
	DLBeatmap.MainNode:addChild(DLBeatmap.InfoDL)
	DLBeatmap.MainNode.brother = DLBeatmap.DiffSelect
end

function DLBeatmap.Update(deltaT)
	if not(DLBeatmap.Download:IsDownloading()) and not(DLBeatmap.CoverArtDraw) then
		DLBeatmap.DLArt.Start()
	end
	
	if DLBeatmap.Download:IsDownloading() and DLBeatmap.InfoDL.okButtonCallback then
		DLBeatmap.InfoDL:setOKButtonCallback(nil)
	end
	
	return DLBeatmap.MainNode:update(deltaT)
end

function DLBeatmap.Draw()
	return DLBeatmap.MainNode:draw()
end

function DLBeatmap.MousePressed(x, y, b, t)
	return DLBeatmap.MainNode:triggerEvent("MousePressed", x, y, b, t)
end

function DLBeatmap.MouseMoved(x, y, dx, dy, t)
	return DLBeatmap.MainNode:triggerEvent("MouseMoved", x, y, dx, dy, t)
end

function DLBeatmap.MouseReleased(x, y, b, t)
	return DLBeatmap.MainNode:triggerEvent("MouseReleased", x, y, b, t)
end

function DLBeatmap.Exit()
	if DLBeatmap.Download:IsDownloading() then
		DLBeamtap.Download:Cancel()
	end
end

return DLBeatmap
