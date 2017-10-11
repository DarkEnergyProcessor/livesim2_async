-- Sukufest Simulator beatmap loader
-- TODO: support for new format https://twitter.com/yuyu0127_/status/823520047582748673
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine, NoteLoader = ...
local love = love
local SIFSLoader = NoteLoader.NoteLoaderLoader:extend("NoteLoader.SIFSLoader", {ProjectLoader = false})
local SIFSBeatmap = NoteLoader.NoteLoaderNoteObject:extend("NoteLoader.SIFSBeatmap")

-------------------------
-- SIFS Beatmap Loader --
-------------------------

local function sifs_fetch_number(iterator, name)
	return tonumber(iterator():match(string.format("^%s = (%%-?%%d+);", name)))
end

function SIFSLoader.GetLoaderName()
	return "SIFs Beatmap"
end

function SIFSLoader.LoadNoteFromFilename(f)
	local lines = f:lines()
	local this = SIFSBeatmap()
	
	this.bpm = sifs_fetch_number(lines, "BPM") or 120
	this.offset = (sifs_fetch_number(lines, "OFFSET") or 0) * 1250 / this.bpm
	lines()
	this.attribute = (sifs_fetch_number(lines, "ATTRIBUTE") or 2) + 1
	this.difficulty = assert(sifs_fetch_number(lines, "DIFFICULTY"))
	this.audio_file = assert(AquaShine.Basename(lines():match("^MUSIC = GetCurrentScriptDirectory~\"([^\"]+)\";")))
	lines()
	this.cover_image = assert(AquaShine.Basename(lines():match("^imgJacket = \"([^\"]+)\";")))
	this.title = assert(lines():match("^TITLE = \"([^\"]+)\";"))
	this.comment = assert(lines():match("^COMMENT = \"([^\"]+)\";"))
	lines()
	this.beatmap_data = lines()
	
	lines = nil
	return this
end

-------------------------
-- SIFS Beatmap Object --
-------------------------

function SIFSBeatmap.GetNotesList(this)
	if not(this.notes_data) then
		local notes_data = {}
		local speed_multipler = 1
		local stop_time_count = 0
		local notes_speed = AquaShine.LoadConfig("NOTE_SPEED", 800) * 0.001
		local last_timing_sec = 0
		local last_tick = 0
		local attribute = this.attribute
		
		for a, b, c in this.beatmap_data:gmatch("([^,]+),([^,]+),([^,]+)") do
			a, b, c = assert(tonumber(a)) + stop_time_count - last_tick, assert(tonumber(b)), assert(tonumber(c))
			
			if b == 10 then
				-- BPM change
				last_timing_sec = (a * 1250 / this.bpm + last_timing_sec)
				last_tick = a
				this.bpm = c
			elseif b == 18 then
				-- Note attribute change
				attribute = math.min(c + 1, 11)
			elseif b == 19 then
				-- Add stop time
				stop_time_count = stop_time_count + c
			elseif b == 20 then
				-- Note speed change
				-- We didn't support negative values, so check for it
				speed_multipler = c > 0 and c or 1
			elseif b < 10 then
				local effect = 1
				local effect_value = 2
				local c_abs = math.abs(c)
				
				if c == 2 or c == 3 then
					effect = 4
				elseif c_abs >= 4 then
					effect = 3
					effect_value = c_abs * 1.25 / this.bpm
				end
				
				notes_data[#notes_data + 1] = {
					timing_sec = (a * 1250 / this.bpm - this.offset + last_timing_sec) * 0.001,
					notes_attribute = attribute,
					notes_level = 1,
					effect = effect,
					effect_value = effect_value,
					speed = notes_speed / speed_multipler,
					position = 10 - b
				}
			end
		end
		
		this.notes_data = notes_data
	end
	
	return this.notes_data
end

function SIFSBeatmap.GetName(this)
	return this.title
end

function SIFSBeatmap.GetBeatmapTypename()
	return "SIFs Beatmap"
end

function SIFSBeatmap.GetCoverArt(this)
	local art_img_name = "live_icon/"..this.cover_image
	
	if not(this.cover) and love.filesystem.isFile(art_img_name) then
		this.cover = {}
		this.cover.title = this.title
		this.cover.arrangement = this.comment
		this.cover.image = love.graphics.newImage(art_img_name)
	end
	
	return this.cover
end


function SIFSBeatmap.GetBeatmapAudio(this)
	if not(this.audio_loaded) then
		local name = "audio/"..this.audio_file
		
		if love.filesystem.isFile(name) then
			this.audio = AquaShine.LoadAudio(name)
		end
		
		this.audio_loaded = true
	end
	
	return this.audio
end

function SIFSBeatmap.GetStarDifficultyInfo(this)
	return this.difficulty
end

function SIFSBeatmap.ReleaseBeatmapAudio(this)
	this.audio_loaded, this.audio = false, nil
end

return SIFSLoader
