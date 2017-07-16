-- (Another) SIF Beatmap Randomizer
-- Written by MilesElectric168
-- Modification is done to make it fit under Live Simulator: 2

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

local function anyNote()
	return math.random( 1 , 9 )
end

local function noCenterNote()
	local temp = math.random( 1 , 8 )
	if temp > 4 then
		temp = temp + 1
	end
	return temp
end

local function leftNote()
	return math.random( 6 , 9 )
end

local function rightNote()
	return math.random( 1 , 4 )
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

local function SIFrandom(notes_list) 
	--[[This randomizer makes the following assumptions:
		 * There are no Swing Notes
		 * SIFTrain Format is loaded
		 * Notes are listed from earliest to latest
		 * There are no more than 2 holds at one time
		 * If 2 notes are being held, then a note will not appear until a hold is released
		 
		SIF's randomizer has the following restrictions:
		 * Double Notes, Hold Notes, and notes that appear during a hold will never appear in the Center Position
		 * If a note is currently being held, all notes during the hold will be placed on the opposite side
		 * If a single note appears after a double action, it's position will not be restricted regardless of how close it was to the previous action
			- A double note tap, double release, and a tap+release counts as a double action
		 * If a single note appears after a single action and was within 0.2 seconds after the previous action, the note will be placed on the opposite side
		 
	--]]

	local recentTime = 0.000 --Marks the time of the most recent action
	local recentPosition = 0 --Marks the position of the most recent action
	local doubleAction = false --Marks if there is a double action
	local holdPosition = 0 --Marks the hold position
	local releaseTime = 0.000 --Marks when the hold will be released

	for i, v in ipairs(notes_list) do
		if v.effect >= 10 then
			return nil, "Swing notes randomizer is unavailable"
		end
		
		if i == 1 then --Note is the first note. 
			if v.effect == 3 then --Note is a hold note
				v.position = noCenterNote()
				holdPosition = v.position
				releaseTime = v.timing_sec + v.effect_value
			elseif isSimultaneous(v, i, notes_list) then --Note is a double
				v.position = noCenterNote()
			else 
				v.position = anyNote()
			end
			
			recentTime = v.timing_sec
			recentPosition = v.position
			
			
		else --Note is not the first note
			
			if isSimultaneous(v, i, notes_list) then--Note is a double
				if v.timing_sec - notes_list[i-1].timing_sec < 0.001 then --Note is paired with previous note
					if notes_list[i-1].position < 5 then --Previous note was on the right side
						v.position = leftNote()
					else
						v.position = rightNote()
					end
				else --Note is paired with a later note
					v.position = noCenterNote() --This note can appear anywhere except the center, the paired note will be restricted
				end
			elseif v.timing_sec - releaseTime < 0.0025  then --Check if the timing of the note is less than the release time (with a 2.5ms buffer) a.k.a note appears during a hold
				if holdPosition < 5 then
					v.position = leftNote()
				else
					v.position = rightNote()
				end
			elseif doubleAction then --Notes after double actions are unrestricted
				if v.effect == 3 then
					v.position = noCenterNote() --Hold Notes cannot be in the center
				else
					v.position = anyNote()
				end
			elseif v.timing_sec - recentTime < 0.2 then --Note is sufficiently close to previous action
				if recentPosition < 5 then
					v.position = leftNote()
				elseif recentPosition > 5 then
					v.position = rightNote()
				elseif recentPosition == 5 then
					v.position = noCenterNote()
				end
			elseif v.effect == 3 then --Last restriction, check if the note is a hold
				v.position = noCenterNote()
			else
				v.position = anyNote()
			end
			
			-- Enter information about most recent tap/hold/release etc.
			
			if v.timing_sec - recentTime < 0.001 or v.timing_sec - releaseTime < 0.001 or v.timing_sec + v.effect_value - releaseTime < 0.001 then
			-- Checking: If the note is tapped at the same time as the previous note, or is tapped at the same time as the most recent hold, or the note releases at the same time
				doubleAction = true
			else
				doubleAction = false
			end
			
			if v.timing_sec > releaseTime then  --Note appeared after the hold ended, so we're no longer in a hold
				releaseTime = 0.000
				holdPosition = 0
			end
			
			if v.effect == 3 and v.timing_sec + v.effect_value > releaseTime then --If the note is a hold AND the hold will be released after the current hold, then record this note as the current hold
				holdPosition = v.position
				releaseTime = v.timing_sec + v.effect_value
			end
			
			recentTime = v.timing_sec
			recentPosition = v.position	
			
		end
	end
	
	return notes_list
end

return function(x)
	local a = {}
	
	for i = 1, #x do
		a[i] = copyBeatmap(x[i])
	end
	
	return SIFrandom(a)	-- Tail call
end
