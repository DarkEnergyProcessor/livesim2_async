-- SIF beatmap loader
-- Part of DEPLS2
-- It's trivial because it's native beatmap format that DEPLS2 uses

local JSON = require("JSON")

local SIFBeatmap = {
	Extension = "json"
}

--! @brief Loads SIF beatmap (raw and captured)
--! @param file Table contains:
--!        - path relative to DEPLS save dir
--!        - absolute path
--!        - forward slashed and not contain trailing slash
--! @returns table with these data
--!          - notes_list is the SIF-compilant notes data
--!          - score is the score information (C, B, A, S score in table) (captured ver only)
function SIFBeatmap.Load(file)
	local sif = JSON:decode(love.filesystem.newFileData(file[1]..".json"):getString())
	
	if sif.response_data then
		sif = sif.response_data
	end
	
	if sif.live_info and sif.rank_info then
		-- Captured version
		table.sort(sif.rank_info, function(a, b) return a.rank > b.rank end)
		table.sort(sif.live_info[1].notes_list, function(a, b)
			return a.timing_sec < b.timing_sec
		end)
		
		return {
			notes_list = sif.live_info[1].notes_list,
			score = {
				sif.rank_info[2].rank_min,
				sif.rank_info[3].rank_min,
				sif.rank_info[4].rank_min,
				sif.rank_info[5].rank_min
			}
		}
	end
	
	-- Raw ver
	table.sort(sif, function(a, b) return a.timing_sec < b.timing_sec end)
	
	return {notes_list = sif}
end

return SIFBeatmap
