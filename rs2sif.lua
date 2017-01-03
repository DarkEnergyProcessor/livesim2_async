-- SIFTrain to SIF beatmap convert

local function hasbit(a, b)
	return a % (b * 2) >= b
end

--! @brief Converts SIFTrain beatmap to SIF beatmap
--! @param rs_map The SIFTrain JSON decoded data to table
--! @returns SIF-compilant beatmap in table
--! @note Modify `LLP_SIFT_DEFATTR` to change default attribute
local function rs2sif(rs_map)
	local DEPLS = _G.DEPLS
	local attribute = DEPLS.LoadConfig("LLP_SIFT_DEFATTR", 1)
	local sif_map = {}
	
	rs_map = rs_map.song_info[1].notes
	
	for n, v in pairs(rs_map) do
		local new_effect = 1
		
		if hasbit(v.effect, 3) then
			new_effect = 3
		elseif hasbit(v.effect, 4) then
			new_effect = 4
		end
		
		table.insert(sif_map, {
			timing_sec = v.timing_sec,
			notes_attribute = attribute or 1,
			notes_level = 1,
			effect = new_effect,
			effect_value = v.effect_value,
			position = v.position
		})
	end
	
	table.sort(sif_map, function(a, b) return a.timing_sec < b.timing_sec end)
	return sif_map
end

return rs2sif
