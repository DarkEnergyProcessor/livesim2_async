-- LLP beatmap download
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
local CoverArtLoading = AquaShine.LoadModule("uielement.cover_art_loading")
local NoteLoader = AquaShine.LoadModule("note_loader2")
local JSONLoader = NoteLoader.GetLoader("JSON-based Beatmap Loader")
local DLBeatmap = {}

DLBeatmap.DLArt = {
	Response = {},
	RespLen = 0,
	Error = function(this, msg)
		DLBeatmap.Status = "Error: "..msg
		-- Retry
		DLBeatmap.DLArt.Start()
	end,
	Receive = function(this, msg)
		DLBeatmap.DLArt.RespLen = DLBeatmap.DLArt.RespLen + #msg
		DLBeatmap.DLArt.Response[#DLBeatmap.DLArt.Response + 1] = msg
		
		if this.ContentLength then
			DLBeatmap.Status = string.format("Downloading Cover Art... (%d%%)", DLBeatmap.DLArt.RespLen / this.ContentLength * 100)
		end
	end,
	Done = function(this, msg)
		if this.StatusCode ~= 200 then
			DLBeatmap.Status = "Error: "..(json and json.message or "Unknown error")
			DLBeatmap.DLArt.Start()
		else
			DLBeatmap.LLPCoverArt = love.filesystem.newFileData(table.concat(DLBeatmap.DLArt.Response), DLBeatmap.LLPData.live_id)
			DLBeatmap.LLPCoverArtDraw = love.graphics.newImage(DLBeatmap.LLPCoverArt)
			DLBeatmap.DLArt.Response = {}
			DLBeatmap.DLArt.RespLen = 0
			DLBeatmap.Status = "Ready..."
			AquaShine.CacheTable[DLBeatmap.LLPData.live_id] = DLBeatmap.LLPCoverArt
			DLBeatmap.CoverArtLoading:setImage(DLBeatmap.LLPCoverArtDraw)
			DLBeatmap.DLButton:enable()
			DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
		end
	end,
	Start = function()
		if not(DLBeatmap.Trigger) then
			DLBeatmap.LLPCoverArt = AquaShine.GetCachedData(DLBeatmap.LLPData.live_id)
			
			if not(DLBeatmap.LLPCoverArt) then
				DLBeatmap.DLButton:disable()
				DLBeatmap.DLButton:setTextColor(0, 0, 0, 0)
				DLBeatmap.Download:SetCallback(DLBeatmap.DLArt)
				DLBeatmap.Download:Download("https://m.tianyi9.com/upload/"..DLBeatmap.LLPData.cover_path)
				DLBeatmap.Status = "Downloading Cover Art..."
			else
				DLBeatmap.LLPCoverArtDraw = love.graphics.newImage(DLBeatmap.LLPCoverArt)
				DLBeatmap.CoverArtLoading:setImage(DLBeatmap.LLPCoverArtDraw)
			end
		end
	end,
}

DLBeatmap.DLMP3 = {
	Response = {},
	RespLen = 0,
	Error = function(this, msg)
		DLBeatmap.Status = "Error: "..msg
		DLBeatmap.DLButton:enable()
		DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
	end,
	Receive = function(this, msg)
		DLBeatmap.DLMP3.RespLen = DLBeatmap.DLMP3.RespLen + #msg
		DLBeatmap.DLMP3.Response[#DLBeatmap.DLMP3.Response + 1] = msg
		
		if this.ContentLength then
			DLBeatmap.Status = string.format("Downloading Song... (%d%%)", DLBeatmap.DLMP3.RespLen / this.ContentLength * 100)
		end
	end,
	Done = function(this, msg)
		if this.StatusCode ~= 200 then
			DLBeatmap.Status = "Error: "..(json and json.message or "Unknown error")
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
		if not(DLBeatmap.MP3File) then
			DLBeatmap.Status = "Downloading Song..."
			DLBeatmap.Download:SetCallback(DLBeatmap.DLMP3)
			DLBeatmap.Download:Download("https://m.tianyi9.com/upload/"..DLBeatmap.LLPData.bgm_path)
		else
			return DLBeatmap.DLBG.Start()
		end
	end,
}

DLBeatmap.DLBG = {
	Response = {},
	RespLen = 0,
	Error = function(this, msg)
		DLBeatmap.Status = "Error: "..msg
		DLBeatmap.DLButton:enable()
		DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
	end,
	Receive = function(this, msg)
		DLBeatmap.DLBG.RespLen = DLBeatmap.DLBG.RespLen + #msg
		DLBeatmap.DLBG.Response[#DLBeatmap.DLBG.Response + 1] = msg
		
		if this.ContentLength then
			DLBeatmap.Status = string.format("Downloading Background... (%d%%)", DLBeatmap.DLBG.RespLen / this.ContentLength * 100)
		end
	end,
	Done = function(this, msg)
		
		if this.StatusCode ~= 200 then
			DLBeatmap.Status = "Error: "..(json and json.message or "Unknown error")
			DLBeatmap.DLButton:enable()
			DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
		else
			DLBeatmap.LLPBackground = table.concat(DLBeatmap.DLBG.Response)
			DLBeatmap.DLBG.Response = {}
			DLBeatmap.DLBG.RespLen = 0
			return DLBeatmap.DLBM.Start()
		end
	end,
	Start = function()
		if not(DLBeatmap.LLPBackground) then
			DLBeatmap.Status = "Downloading Background..."
			DLBeatmap.Download:SetCallback(DLBeatmap.DLBG)
			DLBeatmap.Download:Download("https://m.tianyi9.com/upload/"..DLBeatmap.LLPData.bgimg_path)
		else
			return DLBeatmap.DLBM.Start()
		end
	end,
}

DLBeatmap.DLBM = {
	Response = {},
	Error = function(this, msg)
		DLBeatmap.Status = "Error: "..msg
		DLBeatmap.DLButton:enable()
		DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
	end,
	Receive = function(this, msg)
		DLBeatmap.DLBM.Response[#DLBeatmap.DLBM.Response + 1] = msg
	end,
	Done = function(this, msg)
		if this.StatusCode ~= 200 then
			DLBeatmap.Status = "Error: "..(json and json.message or "Unknown error")
			DLBeatmap.DLButton:enable()
			DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
		else
			local json = JSON:decode(table.concat(DLBeatmap.DLBM.Response))
			return DLBeatmap.ToLS2(json)
		end
	end,
	Start = function()
		DLBeatmap.Status = "Downloading Beatmap..."
		DLBeatmap.Download:SetCallback(DLBeatmap.DLBM)
		DLBeatmap.Download:Download("https://m.tianyi9.com/upload/"..DLBeatmap.LLPData.map_path)
	end,
}

local ls2name
function DLBeatmap.GetLS2Name()
	if not(ls2name) then
		ls2name = DLBeatmap.LLPData.live_name..".llp"
		ls2name = DLBeatmap.LLPData.live_id..".llp."..md5(ls2name)..".ls2"
	end
	return ls2name
end

function DLBeatmap.ToLS2(beatmap)
	local name = "beatmap/"..DLBeatmap.GetLS2Name()
	local fileh = love.filesystem.newFile(name, "w")
	local notes = JSONLoader.LoadNoteFromTable(beatmap, DLBeatmap.LLPData.live_id):GetNotesList()
	
	local score_data = {nil, nil, nil, 0}
	local combo_data = #notes
	for i = 1, #notes do
		score_data[4] = score_data[4] + (notes[i].effect >= 10 and 370 or 739)
	end
	score_data[1] = math.floor(score_data[4] * 0.285521 + 0.5)
	score_data[2] = math.floor(score_data[4] * 0.71448 + 0.5)
	score_data[3] = math.floor(score_data[4] * 0.856563 + 0.5)
	
	-- New LS2 writer
	ls2.encoder.new(fileh, {
		name = DLBeatmap.LLPData.live_name,
		star = DLBeatmap.LLPData.level,
		score = score_data,
		combo = {math.ceil(combo_data * 0.3), math.ceil(combo_data * 0.5), math.ceil(combo_data * 0.7), combo_data}
	})
	-- Add beatmap
	:add_beatmap(notes)
	-- Add audio
	:add_audio("mp3", DLBeatmap.MP3File)
	-- Add background image
	:add_custom_background(DLBeatmap.LLPBackground, 0)
	-- Add cover art
	:add_cover_art({
		image = DLBeatmap.LLPCoverArt:getString(),
		title = DLBeatmap.LLPData.live_name,
		arrangement = "Uploader: "..DLBeatmap.LLPData.upload_user.username.."  Live ID: "..DLBeatmap.LLPData.live_id
	})
	-- Write to output
	:write()
	fileh:close()
	
	DLBeatmap.Status = "Done"
	DLBeatmap.Beatmap = NoteLoader.NoteLoader("beatmap/"..DLBeatmap.GetLS2Name())
	DLBeatmap.DLButton:enable()
	DLBeatmap.DLButton:setText("Play")
	DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
end

function DLBeatmap.GetLLPDestination()
	if AquaShine.Download.HasHTTPS() then
		return "download_beatmap_llp.lua"
	else
		return "external/download_beatmap_llp.lua"
	end
end

function DLBeatmap.Start(arg)
	local dummycanvas = love.graphics.newCanvas(144, 58)
	dummycanvas:renderTo(function() love.graphics.clear(0, 0, 0, 0) end)
	
	DLBeatmap.Download = AquaShine.GetCachedData("BeatmapDLHandle", AquaShine.Download)
	DLBeatmap.LiveIDFont = AquaShine.LoadFont("MTLmr3m.ttf", 24)
	DLBeatmap.LLPData = assert(arg.content)
	DLBeatmap.Status = ""
	DLBeatmap.DLButton = SimpleButton(dummycanvas, dummycanvas, function()
		if DLBeatmap.Beatmap then
			AquaShine.LoadEntryPoint(":livesim_main", {Beatmap = DLBeatmap.Beatmap})
		else
			DLBeatmap.DLButton:disable()
			DLBeatmap.DLButton:setTextColor(0, 0, 0, 0)
		end
	end)
		:setDisabledImage(dummycanvas)
		:setPosition(690, 172)
		:initText(DLBeatmap.LiveIDFont, "Download")
		:setTextPosition(22, 12)
	AquaShine.SetWindowTitle(DLBeatmap.LLPData.live_name)
	
	if DLBeatmap.Download:IsDownloading() then
		DLBeatmap.Download:Cancel()
	end
	
	local tmpstr = {}
	tmpstr[#tmpstr + 1] = string.format("Song Name    : %s", DLBeatmap.LLPData.live_name)
	tmpstr[#tmpstr + 1] = string.format("Uploader     : %s", DLBeatmap.LLPData.upload_user.username)
	tmpstr[#tmpstr + 1] = string.format("Difficulty   : %d\226\152\134", DLBeatmap.LLPData.level)
	tmpstr[#tmpstr + 1] = string.format("Likes        : %d", DLBeatmap.LLPData.like_count)
	tmpstr[#tmpstr + 1] = string.format("Live ID      : %s", DLBeatmap.LLPData.live_id)
	tmpstr[#tmpstr + 1] = ""
	tmpstr[#tmpstr + 1] = DLBeatmap.LLPData.live_info
	DLBeatmap.LLPInfoString = table.concat(tmpstr, "\n")
	
	DLBeatmap.CoverArtLoading = CoverArtLoading()
		:setPosition(686, 237)
	DLBeatmap.MainNode = BackgroundImage(15)
		:addChild(BackNavigation("LLP Beatmap Info", DLBeatmap.GetLLPDestination()))
		:addChild(DLBeatmap.CoverArtLoading)
		:addChild(DLBeatmap.DLButton)
	
	local bminfo = love.filesystem.getInfo("beatmap/"..DLBeatmap.GetLS2Name())
	if bminfo then
		DLBeatmap.Beatmap = NoteLoader.NoteLoader("beatmap/"..DLBeatmap.GetLS2Name())
		local cover = DLBeatmap.Beatmap:GetCoverArt()
		DLBeatmap.LLPCoverArtDraw = cover.image
		DLBeatmap.DLTrigger = true
		
		DLBeatmap.CoverArtLoading:setImage(cover.image)
		--DLBeatmap.DLButton:disable()
		--DLBeatmap.DLButton:setTextColor(0, 0, 0, 0)
		DLBeatmap.DLButton:setText("Play")
	end
end

function DLBeatmap.Update(deltaT)
	if not(DLBeatmap.Download:IsDownloading()) and not(DLBeatmap.LLPCoverArtDraw) then
		DLBeatmap.DLArt.Start()
	end
	
	if not(DLBeatmap.DLButton:isEnabled()) and DLBeatmap.LLPCoverArtDraw and not(DLBeatmap.DLTrigger) then
		print("DL press")
		DLBeatmap.DLTrigger = true
		DLBeatmap.DLMP3.Start()
	end
	
	DLBeatmap.MainNode:update(deltaT)
end

function DLBeatmap.Draw()
	DLBeatmap.MainNode:draw()
	love.graphics.setFont(DLBeatmap.LiveIDFont)
	love.graphics.print("HTTPS mode", 420, 10)
	AquaShine.SetScissor(86, 124, 782, 292)
	love.graphics.printf(DLBeatmap.LLPInfoString, 102, 136, 570)
	love.graphics.print(DLBeatmap.Status, 102, 136+120)
	AquaShine.SetScissor()
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
