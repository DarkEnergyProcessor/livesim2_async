-- Advanced note management routines.
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

	-- Performance data. Contains list of accuracy for each note
	PerformanceData = {},
	-- Tap timings. Contains list of tap timing for each note (number)
	-- For long note, it's table. [1] is press time, [2] is release time.
	TapTiming = {},

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
	Accuracy = {16, 40, 64, 112, 128},	-- Note accuracy
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
	TimingRotation = math.random(0, 11),	-- Like clock

	-- Flash stuff
	Bomb = Yohane.newFlashFromFilename("flash/live_notes_bomb.flsh", "ef_317"),
	LNFX = Yohane.newFlashFromFilename("flash/live_notes_hold_effect.flsh", "ef_326_effect"),
}

-- Precomputed tables
-- Swing rotation
local SlideRotation = {
	(-math.pi / 2) % (2*math.pi),
	(-3 * math.pi / 8) % (2*math.pi),
	(-math.pi / 4) % (2*math.pi),
	(-math.pi / 8) % (2*math.pi),
	0,
	math.pi / 8,
	math.pi / 4,
	3 * math.pi / 8,
	math.pi / 2
}
-- Long note effect rotation
local LNEffectRotation = {
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
-- Distance vector
local DistanceVector = {}
for i = 1, 9 do
	local dist = DEPLS.Distance(DEPLS.IdolPosition[i][1] + 64 - 480, DEPLS.IdolPosition[i][2] + 64 - 160)
	DistanceVector[i] = {
		(DEPLS.IdolPosition[i][1] + 64 - 480) / dist,
		(DEPLS.IdolPosition[i][2] + 64 - 160) / dist,
		-- Due to some rounding error, the distance is actually 400 (plus-minus) 3
		dist
	}
end
-- Note sound accumulation
local NoteSoundAccumulation = nil
if AquaShine.LoadConfig("NS_ACCUMULATION", 0) == 1 then
	NoteSoundAccumulation = {false, false, false, false}
end

-- Note bomb effect. Using Yohane at the moment.
local NoteBombEffect = {}
NoteBombEffect._common_meta = {__index = NoteBombEffect}

function NoteBombEffect.Create(x, y)
	local out = {}
	out.flash = Note.Bomb:clone()
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
	love.graphics.setColor(1, 1, 1)
	self.flash:draw(self.x, self.y)
end

-- Simultaneous note check
local function _internalSimulCheck(timing_sec, i)
	local j = 1
	local notedata = Note[i][j]

	while notedata ~= nil do
		if
			math.floor(notedata.ZeroAccuracyTime) == math.floor(timing_sec)
		then
			notedata.SimulNote = true
			return true
		end

		j = j + 1
		notedata = Note[i][j]
	end
end

-- Sine interpolation tween
local function sineInterpolation(t, b, c, d)
	return c * math.floor(math.sin(t / d * math.pi) * 100000) / 100000 + b
end

-- Simultaneous note check function
local function checkSimulNote(timing_sec)
	return
		_internalSimulCheck(timing_sec, 1) or
		_internalSimulCheck(timing_sec, 2) or
		_internalSimulCheck(timing_sec, 3) or
		_internalSimulCheck(timing_sec, 4) or
		_internalSimulCheck(timing_sec, 5) or
		_internalSimulCheck(timing_sec, 6) or
		_internalSimulCheck(timing_sec, 7) or
		_internalSimulCheck(timing_sec, 8) or
		_internalSimulCheck(timing_sec, 9)
end

local SlideNoteList = {}
local NoteObject = AquaShine.Class("Livesim2.NoteObject")

-- Create new note object based on SIF note data
function NoteObject:init(noteData, offset)
	offset = offset or 0

	-- Time to tap the note in "PERFECT"
	self.ZeroAccuracyTime = noteData.timing_sec * 1000 + offset
	-- Note speed. Sensible default is provided if note object doesn't provide one.
	self.NoteSpeed = (noteData.speed or (DEPLS.NotesSpeed * 0.001)) * 1000
	-- Elapsed time
	self.Time = math.abs(math.min(self.ZeroAccuracyTime - self.NoteSpeed, 0))
	local earlyPos = self.Time / self.NoteSpeed
	-- Touch identifier
	self.TouchID = nil
	-- Note draw function
	self.NoteFunction = nil
	-- Note attribute
	self.Attribute = tonumber(noteData.notes_attribute)
	-- Idol position
	self.IdolPosition = assert(DEPLS.IdolPosition[noteData.position], "Invalid idol position")
	-- Tap audio. Should really use caching in this case.
	self.Audio = {
		Perfect = DEPLS.Sound.PerfectTap:clone(),
		Great = DEPLS.Sound.GreatTap:clone(),
		Good = DEPLS.Sound.GoodTap:clone(),
		Bad = DEPLS.Sound.BadTap:clone(),
	}
	-- Note opacity
	self.Opacity = 1
	-- Note scale
	self.Scale = 0
	-- Note direction
	self.DirectionVector = DistanceVector[noteData.position]
	-- Note velocity, in pixels/second
	self.Velocity = self.DirectionVector[3] / self.NoteSpeed * 1000
	-- Circle position
	self.Position = {
		480 + self.DirectionVector[1] * self.Time / 1000 * self.Velocity,
		160 + self.DirectionVector[2] * self.Time / 1000 * self.Velocity,
	}
	-- Note distance to tap icon. It's 400 - timingOffset by default
	--self.Distance = self.DirectionVector[3] - DEPLS.TimingOffset - earlyPos * self.Velocity / self.NoteSpeed * 1000
	self.Distance = self.DirectionVector[3] * (1 - earlyPos) - DEPLS.TimingOffset
	-- Swing note
	local noSwingEffect = noteData.effect % 10
	self.SlideNote = (noteData.effect - 1) / 10 >= 1 and noSwingEffect < 4
	-- If it's swing note, add it to queue for later initialization
	if self.SlideNote then
		SlideNoteList[#SlideNoteList + 1] = {noteData, self, Note.TotalNotes}
	end
	-- Hidden/sudden note
	self.HiddenType = DEPLS.OverrideHiddenType or noteData.vanish
	-- Simultaneous note
	self.SimulNote = checkSimulNote(self.ZeroAccuracyTime)

	-- Other internal stuff
	self.LastJudgementIndex = nil
	self.LastJudgementIndex2 = nil
	self.PressTime = nil
	self.ScoreMultipler = nil
	self.ScoreMultipler2 = nil

	if noSwingEffect == 2 then
		-- Token note
		self.TokenNote = true
	elseif noSwingEffect == 4 then
		-- Star note
		self.StarNote = true
		self.Audio.StarExplode = DEPLS.Sound.StarExplode:clone()
	elseif noSwingEffect == 3 then
		-- Long note. Fill "LN" field
		local LN = {}
		LN.ZeroAccuracyEndNote = noteData.effect_value * 1000
		LN.Audio = {
			Perfect = DEPLS.Sound.PerfectTap:clone(),
			Great = DEPLS.Sound.GreatTap:clone(),
			Good = DEPLS.Sound.GoodTap:clone(),
			Bad = DEPLS.Sound.BadTap:clone(),
		}

		-- Create trail mesh vertices
		LN.Vert = {
			{40, 0, 1, 0.0625, 1, 1, 1, 1, 0},
			{40, 0, 1, 0.9375, 1, 1, 1, 1, 0},
			{-1, -1, 0, 0.9375, 1, 1, 1, 1, 0},
			{-1, -1, 0, 0.0625, 1, 1, 1, 1, 0}
		}
		LN.Position = {
			480 + self.DirectionVector[1] * math.max(self.Time - LN.ZeroAccuracyEndNote, 0) / 1000 * self.Velocity,
			160 + self.DirectionVector[2] * math.max(self.Time - LN.ZeroAccuracyEndNote, 0) / 1000 * self.Velocity
		}
		LN.Scale = 0
		LN.Distance = self.Distance + self.DirectionVector[3] * noteData.effect_value / self.NoteSpeed * 1000
		LN.EndNoteImage = DEPLS.Images.Note.NoteEnd
		LN.Mesh = love.graphics.newMesh(4, "strip", "stream")
		LN.Opacity = 1

		LN.Mesh:setTexture(DEPLS.Images.Note.LongNote)
		LN.Rotation = LNEffectRotation[noteData.position] + math.pi/2

		if not(DEPLS.MinimalEffect) then
			LN.LNEffectRotation = LNEffectRotation[noteData.position]
			LN.LNEffect = Note.LNFX:clone()
			LN.LNTrail = 0
			LN.LNTrailTween = tween.new(500, LN, {LNTrail = 1}, sineInterpolation)
		end

		-- Long note marking.
		self.LN = LN
	end

	if not(self.LN) then self.ScoreMultipler2 = 1 end
end

-- Update note object
-- Return true if the object should be destroyed.
function NoteObject:Update(deltaT)
	local dtS = deltaT * 0.001
	self.Time = self.Time + deltaT

	-- Calculate note distance, at it's finest
	self.Distance = self.Distance - self.Velocity * dtS
	if self.LN then self.LN.Distance = self.LN.Distance - self.Velocity * dtS end
	local distCheck = self.TouchID and self.LN.Distance or self.Distance

	-- If it's not pressed, and it's beyond 128px range, make it miss
	if -distCheck > Note.Accuracy[5] then
		DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Miss
		DEPLS.Routines.PerfectNode.Replay = true
		DEPLS.Routines.ComboCounter.Reset = true
		self.ScoreMultipler = 0
		self.ScoreMultipler2 = 0

		if self.StarNote then
			local ef = NoteBombEffect.Create(
				480 + self.DirectionVector[1] * self.DirectionVector[3],
				160 + self.DirectionVector[2] * self.DirectionVector[3]
			)

			EffectPlayer.Spawn(ef)
			self.Audio.StarExplode:play()
		end

		-- Storyboard callback
		if self.LN then
			DEPLS.StoryboardCallback("LongNoteTap",
				not(not(self.TouchID)),  -- release
				self.IdolPosition,       -- pos
				0,                       -- accuracy (miss)
				distCheck,               -- distance
				self.Attribute,          -- attribute
				self.SimulNote,          -- is_simul
				self.SlideNote           -- is_slide
			)
		else
			DEPLS.StoryboardCallback("NoteTap",
				self.IdolPosition,      -- pos
				0,                      -- accuracy (miss)
				self.Distance,          -- distance
				self.Attribute,         -- attribute
				self.StarNote,          -- is_star
				self.SimulNote,         -- is_simul
				self.TokenNote,         -- is_token
				self.SlideNote          -- is_slide
			)
		end

		Note.Miss = Note.Miss + 1
		-- Kill object
		return true
	end

	-- Calculate the note position
	if self.TouchID == nil then
		-- The note isn't in tapping state
		self.Position[1] = self.Position[1] + self.DirectionVector[1] * dtS * self.Velocity
		self.Position[2] = self.Position[2] + self.DirectionVector[2] * dtS * self.Velocity
		self.Scale = math.min(self.Time / self.NoteSpeed, 1)
	else
		self.Position[1] = self.DirectionVector[1] * self.DirectionVector[3] + 480
		self.Position[2] = self.DirectionVector[2] * self.DirectionVector[3] + 160
		self.Scale = 1
		self.Distance = -DEPLS.TimingOffset
	end

	-- Calculate long note position
	if self.LN and self.LN.Distance + DEPLS.TimingOffset < self.DirectionVector[3] then
		self.LN.Position[1] = self.LN.Position[1] + self.DirectionVector[1] * dtS * self.Velocity
		self.LN.Position[2] = self.LN.Position[2] + self.DirectionVector[2] * dtS * self.Velocity
		self.LN.Scale = math.max(math.min((self.Time - self.LN.ZeroAccuracyEndNote) / self.NoteSpeed, 1), 0)
	end

	-- Calculate hidden/sudden opacity if necessary
	if self.HiddenType then
		-- Calculate note distance
		local d1 = self.Distance + DEPLS.TimingOffset

		if self.HiddenType == 1 then
			-- Hidden note
			self.Opacity = math.max(math.min((264 - (400 - d1)) * 0.0125, 1), 0)
		elseif self.HiddenType == 2 then
			-- Sudden note
			self.Opacity = math.max(math.min(((400 - d1) - 160) * 0.0125, 1), 0)
		end

		-- Calculate long note opacity
		if self.LN then
			local d2 = self.LN.Distance + DEPLS.TimingOffset
			if self.HiddenType == 1 then
				-- Hidden note
				self.LN.Opacity = math.max(math.min((264 - (400 - d2)) * 0.0125, 1), 0)
			elseif self.HiddenType == 2 then
				-- Sudden note
				self.LN.Opacity = math.max(math.min(((400 - d2) - 160) * 0.0125, 1), 0)
			end
		end
	end

	-- Long note specific code
	if self.LN then
		-- Calculate vertex
		-- First position
		self.LN.Vert[4][1] = math.floor((self.Position[1] + (self.Scale * 62) * math.cos(self.LN.Rotation)) + 0.5)                 -- x
		self.LN.Vert[4][2] = math.floor((self.Position[2] + (self.Scale * 62) * math.sin(self.LN.Rotation)) + 0.5)                 -- y
		self.LN.Vert[4][8] = self.Opacity
		-- Second position
		self.LN.Vert[3][1] = math.floor((self.Position[1] + (self.Scale * 62) * math.cos(self.LN.Rotation - math.pi)) + 0.5)       -- x
		self.LN.Vert[3][2] = math.floor((self.Position[2] + (self.Scale * 62) * math.sin(self.LN.Rotation - math.pi)) + 0.5)       -- y
		self.LN.Vert[3][8] = self.Opacity
		-- Third position
		self.LN.Vert[1][1] = math.floor((self.LN.Position[1] + (self.LN.Scale * 62) * math.cos(self.LN.Rotation - math.pi)) + 0.5) -- x
		self.LN.Vert[1][2] = math.floor((self.LN.Position[2] + (self.LN.Scale * 62) * math.sin(self.LN.Rotation - math.pi)) + 0.5) -- y
		self.LN.Vert[1][8] = self.LN.Opacity
		-- Fourth position
		self.LN.Vert[2][1] = math.floor((self.LN.Position[1] + (self.LN.Scale * 62) * math.cos(self.LN.Rotation)) + 0.5)           -- x
		self.LN.Vert[2][2] = math.floor((self.LN.Position[2] + (self.LN.Scale * 62) * math.sin(self.LN.Rotation)) + 0.5)           -- y
		self.LN.Vert[2][8] = self.LN.Opacity
		-- Update
		self.LN.Mesh:setVertices(self.LN.Vert)

		-- Update long note trail animation
		if self.TouchID and not(DEPLS.MinimalEffect) then
			self.LN.LNEffect:update(deltaT)

			if self.LN.LNTrailTween:update(deltaT) then
				self.LN.LNTrailTween:reset()
			end
		end
	end
end

-- Draw note object
function NoteObject:Draw()
	-- LN draw is very different compared to single note draw
	-- and non-LN note drawis just 1 line.
	if not(self.LN) then
		return self:NoteFunction()
	end

	-- Draw note trail
	love.graphics.setColor(1, 1, self.TouchID and 0.5 or 1, DEPLS.LiveOpacity * (self.TouchID and self.LN.LNTrail or 1))
	love.graphics.draw(self.LN.Mesh)

	-- Draw end trail circle
	if self.LN.Scale > 0 then
		love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity * self.LN.Opacity)
		love.graphics.draw(self.LN.EndNoteImage, self.LN.Position[1], self.LN.Position[2], 0, self.LN.Scale, self.LN.Scale, 64, 64)
	end

	-- Draw main note
	self:NoteFunction()

	-- Draw LN tap effect
	if not(DEPLS.MinimalEffect) and self.TouchID then
		love.graphics.push()
		love.graphics.translate(self.Position[1], self.Position[2])
		love.graphics.rotate(self.LN.LNEffectRotation)
		-- Yohane needs the color range from 0..255
		self.LN.LNEffect:setOpacity(DEPLS.LiveOpacity * 255)
		self.LN.LNEffect:draw()
		love.graphics.pop()
	end
end

local JudgementMap =   {"Perfect", "Great", "Good", "Bad", "Miss"}
local JudgementScore = {1        , 0.88   , 0.8   , 0.4  , 0     }

-- Internal function to tap note
local function _internalTapNote(note, judgementIndex, incCounter, audio)
	local idx = JudgementMap[judgementIndex]
	local reset = judgementIndex > 2
	DEPLS.Routines.PerfectNode.Image = DEPLS.Images[idx]
	DEPLS.Routines.ComboCounter.Reset = reset

	-- Set score multipler
	if note.ScoreMultipler then
		note.ScoreMultipler2 = JudgementScore[judgementIndex]
	else
		note.ScoreMultipler = JudgementScore[judgementIndex]
	end

	if incCounter then
		local nidx = JudgementMap[math.max(note.LastJudgementIndex or judgementIndex, judgementIndex)]
		Note[nidx] = Note[nidx] + 1
	else
		note.LastJudgementIndex2 = judgementIndex
	end
	note.LastJudgementIndex = judgementIndex

	-- Play audio
	if audio[idx] and (not(NoteSoundAccumulation) or NoteSoundAccumulation[judgementIndex] == false) then
		audio[idx]:play()
		if NoteSoundAccumulation then
			NoteSoundAccumulation[judgementIndex] = true
		end
	end

	-- Play star explode effect. Only applicable for single note
	if note.StarNote and reset then
		local ef = NoteBombEffect.Create(
			480 + note.DirectionVector[1] * note.DirectionVector[3],
			160 + note.DirectionVector[2] * note.DirectionVector[3]
		)

		EffectPlayer.Spawn(ef)
		note.Audio.StarExplode:play()
	end
end

-- Internal function to call storyboard callback
-- Mode, 0 = normal note, 1 = long note press, 2 = long note release
local function _internalTapCallback(note, dist, mode)
	if mode == 0 then
		DEPLS.StoryboardCallback("NoteTap",
			note.IdolPosition,       -- pos
			note.ScoreMultipler,     -- accuracy
			dist,                    -- distance
			note.Attribute,          -- attribute
			note.StarNote,           -- is_star
			note.SimulNote,          -- is_simul
			note.TokenNote,          -- is_token
			note.SlideNote           -- is_slide
		)
		-- Add to performance graph
		Note.PerformanceData[#Note.PerformanceData + 1] = 5 - note.LastJudgementIndex
		-- Tap timing
		Note.TapTiming[#Note.TapTiming + 1] = DEPLS.ElapsedTime
	else
		local r = mode == 2
		local sm = r and note.ScoreMultipler2 or note.ScoreMultipler
		DEPLS.StoryboardCallback("LongNoteTap",
			r,                       -- release
			note.Position,           -- pos
			sm,                      -- accuracy
			dist,                    -- distance
			note.Attribute,          -- attribute
			note.SimulNote,          -- is_simul
			note.SlideNote           -- is_slide
		)

		if r then
			-- If release, add to performance graph
			local avg = ((5 - note.LastJudgementIndex) + (5 - note.LastJudgementIndex2)) * 0.5
			Note.PerformanceData[#Note.PerformanceData + 1] = avg
			-- Tap timing.
			Note.TapTiming[#Note.TapTiming + 1] = {note.PressTime, DEPLS.ElapsedTime}
		else
			-- Track press time
			note.PressTime = DEPLS.ElapsedTime
		end
	end

	if mode == 0 or mode == 2 then
		local AfterCircleTap = DEPLS.Routines.CircleTapEffect.Create(note.Position[1], note.Position[2], 1, 1, 1)
		EffectPlayer.Spawn(AfterCircleTap)
	end
end

-- Set touch ID of note
function NoteObject:SetTouchID(touchID)
	local notedistance = math.abs(touchID == "autoplay" and 1 or self.Distance)
	local isLN = not(not(self.LN))

	-- Don't register tap if it's too far
	if notedistance <= Note.Accuracy[5] then
		local i = self.SlideNote and 1 or 0

		if notedistance <= Note.Accuracy[1+i] or
			(notedistance <= Note.Accuracy[2+i] and Note.YellowTiming.Duration > 0) or
			(notedistance <= Note.Accuracy[3+i] and Note.RedTiming.Duration > 0)
		then
			-- Perfect
			_internalTapNote(self, 1, not(isLN), self.Audio)
		elseif notedistance <= Note.Accuracy[2+i] then
			-- Great
			_internalTapNote(self, 2, not(isLN), self.Audio)
		elseif notedistance <= Note.Accuracy[3+i] then
			-- Good
			_internalTapNote(self, 3, not(isLN), self.Audio)
		else
			-- Bad
			_internalTapNote(self, 4, not(isLN), self.Audio)
		end

		DEPLS.Routines.PerfectNode.Replay = true
		_internalTapCallback(self, notedistance, isLN and 1 or 0)

		if isLN then
			self.TouchID = touchID
		else
			-- Destroy
			return true
		end
	end

	return false
end

-- Unset touch ID (long note release)
function NoteObject:UnsetTouchID(touchID)
	-- Only allow last registered touch ID
	if self.TouchID ~= touchID then return false end
	local notedistance = math.abs(touchID == "autoplay" and 1 or self.LN.Distance)

	-- Check if note is not in 112-128 range (bad-miss range)
	if notedistance <= Note.Accuracy[4] then
		local i = self.SlideNote and 1 or 0

		if notedistance <= Note.Accuracy[1+i] or
			(notedistance <= Note.Accuracy[2+i] and Note.YellowTiming.Duration > 0) or
			(notedistance <= Note.Accuracy[3+i] and Note.RedTiming.Duration > 0)
		then
			-- Perfect
			_internalTapNote(self, 1, true, self.LN.Audio)
		elseif notedistance <= Note.Accuracy[2+i] then
			-- Great
			_internalTapNote(self, 2, true, self.LN.Audio)
		elseif notedistance <= Note.Accuracy[3+i] then
			-- Good
			_internalTapNote(self, 3, true, self.LN.Audio)
		else
			-- Bad
			_internalTapNote(self, 4, true, self.LN.Audio)
		end
	else
		-- Miss
		_internalTapNote(self, 5, true, self.LN.Audio)
	end

	_internalTapCallback(self, notedistance, 2)
	DEPLS.Routines.PerfectNode.Replay = true
	return true
end

-- Add note to current
-- noteData must be SIF-compilant note data
function Note.Add(noteData, offset)
	Note.NoteRemaining = Note.NoteRemaining + 1
	Note.TotalNotes = Note.TotalNotes + 1
	Note[noteData.position][#Note[noteData.position] + 1] = NoteObject(noteData, offset)
end

-- Internal function to initialize note
local function _internalInitNoteForPos(p)
	for i = 1, #Note[p] do
		Note[p][i].NoteFunction = DEPLS.NoteImageLoader.GetNoteImageFunction()
	end
end

function Note.InitializeImage()
	-- Scan swing notes
	for i = 1, #SlideNoteList do
		local swing = SlideNoteList[i]

		if swing[2].Rotation == nil then
			local last_level = swing[1].notes_level
			local last_pos_2 = swing[1].position
			local last_timing = swing[1].timing_sec
			local last_pos = swing[1].position
			local last_obj = swing[2]
			local last_index = swing[3]

			if swing[1].effect == 13 then
				last_timing = last_timing + swing[1].effect_value
			end

			local function applyswing(chainswing)
				last_obj.Rotation = (last_pos - chainswing[1].position > 0 and 0 or math.pi) + SlideRotation[last_pos]

				last_pos_2 = last_pos
				last_timing = chainswing[1].timing_sec
				last_pos = chainswing[1].position
				last_obj = chainswing[2]
				last_index = chainswing[3]

				if chainswing[1].effect == 13 then
					last_timing = last_timing + chainswing[1].effect_value
				end
			end

			for j = i + 1, #SlideNoteList do
				local chainswing = SlideNoteList[j]

				if chainswing[2].Rotation == nil then
					if chainswing[1].notes_level and chainswing[1].notes_level > 1 then
						if chainswing[1].notes_level - last_level == 0 then
							applyswing(chainswing)
						end
					elseif
						chainswing[1].timing_sec + 0.001 >= last_timing and
						math.abs(chainswing[3] - last_index) < 3 and
						math.abs(chainswing[1].position - last_pos) == 1
					then
						applyswing(chainswing)
					end

					if (chainswing[1].effect == 13 and
							chainswing[1].timing_sec  + chainswing[1].effect_value or
							chainswing[1].timing_sec
						) - last_timing > 0.25
					then
						break
					end
				end
			end

			last_obj.Rotation = (last_pos_2 - last_pos > 0 and 0 or math.pi) + SlideRotation[last_pos]
		end
	end

	-- Load images
	for i = 1, 9 do
		_internalInitNoteForPos(i)
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

-- Note management update function
function Note.Update(deltaT)
	local ComboCounter = DEPLS.Routines.ComboCounter
	local ElapsedTime = DEPLS.ElapsedTime
	local score = 0

	-- if note sound accumulation is enabled, clear state
	if NoteSoundAccumulation then
		NoteSoundAccumulation[1] = false
		NoteSoundAccumulation[2] = false
		NoteSoundAccumulation[3] = false
		NoteSoundAccumulation[4] = false
	end

	-- Timing window duration recalculate
	Note.RedTiming.Duration = math.max(Note.RedTiming.Duration - deltaT, 0)
	Note.YellowTiming.Duration = math.max(Note.YellowTiming.Duration - deltaT, 0)

	for i = 1, 9 do
		local j = 1
		local noteobj = Note[i][j]

		while noteobj and ElapsedTime >= noteobj.ZeroAccuracyTime - noteobj.NoteSpeed do
			local delete = noteobj:Update(deltaT)

			-- If autoplay, make it always perfect
			if DEPLS.AutoPlay then
				if ElapsedTime >= noteobj.ZeroAccuracyTime - deltaT and noteobj.TouchID == nil then
					delete = noteobj:SetTouchID("autoplay")
				elseif noteobj.LN and ElapsedTime >= noteobj.LN.ZeroAccuracyEndNote + noteobj.ZeroAccuracyTime - deltaT then
					delete = noteobj:UnsetTouchID("autoplay")
				end
			end

			if delete then
				-- Calculate score and remove
				score = score + DEPLS.ScoreBase * noteobj.ScoreMultipler * noteobj.ScoreMultipler2 * (noteobj.LN and 1.25 or 1) * (noteobj.SlideNote and 0.5 or 1)
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

-- Note management draw
function Note.Draw()
	--love.graphics.push("all")
	for i = 1, 9 do
		for j = 1, #Note[i] do
			local noteobj = Note[i][j]

			-- Only update if it should be spawned
			if DEPLS.ElapsedTime >= noteobj.ZeroAccuracyTime - noteobj.NoteSpeed then
				Note[i][j]:Draw()
			else
				break
			end
		end
	end
	--love.graphics.pop()
end


--! Function to draw the timing icon
function Note.TimingIconDraw()
	-- In terms of simplicity, switching between red/yellow timing icon is
	-- performance penalty in the GPU because the drawcalls aren't batched.
	-- But does doing 2x loop will cause performance penalty in the CPU instead?
	-- Well, I'm gonna do the second option anyway.

	love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity)

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
				if noteobj:UnsetTouchID(touchid) then
					score = score + DEPLS.ScoreBase * noteobj.ScoreMultipler * noteobj.ScoreMultipler2 * (noteobj.LN and 1.25 or 1) * (noteobj.SlideNote and 0.5 or 1)
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

	if ElapsedTime >= noteobj.ZeroAccuracyTime - noteobj.NoteSpeed then
		if noteobj:SetTouchID(touchid) then
			score = score + DEPLS.ScoreBase * noteobj.ScoreMultipler * noteobj.ScoreMultipler2 * (noteobj.SlideNote and 0.5 or 1)
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
