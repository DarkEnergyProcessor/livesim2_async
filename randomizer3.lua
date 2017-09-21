-- (Again, Another) SIF Beatmap Randomizer
-- Written by MilesElectric168 in C++
-- Rewritten to Lua by MikuAuahDark

local function copyBeatmap(b)
	local a = {}
	
	a.timing_sec = b.timing_sec
	a.notes_attribute = b.notes_attribute
	a.notes_level = b.notes_level
	a.effect = b.effect
	a.effect_value = b.effect_value
	a.speed = b.speed
	a.live_vanish = b.live_vanish
	a.position = b.position
	
	return a
end

local function randomNote(notes, includeExclude)
	if includeExclude then
		return notes[math.random(1, #notes)]
	else
		local notesIncluded = {}
		
		for x = 1, 9 do
			local includeNote = true
			
			for y = 1, #notes do
				if x == notes[y] then
					includeNote = false
					break
				end
			end
			
			if includeNote then
				notesIncluded[#notesIncluded + 1] = x
			end
		end
		
		return notesIncluded[math.random(1, #notesIncluded)]
	end
end

local function isSimultaneous(v, i, notes_list)
	for j = i + 1, #notes_list do
		if notes_list[j].timing_sec == v.timing_sec then
			return true
		else
			break
		end
	end
	
	for j = i - 1, 1, -1 do
		if notes_list[j].timing_sec == v.timing_sec then
			return true
		else
			break
		end
	end
	
	return false
end

local function isTapSwing(note_effect)
	local a = note_effect / 10
	return a >= 1 and a < 3
end
	
local all = {1, 2, 3, 4, 5, 6, 7, 8, 9}
local center = {5}
local left = {6, 7, 8, 9}
local right = {1, 2, 3, 4}

local function randomizer3(m_notesList, timeRestriction)
	timeRestriction = timeRestriction or 0.2
	
	-- This is an extended version of the SIF Randomizer, so that it can handle
	-- randomizing swing notes.
	
	-- A few notes on swing randomization:
	--	- A swing chain is dependent on the position of the previous note in
	--    the chain.  It can only be adjacent to the note of the previous chain
	--	- It can be adjacent in either direction, but we must make note that
	--    the position can't be 0 or 10 (account for out-of-bounds possiblity)
	--	- Swings should also follow the no-center rule when appropriate (no
	--    centers on doubles, no centers during holds, no hold-swings will be
	--    in the center)
	--	- Since the lead note in a swing-chain isn't dependent on any previous
	--    swing note, the lead note is treated, essentially, as a regular note.
	--	- Lead swings should follow the 20 ms proximity rule and be placed on
	--    the opposite side of the previous note, but subsequent swings of the
	--    same chain need to ignore this rule
	--	- Swings during holds are easy; if notes can't be in the middle if they
	--    appear during a hold, then the swing will never cross sides, so this
	--    case is easy
	--	- I try to explain the process of handling taps+swings at the same
	--    time, but the process is a little complicated.
	
	-- Notes the current position of the swing chain, used to make sure
	-- subsequent notes in the chain are adjacent
	local swingPosition = {}
	
	-- Create a vector for the most recent position of a particular swing
	-- chain; and mark each one as 0 to prevent a out-of-bounds error
	for i, v in ipairs(m_notesList) do
		while v.notes_level >= #swingPosition do
			swingPosition[#swingPosition + 1] = 0
		end
	end
	
	-- Marks the time of the most recent action
	local recentTime = 0.000
	-- Marks the position of the most recent action
	local recentPosition = 0
	-- Marks if there is a double action
	local doubleAction = false
	-- Marks the hold position
	local holdPosition = 0
	-- Marks when the hold will be released
	local releaseTime = 0.000
	
	-- Move through each note
	for i, v in ipairs(m_notesList) do
		-- Note is the first note. 
		if i == 1 then
			-- Naturally, we don't have to worry about swings here, since it's
			-- the first note and it will always start a chain; we just need to
			-- mark the most recent position if it is a swing
			
			if v.effect % 10 == 3 then
				-- Note is a hold note
				v.position = randomNote(center, false)
				holdPosition = v.position
				releaseTime = v.timing_sec + v.effect_value
			elseif isSimultaneous(v, i, m_notesList) then
				-- Note is a double
				v.position = randomNote(center, false)
			else
				v.position = randomNote(all, true)
			end
			
			recentTime = v.timing_sec
			recentPosition = v.position
			
			if isTapSwing(v.effect) then
				swingPosition[v.notes_level] = v.position
			end
		else
			-- Note is not the first note
			
			if isSimultaneous(v, i, m_notesList) then
				-- Note is a double
				if isTapSwing(v.effect) and swingPosition[v.notes_level] ~= 0 then
					-- Note is a swing (and not the start of the chain), this
					-- is going to get complicated...This note needs to be
					-- adjecent to the previous swing note in the chain, AND,
					-- it needs to not be the middle, AND the other note has to
					-- be properly placed on the other side of the screen.
					
					-- If the posiion to the left is the center or OOB
					if swingPosition[v.notes_level] + 1 == 5 or swingPosition[v.notes_level] + 1 > 9 then
						-- Force the swing to move right
						v.position = swingPosition[v.notes_level] - 1
					elseif swingPosition[v.notes_level] - 1 == 5 or swingPosition[v.notes_level] - 1 < 1 then
						-- Force the swing to move left
						v.position = swingPosition[v.notes_level] + 1
					elseif swingPosition[v.notes_level] == 5 and v.timing_sec - m_notesList[i - 1].timing_sec < 0.001 then
						-- If the previous note of the swing is in the center
						-- position, and the previous note was the paired note,
						-- then we run into a lot of issues
						
						-- The non-swing note lets the swing decide where to go
						-- first and move to the other side to compensate.
						-- Swings are commanded to not move to the middle
						-- during doubles so it can't switch sides during a
						-- double swing.  However, if we're riding a single
						-- swing into a double note, and the previous swing was
						-- in the middle, it could theoretically go either left
						-- or right, and the other note has no clue which side
						-- to go on, so in this case, the swing will let the
						-- previous note decide which side first, and the swing
						-- will adjust.
						
						if m_notesList[i - 1].position < 5 then
							v.position = 6
						else
							v.position = 4
						end
					else
						-- We don't need to worry about OOB, hitting, or
						-- crossing the middle
						
						local a = swingPosition[v.notes_level]
						v.position = randomNote({a - 1 , a + 1}, true)
					end
				elseif v.timing_sec - m_notesList[i - 1].timing_sec < 0.001 then
					-- Note is paired with previous note AND not a swing
					v.position = randomNote(m_notesList[i - 1].position < 5 and left or right, true)
				elseif m_notesList[i + 1] and isTapSwing(m_notesList[i + 1].effect) and swingPosition[m_notesList[i + 1].notes_level] ~= 0 then
					-- If the later note is a swing, then we need to restrict
					-- this one too
					local a = m_notesList[i + 1]
					
					if swingPosition[a.notes_level] < 5 then
						-- If the previous swing note of the chain is on the
						-- right side, the next swing will also be on the
						-- right, so force the note to the left
						v.position = randomNote(left, true)
					elseif swingPosition[a.notes_level] > 5 then
						v.position = randomNote(right, true)
					else
						-- If the previous swing note of the chain is in the
						-- center, we'll let this one choose it's place and let
						-- the other note move accordingly, see above
						v.position = randomNote(center, false)
					end
				else
					-- Note is paired with a later note and later note isn't a
					-- swing
					
					-- This note can appear anywhere except the center, the
					-- paired note will be restricted
					v.position = randomNote(center, false)
				end
			-- Check if the timing of the note is less than the release time
			-- (with a 2.5ms buffer) a.k.a note appears during a hold
			elseif v.timing_sec - releaseTime < 0.0025 then
				-- If note is a swing and next in the chain, make sure it
				-- doesn't hit position 5 or OOB
				if isTapSwing(v.effect) and swingPosition[v.notes_level] ~= 0 then
					-- Same lines as above, without the case for if the
					-- previous note is in the middle, because it's
					-- theoretically impossible. We dont need to check what the
					-- hold position is, only where the previous swing was.
					local a = swingPosition[v.notes_level]
					
					if a + 1 == 5 or a + 1 > 9 then
						v.position = a - 1
					elseif a - 1 == 5 or a - 1 < 1 then
						v.position = a + 1
					else
						v.position = randomNote({a - 1, a + 1}, true)
					end
				elseif holdPosition < 5 then
					-- Otherwise, make sure note is on the opposite side of the held note
					v.position = randomNote(left, true)
				else
					v.position = randomNote(right, true)
				end
			elseif doubleAction then
				-- Notes after double actions are "unrestricted"
				
				if v.effect % 10 == 3 then
					-- Note is a hold; cannot be centered, but otherwise
					-- anywhere
					
					-- If the note is a swing and a hold, make sure it doesn't
					-- slide into the middle
					if v.effect > 10 and swingPosition[v.notes_level] ~= 0 then
						local a = swingPosition[v.notes_level]
						
						if a + 1 == 5 or a + 1 > 9 then
							v.position = a - 1
						elseif a - 1 == 5 or a - 1 < 1 then
							v.position = a + 1
						else
							v.position = randomNote({a - 1, a + 1}, true)
						end
					else
						-- Hold Notes cannot be in the center
						v.position = randomNote(center, false)
					end
				else
					-- Note is not a hold
					
					if isTapSwing(v.effect) and swingPosition[v.notes_level] ~= 0 then
						-- Now we only need to keep the swing from going OOB
						local a = swingPosition[v.notes_level]
						
						if a + 1 > 9 then
							v.position = a - 1
						elseif a - 1 < 1 then
							v.position = a + 1
						else
							v.position = randomNote({a - 1, a + 1}, true)
						end
					else
						-- Note is not a swing or a hold, no restrictions
						v.position = randomNote(all, true)
					end
				end
			elseif
				v.timing_sec - recentTime < timeRestriction + 0.001 and (
					not(isTapSwing(v.effect)) or (
						isTapSwing(v.effect) and
						swingPosition[v.notes_level] == 0
					)
				)
			then
				-- Note is sufficiently close to previous action AND
				-- (Note is not a swing OR
				-- (Note is a swing AND it's the beginning of the swing chain))
				-- In English: Swings in the middle of the chain are exempt
				-- from the rule, swings in the beginning of the chain are not
				
				if recentPosition < 5 then
					v.position = randomNote(left, true)
				elseif recentPosition > 5 then
					v.position = randomNote(right, true)
				elseif recentPosition == 5 then
					v.position = randomNote(center, false)
				end
			-- Last restriction, check if the note is a hold
			elseif v.effect == 3 or v.effect == 13 then
				if v.effect > 10 and swingPosition[v.notes_level] ~= 0 then
					-- Once again, keep swing from hitting the middle or OOB
					local a = swingPosition[v.notes_level]
					
					if a + 1 == 5 or a + 1 > 9 then
						v.position = a - 1
					elseif a - 1 == 5 or a - 1 < 1 then
						v.position = a + 1
					else
						v.position = randomNote({a - 1, a + 1}, true)
					end
				else
					v.position = randomNote(center, false)
				end
			else
				if isTapSwing(v.effect) and swingPosition[v.notes_level] ~= 0 then
					-- Keep swing from going OOB
					local a = swingPosition[v.notes_level]
					
					if a + 1 > 9 then
						v.position = a - 1
					elseif a - 1 < 1 then
						v.position = a + 1
					else
						v.position = randomNote({a - 1, a + 1}, true)
					end
				else
					v.position = randomNote(all, true)
				end
			end
			
			-- Enter information about most recent tap/hold/release etc.
			doubleAction = v.timing_sec - recentTime < 0.001 or v.timing_sec - releaseTime < 0.001 or v.timing_sec + v.effect_value - releaseTime < 0.001
			
			if v.timing_sec > releaseTime then
				-- Note appeared after the hold ended, so we're no longer in a
				-- hold
				releaseTime = 0
				holdPosition = 0
			end
			
			if (v.effect == 3 or v.effect == 13) and v.timing_sec + v.effect_value > releaseTime then
				-- If the note is a hold AND the hold will be released after
				-- the current hold, then record this note as the current hold
				holdPosition = v.position
				releaseTime = v.timing_sec + v.effect_value
			end
			
			recentTime = v.timing_sec
			recentPosition = v.position
			
			if v.effect > 10 then
				swingPosition[v.notes_level] = v.position
			end
		end
	end
	
	return m_notesList
end

return function(x)
	local a = {}
	
	for i = 1, #x do
		a[i] = copyBeatmap(x[i])
	end
	
	local s, m = pcall(randomizer3, a)	-- Tail call
	
	if not(s) then
		return nil, m
	end
	
	return a
end
