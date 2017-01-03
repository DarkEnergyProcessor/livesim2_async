-- LLPractice to SIF beatmap converter

--! @brief Converts LLPractice beatmap to SIF beatmap
--! @param llp The LLPractice JSON decoded data to table
--! @returns SIF-compilant beatmap in table
--! @note Modify `LLP_SIFT_DEFATTR` to change default attribute
local llp2sif = function(llp)
	local DEPLS = _G.DEPLS
	local attribute = DEPLS.LoadConfig("LLP_SIFT_DEFATTR", 1)	-- Smile is default
	local offset = (llp.offsettime or 0) / 1000	-- In seconds
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
	return sif_map
end

return llp2sif
