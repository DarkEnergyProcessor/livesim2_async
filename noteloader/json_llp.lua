-- LLPractice beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine, NoteLoader = ...
local LLPBeatmap = NoteLoader.NoteLoaderNoteObject:extend("NoteLoader.LLPBeatmap")

------------------------------------
-- LLPractice Beatmap Note Object --
------------------------------------

function LLPBeatmap.GetNotesList(this)
	if not(this.notes_list) then	
		local attribute = AquaShine.LoadConfig("LLP_SIFT_DEFATTR", 10)	-- Rainbow is default attribute
		local sif_map = {}
		
		for n, v in ipairs(this.llp.lane) do
			for a, b in ipairs(v) do
				local new_effect = 1
				local new_effect_val = 2
				
				if b.longnote then
					new_effect = 3
					new_effect_val = (b.endtime - b.starttime) / 1000
				end
				
				sif_map[#sif_map + 1] = {
					timing_sec = b.starttime / 1000,
					notes_attribute = attribute or 1,
					notes_level = 1,
					effect = new_effect,
					effect_value = new_effect_val,
					position = 9 - b.lane
				}
			end
		end
		
		table.sort(sif_map, function(a, b) return a.timing_sec < b.timing_sec end)
		this.notes_list = sif_map
	end
	
	return this.notes_list
end

function LLPBeatmap.GetName(this)
	return this.name
end

function LLPBeatmap.GetBeatmapTypename()
	return "LLPractice Beatmap"
end

function LLPBeatmap.GetBeatmapAudio(this)
	if not(this.song_file_loaded) then
		if this.llp.audiofile then
			this.song_file = AquaShine.LoadAudio("audio/"..this.llp.audiofile..".wav")
		end
		
		this.song_file = this.song_file or NoteLoader._LoadDefaultAudioFromFilename(file)
		this.song_file_loaded = true
	end
	
	return this.song_file
end

return function(json, filename)
	assert(json.audiofile and json.lane)
	local this = LLPBeatmap()
	
	this.name = NoteLoader._GetBasenameWOExt(filename)
	this.llp = json
	
	return this
end
