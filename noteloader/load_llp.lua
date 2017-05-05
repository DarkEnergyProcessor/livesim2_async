-- LLPractice beatmap loader
-- Part of Live Simulator: 2

local AquaShine, NoteLoader = ...
local JSON = require("JSON")

local LLPBeatmap = {
	Extension = "llp"	-- Since extension exist, Detect function is unnecessary
}

--! @brief Loads LLPractice beatmap
--! @param file Table contains:
--!        - path relative to DEPLS save dir
--!        - absolute path
--!        - forward slashed and not contain trailing slash
--! @returns table with these data
--!          - notes_list is the SIF-compilant notes data
--!          - song_file is the song file handle (Source object) or nil
--! @note Modify `LLP_SIFT_DEFATTR` config to change default attribute
function LLPBeatmap.Load(file)
	local llp = JSON:decode(love.filesystem.newFileData(file[1]..".llp"):getString())
	local attribute = AquaShine.LoadConfig("LLP_SIFT_DEFATTR", 1)	-- Smile is default
	local sif_map = {}
	
	for n, v in pairs(llp.lane) do
		for a, b in pairs(v) do
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
	
	return {
		notes_list = sif_map,
		song_file = AquaShine.LoadAudio("audio/"..llp.audiofile..".wav")
	}
end

return LLPBeatmap
