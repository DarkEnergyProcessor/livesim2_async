--! @file note.lua
-- DEPLS2 Note management routines
-- Copyright © 2038 Dark Energy Processor

local DEPLS = _G.DEPLS
local List = require("List")
local EffectPlayer = require("effect_player")
local bit = require("bit")
local Yohane = require("Yohane")
local Note = {{}, {}, {}, {}, {}, {}, {}, {}, {}, Perfect = 0, Great = 0, Good = 0, Bad = 0, Miss = 0, NoteRemaining = 0, HighestCombo = 0}
-- Import some data from DEPLS
local ScoreBase = DEPLS.ScoreBase
local AddScore = DEPLS.AddScore
local NoteAccuracy = DEPLS.NoteAccuracy
local distance = DEPLS.Distance
local angle_from = DEPLS.AngleFrom
local storyboard_callback = DEPLS.StoryboardCallback
local floor = math.floor
local notes_bomb = Yohane.newFlashFromFilename("live_notes_bomb.flsh")
notes_bomb:setMovie("ef_317")

local NoteBombEffect = {}
NoteBombEffect._common_meta = {__index = NoteBombEffect}

function NoteBombEffect.Create(x, y)
	local out = {}
	out.flash = notes_bomb:clone()
	out.x = x
	out.y = y
	
	out.flash:jumpToLabel("bomb")
	return (setmetatable(out, NoteBombEffect._common_meta))
end

function NoteBombEffect:Update(deltaT)
	if not(self.flash:isFrozen()) then
		self.flash:update(deltaT)
		
		return false
	else
		return true
	end
end

function NoteBombEffect:Draw()
	self.flash:draw(self.x, self.y)
end

local function internal_simulnote_check(timing_sec, i)
	local j = 1
	local notedata = Note[i][j]
	
	while notedata ~= nil do
		if floor(notedata.ZeroAccuracyTime) == floor(timing_sec) then
			notedata.SimulNote = true
			return true
		end
		
		j = j + 1
		notedata = Note[i][j]
	end
end

--! @brief Check if there's another note with same timing
--! @param timing_sec The note timing to check
--! @param multiply1000 Is the `timing_sec` is in seconds?
--! @returns `true` if there's one, false otherwise
--! @note This function modifies the note object that already queued if necessary
local function CheckSimulNote(timing_sec, multiply1000)
	if multiply1000 then
		timing_sec = timing_sec * 1000
	end
	
	return
		internal_simulnote_check(timing_sec, 1) or
		internal_simulnote_check(timing_sec, 2) or
		internal_simulnote_check(timing_sec, 3) or
		internal_simulnote_check(timing_sec, 4) or
		internal_simulnote_check(timing_sec, 5) or
		internal_simulnote_check(timing_sec, 6) or
		internal_simulnote_check(timing_sec, 7) or
		internal_simulnote_check(timing_sec, 8) or
		internal_simulnote_check(timing_sec, 9)
end

local SingleNoteObject = {}
local LongNoteObject = {}

--! @brief Creates new SingleNoteObject
--! @param note_data SIF-compilant note data
--! @returns New NoteObject
local function NewNoteObject(note_data)
	local noteobj = {
		ZeroAccuracyTime = note_data.timing_sec * 1000,
		Attribute = tonumber(note_data.notes_attribute),
		Position = note_data.position,
		Audio = {
			Perfect = DEPLS.Sound.PerfectTap:clone(),
			Great = DEPLS.Sound.GreatTap:clone(),
			Good = DEPLS.Sound.GoodTap:clone(),
			Bad = DEPLS.Sound.BadTap:clone(),
		},
		FirstCircle = {480, 160}
	}
	local idolpos = assert(DEPLS.IdolPosition[note_data.position], "Invalid idol position")
	
	-- Idol position
	noteobj.NoteposDiff = {idolpos[1] - 416, idolpos[2] - 96}
	noteobj.CenterIdol = {idolpos[1] + 64, idolpos[2] + 64}
	noteobj.Direction = angle_from(480, 160, noteobj.CenterIdol[1], noteobj.CenterIdol[2])
	
	-- Simultaneous check
	if CheckSimulNote(noteobj.ZeroAccuracyTime) then
		noteobj.SimulNote = true
	end
	
	if note_data.effect == 2 then
		-- Token note
		noteobj.TokenNote = true
	elseif note_data.effect == 4 then
		-- Star note
		noteobj.StarNote = true
	elseif note_data.effect == 3 then
		-- Long note. Use LongNoteObject metatable
		noteobj.Audio2 = {
			Perfect = DEPLS.Sound.PerfectTap:clone(),
			Great = DEPLS.Sound.GreatTap:clone(),
			Good = DEPLS.Sound.GoodTap:clone(),
			Bad = DEPLS.Sound.BadTap:clone(),
		}
		noteobj.Vert = {}
		noteobj.SecondCircle = {480, 160}
		noteobj.ZeroAccuracyEndNote = note_data.effect_value * 1000
		noteobj.EndNoteImage = DEPLS.Images.Note.NoteEnd
		noteobj.LongNoteMesh = love.graphics.newMesh(4, "strip", "stream")
		noteobj.EndCircleScale = 0
		
		noteobj.Vert[1] = {40, 0, 1, 0.0625}
		noteobj.Vert[2] = {40, 0, 1, 0.9375}
		noteobj.Vert[3] = {-1, -1, 0, 0.9375}
		noteobj.Vert[4] = {-1, -1, 0, 0.0625}
		
		noteobj.LongNoteMesh:setTexture(DEPLS.Images.Note.LongNote)
		
		setmetatable(noteobj, {__index = LongNoteObject})
		return noteobj
	end
	
	-- SingleNoteObject in here
	noteobj.Audio.StarExplode = DEPLS.Sound.StarExplode:clone()
	noteobj.ScoreMultipler2 = 1
	
	setmetatable(noteobj, {__index = SingleNoteObject})
	return noteobj
end

--! @brief SingleNoteObject Update routine
--! @param this NoteObject
--! @param deltaT Delta-time between frame, in milliseconds
function SingleNoteObject.Update(this, deltaT)
	-- deltaT is in milliseconds
	local NotesSpeed = DEPLS.NotesSpeed
	local ElapsedTime = DEPLS.ElapsedTime - this.ZeroAccuracyTime + NotesSpeed
	
	this.FirstCircle[1] = this.NoteposDiff[1] * (ElapsedTime / NotesSpeed) + 480
	this.FirstCircle[2] = this.NoteposDiff[2] * (ElapsedTime / NotesSpeed) + 160
	this.CircleScale = ElapsedTime / DEPLS.NotesSpeed
	
	-- If it's not pressed, and it's beyond miss range, make it miss
	local notedistance = distance(this.FirstCircle[1] - this.CenterIdol[1], this.FirstCircle[2] - this.CenterIdol[2])

	if ElapsedTime >= DEPLS.NotesSpeed and notedistance >= NoteAccuracy[5][2] then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Miss
		DEPLS.Routines.PerfectNode.Replay = true
		DEPLS.Routines.ComboCounter.Reset = true
		this.ScoreMultipler = 0
		this.Delete = true
		
		if this.StarNote then
			local ef = NoteBombEffect.Create(this.CenterIdol[1], this.CenterIdol[2])
			
			EffectPlayer.Spawn(ef)
			this.Audio.StarExplode:play()
		end
		
		-- Storyboard callback
		storyboard_callback("NoteTap",
			this.Position,					-- pos
			0, 								-- accuracy (miss)
			notedistance,					-- distance
			this.Attribute,					-- attribute
			this.StarNote,					-- is_star
			this.SimulNote,					-- is_simul
			this.TokenNote,					-- is_token
			this.SlideNote					-- is_slide
		)
		
		Note.Miss = Note.Miss + 1
		return
	end
	
end

local setBlendMode = love.graphics.setBlendMode
function SingleNoteObject.Draw(this)
	local draw = love.graphics.draw
	local setColor = love.graphics.setColor
	
	setColor(255, 255, 255, DEPLS.LiveOpacity)
	draw(this.NoteImage, this.FirstCircle[1], this.FirstCircle[2], 0, this.CircleScale, this.CircleScale, 64, 64)
	
	if DEPLS.DebugNoteDistance then
		local dist = distance(this.FirstCircle[1] - this.CenterIdol[1], this.FirstCircle[2] - this.CenterIdol[2])
		local printf = love.graphics.print
		setColor(0, 0, 0, 255)
		printf(("%.2f"):format(dist), this.FirstCircle[1], this.FirstCircle[2])
		setColor(255, 255, 255, 255)
		printf(("%.2f"):format(dist), this.FirstCircle[1] + 1, this.FirstCircle[2] + 1)
	else
		setColor(255, 255, 255)
	end
end

local function coroutine_wrapper(func)
	return coroutine.wrap(func)
end

function SingleNoteObject.SetTouchID(this, touchid)
	local notedistance = distance(this.FirstCircle[1] - this.CenterIdol[1], this.FirstCircle[2] - this.CenterIdol[2])
	
	if DEPLS.AutoPlay then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
		DEPLS.Routines.PerfectNode.Replay = true
		this.ScoreMultipler = 1
		this.Audio.Perfect:play()
		this.Delete = true
		
		Note.Perfect = Note.Perfect + 1
		
		local AfterCircleTap = DEPLS.Routines.CircleTapEffect.Create(this.FirstCircle[1], this.FirstCircle[2], 255, 255, 255)
		EffectPlayer.Spawn(AfterCircleTap)
		
		-- Call storyboard callback
		storyboard_callback("NoteTap",
			this.Position,					-- pos
			this.ScoreMultipler, 			-- accuracy
			notedistance,					-- distance
			this.Attribute,					-- attribute
			this.StarNote,					-- is_star
			this.SimulNote,					-- is_simul
			this.TokenNote,					-- is_token
			this.SlideNote					-- is_slide
		)
		
		return
	end
	
	-- We don't want someone accidentally tap it while it's in long distance
	if notedistance <= NoteAccuracy[4][2] then
		if notedistance <= NoteAccuracy[1][2] then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
			
			this.ScoreMultipler = 1
			this.Audio.Perfect:play()
			
			Note.Perfect = Note.Perfect + 1
		elseif notedistance <= NoteAccuracy[2][2] then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Great
			
			this.ScoreMultipler = 0.88
			this.Audio.Great:play()
			
			Note.Great = Note.Great + 1
		elseif notedistance <= NoteAccuracy[3][2] then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Good
			DEPLS.Routines.ComboCounter.Reset = true
			
			this.ScoreMultipler = 0.8
			this.Audio.Good:play()
			
			Note.Good = Note.Good + 1
		else
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Bad
			DEPLS.Routines.ComboCounter.Reset = true
			
			this.ScoreMultipler = 0.4
			this.Audio.Bad:play()
			
			Note.Bad = Note.Bad + 1
		end
		
		DEPLS.Routines.PerfectNode.Replay = true
		
		if DEPLS.Routines.ComboCounter.Reset and this.StarImage then
			this.Audio.StarExplode:play()
			-- TODO: play star explode effect
		end
		
		local AfterCircleTap = DEPLS.Routines.CircleTapEffect.Create(this.FirstCircle[1], this.FirstCircle[2], 255, 255, 255)
		EffectPlayer.Spawn(AfterCircleTap)
		
		this.Delete = true
		
		-- Call storyboard callback
		storyboard_callback("NoteTap",
			this.Position,					-- pos
			this.ScoreMultipler, 			-- accuracy
			notedistance,					-- distance
			this.Attribute,					-- attribute
			this.StarNote,					-- is_star
			this.SimulNote,					-- is_simul
			this.TokenNote,					-- is_token
			this.SlideNote					-- is_slide
		)
	end
end

--! @brief LongNoteObject Update routine
--! @param this NoteObject
--! @param deltaT Delta-time between frame, in milliseconds
function LongNoteObject.Update(this, deltaT)
	local direction = this.Direction
	local NotesSpeed = DEPLS.NotesSpeed
	local ElapsedTime = DEPLS.ElapsedTime - this.ZeroAccuracyTime + NotesSpeed
	
	if this.TouchID == nil then
		-- The note isn't in tapping state
		this.FirstCircle[1] = this.NoteposDiff[1] * ElapsedTime / NotesSpeed + 480
		this.FirstCircle[2] = this.NoteposDiff[2] * ElapsedTime / NotesSpeed + 160
		this.CircleScale = ElapsedTime / NotesSpeed
	else
		this.FirstCircle[1] = this.CenterIdol[1]
		this.FirstCircle[2] = this.CenterIdol[2]
		this.CircleScale = 1
	end
	
	-- If it's not pressed/holded for long time, and it's beyond miss range, make it miss
	do
		local cmp = this.TouchID and this.SecondCircle or this.FirstCircle
		local cmp2 = this.TouchID and NotesSpeed + this.ZeroAccuracyEndNote or NotesSpeed
		
		if ElapsedTime >= cmp2 then
			local notedistance = distance(cmp[1] - this.CenterIdol[1], cmp[2] - this.CenterIdol[2])
			
			if notedistance >= NoteAccuracy[5][2] then
				DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Miss
				DEPLS.Routines.PerfectNode.Replay = true
				DEPLS.Routines.ComboCounter.Reset = true
				this.ScoreMultipler = 0
				this.ScoreMultipler2 = 0
				this.Delete = true
				Note.Miss = Note.Miss + 1
				
				storyboard_callback("LongNoteTap",
					cmp == this.SecondCircle,		-- release
					this.Position,					-- pos
					0, 								-- accuracy (miss)
					notedistance,					-- distance
					this.Attribute,					-- attribute
					this.SimulNoteImage				-- is_simul
				)
				return
			end
		end
	end
	
	if -this.ZeroAccuracyEndNote + ElapsedTime >= 0 then
		-- Spawn end note circle
		local EndNoteElapsedTime = DEPLS.ElapsedTime - (this.ZeroAccuracyTime + this.ZeroAccuracyEndNote) + NotesSpeed
		
		this.SecondCircle[1] = this.NoteposDiff[1] * EndNoteElapsedTime / NotesSpeed + 480
		this.SecondCircle[2] = this.NoteposDiff[2] * EndNoteElapsedTime / NotesSpeed + 160
		this.EndCircleScale = EndNoteElapsedTime / NotesSpeed
	end
	
	-- First position
	this.Vert[4][1] = math.floor((this.FirstCircle[1] + (this.CircleScale * 62) * math.cos(direction)) + 0.5)		-- x
	this.Vert[4][2] = math.floor((this.FirstCircle[2] + (this.CircleScale * 62) * math.sin(direction)) + 0.5)		-- y
	-- Second position
	this.Vert[3][1] = math.floor((this.FirstCircle[1] + (this.CircleScale * 62) * math.cos(direction - math.pi)) + 0.5)	-- x
	this.Vert[3][2] = math.floor((this.FirstCircle[2] + (this.CircleScale * 62) * math.sin(direction - math.pi)) + 0.5)	-- y
	-- Third position
	this.Vert[1][1] = math.floor((this.SecondCircle[1] + (this.EndCircleScale * 62) * math.cos(direction - math.pi)) + 0.5)	-- x
	this.Vert[1][2] = math.floor((this.SecondCircle[2] + (this.EndCircleScale * 62) * math.sin(direction - math.pi)) + 0.5)	-- y
	-- Fourth position
	this.Vert[2][1] = math.floor((this.SecondCircle[1] + (this.EndCircleScale * 62) * math.cos(direction)) + 0.5)		-- x
	this.Vert[2][2] = math.floor((this.SecondCircle[2] + (this.EndCircleScale * 62) * math.sin(direction)) + 0.5)		-- y
	
	this.LongNoteMesh:setVertices(this.Vert)
end

--! @brief LongNoteObject draw routine
--! @param this NoteObject
function LongNoteObject.Draw(this)
	local NoteImage
	local graphics = love.graphics
	local setColor = love.graphics.setColor
	local draw = love.graphics.draw
	
	-- Draw note trail
	setBlendMode("add")
	setColor(255, 255, this.TouchID and 64 or 255, DEPLS.LiveOpacity)
	draw(this.LongNoteMesh)
	
	setBlendMode("alpha")
	setColor(255, 255, 255, DEPLS.LiveOpacity)
	draw(this.NoteImage, this.FirstCircle[1], this.FirstCircle[2], 0, this.CircleScale, this.CircleScale, 64, 64)
	
	-- Draw simultaneous note bar if it is
	if this.SimulNoteImage then
		draw(this.SimulNoteImage, this.FirstCircle[1], this.FirstCircle[2], 0, this.CircleScale, this.CircleScale, 64, 64)
	end
	
	local draw_endcircle = this.EndCircleScale > 0
	-- Draw end note trail if it is
	if draw_endcircle then
		draw(this.EndNoteImage, this.SecondCircle[1], this.SecondCircle[2], 0, this.EndCircleScale, this.EndCircleScale, 64, 64)
	end
	
	if DEPLS.DebugNoteDistance then
		local printf = graphics.print
		local notedistance = distance(this.FirstCircle[1] - this.CenterIdol[1], this.FirstCircle[2] - this.CenterIdol[2])
		
		setColor(0, 0, 0, 255)
		printf(("%.2f"):format(notedistance), this.FirstCircle[1], this.FirstCircle[2])
		setColor(255, 255, 255, 255)
		printf(("%.2f"):format(notedistance), this.FirstCircle[1] + 1, this.FirstCircle[2] + 1)
		
		if draw_endcircle then
			notedistance = distance(this.SecondCircle[1] - this.CenterIdol[1], this.SecondCircle[2] - this.CenterIdol[2])
			
			setColor(0, 0, 0, 255)
			printf(("%.2f"):format(notedistance), this.SecondCircle[1], this.SecondCircle[2])
			setColor(255, 255, 255, 255)
			printf(("%.2f"):format(notedistance), this.SecondCircle[1] + 1, this.SecondCircle[2] + 1)
		end
	else
		setColor(255, 255, 255, 255)
	end
end

--! @brief LongNoteObject on hold note
--! @param this NoteObject
--! @param touchid Unique touch identified which needs to be same on release
function LongNoteObject.SetTouchID(this, touchid)
	local notedistance = distance(this.FirstCircle[1] - this.CenterIdol[1], this.FirstCircle[2] - this.CenterIdol[2])
	
	if DEPLS.AutoPlay then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
		DEPLS.Routines.PerfectNode.Replay = true
		
		this.ScoreMultipler = 1
		this.TouchID = touchid
		this.Audio.Perfect:play()
		
		Note.Perfect = Note.Perfect + 1

		storyboard_callback("LongNoteTap",
			false,							-- release
			this.Position,					-- pos
			this.ScoreMultipler, 			-- accuracy
			notedistance,					-- distance
			this.Attribute,					-- attribute
			this.SimulNoteImage				-- is_simul
		)
		
		return
	end
	
	-- We don't want someone accidentally tap it while it's in long distance
	if notedistance <= NoteAccuracy[4][2] then
		if notedistance <= NoteAccuracy[1][2] then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
			
			this.ScoreMultipler = 1
			this.Audio.Perfect:play()
			
			Note.Perfect = Note.Perfect + 1
		elseif notedistance <= NoteAccuracy[2][2] then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Great
			this.ScoreMultipler = 0.88
			this.Audio.Great:play()
			
			Note.Great = Note.Great + 1
		elseif notedistance <= NoteAccuracy[3][2] then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Good
			DEPLS.Routines.ComboCounter.Reset = true
			
			this.ScoreMultipler = 0.8
			this.Audio.Good:play()
			
			Note.Good = Note.Good + 1
		else
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Bad
			DEPLS.Routines.ComboCounter.Reset = true
			
			this.ScoreMultipler = 0.4
			this.Audio.Bad:play()
			
			Note.Bad = Note.Bad + 1
		end
		
		DEPLS.Routines.PerfectNode.Replay = true
		this.TouchID = touchid

		storyboard_callback("LongNoteTap",
			false,							-- release
			this.Position,					-- pos
			this.ScoreMultipler, 			-- accuracy
			notedistance,					-- distance
			this.Attribute,					-- attribute
			this.SimulNote					-- is_simul
		)
	end
end

--! @brief LongNoteObject on hold note released
--! @param this NoteObject
--! @param touchid Touch ID passed to SetTouchID before
function LongNoteObject.UnsetTouchID(this, touchid)
	if this.TouchID ~= touchid then return end
	
	local notedistance = distance(this.SecondCircle[1] - this.CenterIdol[1], this.SecondCircle[2] - this.CenterIdol[2])
	local is_miss = false
	
	-- Check if perfect
	if DEPLS.AutoPlay or notedistance <= NoteAccuracy[1][2] then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
		DEPLS.Routines.PerfectNode.Replay = true
		
		this.ScoreMultipler2 = 1
		this.Audio2.Perfect:play()
		
		Note.Perfect = Note.Perfect + 1
	elseif notedistance <= NoteAccuracy[2][2] then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Great
		DEPLS.Routines.PerfectNode.Replay = true
		
		this.ScoreMultipler2 = 0.88
		this.Audio2.Great:play()
		
		Note.Great = Note.Great + 1
	elseif notedistance <= NoteAccuracy[3][2] then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Good
		DEPLS.Routines.PerfectNode.Replay = true
		DEPLS.Routines.ComboCounter.Reset = true
		
		this.ScoreMultipler2 = 0.8
		this.Audio2.Good:play()
		
		Note.Good = Note.Good + 1
	elseif notedistance <= NoteAccuracy[4][2] then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Bad
		DEPLS.Routines.PerfectNode.Replay = true
		DEPLS.Routines.ComboCounter.Reset = true
		
		this.ScoreMultipler2 = 0.4
		this.Audio2.Bad:play()
		
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
		local AfterCircleTap = DEPLS.Routines.CircleTapEffect.Create(this.SecondCircle[1], this.SecondCircle[2], 255, 255, 255)
		EffectPlayer.Spawn(AfterCircleTap)
	end
	
	this.Delete = true
	
	storyboard_callback("LongNoteTap",
		true,							-- release
		this.Position,					-- pos
		this.ScoreMultipler2, 			-- accuracy
		notedistance,					-- distance
		this.Attribute,					-- attribute
		this.SimulNote					-- is_simul
	)
end

--! @brief Add note
--! @param note_data SIF-compilant note data
function Note.Add(note_data)
	Note.NoteRemaining = Note.NoteRemaining + 1
	table.insert(Note[note_data.position], NewNoteObject(note_data))
end

local function initnote_pos(a)
	for i = 1, #Note[a] do
		local obj = Note[a][i]
		
		obj.NoteImage = DEPLS.NoteImageLoader.LoadNoteImage(obj.Attribute, obj.TokenNote, obj.SimulNote, obj.StarNote, obj.SlideNote)
	end
end

--! @brief Loads image for notes
function Note.InitializeImage()
	for i = 1, 9 do
		initnote_pos(i)
	end
end

local ComboCounter = DEPLS.Routines.ComboCounter

--! @brief Function to update the note
--! @param deltaT The delta time
function Note.Update(deltaT)
	local ElapsedTime = DEPLS.ElapsedTime
	local score = 0
	
	for i = 1, 9 do
		local j = 1
		local noteobj = Note[i][j]
		
		while noteobj and ElapsedTime >= noteobj.ZeroAccuracyTime - DEPLS.NotesSpeed do
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
				Note.NoteRemaining = Note.NoteRemaining - 1
				Note.HighestCombo = math.max(ComboCounter.CurrentCombo, Note.HighestCombo)
				
				ComboCounter.Replay = true
			else
				j = j + 1
			end
			
			noteobj = Note[i][j]
		end
	end
	
	if score > 0 then
		DEPLS.AddScore(score)	-- Add score
	end
end

--! Function to draw the note
function Note.Draw()
	local ElapsedTime = DEPLS.ElapsedTime
	
	for i = 1, 9 do
		for j = 1, #Note[i] do
			local noteobj = Note[i][j]
			
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
			Note.NoteRemaining = Note.NoteRemaining - 1
			Note.HighestCombo = math.max(ComboCounter.CurrentCombo, Note.HighestCombo)
			
			ComboCounter.Replay = true
		end
	end
	
	if score > 0 then
		DEPLS.AddScore(score)
	end
end

return Note
