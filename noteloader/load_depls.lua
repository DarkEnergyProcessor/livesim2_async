-- Dark Energy Processor Live Simulator beatmap project loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine, NoteLoader = ...
local love = love
local LuaStoryboard = require("luastoryboard2")
local DEPLSLoader = NoteLoader.NoteLoaderLoader:extend("NoteLoader.DEPLSLoader", {ProjectLoader = true})
local DEPLSBeatmap = NoteLoader.NoteLoaderNoteObject:extend("NoteLoader.DEPLSBeatmap")

------------------
-- DEPLS Loader --
------------------

function DEPLSLoader.GetLoaderName()
	return "DEPLS Beatmap Project"
end

function DEPLSLoader.LoadNoteFromFilename(file)
	local this = DEPLSBeatmap()
	this.project_dir = file
	
	-- At least one DEPLS beatmap project must have "beatmap.*"
	-- file which is supported by NoteLoader2
	for _, v in ipairs(love.filesystem.getDirectoryItems(file)) do
		if v:find("^beatmap%.[^%.]+$") == 1 then
			-- Looks like we have one here. Try to load it
			-- NoteLoader will return nil if it's not supported
			this.note_object = NoteLoader.NoteLoader(file.."/"..v)
		end
		
		if this.note_object then break end
	end
	
	assert(this.note_object, "No beatmap file found")
	return this
end

--------------------------
-- DEPLS Beatmap Object --
--------------------------

function DEPLSBeatmap.GetNotesList(this)
	return this.note_object:GetNotesList()
end

function DEPLSBeatmap.GetName(this)
	if not(this.name) then
		this.name = this.note_object:GetName()
		
		-- If it's named "beatmap", then it should be taken from
		-- the filename argument. In that case, don't use that name
		if this.name == "beatmap" then
			local cover_info = this:GetCoverArt()
			
			if cover_info and cover_info.title then
				this.name = cover_info.title
			else
				this.name = NoteLoader._GetBasenameWOExt(this.project_dir)
			end
		end
	end
	
	return this.name
end

function DEPLSBeatmap.GetBeatmapTypename(this)
	if not(this.typename) then
		this.typename = "DEPLS Project: "..this.note_object:GetBeatmapTypename()
	end
	
	return this.typename
end

function DEPLSBeatmap.GetCoverArt(this)
	if not(this.cover_loaded) then
		local cover_info = this.project_dir.."/cover.txt"
		local cover_img = this.project_dir.."/cover.png"
		local cover_info_file = love.filesystem.getInfo(cover_info)
		local cover_img_file = love.filesystem.getInfo(cover_img)
		
		if cover_info_file and cover_info_file.type == "file" and cover_img_file and cover_img_file.type == "file" then
			local f = assert(love.filesystem.newFile(cover_info, "r"))
			local line = f:lines()
			
			this.cover = {}
			this.cover.image = love.graphics.newImage(cover_img)
			this.cover.title = line()
			this.cover.arrangement = line()
			
			line = nil
			f:close()
		else
			this.cover = this.note_object:GetCoverArt()
		end
		
		this.cover_loaded = true
	end
	
	return this.cover
end

function DEPLSBeatmap.GetCustomUnitInformation(this)
	if not(this.custom_unit) then
		local image_cache = {}
		this.custom_unit = {}
		this.note_object_custom_unit = this.note_object:GetCustomUnitInformation(this)
		
		for i = 1, 9 do
			local filename = this.project_dir.."/unit_pos_"..i..".txt"
			
			if love.filesystem.isFile(filename) then
				local image_name = love.filesystem.read(filename)
				
				if not(image_cache[image_name]) then
					image_cache[image_name] = love.graphics.newImage(this.project_dir.."/"..image_name)
				end
				
				this.custom_unit[i] = image_cache[image_name]
			else
				local image_name = "unit_pos_"..i..".png"
				filename = this.project_dir.."/"..image_name
				
				if not(image_cache[image_name]) and love.filesystem.isFile(filename) then
					image_cache[image_name] = love.graphics.newImage(filename)
				end
				
				this.custom_unit[i] = image_cache[image_name]
			end
			
			this.custom_unit[i] = this.custom_unit[i] or this.note_object_custom_unit[i]
		end
	end
	
	return this.custom_unit
end

function DEPLSBeatmap.GetScoreInformation(this)
	return this.note_object:GetScoreInformation()
end

function DEPLSBeatmap.HasStoryboard(this)
	return love.filesystem.isFile(this.project_dir.."/storyboard.lua") or this.note_object:HasStoryboard()
end

function DEPLSBeatmap.GetStoryboard(this)
	-- 1. Get "storyboard.lua" file
	local storyboard_file = this.project_dir.."/storyboard.lua"
	
	if love.filesystem.isFile(storyboard_file) then
		return LuaStoryboard.Load(storyboard_file)
	end
	
	return this.note_object:GetStoryboard()
end

function DEPLSBeatmap.GetBackgroundID(this)
	local bgobj = this:GetCustomBackground()
	
	if bgobj then
		return -1
	end
	
	local bgidname = this.project_dir.."/background.txt"
	if not(this.bgid_loaded) and love.filesystem.isFile(bgidname) then
		this.bgid = tonumber((love.filesystem.read(bgidname)))
		this.bgid_loaded = true
	end
	
	return this.bgid or 0
end

local supported_img_fmts = {".png", ".jpg", ".bmp"}
function DEPLSBeatmap.GetCustomBackground(this)
	if not(this.bg_loaded) then
		for _, ext in ipairs(supported_img_fmts) do
			local bgname = this.project_dir.."/background"..ext
			local bgname_info = love.filesystem.getInfo(bgname)
			
			if bgname and bgname_info.type == "file" then
				this.background = {}
				this.background[0] = love.graphics.newImage(bgname)
				
				for i = 1, 4 do
					bgname = this.project_dir.."/background-"..i..ext
					
					if love.filesystem.isFile(bgname) then
						this.background[i] = love.graphics.newImage(bgname)
					end
				end
				
				if not(this.background[1]) or not(this.background[2]) then
					AquaShine.Log("NoteLoader2/load_depls", "Non-balanced background (only contain left or right part). Removed")
					this.background[1], this.background[2] = nil, nil
				end
				
				if not(this.background[3]) or not(this.background[4]) then
					AquaShine.Log("NoteLoader2/load_depls", "Non-balanced background (only contain top or bottom part). Removed")
					this.background[3], this.background[4] = nil, nil
				end
				
				break
			end
		end
		
		this.bg_loaded = true
	end
	
	return this.background
end

local supported_video_fmts = {".ogg", ".ogv"}
if AquaShine.FFmpegExt then
	supported_video_fmts[#supported_video_fmts + 1] = ".mp4"
	supported_video_fmts[#supported_video_fmts + 1] = ".mkv"
	supported_video_fmts[#supported_video_fmts + 1] = ".avi"
	supported_video_fmts[#supported_video_fmts + 1] = ".flv"
end
function DEPLSBeatmap.GetVideoBackground(this)
	if not(this.video_loaded) then
		for _, v in ipairs(supported_video_fmts) do
			local name = this.project_dir.."/video_background"..v
			
			if love.filesystem.isFile(name) then
				local message
				this.video, message = AquaShine.LoadVideo(name)
				
				if not(this.video) then
					AquaShine.Log("NoteLoader2/load_depls", "Failed to load video: %s", message)
				end
			end
		end
		
		this.video_loaded = true
	end
	
	return this.video
end

function DEPLSBeatmap.GetScorePerTap(this)
	return this.note_object:GetScorePerTap()
end

function DEPLSBeatmap.GetStamina(this)
	return this.note_object:GetStamina()
end

function DEPLSBeatmap.GetNotesStyle(this)
	return this.note_object:GetNotesStyle()
end

function DEPLSBeatmap.GetBeatmapAudio(this)
	if not(this.audio_loaded) then
		-- 1. Load songFile.wav/ogg/mp3 file
		this.audio = AquaShine.LoadAudio(this.project_dir.."/songFile.wav")
		
		if not(this.audio) then
			-- 2. Load embedded audio from beatmap
			this.audio = this.note_object:GetBeatmapAudio()
			
			if not(this.audio) then
				-- 3. Load from audio/ folder
				this.audio = AquaShine.LoadAudio("audio/"..AquaShine.Basename(this.project_dir)..".wav")
			end
		end
		
		this.audio_loaded = true
	end
	
	return this.audio
end

function DEPLSBeatmap.GetLiveClearSound(this)
	return AquaShine.LoadAudio(this.project_dir.."/live_clear.wav") or this.note_object:GetLiveClearSound()
end

function DEPLSBeatmap.GetStarDifficultyInfo(this)
	return this.note_object:GetStarDifficultyInfo()
end

function DEPLSBeatmap.ReleaseBeatmapAudio(this)
	this.audio_loaded, this.audio = false, nil
	return this.note_object:ReleaseBeatmapAudio()
end

return DEPLSLoader
