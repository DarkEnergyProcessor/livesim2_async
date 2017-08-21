-- SIF beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine, NoteLoader = ...
local SIFBeatmap = {}
SIFBeatmap.__index = NoteLoader.NoteLoaderNoteObject._derive(SIFBeatmap)

-----------------------------
-- SIF Beatmap Note Object --
-----------------------------

function SIFBeatmap.GetNotesList(this)
	return this.notes_list
end

function SIFBeatmap.GetName(this)
	return this.name
end

function SIFBeatmap.GetBeatmapTypename(this)
	return this.score and "SIF Beatmap (capture)" or "SIF Beatmap (raw)"
end

function SIFBeatmap.GetScoreInformation(this)
	return this.score
end

function SIFBeatmap.GetBeatmapAudio(this)
	if not(this.song_file_loaded) then
		this.song_file = AquaShine.LoadAudio("audio/"..this.name..".wav")
		this.song_file_loaded = true
	end
	
	return this.song_file
end

return function(sif, file)
	local this = setmetatable({}, SIFBeatmap)
	assert(not(sif.song_info), "Not a valid SIF beatmap")
	
	if sif.response_data and sif.response_data.live_info then
		sif = sif.response_data
		
		if sif.live_info then
			-- Captured version
			table.sort(sif.live_info[1].notes_list, function(a, b)
				return a.timing_sec < b.timing_sec
			end)
			
			this.notes_list = sif.live_info[1].notes_list
			
			if sif.rank_info then
				table.sort(sif.rank_info, function(a, b) return a.rank > b.rank end)
				this.score = {
					sif.rank_info[2].rank_min,
					sif.rank_info[3].rank_min,
					sif.rank_info[4].rank_min,
					sif.rank_info[5].rank_min
				}
			end
		end
	elseif #sif > 0 then
		this.notes_list = sif
	else
		assert(false, "Not a valid SIF beatmap")
	end
	
	this.name = NoteLoader._GetBasenameWOExt(file)
	return this
end
