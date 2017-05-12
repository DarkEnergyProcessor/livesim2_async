-- SIF Beatmap randomizer
-- Written by AuahDark, with help from Winshley

local function CopyBeatmap(b)
	local a = {}
	
	a.timing_sec = b.timing_sec
	a.notes_attribute = b.notes_attribute
	a.effect = b.effect
	a.effect_value = b.effect_value
	a.position = b.position
	a.secondchain = b.secondchain
	a.lnchain = b.lnchain
	
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
	print("Random test")
	print(beatmap[1], beatmap[1].position)
	print(beatmap[2], beatmap[2].position)
	
	-- First, do long traverse of all beatmap
	local bmlen = #beatmap
	for i = 1, bmlen do
		local bm = beatmap[i]
		
		if bm.effect == 11 then
			return nil, "Contain swing notes"
		elseif bm.effect == 13 then
			return nil, "Contain swing long notes"
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
		
		if bm.effect == 3 then
			local tempbm = {}
			
			tempbm.timing_sec = bm.timing_sec + bm.effect_value
			tempbm.position = bm.position
			tempbm.lnchain = bm
			
			beatmap[#beatmap + 1] = tempbm
		end
		
		last_timing_sec = bm.timing_sec
	end
	
	table.sort(beatmap, function(a, b) return a.timing_sec < b.timing_sec end)
	
	-- Second, Randomize it
	local new_beatmap = {}
	local longnote_list = {}
	
	for i = 1, #beatmap do
		local bm = beatmap[i]
		
		if not(bm.processed) then
			local nb = CopyBeatmap(bm)
			
			if nb.notes_attribute then
				if nb.effect == 3 then
					local newpos
					local last_ln = longnote_list[#longnote_list]
					
					if last_ln and last_ln.timing_sec + last_ln.effect_value >= nb.timing_sec then
						if last_ln.position > 5 then
							-- Left
							newpos = math.random(1, 4)
						else
							-- Right
							newpos = math.random(6, 9)
						end
					else
						repeat
							newpos = math.random(1, 9)
						until newpos ~= 5
					end
					
					longnote_list[#longnote_list + 1] = nb
					nb.position = newpos
					bm.secondchain = nb
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
						
						temp.processed = true
						new_beatmap[i + 1] = tgtbm
					else
						-- Scan single notes in next 200ms range
						local j = i + 1
						local pos = math.random(1, 9)
						local forbidden_pos = {pos}
						
						nb.position = pos
						
						while true do
							local tgtbm = CopyBeatmap(beatmap[j])
							
							if
								not(tgtbm) or
								tgtbm.effect == 3 or
								tgtbm.timing_sec - nb.timing_sec > 0.2 or
								(beatmap[j + 1] and beatmap[j + 1].timing_sec == tgtbm.timing_sec)
							then
								break
							end
							
							local pos = PickPosWhichIsNot(forbidden_pos)
							forbidden_pos[#forbidden_pos + 1] = pos
							
							tgtbm.position = pos
							bm.processed = true
							
							new_beatmap[j] = tgtbm
							j = j + 1
						end
					end
				end
			else
				nb.position = nb.lnchain.secondchain.position
			end
			
			-- Insert
			new_beatmap[i] = nb
		end
	end
	
	-- Third, remove any temporary placeholder beatmap
	for i = #new_beatmap, 1, -1 do
		new_beatmap[i].secondchain = nil
		
		if not(new_beatmap[i].notes_attribute) then
			table.remove(new_beatmap, i)
		end
	end
	
	return new_beatmap
end

return function(beatmap)
	local a = {}
	
	for i = 1, #beatmap do
		a[i] = CopyBeatmap(beatmap[i])
	end
	
	return Randomizer(a)
end
