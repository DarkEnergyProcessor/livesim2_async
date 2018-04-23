-- Live Simulator: 2 Note management routines
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local DEPLS, AquaShine = ...
local love = require("love")
local EffectPlayer = require("effect_player")
local Yohane = require("Yohane")
local tween = require("tween")
local Note = {
	-- Note queue
	{}, {}, {}, {}, {}, {}, {}, {}, {},

	-- Judgement
	Perfect = 0,
	Great = 0,
	Good = 0,
	Bad = 0,
	Miss = 0,

	-- Note info
	NoteRemaining = 0,
	HighestCombo = 0,
	TotalNotes = 0,

	-- Timing system
	YellowTiming = {
		Image = AquaShine.LoadImage("assets/image/live/tl_skill_02.png"),
		Duration = 0,
		Rotation = 0
	},
	RedTiming = {
		Image = AquaShine.LoadImage("assets/image/live/tl_skill_01.png"),
		Duration = 0,
		Rotation = 0
	},
	TimingRotation = math.random(0, 11)	-- Like clock
}

-- Import some data from DEPLS
local ScoreBase = DEPLS.ScoreBase
local distance = DEPLS.Distance
local angle_from = DEPLS.AngleFrom
local storyboard_callback = DEPLS.StoryboardCallback
local floor = math.floor
local notes_bomb = Yohane.newFlashFromFilename("flash/live_notes_bomb.flsh", "ef_317")
local hold_effect = Yohane.newFlashFromFilename("flash/live_notes_hold_effect.flsh", "ef_326_effect")

local NoteSoundAccumulation = AquaShine.LoadConfig("NS_ACCUMULATION", 0) == 1
local NoteSoundAccumulationState = {false, false, false, false}

-- Precomputed tables
local FullRot = 2 * math.pi
local PredefinedSlideRotation = {
	(-math.pi / 2) % FullRot,
	(-3 * math.pi / 8) % FullRot,
	(-math.pi / 4) % FullRot,
	(-math.pi / 8) % FullRot,
	0,
	math.pi / 8,
	math.pi / 4,
	3 * math.pi / 8,
	math.pi / 2
}
local PredefinedLNEffectRotation = {
	-math.pi,
	-7 * math.pi / 8,
	-3 * math.pi / 4,
	-5 * math.pi / 8,
	-math.pi / 2,
	-3 * math.pi / 8,
	-math.pi / 4,
	-math.pi / 8,
	0
}

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

local function internal_simulnote_check(timing_sec, i, is_swing)
	local j = 1
	local notedata = Note[i][j]

	while notedata ~= nil do
		if
			floor(notedata.ZeroAccuracyTime) == floor(timing_sec) and
			not(notedata.SlideNote and is_swing)
		then
			notedata.SimulNote = true
			return true
		end

		j = j + 1
		notedata = Note[i][j]
	end
end

local function sine_interpolation(t, b, c, d)
	return c * math.floor(math.sin(t / d * math.pi) * 100000) / 100000 + b
end

--! @brief Check if there's another note with same timing
--! @param timing_sec The note timing to check
--! @param swing Is the note we're comparing to is swing note?
--! @returns `true` if there's one, false otherwise
--! @note This function modifies the note object that already queued if necessary
local function CheckSimulNote(timing_sec, swing)
	return
		internal_simulnote_check(timing_sec, 1, swing) or
		internal_simulnote_check(timing_sec, 2, swing) or
		internal_simulnote_check(timing_sec, 3, swing) or
		internal_simulnote_check(timing_sec, 4, swing) or
		internal_simulnote_check(timing_sec, 5, swing) or
		internal_simulnote_check(timing_sec, 6, swing) or
		internal_simulnote_check(timing_sec, 7, swing) or
		internal_simulnote_check(timing_sec, 8, swing) or
		internal_simulnote_check(timing_sec, 9, swing)
end

local SingleNoteObject = {}
local LongNoteObject = {}
local SlideNoteList = {}

--! @brief Creates new SingleNoteObject
--! @param note_data SIF-compilant note data
--! @returns New NoteObject
local function NewNoteObject(note_data, offset)
	offset = offset or 0
	
	local note_speed = (note_data.speed or (DEPLS.NotesSpeed * 0.001)) * 1000
	local note_speed_limit = math.max(note_speed, 800)
	local noteobj = {
		ZeroAccuracyTime = note_data.timing_sec * 1000 + offset,
		Attribute = tonumber(note_data.notes_attribute),
		Position = note_data.position,
		Audio = {
			Perfect = DEPLS.Sound.PerfectTap:clone(),
			Great = DEPLS.Sound.GreatTap:clone(),
			Good = DEPLS.Sound.GoodTap:clone(),
			Bad = DEPLS.Sound.BadTap:clone(),
		},
		NotesSpeed = note_speed,
		FirstCircle = {480, 160},
		NoteAccuracy = {
			DEPLS.NoteAccuracy[1] / 325 * note_speed_limit,
			DEPLS.NoteAccuracy[2] / 325 * note_speed_limit,
			DEPLS.NoteAccuracy[3] / 325 * note_speed_limit,
			DEPLS.NoteAccuracy[4] / 325 * note_speed_limit,
			DEPLS.NoteAccuracy[5] / 325 * note_speed_limit,
			InvV = note_speed_limit / 400
		},
		Opacity = 1
	}
	local idolpos = assert(DEPLS.IdolPosition[note_data.position], "Invalid idol position")
	local note_effect = note_data.effect % 10
	
	-- Idol position
	noteobj.NoteposDiff = {idolpos[1] - 416, idolpos[2] - 96}
	noteobj.CenterIdol = {idolpos[1] + 64, idolpos[2] + 64}
	noteobj.Direction = angle_from(480, 160, noteobj.CenterIdol[1], noteobj.CenterIdol[2])
	
	-- Swing note
	noteobj.SlideNote = (note_data.effect - 1) / 10 >= 1 and note_effect < 4
	
	-- Hidden/sudden note
	noteobj.HiddenType = note_data.vanish
	
	-- If it's swing note, add it to queue for later initialization
	if noteobj.SlideNote then
		local newnotedata = Yohane.CopyTable(note_data)
		
		SlideNoteList[#SlideNoteList + 1] = newnotedata
		newnotedata.noteobj = noteobj
		newnotedata.index = Note.TotalNotes
	end
	
	-- Simultaneous check
	if CheckSimulNote(noteobj.ZeroAccuracyTime, noteobj.SlideNote) then
		noteobj.SimulNote = true
	end
	
	if note_effect == 2 then
		-- Token note
		noteobj.TokenNote = true
	elseif note_effect == 4 then
		-- Star note
		noteobj.StarNote = true
	elseif note_effect == 3 then
		-- Long note. Use LongNoteObject metatable
		noteobj.Audio2 = {
			Perfect = DEPLS.Sound.PerfectTap:clone(),
			Great = DEPLS.Sound.GreatTap:clone(),
			Good = DEPLS.Sound.GoodTap:clone(),
			Bad = DEPLS.Sound.BadTap:clone(),
		}
		
		-- Create trail mesh vertices
		local mulcol = AquaShine.NewLove and 1 or 255
		noteobj.Vert = {}
		noteobj.SecondCircle = {480, 160}
		noteobj.ZeroAccuracyEndNote = note_data.effect_value * 1000
		noteobj.EndNoteImage = DEPLS.Images.Note.NoteEnd
		noteobj.LongNoteMesh = love.graphics.newMesh(4, "strip", "stream")
		noteobj.EndCircleScale = 0
		noteobj.MulCol = mulcol
		
		noteobj.Vert[1] = {40, 0, 1, 0.0625, 1 * mulcol, 1 * mulcol, 1 * mulcol, 1 * mulcol, 0}
		noteobj.Vert[2] = {40, 0, 1, 0.9375, 1 * mulcol, 1 * mulcol, 1 * mulcol, 1 * mulcol, 0}
		noteobj.Vert[3] = {-1, -1, 0, 0.9375, 1 * mulcol, 1 * mulcol, 1 * mulcol, 1 * mulcol, 0}
		noteobj.Vert[4] = {-1, -1, 0, 0.0625, 1 * mulcol, 1 * mulcol, 1 * mulcol, 1 * mulcol, 0}
		noteobj.Opacity2 = 1
		
		noteobj.LongNoteMesh:setTexture(DEPLS.Images.Note.LongNote)
		
		if not(DEPLS.MinimalEffect) then
			noteobj.LNEffectRotation = PredefinedLNEffectRotation[note_data.position]
			noteobj.LNEffect = hold_effect:clone()
			noteobj.LNTrail = 0
			noteobj.LNTrailTween = tween.new(500, noteobj, {LNTrail = 1}, sine_interpolation)
		end
		
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
	local NotesSpeed = this.NotesSpeed
	local ElapsedTime = DEPLS.ElapsedTime - this.ZeroAccuracyTime + NotesSpeed
	
	this.FirstCircle[1] = this.NoteposDiff[1] * (ElapsedTime / NotesSpeed) + 480
	this.FirstCircle[2] = this.NoteposDiff[2] * (ElapsedTime / NotesSpeed) + 160
	this.CircleScale = math.min(ElapsedTime / NotesSpeed, 1)
	
	-- Calculate note accuracy
	local notedistance = distance(this.FirstCircle[1] - this.CenterIdol[1], this.FirstCircle[2] - this.CenterIdol[2])
	local noteaccuracy = this.NoteAccuracy.InvV * notedistance
	
	-- Calculate hidden/sudden opacity
	if this.HiddenType == 1 then
		-- Hidden note
		this.Opacity = math.max(math.min((264 - (400 - notedistance)) * 0.0125, 1), 0)
	elseif this.HiddenType == 2 then
		-- Sudden note
		this.Opacity = math.max(math.min(((400 - notedistance) - 160) * 0.0125, 1), 0)
	end

	-- If it's not pressed, and it's beyond miss range, make it miss
	if ElapsedTime >= NotesSpeed and noteaccuracy >= this.NoteAccuracy[5] then
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
			noteaccuracy,					-- distance
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

function SingleNoteObject.Draw(this)
	return this:NoteFunction()
end

function SingleNoteObject.SetTouchID(this, touchid)
	local notedistance = this.NoteAccuracy.InvV * distance(this.FirstCircle[1] - this.CenterIdol[1], this.FirstCircle[2] - this.CenterIdol[2])
	
	if DEPLS.AutoPlay then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
		DEPLS.Routines.PerfectNode.Replay = true
		this.ScoreMultipler = 1
		Note.Perfect = Note.Perfect + 1
		this.Delete = true
		
		if not(NoteSoundAccumulation) or NoteSoundAccumulationState[1] == false then
			this.Audio.Perfect:play()
			NoteSoundAccumulationState[1] = true
		end
		
		local AfterCircleTap = DEPLS.Routines.CircleTapEffect.Create(this.FirstCircle[1], this.FirstCircle[2], 1, 1, 1)
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
	if notedistance <= this.NoteAccuracy[5] then
		local Idx = this.SlideNote and 1 or 0
		
		if notedistance <= this.NoteAccuracy[1 + Idx] or
			(notedistance <= this.NoteAccuracy[2 + Idx] and Note.YellowTiming.Duration > 0) or
			(notedistance <= this.NoteAccuracy[3 + Idx] and Note.RedTiming.Duration > 0)
		then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
			this.ScoreMultipler = 1
			Note.Perfect = Note.Perfect + 1
			
			if not(NoteSoundAccumulation) or NoteSoundAccumulationState[1] == false then
				this.Audio.Perfect:play()
				NoteSoundAccumulationState[1] = true
			end
		elseif notedistance <= this.NoteAccuracy[2 + Idx] then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Great
			this.ScoreMultipler = 0.88
			Note.Great = Note.Great + 1
			
			if not(NoteSoundAccumulation) or NoteSoundAccumulationState[2] == false then
				this.Audio.Great:play()
				NoteSoundAccumulationState[2] = true
			end
		elseif notedistance <= this.NoteAccuracy[3 + Idx] then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Good
			DEPLS.Routines.ComboCounter.Reset = true
			this.ScoreMultipler = 0.8
			Note.Good = Note.Good + 1
			
			if not(NoteSoundAccumulation) or NoteSoundAccumulationState[3] == false then
				this.Audio.Good:play()
				NoteSoundAccumulationState[3] = true
			end
		else
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Bad
			DEPLS.Routines.ComboCounter.Reset = true
			this.ScoreMultipler = 0.4
			Note.Bad = Note.Bad + 1
			
			if not(NoteSoundAccumulation) or NoteSoundAccumulationState[4] == false then
				this.Audio.Bad:play()
				NoteSoundAccumulationState[4] = true
			end
		end
		
		DEPLS.Routines.PerfectNode.Replay = true
		
		if DEPLS.Routines.ComboCounter.Reset and this.StarImage then
			local ef = NoteBombEffect.Create(this.CenterIdol[1], this.CenterIdol[2])
			
			EffectPlayer.Spawn(ef)
			this.Audio.StarExplode:play()
		end
		
		local AfterCircleTap = DEPLS.Routines.CircleTapEffect.Create(this.FirstCircle[1], this.FirstCircle[2], 1, 1, 1)
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
	local NotesSpeed = this.NotesSpeed
	local ElapsedTime = DEPLS.ElapsedTime - this.ZeroAccuracyTime + NotesSpeed
	
	if this.TouchID == nil then
		-- The note isn't in tapping state
		this.FirstCircle[1] = this.NoteposDiff[1] * ElapsedTime / NotesSpeed + 480
		this.FirstCircle[2] = this.NoteposDiff[2] * ElapsedTime / NotesSpeed + 160
		this.CircleScale = math.min(ElapsedTime / NotesSpeed, 1)
	else
		this.FirstCircle[1] = this.CenterIdol[1]
		this.FirstCircle[2] = this.CenterIdol[2]
		this.CircleScale = 1
	end
	
	-- Calculate hidden/sudden opacity if necessary
	if this.HiddenType then
		-- Calculate note accuracy
		local nd1 = distance(this.FirstCircle[1] - this.CenterIdol[1], this.FirstCircle[2] - this.CenterIdol[2])
		local nd2 = distance(this.SecondCircle[1] - this.CenterIdol[1], this.SecondCircle[2] - this.CenterIdol[2])
		
		if this.HiddenType == 1 then
			-- Hidden note
			this.Opacity = math.max(math.min((264 - (400 - nd1)) * 0.0125, 1), 0)
			this.Opacity2 = math.max(math.min((264 - (400 - nd2)) * 0.0125, 1), 0)
		elseif this.HiddenType == 2 then
			-- Sudden note
			this.Opacity = math.max(math.min(((400 - nd1) - 160) * 0.0125, 1), 0)
			this.Opacity2 = math.max(math.min(((400 - nd2) - 160) * 0.0125, 1), 0)
		end
	end
	
	-- If it's not pressed/holded for long time, and it's beyond miss range, make it miss
	do
		local cmp = this.TouchID and this.SecondCircle or this.FirstCircle
		local cmp2 = this.TouchID and NotesSpeed + this.ZeroAccuracyEndNote or NotesSpeed
		
		if ElapsedTime >= cmp2 then
			local nd = this.NoteAccuracy.InvV * distance(cmp[1] - this.CenterIdol[1], cmp[2] - this.CenterIdol[2])
			
			if nd > this.NoteAccuracy[5] then
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
					nd / this.NoteAccuracy.InvV,	-- distance
					this.Attribute,					-- attribute
					this.SimulNote,					-- is_simul
					this.SlideNote					-- is_slide
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
		this.EndCircleScale = math.min(EndNoteElapsedTime / NotesSpeed, 1)
	end
	
	local alpha1 = this.Opacity * this.MulCol
	local alpha2 = this.Opacity2 * this.MulCol
	-- First position
	this.Vert[4][1] = math.floor((this.FirstCircle[1] + (this.CircleScale * 62) * math.cos(direction)) + 0.5)		-- x
	this.Vert[4][2] = math.floor((this.FirstCircle[2] + (this.CircleScale * 62) * math.sin(direction)) + 0.5)		-- y
	this.Vert[4][8] = alpha1
	-- Second position
	this.Vert[3][1] = math.floor((this.FirstCircle[1] + (this.CircleScale * 62) * math.cos(direction - math.pi)) + 0.5)	-- x
	this.Vert[3][2] = math.floor((this.FirstCircle[2] + (this.CircleScale * 62) * math.sin(direction - math.pi)) + 0.5)	-- y
	this.Vert[3][8] = alpha1
	-- Third position
	this.Vert[1][1] = math.floor((this.SecondCircle[1] + (this.EndCircleScale * 62) * math.cos(direction - math.pi)) + 0.5)	-- x
	this.Vert[1][2] = math.floor((this.SecondCircle[2] + (this.EndCircleScale * 62) * math.sin(direction - math.pi)) + 0.5)	-- y
	this.Vert[1][8] = alpha2
	-- Fourth position
	this.Vert[2][1] = math.floor((this.SecondCircle[1] + (this.EndCircleScale * 62) * math.cos(direction)) + 0.5)		-- x
	this.Vert[2][2] = math.floor((this.SecondCircle[2] + (this.EndCircleScale * 62) * math.sin(direction)) + 0.5)		-- y
	this.Vert[2][8] = alpha2
	
	this.LongNoteMesh:setVertices(this.Vert)
	
	if this.TouchID and not(DEPLS.MinimalEffect) then
		this.LNEffect:update(deltaT)
		
		if this.LNTrailTween:update(deltaT) then
			this.LNTrailTween:reset()
		end
	end
end

--! @brief LongNoteObject draw routine
--! @param this NoteObject
function LongNoteObject.Draw(this)
	-- Draw note trail
	love.graphics.setColor(1, 1, this.TouchID and 0.5 or 1, DEPLS.LiveOpacity * (this.TouchID and this.LNTrail or 1))
	love.graphics.draw(this.LongNoteMesh)
	
	-- Draw note object
	--[[
	setColor(1, 1, 1, DEPLS.LiveOpacity * this.Opacity)
	draw(this.NoteImage, this.FirstCircle[1], this.FirstCircle[2], this.Rotation or 0, this.CircleScale, this.CircleScale, 64, 64)
	
	-- Draw simultaneous note bar if it is
	if this.SimulNoteImage then
		draw(this.SimulNoteImage, this.FirstCircle[1], this.FirstCircle[2], 0, this.CircleScale, this.CircleScale, 64, 64)
	end
	]]
	this:NoteFunction()
	
	local draw_endcircle = this.EndCircleScale > 0
	-- Draw end note trail if it is
	if draw_endcircle then
		love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity * this.Opacity2)
		love.graphics.draw(this.EndNoteImage, this.SecondCircle[1], this.SecondCircle[2], 0, this.EndCircleScale, this.EndCircleScale, 64, 64)
	end
	
	love.graphics.setColor(1, 1, 1)
	if this.TouchID and not(DEPLS.MinimalEffect) then
		love.graphics.push()
		love.graphics.translate(this.FirstCircle[1], this.FirstCircle[2])
		love.graphics.rotate(this.LNEffectRotation)
		-- Yohane needs the color range from 0..255
		this.LNEffect:setOpacity(DEPLS.LiveOpacity * 255)
		this.LNEffect:draw()
		love.graphics.pop()
	end
	
	love.graphics.setColor(1, 1, 1)
end

--! @brief LongNoteObject on hold note
--! @param this NoteObject
--! @param touchid Unique touch identification which needs to be same on release
function LongNoteObject.SetTouchID(this, touchid)
	local notedistance = this.NoteAccuracy.InvV * distance(this.FirstCircle[1] - this.CenterIdol[1], this.FirstCircle[2] - this.CenterIdol[2])
	
	if DEPLS.AutoPlay then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
		DEPLS.Routines.PerfectNode.Replay = true
		
		this.ScoreMultipler = 1
		this.TouchID = touchid
		Note.Perfect = Note.Perfect + 1
		
		if not(NoteSoundAccumulation) or NoteSoundAccumulationState[1] == false then
			this.Audio.Perfect:play()
			NoteSoundAccumulationState[1] = true
		end

		storyboard_callback("LongNoteTap",
			false,							-- release
			this.Position,					-- pos
			this.ScoreMultipler, 			-- accuracy
			notedistance,					-- distance
			this.Attribute,					-- attribute
			this.SimulNote,					-- is_simul
			this.SlideNote					-- is_slide
		)
		
		return
	end
	
	-- We don't want someone accidentally tap it while it's in long distance
	if notedistance <= this.NoteAccuracy[5] then
		local Idx = this.SlideNote and 1 or 0
		
		if notedistance <= this.NoteAccuracy[1 + Idx] or
			(notedistance <= this.NoteAccuracy[2 + Idx] and Note.YellowTiming.Duration > 0) or
			(notedistance <= this.NoteAccuracy[3 + Idx] and Note.RedTiming.Duration > 0)
		then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
			this.ScoreMultipler = 1
			Note.Perfect = Note.Perfect + 1
			
			if not(NoteSoundAccumulation) or NoteSoundAccumulationState[1] == false then
				this.Audio.Perfect:play()
				NoteSoundAccumulationState[1] = true
			end
		elseif notedistance <= this.NoteAccuracy[2 + Idx] or (this.SlideNote and notedistance <= this.NoteAccuracy[3]) then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Great
			this.ScoreMultipler = 0.88
			Note.Great = Note.Great + 1
			
			if not(NoteSoundAccumulation) or NoteSoundAccumulationState[2] == false then
				this.Audio.Great:play()
				NoteSoundAccumulationState[2] = true
			end
		elseif notedistance <= this.NoteAccuracy[3 + Idx] or (this.SlideNote and notedistance <= this.NoteAccuracy[4]) then
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Good
			DEPLS.Routines.ComboCounter.Reset = true
			this.ScoreMultipler = 0.8
			Note.Good = Note.Good + 1
			
			if not(NoteSoundAccumulation) or NoteSoundAccumulationState[3] == false then
				this.Audio.Good:play()
				NoteSoundAccumulationState[3] = true
			end
		else
			DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Bad
			DEPLS.Routines.ComboCounter.Reset = true
			this.ScoreMultipler = 0.4
			Note.Bad = Note.Bad + 1
			
			if not(NoteSoundAccumulation) or NoteSoundAccumulationState[4] == false then
				this.Audio.Bad:play()
				NoteSoundAccumulationState[4] = true
			end
		end
		
		DEPLS.Routines.PerfectNode.Replay = true
		this.TouchID = touchid

		storyboard_callback("LongNoteTap",
			false,							-- release
			this.Position,					-- pos
			this.ScoreMultipler, 			-- accuracy
			notedistance,					-- distance
			this.Attribute,					-- attribute
			this.SimulNote,					-- is_simul
			this.SlideNote					-- is_slide
		)
	end
end

--! @brief LongNoteObject on hold note released
--! @param this NoteObject
--! @param touchid Touch ID passed to SetTouchID before
function LongNoteObject.UnsetTouchID(this, touchid)
	if this.TouchID ~= touchid then return end
	
	local notedistance = this.NoteAccuracy.InvV * distance(this.SecondCircle[1] - this.CenterIdol[1], this.SecondCircle[2] - this.CenterIdol[2])
	local is_miss = false
	
	-- Check if perfect
	if
		DEPLS.AutoPlay or
		notedistance <= this.NoteAccuracy[1] or
		(notedistance <= this.NoteAccuracy[2] and Note.YellowTiming.Duration > 0) or
		(notedistance <= this.NoteAccuracy[3] and Note.RedTiming.Duration > 0)
	then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
		this.ScoreMultipler2 = 1
		Note.Perfect = Note.Perfect + 1
		
		if not(NoteSoundAccumulation) or NoteSoundAccumulationState[1] == false then
			this.Audio2.Perfect:play()
			NoteSoundAccumulationState[1] = true
		end
	elseif notedistance <= this.NoteAccuracy[2] then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Great
		this.ScoreMultipler2 = 0.88
		Note.Great = Note.Great + 1
		
		if not(NoteSoundAccumulation) or NoteSoundAccumulationState[2] == false then
			this.Audio2.Great:play()
			NoteSoundAccumulationState[2] = true
		end
	elseif notedistance <= this.NoteAccuracy[3] then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Good
		DEPLS.Routines.ComboCounter.Reset = true
		this.ScoreMultipler2 = 0.8
		Note.Good = Note.Good + 1
		
		if not(NoteSoundAccumulation) or NoteSoundAccumulationState[3] == false then
			this.Audio2.Good:play()
			NoteSoundAccumulationState[3] = true
		end
	elseif notedistance <= this.NoteAccuracy[4] then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Bad
		DEPLS.Routines.ComboCounter.Reset = true
		this.ScoreMultipler2 = 0.4
		Note.Bad = Note.Bad + 1
		
		if not(NoteSoundAccumulation) or NoteSoundAccumulationState[4] == false then
			this.Audio2.Bad:play()
			NoteSoundAccumulationState[4] = true
		end
	else
		Note.Miss = Note.Miss + 1
		is_miss = true
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Miss
		DEPLS.Routines.ComboCounter.Reset = true
		this.ScoreMultipler2 = 0
	end
	
	DEPLS.Routines.PerfectNode.Replay = true
	
	if not(is_miss) then
		local AfterCircleTap = DEPLS.Routines.CircleTapEffect.Create(this.SecondCircle[1], this.SecondCircle[2], 1, 1, 1)
		EffectPlayer.Spawn(AfterCircleTap)
	end
	
	this.Delete = true
	
	storyboard_callback("LongNoteTap",
		true,							-- release
		this.Position,					-- pos
		this.ScoreMultipler2, 			-- accuracy
		notedistance,					-- distance
		this.Attribute,					-- attribute
		this.SimulNote,					-- is_simul
		this.SlideNote					-- is_slide
	)
end

--! @brief Add note
--! @param note_data SIF-compilant note data
function Note.Add(note_data, offset)
	Note.NoteRemaining = Note.NoteRemaining + 1
	Note.TotalNotes = Note.TotalNotes + 1
	table.insert(Note[note_data.position], NewNoteObject(note_data, offset))
end

local function initnote_pos(a)
	for i = 1, #Note[a] do
		local obj = Note[a][i]
		
		--obj.NoteImage = DEPLS.NoteImageLoader.LoadNoteImage(obj.Attribute, a, obj.TokenNote, obj.SimulNote, obj.StarNote, obj.SlideNote, obj.Rotation)
		obj.NoteFunction = DEPLS.NoteImageLoader.GetNoteImageFunction()
	end
end

--! @brief Loads image for notes
function Note.InitializeImage()
	-- Scan swing notes
	for i = 1, #SlideNoteList do
		local swing = SlideNoteList[i]
		
		if swing.noteobj.Rotation == nil then
			local last_level = swing.notes_level
			local last_pos_2 = swing.position
			local last_timing = swing.timing_sec
			local last_pos = swing.position
			local last_obj = swing.noteobj
			local last_index = swing.index
			
			if swing.effect == 13 then
				last_timing = last_timing + swing.effect_value
			end
			
			local function applyswing(chainswing)
				last_obj.Rotation = (last_pos - chainswing.position > 0 and 0 or math.pi) + PredefinedSlideRotation[last_pos]
				
				last_pos_2 = last_pos
				last_timing = chainswing.timing_sec
				last_pos = chainswing.position
				last_obj = chainswing.noteobj
				last_index = chainswing.index
				
				if chainswing.effect == 13 then
					last_timing = last_timing + chainswing.effect_value
				end
			end
			
			for j = i + 1, #SlideNoteList do
				local chainswing = SlideNoteList[j]
				
				if chainswing.noteobj.Rotation == nil then
					if chainswing.notes_level and chainswing.notes_level > 1 then
						if chainswing.notes_level - last_level == 0 then
							applyswing(chainswing)
						end
					elseif
						chainswing.timing_sec + 0.001 >= last_timing and
						math.abs(chainswing.index - last_index) < 3 and
						math.abs(chainswing.position - last_pos) == 1
					then
						applyswing(chainswing)
					end

					if (chainswing.effect == 13 and
							chainswing.timing_sec  + chainswing.effect_value or
							chainswing.timing_sec
						) - last_timing > 0.25
					then
						break
					end
				end
			end

			last_obj.Rotation = (last_pos_2 - last_pos > 0 and 0 or math.pi) + PredefinedSlideRotation[last_pos]
		end
	end
	
	-- Load images
	for i = 1, 9 do
		initnote_pos(i)
	end
end

--! @brief Set red timing (Timing Window++ skill) duration
--! @param dur Duration in milliseconds
--! @note If the current duration is higher than `dur`, this function has no effect
function Note.TimingRed(dur)
	if Note.RedTiming.Duration == 0 then
		-- Retrieve new rotation sequence
		Note.RedTiming.Rotation = Note.TimingRotation
		Note.TimingRotation = (Note.TimingRotation + 1) % 12
	end
	
	Note.RedTiming.Duration = math.max(Note.RedTiming.Duration, dur)
end

--! @brief Set yellow timing (Timing Window+ skill) duration
--! @param dur Duration in milliseconds
--! @note If the current duration is higher than `dur`, this function has no effect
function Note.TimingYellow(dur)
	if Note.YellowTiming.Duration == 0 then
		-- Retrieve new rotation sequence
		Note.YellowTiming.Rotation = Note.TimingRotation
		Note.TimingRotation = (Note.TimingRotation + 1) % 12
	end
	
	Note.YellowTiming.Duration = math.max(Note.YellowTiming.Duration, dur)
end

--! @brief Function to update the note
--! @param deltaT The delta time
function Note.Update(deltaT)
	local ComboCounter = DEPLS.Routines.ComboCounter
	local ElapsedTime = DEPLS.ElapsedTime
	local score = 0
	
	-- if note sound accumulation is enabled, clear state
	if NoteSoundAccumulation then
		NoteSoundAccumulationState[1] = false
		NoteSoundAccumulationState[2] = false
		NoteSoundAccumulationState[3] = false
		NoteSoundAccumulationState[4] = false
	end
	
	-- Timing window duration recalculate
	Note.RedTiming.Duration = math.max(Note.RedTiming.Duration - deltaT, 0)
	Note.YellowTiming.Duration = math.max(Note.YellowTiming.Duration - deltaT, 0)
	
	for i = 1, 9 do
		local j = 1
		local noteobj = Note[i][j]
		
		while noteobj and ElapsedTime >= noteobj.ZeroAccuracyTime - noteobj.NotesSpeed do
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
				score = score + ScoreBase * noteobj.ScoreMultipler * noteobj.ScoreMultipler2 * (noteobj.UnsetTouchID and 1.25 or 1) * (noteobj.SlideNote and 0.5 or 1)
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
	love.graphics.push("all")
	
	for i = 1, 9 do
		for j = 1, #Note[i] do
			local noteobj = Note[i][j]
			
			-- Only update if it should be spawned
			if ElapsedTime >= noteobj.ZeroAccuracyTime - noteobj.NotesSpeed then
				Note[i][j]:Draw()
			else
				break
			end
		end
	end
	
	love.graphics.pop()
end

--! Function to draw the timing icon
function Note.TimingIconDraw()
	-- In terms of simplicity, switching between red/yellow timing icon is
	-- performance penalty in the GPU because the drawcalls aren't batched.
	-- But does doing 2x loop will cause performance penalty in the CPU instead?
	-- Well, I'm gonna do the second option anyway.
	
	love.graphics.setColor(1, 1, 1)
	
	-- Draw red icon
	if Note.RedTiming.Duration > 0 then
		local xp = math.sin(math.pi * Note.RedTiming.Rotation / 6) * 64
		local yp = -math.cos(math.pi * Note.RedTiming.Rotation / 6) * 64
		
		for i = 1, 9 do
			love.graphics.draw(
				Note.RedTiming.Image,
				DEPLS.IdolPosition[i][1] + 64 + xp,
				DEPLS.IdolPosition[i][2] + 64 + yp,
				0, 1, 1, 16, 16
			)
		end
	end
	
	-- Draw yellow icon
	if Note.YellowTiming.Duration > 0 then
		local xp = math.sin(math.pi * Note.YellowTiming.Rotation / 6) * 64
		local yp = math.cos(math.pi * Note.YellowTiming.Rotation / 6) * 64
		
		for i = 1, 9 do
			love.graphics.draw(
				Note.YellowTiming.Image,
				DEPLS.IdolPosition[i][1] + 64 + xp,
				DEPLS.IdolPosition[i][2] + 64 + yp,
				0, 1, 1, 16, 16
			)
		end
	end
end

--! @brief Set the note touch
--! @param pos The idol position. nil if `release` is true
--! @param touchid The touch ID
--! @param release Is this a touch release message?
--! @param previous The previous position, used for slide notes (or nil)
function Note.SetTouch(pos, touchid, release, previous)
	if DEPLS.AutoPlay then return end
	
	local ElapsedTime = DEPLS.ElapsedTime
	local ComboCounter = DEPLS.Routines.ComboCounter
	local noteobj
	local score = 0
	
	if release then
		for i = 1, 9 do
			noteobj = Note[i][1]
			
			if noteobj and noteobj.TouchID == touchid then
				noteobj:UnsetTouchID(touchid)
				
				if noteobj.Delete then
					score = score + ScoreBase * noteobj.ScoreMultipler * noteobj.ScoreMultipler2 * (noteobj.UnsetTouchID and 1.25 or 1) * (noteobj.SlideNote and 0.5 or 1)
					table.remove(Note[i], 1)
				
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
		end
		
		if score > 0 then
			DEPLS.AddScore(score)
		end
		return
	end
	
	noteobj = Note[pos][1]
	
	if not(noteobj) or (not(noteobj.SlideNote) and previous) then
		return
	end
	
	Note.SetTouch(previous, touchid, true)
	
	if ElapsedTime >= noteobj.ZeroAccuracyTime - noteobj.NotesSpeed then
		noteobj:SetTouchID(touchid)

		if noteobj.Delete then
			score = score + ScoreBase * noteobj.ScoreMultipler * noteobj.ScoreMultipler2 * (noteobj.SlideNote and 0.5 or 1)
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
		elseif ComboCounter.Reset == true then
			ComboCounter.CurrentCombo = 0
			ComboCounter.Reset = false
		end
	end

	if score > 0 then
		DEPLS.AddScore(score)
	end
end

return Note
