--! @file note.lua
-- Note management routines

local DEPLS = _G.DEPLS
local List = require("List")
local EffectPlayer = require("effect_player")
local Note = {{}, {}, {}, {}, {}, {}, {}, {}, {}, Perfect = 0, Great = 0, Good = 0, Bad = 0, Miss = 0}
-- Import some data from DEPLS
local ScoreBase = DEPLS.ScoreBase
local AddScore = DEPLS.AddScore
local NoteAccuracy = DEPLS.NoteAccuracy
local distance = DEPLS.Distance
local angle_from = DEPLS.AngleFrom
local storyboard_callback = DEPLS.StoryboardCallback
local floor = math.floor

--! @brief Check if there's another note with same timing
--! @param timing_sec The note timing to check
--! @param multiply1000 Is the `timing_sec` is in seconds?
--! @returns `true` if there's one, false otherwise
--! @note This function modifies the note object that already queued if necessary
local function CheckSimulNote(timing_sec, multiply1000)
	if multiply1000 then
		timing_sec = timing_sec * 1000
	end
	
	for i = 1, 9 do
		for j = 1, #Note[i] do
			local notedata = Note[i][j]
			
			if floor(notedata.ZeroAccuracyTime) == floor(timing_sec) then
				notedata.SimulNoteImage = DEPLS.Images.Note.Simultaneous
				return true
			end
		end
	end
	
	return false
end

--! @brief Add note
--! @param note_data SIF-compilant note data
function Note.Add(note_data)
	local unpack = unpack or table.unpack
	local math = math
	local noteobj = {}
	local idolpos = DEPLS.IdolPosition[note_data.position]
	
	-- Define the elapsed time variable
	local ElapsedTime = 0
	-- Store the timing sec
	local ZeroAccuracyTime = note_data.timing_sec * 1000
	noteobj.ZeroAccuracyTime = ZeroAccuracyTime
	-- Note scale
	local CircleScale = 0
	
	-- Set the note image
	local NoteImage = assert(DEPLS.Images.Note[note_data.notes_attribute], "Invalid note attribute specificed")
	-- If it's token note, add token note image too
	if note_data.effect == 2 then
		noteobj.TokenImage = DEPLS.Images.Note.Token
	end
	-- If it's star note, add star note image
	if note_data.effect == 4 then
		noteobj.StarImage = DEPLS.Images.Note.Star
	end
	-- Simultaneous note image
	if CheckSimulNote(ZeroAccuracyTime) then
		noteobj.SimulNoteImage = DEPLS.Images.Note.Simultaneous
	end
	
	-- love.graphics functions
	local draw = love.graphics.draw
	local setColor = love.graphics.setColor
	local setBlendMode = love.graphics.setBlendMode
	local printf = love.graphics.print
	
	-- Cloned audios
	local Audio = {
		Perfect = DEPLS.Sound.PerfectTap:clone(),
		Great = DEPLS.Sound.GreatTap:clone(),
		Good = DEPLS.Sound.GoodTap:clone(),
		Bad = DEPLS.Sound.BadTap:clone()
	}
	
	-- Center position of the idol image
	local idx, idy = idolpos[1] + 64, idolpos[2] + 64
	
	-- Used for our custom tween
	local notepos_x_diff = idolpos[1] - 416
	local notepos_y_diff = idolpos[2] - 96
	
	-- First circle position
	local FirstCircle = {480, 160}
	
	noteobj.ScoreMultipler2 = 1
	
	if note_data.effect == 3 then
		-- Determine note trail direction and drawing origin coordinate
		local direction = angle_from(480, 160, idx, idy)
		
		-- Set end note time
		local ZeroAccuracyEndNote = note_data.effect_value * 1000
		noteobj.ZeroAccuracyEndNote = ZeroAccuracyEndNote
		-- Spotlight Image
		local SpotlightImage = DEPLS.Images.Spotlight
		-- Spotlight scale
		local SpotlightImageScale = 0
		-- End note circle scale
		local EndCircleScale = 0
		-- End note circle image
		local EndNoteImage = DEPLS.Images.Note.NoteEnd
		-- Second circle position
		local SecondCircle = {480, 160}
		-- Note trail vertices
		local Vert = {0, 0, 0, 0, 0, 0, 0, 0}
		local polygon = love.graphics.polygon
		
		-- Endnote audio
		local Audio2 = {
			Perfect = DEPLS.Sound.PerfectTap:clone(),
			Great = DEPLS.Sound.GreatTap:clone(),
			Good = DEPLS.Sound.GoodTap:clone(),
			Bad = DEPLS.Sound.BadTap:clone(),
		}
		
		-- Long note functions is different than normal tap function routine
		function noteobj.Update(this, deltaT)
			-- deltaT is in milliseconds
			--ElapsedTime = ElapsedTime + deltaT
			ElapsedTime = DEPLS.ElapsedTime - ZeroAccuracyTime + DEPLS.NotesSpeed
			
			FirstCircle[1], FirstCircle[2] = unpack(idolpos)
			CircleScale = 1
			EndCircleScale = 0
			
			if this.TouchID == nil then
				-- The note isn't in tapping state
				FirstCircle[1] = notepos_x_diff * ElapsedTime / DEPLS.NotesSpeed + 480
				FirstCircle[2] = notepos_y_diff * ElapsedTime / DEPLS.NotesSpeed + 160
				CircleScale = ElapsedTime / DEPLS.NotesSpeed
			else
				FirstCircle[1] = idx
				FirstCircle[2] = idy
				CircleScale = 1
			end
			
			-- If it's not pressed/holded for long time, and it's beyond miss range, make it miss
			do
				local cmp = this.TouchID and SecondCircle or FirstCircle
				local cmp2 = this.TouchID and DEPLS.NotesSpeed + ZeroAccuracyEndNote or DEPLS.NotesSpeed
				
				if ElapsedTime >= cmp2 then
					local notedistance = distance(cmp[1] - idx, cmp[2] - idy)
					
					if notedistance >= NoteAccuracy[5][2] then
						DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Miss
						DEPLS.Routines.PerfectNode.Replay = true
						DEPLS.Routines.ComboCounter.Reset = true
						this.ScoreMultipler = 0
						this.Delete = true
						Note.Miss = Note.Miss + 1
						
						storyboard_callback("LongNoteTap",
							cmp == SecondCircle,			-- release
							note_data.position,				-- pos
							0, 								-- accuracy (miss)
							notedistance,					-- distance
							note_data.notes_attribute,		-- attribute
							not(not(this.SimulNoteImage))	-- is_simul
						)
						return
					end
				end
			end
			
			if -ZeroAccuracyEndNote + ElapsedTime >= 0 then
				-- Spawn end note circle
				local EndNoteElapsedTime = DEPLS.ElapsedTime - (ZeroAccuracyTime + ZeroAccuracyEndNote) + DEPLS.NotesSpeed
				
				SecondCircle[1] = notepos_x_diff * EndNoteElapsedTime / DEPLS.NotesSpeed + 480
				SecondCircle[2] = notepos_y_diff * EndNoteElapsedTime / DEPLS.NotesSpeed + 160
				EndCircleScale = EndNoteElapsedTime / DEPLS.NotesSpeed
			end
			
				-- First position
			Vert[1] = math.floor((FirstCircle[1] + (CircleScale * 62) * math.cos(direction)) + 0.5)		-- x
			Vert[2] = math.floor((FirstCircle[2] + (CircleScale * 62) * math.sin(direction)) + 0.5)		-- y
				-- Second position
			Vert[3] = math.floor((FirstCircle[1] + (CircleScale * 62) * math.cos(direction - math.pi)) + 0.5)	-- x
			Vert[4] = math.floor((FirstCircle[2] + (CircleScale * 62) * math.sin(direction - math.pi)) + 0.5)	-- y
				-- Third position
			Vert[5] = math.floor((SecondCircle[1] + (EndCircleScale * 62) * math.cos(direction - math.pi)) + 0.5)	-- x
			Vert[6] = math.floor((SecondCircle[2] + (EndCircleScale * 62) * math.sin(direction - math.pi)) + 0.5)	-- y
				-- Fourth position
			Vert[7] = math.floor((SecondCircle[1] + (EndCircleScale * 62) * math.cos(direction)) + 0.5)		-- x
			Vert[8] = math.floor((SecondCircle[2] + (EndCircleScale * 62) * math.sin(direction)) + 0.5)		-- y
		end
		
		function noteobj.Draw(this)
			-- Draw note trail
			setBlendMode("add")
			if this.TouchID then
				setColor(255, 255, 64, DEPLS.LiveOpacity * 0.5)
			else
				setColor(255, 255, 255, DEPLS.LiveOpacity * 0.5)
			end
			
			polygon("fill", Vert[1], Vert[2], Vert[3], Vert[4], Vert[5], Vert[6])
			polygon("fill", Vert[5], Vert[6], Vert[7], Vert[8], Vert[1], Vert[2])
			setColor(255, 255, 255, DEPLS.LiveOpacity)
			setBlendMode("alpha")
			
			-- Draw note image
			draw(NoteImage, FirstCircle[1], FirstCircle[2], 0, CircleScale, CircleScale, 64, 64)
			
			-- Draw simultaneous note bar if it is
			if noteobj.SimulNoteImage then
				draw(noteobj.SimulNoteImage, FirstCircle[1], FirstCircle[2], 0, CircleScale, CircleScale, 64, 64)
			end
			
			local draw_endcircle = EndCircleScale > 0
			-- Draw end note trail if it is
			if draw_endcircle then
				draw(EndNoteImage, SecondCircle[1], SecondCircle[2], 0, EndCircleScale, EndCircleScale, 64, 64)
			end
			
			--setColor(255, 255, 255, 255)
			if DEPLS.DebugNoteDistance then
				local notedistance = distance(FirstCircle[1] - idx, FirstCircle[2] - idy)
				
				setColor(0, 0, 0, 255)
				printf(("%.2f"):format(notedistance), FirstCircle[1], FirstCircle[2])
				setColor(255, 255, 255, 255)
				printf(("%.2f"):format(notedistance), FirstCircle[1] + 1, FirstCircle[2] + 1)
				
				if draw_endcircle then
					notedistance = distance(SecondCircle[1] - idx, SecondCircle[2] - idy)
					
					setColor(0, 0, 0, 255)
					printf(("%.2f"):format(notedistance), SecondCircle[1], SecondCircle[2])
					setColor(255, 255, 255, 255)
					printf(("%.2f"):format(notedistance), SecondCircle[1] + 1, SecondCircle[2] + 1)
				end
			else
				setColor(255, 255, 255, 255)
			end
		end
		
		function noteobj.SetTouchID(this, touchid)
			local notedistance = distance(FirstCircle[1] - idx, FirstCircle[2] - idy)
			
			local function done_tap()
				DEPLS.Routines.PerfectNode.Replay = true
				this.TouchID = touchid

				storyboard_callback("LongNoteTap",
					false,							-- release
					note_data.position,				-- pos
					this.ScoreMultipler, 			-- accuracy
					notedistance,					-- distance
					note_data.notes_attribute,		-- attribute
					not(not(this.SimulNoteImage))	-- is_simul
				)
			end
			
			if DEPLS.AutoPlay then
				DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
				DEPLS.Routines.PerfectNode.Replay = true
				this.ScoreMultipler = 1
				
				Audio.Perfect:play()
				Note.Perfect = Note.Perfect + 1
				
				--[[
				DEPLS.Routines.PerfectNode.Replay = true
				this.TouchID = touchid
				
				]]
				done_tap()
				
				return
			end
			
			-- We don't want someone accidentally tap it while it's in long distance
			if notedistance <= NoteAccuracy[4][2] then
				if notedistance <= NoteAccuracy[1][2] then
					DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
					this.ScoreMultipler = 1
					
					Audio.Perfect:play()
					Note.Perfect = Note.Perfect + 1
				elseif notedistance <= NoteAccuracy[2][2] then
					DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Great
					this.ScoreMultipler = 0.88
					
					Audio.Great:play()
					Note.Great = Note.Great + 1
				elseif notedistance <= NoteAccuracy[3][2] then
					DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Good
					DEPLS.Routines.ComboCounter.Reset = true
					this.ScoreMultipler = 0.8
					
					Audio.Good:play()
					Note.Good = Note.Good + 1
				else
					DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Bad
					DEPLS.Routines.ComboCounter.Reset = true
					this.ScoreMultipler = 0.4
					
					Audio.Bad:play()
					Note.Bad = Note.Bad + 1
				end
				
				done_tap()
			end
		end
		
		function noteobj.UnsetTouchID(this, touchid)
			if this.TouchID ~= touchid then return end
			
			local notedistance = distance(SecondCircle[1] - idx, SecondCircle[2] - idy)
			local is_miss = false
			
			-- Check if perfect
			if DEPLS.AutoPlay or notedistance <= NoteAccuracy[1][2] then
				DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
				DEPLS.Routines.PerfectNode.Replay = true
				this.ScoreMultipler2 = 1
				
				Audio2.Perfect:play()
				Note.Perfect = Note.Perfect + 1
			elseif notedistance <= NoteAccuracy[2][2] then
				DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Great
				DEPLS.Routines.PerfectNode.Replay = true
				this.ScoreMultipler2 = 0.88
				
				Audio2.Great:play()
				Note.Great = Note.Great + 1
			elseif notedistance <= NoteAccuracy[3][2] then
				DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Good
				DEPLS.Routines.PerfectNode.Replay = true
				DEPLS.Routines.ComboCounter.Reset = true
				this.ScoreMultipler2 = 0.8
				
				Audio2.Good:play()
				Note.Good = Note.Good + 1
			elseif notedistance <= NoteAccuracy[4][2] then
				DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Bad
				DEPLS.Routines.PerfectNode.Replay = true
				DEPLS.Routines.ComboCounter.Reset = true
				this.ScoreMultipler2 = 0.4
				
				Audio2.Bad:play()
				Note.Bad = Note.Bad + 1
			else
				Note.Miss = Note.Miss + 1
				is_miss = true
				DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Miss
				DEPLS.Routines.PerfectNode.Replay = true
				DEPLS.Routines.ComboCounter.Reset = true
				this.ScoreMultipler2 = 0
			end
			
			if not(is_miss) then
				local AfterCircleTap = coroutine.wrap(DEPLS.Routines.CircleTapEffect)
				AfterCircleTap(SecondCircle[1], SecondCircle[2], 255, 255, 255)
				EffectPlayer.Spawn(AfterCircleTap)
			end
			
			this.Delete = true
			
			storyboard_callback("LongNoteTap",
				true,							-- release
				note_data.position,				-- pos
				this.ScoreMultipler2, 			-- accuracy
				notedistance,					-- distance
				note_data.notes_attribute,		-- attribute
				not(not(this.SimulNoteImage))	-- is_simul
			)
		end
	else
		Audio.StarExplode = DEPLS.Sound.StarExplode:clone()
		-- Single tap note
		function noteobj.Update(this, deltaT)
			-- deltaT is in milliseconds
			--ElapsedTime = ElapsedTime + deltaT
			ElapsedTime = DEPLS.ElapsedTime - ZeroAccuracyTime  + DEPLS.NotesSpeed
			
			FirstCircle[1] = notepos_x_diff * (ElapsedTime / DEPLS.NotesSpeed) + 480
			FirstCircle[2] = notepos_y_diff * (ElapsedTime / DEPLS.NotesSpeed) + 160
			CircleScale = ElapsedTime / DEPLS.NotesSpeed
			
			-- If it's not pressed, and it's beyond miss range, make it miss
			local notedistance = distance(FirstCircle[1] - idx, FirstCircle[2] - idy)
			if ElapsedTime >= DEPLS.NotesSpeed and notedistance >= NoteAccuracy[5][2] then
				DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Miss
				DEPLS.Routines.PerfectNode.Replay = true
				DEPLS.Routines.ComboCounter.Reset = true
				this.ScoreMultipler = 0
				this.Delete = true
				
				if this.StarImage then
					Audio.StarExplode:play()
				end
				
				-- Storyboard callback
				storyboard_callback("NoteTap",
					note_data.position,				-- pos
					0, 								-- accuracy (miss)
					notedistance,					-- distance
					note_data.notes_attribute,		-- attribute
					not(not(this.StarImage)),		-- is_star
					not(not(this.SimulNoteImage)),	-- is_simul
					not(not(this.TokenImage))		-- is_token
				)
				
				Note.Miss = Note.Miss + 1
				return
			end
			
		end
		
		function noteobj.Draw(this)
			local dist = distance(FirstCircle[1] - idx, FirstCircle[2] - idy)
			
			-- Draw note image
			setColor(255, 255, 255, DEPLS.LiveOpacity)
			draw(NoteImage, FirstCircle[1], FirstCircle[2], 0, CircleScale, CircleScale, 64, 64)
			
			-- Draw token image if any
			if this.TokenImage then
				draw(this.TokenImage, FirstCircle[1], FirstCircle[2], 0, CircleScale, CircleScale, 64, 64)
			end
			
			-- Draw star image if any
			if this.StarImage then
				draw(this.StarImage, FirstCircle[1], FirstCircle[2], 0, CircleScale, CircleScale, 64, 64)
			end
			
			
			-- Draw simultaneous note bar if it is
			if noteobj.SimulNoteImage then
				draw(noteobj.SimulNoteImage, FirstCircle[1], FirstCircle[2], 0, CircleScale, CircleScale, 64, 64)
			end
			
			if DEPLS.DebugNoteDistance then
				setColor(0, 0, 0, 255)
				printf(("%.2f"):format(dist), FirstCircle[1], FirstCircle[2])
				setColor(255, 255, 255, 255)
				printf(("%.2f"):format(dist), FirstCircle[1] + 1, FirstCircle[2] + 1)
			else
				setColor(255, 255, 255, 255)
			end
		end
		
		function noteobj.SetTouchID(this, touchid)
			local notedistance = distance(FirstCircle[1] - idx, FirstCircle[2] - idy)
			
			local function done_tap()
				local AfterCircleTap = coroutine.wrap(DEPLS.Routines.CircleTapEffect)
				AfterCircleTap(FirstCircle[1], FirstCircle[2], 255, 255, 255)
				EffectPlayer.Spawn(AfterCircleTap)
				
				--DEPLS.Routines.PerfectNode.Replay = true
				this.Delete = true
				
				-- Call storyboard callback
				storyboard_callback("NoteTap",
					note_data.position,				-- pos
					this.ScoreMultipler, 			-- accuracy
					notedistance,					-- distance
					note_data.notes_attribute,		-- attribute
					not(not(this.StarImage)),		-- is_star
					not(not(this.SimulNoteImage)),	-- is_simul
					not(not(this.TokenImage))		-- is_token
				)
			end
			
			if DEPLS.AutoPlay then
				DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
				DEPLS.Routines.PerfectNode.Replay = true
				this.ScoreMultipler = 1
				
				Audio.Perfect:play()
				Note.Perfect = Note.Perfect + 1
				--[[
				local AfterCircleTap = coroutine.wrap(DEPLS.Routines.CircleTapEffect)
				AfterCircleTap(FirstCircle[1], FirstCircle[2], 255, 255, 255)
				EffectPlayer.Spawn(AfterCircleTap)
				
				this.Delete = true
				
				return
				]]
				
				done_tap()
				
				return
			end
			
			-- We don't want someone accidentally tap it while it's in long distance
			if notedistance <= NoteAccuracy[4][2] then
				if notedistance <= NoteAccuracy[1][2] then
					DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
					this.ScoreMultipler = 1
					
					Audio.Perfect:play()
					Note.Perfect = Note.Perfect + 1
				elseif notedistance <= NoteAccuracy[2][2] then
					DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Great
					this.ScoreMultipler = 0.88
					
					Audio.Great:play()
					Note.Great = Note.Great + 1
				elseif notedistance <= NoteAccuracy[3][2] then
					DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Good
					DEPLS.Routines.ComboCounter.Reset = true
					this.ScoreMultipler = 0.8
					
					Audio.Good:play()
					Note.Good = Note.Good + 1
				else
					DEPLS.Routines.ComboCounter.Reset = true
					this.ScoreMultipler = 0.4
					
					Audio.Bad:play()
					Note.Bad = Note.Bad + 1
				end
				
				DEPLS.Routines.PerfectNode.Replay = true
				
				if DEPLS.Routines.ComboCounter.Reset and this.StarImage then
					Audio.StarExplode:play()
					-- TODO: play star explode effect
				end
				
				done_tap()
			end
		end
	end
	
	table.insert(Note[note_data.position], noteobj)
end

local ComboCounter = DEPLS.Routines.ComboCounter

--! @brief Function to update the note
--! @param deltaT The delta time
function Note.Update(deltaT)
	local ElapsedTime = DEPLS.ElapsedTime
	local score = 0
	local noteobj
	
	for i = 1, 9 do
		local j = 1
		
		while true do
			noteobj = Note[i][j]
			
			if noteobj and ElapsedTime >= noteobj.ZeroAccuracyTime - DEPLS.NotesSpeed then
				noteobj:Update(deltaT)
				
				-- If autoplay, make it always perfect
				if DEPLS.AutoPlay then
					if ElapsedTime >= noteobj.ZeroAccuracyTime - deltaT and noteobj.TouchID == nil then
						noteobj:SetTouchID("")
					elseif noteobj.ZeroAccuracyEndNote and ElapsedTime >= noteobj.ZeroAccuracyEndNote + noteobj.ZeroAccuracyTime - deltaT then
						noteobj:UnsetTouchID("")
					end
				end
				
				if noteobj.Delete then
					-- Calculate score and remove
					score = score + ScoreBase * noteobj.ScoreMultipler * noteobj.ScoreMultipler2 * (noteobj.UnsetTouchID and 1.25 or 1)
					table.remove(Note[i], j)
					
					if ComboCounter.Reset == true then
						ComboCounter.CurrentCombo = 0
						ComboCounter.Reset = false
					else
						ComboCounter.CurrentCombo = ComboCounter.CurrentCombo + 1
					end
					
					ComboCounter.Replay = true
				else
					j = j + 1
				end
				
			else
				break
			end
		end
	end
	
	if score > 0 then
		DEPLS.AddScore(score)	-- Add score
	end
end

--! Function to draw the note
function Note.Draw()
	local ElapsedTime = DEPLS.ElapsedTime
	local noteobj
	
	for i = 1, 9 do
		for j = 1, #Note[i] do
			noteobj = Note[i][j]
			
			-- Only update if it should be spawned
			if ElapsedTime >= noteobj.ZeroAccuracyTime - DEPLS.NotesSpeed then
				Note[i][j]:Draw()
			else
				break
			end
		end
	end
end

--! @brief Set the note touch
--! @param pos The idol position. nil if `release` is true
--! @param touchid The touch ID
--! @param release Is this a touch release message?
function Note.SetTouch(pos, touchid, release)
	if DEPLS.AutoPlay then return end
	
	local ElapsedTime = DEPLS.ElapsedTime
	local noteobj
	local score = 0
	
	if release then
		for i = 1, 9 do
			noteobj = Note[i][1]
			
			if noteobj and noteobj.TouchID == touchid then
				noteobj:UnsetTouchID(touchid)
				
				if noteobj.Delete then
					score = score + ScoreBase * noteobj.ScoreMultipler * noteobj.ScoreMultipler2 * (noteobj.UnsetTouchID and 1.25 or 1)
					table.remove(Note[i], 1)
				
					if ComboCounter.Reset == true then
						ComboCounter.CurrentCombo = 0
						ComboCounter.Reset = false
					else
						ComboCounter.CurrentCombo = ComboCounter.CurrentCombo + 1
					end
					
					ComboCounter.Replay = true
				end
				
				--break
			end
		end
		
		if score > 0 then
			DEPLS.AddScore(score)
		end
		return
	end
	
	noteobj = Note[pos][1]
	
	if noteobj and ElapsedTime >= noteobj.ZeroAccuracyTime - DEPLS.NotesSpeed then
		noteobj:SetTouchID(touchid)
		
		if noteobj.Delete then
			score = score + ScoreBase * noteobj.ScoreMultipler * noteobj.ScoreMultipler2
			table.remove(Note[pos], 1)
			
			-- Update combo counter
			if ComboCounter.Reset == true then
				ComboCounter.CurrentCombo = 0
				ComboCounter.Reset = false
			else
				ComboCounter.CurrentCombo = ComboCounter.CurrentCombo + 1
			end
			
			ComboCounter.Replay = true
		end
	end
	
	if score > 0 then
		DEPLS.AddScore(score)
	end
end

return Note
