-- Live Simulator: 2 binary beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine, NoteLoader = ...
local love = love
local ls2 = require("ls2")
local LuaStoryboard = require("luastoryboard2")
ls2.has_ffmpegext = AquaShine.FFmpegExt

local LS2Loader = NoteLoader.NoteLoaderLoader:extend("NoteLoader.LS2Loader", {ProjectLoader = false})
local LS2Beatmap = NoteLoader.NoteLoaderNoteObject:extend("NoteLoader.LS2Beatmap")

------------------------
-- LS2 Beatmap Loader --
------------------------

function LS2Loader.GetLoaderName()
	return "LS2 Loader"
end

function LS2Loader.LoadNoteFromFilename(f, file)
	local this = LS2Beatmap()
	
	this.name = NoteLoader._GetBasenameWOExt(file)
	this.ls2 = ls2.loadstream(f)
	this.file = f
	this.file_count = 0

	return this
end

------------------------
-- LS2 Beatmap Object --
------------------------

local function _wrapFileHandle(func)
	return function(this, ...)
		if this.file_count == 0 then
			assert(this.file:open("r"))
			this.file_count = 1
		else
			this.file_count = this.file_count + 1
		end
		
		local r1, r2, r3, r4 = func(this, select(1, ...))
		
		this.file_count = this.file_count - 1
		if this.file_count == 0 then
			this.file:close()
		end
		
		return r1, r2, r3, r4
	end
end

LS2Beatmap.GetNotesList = _wrapFileHandle(function(this)
	if not(this.notes_list) then
		local nlist = {}
		
		-- Select and process BMPM and BMPT sections
		-- We don't have to check if notes data were
		-- empty or not, since it's already handled when
		-- loading the beatmap file.
		if this.ls2.sections.BMPM then
			for _, v in ipairs(this.ls2.sections.BMPM) do
				local notes_data
				
				this.file:seek(v)
				notes_data = ls2.section_processor.BMPM[1](this.file, this.ls2.version_2)
				
				for _, n in ipairs(notes_data) do
					nlist[#nlist + 1] = n
				end
			end
		end
		
		if this.ls2.sections.BMPT then
			for _, v in ipairs(this.ls2.sections.BMPT) do
				local notes_data
				
				this.file:seek(v)
				notes_data = ls2.section_processor.BMPT[1](this.file, this.ls2.version_2)
				
				for _, n in ipairs(notes_data) do
					nlist[#nlist + 1] = n
				end
			end
		end
		
		
		table.sort(nlist, function(a, b) return a.timing_sec < b.timing_sec end)
		this.notes_list = nlist
	end
	
	return this.notes_list
end)

LS2Beatmap._GetMetadata = _wrapFileHandle(function(this)
	if not(this.metadata) then
		if this.ls2.sections.MTDT then
			this.file:seek(this.ls2.sections.MTDT[1])
			this.metadata = ls2.section_processor.MTDT[1](this.file, this.ls2.version_2)
		else
			this.metadata = {}
		end
	end
	
	return this.metadata
end)

LS2Beatmap.GetName = _wrapFileHandle(function(this)
	-- Get from metadata (v2.0)
	local meta = this:_GetMetadata()
	if meta.name then return meta.name end
	
	-- From metadata not found. Find in cover art
	local cover = this:GetCoverArt()
	if cover and cover.title then
		return cover.title
	end
	
	-- Not found too? Okay, fallback to basename without extension
	return this.name
end)

function LS2Beatmap.GetBeatmapTypename(this)
	return string.format("Live Simulator: 2 Beatmap (v%s)", this.ls2.version_2 and "2.0" or "1.x")
end

LS2Beatmap.GetCoverArt = _wrapFileHandle(function(this)
	if not(this.cover_art_loaded) then
		if this.ls2.sections.COVR then
			-- Cover available
			this.file:seek(this.ls2.sections.COVR[1])
			this.cover_art = ls2.section_processor.COVR[1](this.file, this.ls2.version_2)
			this.cover_art.image = love.graphics.newImage(love.filesystem.newFileData(this.cover_art.image, ""), {mipmaps = true})
		end
		
		this.cover_art_loaded = true
	end
	
	return this.cover_art
end)

LS2Beatmap.GetCustomUnitInformation = _wrapFileHandle(function(this)
	-- Get all UIMG information
	if not(this.unit_info) then
		local unit_list = {}
		
		if this.ls2.sections.UNIT and this.ls2.sections.UIMG then
			local uimgs = {}
			
			for _, v in ipairs(this.ls2.sections.UIMG) do
				local idx, img
				this.file:seek(v)
				
				idx, img = ls2.section_processor.UIMG[1](this.file, this.ls2.version_2)
				uimgs[idx] = love.graphics.newImage(love.filesystem.newFileData(img, ""))
			end
			
			for _, v in ipairs(this.ls2.sections.UNIT) do
				local idx
				this.file:seek(v)
				
				for _, u in ipairs(ls2.section_processor.UNIT[1](this.file, this.ls2.version_2)) do
					unit_list[u[1]] = uimgs[u[2]]
				end
			end
		end
		
		this.unit_info = unit_list
	end
	
	return this.unit_info
end)

LS2Beatmap.GetScoreInformation = _wrapFileHandle(function(this)
	if this.ls2.version_2 then
		-- Live Simulator: 2 beatmap v2.0
		-- Get from metadata instead from SCRI
		return this:_GetMetadata().score
	elseif not(this.score_loaded) and this.ls2.sections.SCRI then
		for _, v in ipairs(this.ls2.sections.SCRI) do
			this.file:seek(v)
			this.score = ls2.section_processor.SCRI[1](this.file)
		end
		
		this.score_loaded = true
	end
	
	return this.score
end)

function LS2Beatmap.GetComboInformation(this)
	-- Combo information only supported in v2.0 beatmap format
	if this.ls2.version_2 then
		return this:_GetMetadata().combo
	end
	
	return nil
end

function LS2Beatmap.HasStoryboard(this)
	return not(not(this.ls2.sections.SRYL))
end

LS2Beatmap.GetStoryboard = _wrapFileHandle(function(this)
	if this.ls2.sections.SRYL then
		this.file:seek(this.ls2.sections.SRYL[1])
		local story_data = ls2.section_processor.SRYL[1](this.file)
		
		-- Attempt to decompress storyboard script
		do
			local status, new_story = pcall(love.data.decompress, "string", "zlib", story_data)
			
			if status then
				story_data = new_story
			end
		end
		
		local story = LuaStoryboard.LoadString(story_data)
		
		-- Enumerate all DATA
		if this.ls2.sections.DATA then
			local datalist = {}
			
			for _, v in ipairs(this.ls2.sections.DATA) do
				this.file:seek(v)
				local name, cont = ls2.section_processor.DATA[1](this.file)
				
				datalist[name] = love.filesystem.newFileData(cont, name)
			end
			
			story:SetAdditionalFiles(datalist)
		end
		
		return story
	end
	
	return nil
end)

function LS2Beatmap.GetBackgroundID(this)
	if this.ls2.sections.BIMG then
		return -1
	else
		return this.ls2.background_id
	end
end

LS2Beatmap.GetCustomBackground = _wrapFileHandle(function(this)
	if not(this.background_loaded) and this.ls2.sections.BIMG then
		local backgrounds = {}
		
		for _, v in ipairs(this.ls2.sections.BIMG) do
			this.file:seek(v)
			local idx, img = ls2.section_processor.BIMG[1](this.file, this.ls2.version_2)
			
			backgrounds[idx] = love.graphics.newImage(love.filesystem.newFileData(img, ""))
		end
		
		this.background_loaded = true
		this.background = backgrounds
	end
	
	return this.background
end)

function LS2Beatmap.GetScorePerTap(this)
	return this.ls2.score_tap or 0
end

function LS2Beatmap.GetStamina(this)
	return this.ls2.stamina_display or 0
end

function LS2Beatmap.GetNotesStyle(this)
	return this.ls2.note_style
end

LS2Beatmap.GetBeatmapAudio = _wrapFileHandle(function(this)
	if not(this.audio_loaded) then
		if this.ls2.sections.ADIO then
			-- Embedded audio available
			this.file:seek(this.ls2.sections.ADIO[1])
			local ext, data, ff = ls2.section_processor.ADIO[1](this.file, this.ls2.version_2)
			local fdata = love.filesystem.newFileData(data, "_."..ext)
			
			if ff then
				this.audio = AquaShine.FFmpegExt.LoadAudio(data, true)
			else
				this.audio = love.sound.newSoundData(love.filesystem.newFileData(data, "_."..ext))
			end
		end
		
		if not(this.audio) then
			-- Get from metadata
			local meta = this:_GetMetadata()
			
			if meta.song_file then
				this.audio = AquaShine.LoadAudio("audio/"..meta.song_file)
			end
		end
		
		this.audio_loaded = true
	end
	
	return this.audio
end)

LS2Beatmap.GetLiveClearSound = _wrapFileHandle(function(this)
	if this.ls2.sections.LCLR then
		-- Embedded audio available
		this.file:seek(this.ls2.sections.LCLR[1])
		local ext, data, ff = ls2.section_processor.LCLR[1](this.file, this.ls2.version_2)
		local fdata = love.filesystem.newFileData(data, "_."..ext)
		
		if ff then
			return AquaShine.FFmpegExt.LoadAudio(data, true)
		else
			return love.sound.newSoundData(love.filesystem.newFileData(data, "_."..ext))
		end
	end
	
	return nil
end)

function LS2Beatmap.GetStarDifficultyInfo(this, rand)
	local metadata = this:_GetMetadata()
	
	return rand and metadata.random_star or metadata.star or 0
end

return LS2Loader
