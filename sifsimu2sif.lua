return function(...)
	local arg = {...}

	if arg[1] == nil then
		print("Usage: sifsimu2sif.lua <sifsimu>")
		print("Variable tempo isn't supported yet")
		return
	end

	local JSON = require("JSON")
	local sifsimu = assert(io.open(arg[1], "rb"))
	local offset_ms = 0
	local bpm = 120
	local attribute = 3
	local beatmap_string = ""
	local sif_beatmap_data = {}

	do
		local x = sifsimu:lines()
		
		-- Parse BPM
		bpm = tonumber(x():match("BPM = (%d+)")) or 120
		
		-- Parse offset. Offset time unit is in "count" (in Excel)
		offset_ms = (tonumber(x():match("OFFSET = ([-]?%d+)")) or 0) * 1250 / bpm
		x()
		
		-- Parse attribute
		attribute = (tonumber(x():match("ATTRIBUTE = (%d+)")) or 2) + 1
		
		-- Skip until beatmap
		while x():find("BEATMAP") == nil do end
		
		beatmap_string = x()
	end

	sifsimu:close()
	
	local stop_time_count = 0

	for a, b, c in beatmap_string:gmatch("([^,]+),([^,]+),([^,]+)") do
		a, b, c = assert(tonumber(a)) + stop_time_count, assert(tonumber(b)), assert(tonumber(c))
		local c_abs = math.abs(c)
		
		if b == 18 then
			-- Note attribute change
			attribute = math.min(c + 1, 10)
		elseif b == 19 then
			-- Add stop time
			stop_time_count = stop_time_count + c
		elseif b < 10 then
			local effect = 1
			local effect_value = 2
			
			if c == 2 or c == 3 then
				effect = 4
			elseif c_abs >= 4 then
				effect = 3
				effect_value = c_abs * 1.25 / bpm
			end
			
			sif_beatmap_data[#sif_beatmap_data + 1] = {
				timing_sec = (a * 1250 / bpm - offset_ms) / 1000,
				notes_attribute = attribute,
				notes_level = 1,
				effect = effect,
				effect_value = effect_value,
				position = 10 - b
			}
		end
	end

	table.sort(sif_beatmap_data, function(a, b) return a.timing_sec < b.timing_sec end)
	
	return sif_beatmap_data
end
