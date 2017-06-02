-- SIF Beatmap randomizer (experimental)
-- Written by AuahDark, with help from Winshley

local function CopyBeatmap(b)
	local a = {}
	
	a.timing_sec = b.timing_sec
	a.notes_attribute = b.notes_attribute
	a.notes_level = b.notes_level
	a.effect = b.effect
	a.effect_value = b.effect_value
	a.position = b.position
	
	return a
end

local function PickPosWhichIsNot(arg)
	local unselval = {}
	local val
	
	for i = 1, #arg do
		unselval[arg[i]] = true
	end
	
	local all_used = true
	for i = 1, 9 do
		if not(unselval[i]) then
			all_used = false
			break
		end
	end
	
	assert(not(all_used), "All position disabled")
	
	repeat
		val = math.random(1, 9)
	until not(unselval[val])
	
	return val
end

local function Randomizer(beatmap)
	local last_timing_sec
	
	-- First, do long traverse of all beatmap
	local bmlen = #beatmap
	for i = 1, bmlen do
		local bm = beatmap[i]
		
		if bm.effect == 11 then
			return nil, "Contain swing notes"
		elseif bm.effect == 13 then
			return nil, "Contain swing long notes"
		end
		
		if bm.effect == 3 then
			-- Find overlapped LN >= 3
			local overlapped_count = 0
			local end_time = bm.timing_sec + bm.effect_value
			
			for j = i + 1, #beatmap do
				local anbm = beatmap[j]
				
				if anbm.timing_sec >= end_time then
					break
				elseif anbm.effect == 3 and anbm.timing_sec < end_time and anbm.timing_sec + anbm.effect_value >= end_time then
					overlapped_count = overlapped_count + 1
				end
			end
			
			if overlapped_count > 1 then
				return nil, "More than 2 simultaneous long note"
			end
		end
		
		if bm.timing_sec == last_timing_sec then
			local simul_count = 0
			
			for j = i + 1, #beatmap do
				if beatmap[j].timing_sec == last_timing_sec then
					simul_count = simul_count + 1
				else
					break
				end
			end
			
			if simul_count > 0 then
				return nil, "More than 2 simultaneous note"
			end
		end
		
		last_timing_sec = bm.timing_sec
	end
	
	table.sort(beatmap, function(a, b) return a.timing_sec < b.timing_sec end)
	
	-- Second, Randomize it
	local new_beatmap = {}
	local buffer_200ms = {}
	
	for i = 1, bmlen do
		local bm = beatmap[i]
		
		if not(new_beatmap[i]) then
			local nb = CopyBeatmap(bm)
			
			if nb.effect == 3 then
				local end_time = nb.timing_sec + nb.effect_value
				local newpos
				
				repeat
					newpos = math.random(1, 9)
				until newpos ~= 5
				
				for j = i + 1, #beatmap do
					local abm = beatmap[j]
					
					if (abm.timing_sec >= end_time and abm.effect == 3) or abm.timing_sec > end_time then
						break
					end
					
					local tgtbm = CopyBeatmap(abm)
					
					if newpos > 5 then
						-- Left
						tgtbm.position = math.random(1, 4)
					else
						-- Right
						tgtbm.position = math.random(6, 9)
					end
					
					new_beatmap[j] = tgtbm
				end
				
				nb.position = newpos
				
				-- Clear 200ms note buffer
				repeat until not(table.remove(buffer_200ms))
			else
				local temp = beatmap[i + 1]
				
				if temp and temp.timing_sec == nb.timing_sec and temp.notes_attribute then
					-- Simultaneous note
					local tgtbm = CopyBeatmap(temp)
					
					if math.random(1, 2) == 1 then
						-- First one is left
						nb.position = math.random(1, 4)
						tgtbm.position = math.random(6, 9)
					else
						-- First one is right
						nb.position = math.random(6, 9)
						tgtbm.position = math.random(1, 4)
					end
					
					new_beatmap[i + 1] = tgtbm
					
					-- Clear 200ms note buffer
					repeat until not(table.remove(buffer_200ms))
				else
					local forbidden_pos = {}
					
					for j = #buffer_200ms, 1, -1 do
						if nb.timing_sec - buffer_200ms[j].timing_sec <= 0.2 then
							forbidden_pos[#forbidden_pos + 1] = buffer_200ms[j].position
						else
							table.remove(buffer_200ms, j)
						end
					end
					
					nb.position = PickPosWhichIsNot(forbidden_pos)
					table.insert(buffer_200ms, nb)
				end
			end
			
			-- Insert
			new_beatmap[i] = nb
		end
	end
	
	return new_beatmap
end

return function(beatmap)
	local a = {}
	
	for i = 1, #beatmap do
		a[i] = CopyBeatmap(beatmap[i])
	end
	
	local _, b, c = pcall(Randomizer, a)
	
	if _ == false then
		return nil, b
	else
		return b, c
	end
end
