-- Single Note Object
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine, Note, NoteObject = ...
local love = require("love")
local SingleNoteObject = NoteObject:extend("Livesim2.SingleNoteObject")

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

local function angle_from(x1, y1, x2, y2)
	return math.atan2(y2 - y1, x2 - x1) - math.pi / 2
end

--! @brief Create new single note object
--! @param DEPLS Live Simulator: 2 entry point handle
--! @param note_data SIF note data
function SingleNoteObject.init(this, DEPLS, note_data)
	assert(DEPLS.__name == "Livesim2.Livesim2", "bad argument #1 to 'SingleNoteObject' (Livesim2.Livesim2 expected)")

	local note_speed = (note_data.speed or (DEPLS.NotesSpeed * 0.001)) * 1000
	local note_speed_limit = math.max(note_speed, 800)
	this.ZeroAccuracyTime = note_data.timing_sec * 1000 + offset
	this.Attribute = tonumber(note_data.notes_attribute)
	this.Position = note_data.position
	this.Audio = {
			Perfect = DEPLS.Sound.PerfectTap:clone(),
			Great = DEPLS.Sound.GreatTap:clone(),
			Good = DEPLS.Sound.GoodTap:clone(),
			Bad = DEPLS.Sound.BadTap:clone()
	}
	this.NotesSpeed = note_speed
	this.FirstCircle = {480, 160}
	this.NoteAccuracy = {
		DEPLS.NoteAccuracy[1] / 325 * note_speed_limit,
		DEPLS.NoteAccuracy[2] / 325 * note_speed_limit,
		DEPLS.NoteAccuracy[3] / 325 * note_speed_limit,
		DEPLS.NoteAccuracy[4] / 325 * note_speed_limit,
		DEPLS.NoteAccuracy[5] / 325 * note_speed_limit,
		InvV = note_speed_limit / 400
	}
	this.Opacity = 1

	local idolpos = assert(DEPLS.IdolPosition[note_data.position], "Invalid idol position")
	local note_effect = note_data.effect % 10
	
	-- Idol position
	this.NoteposDiff = {idolpos[1] - 416, idolpos[2] - 96}
	this.CenterIdol = {idolpos[1] + 64, idolpos[2] + 64}
	this.Direction = angle_from(480, 160, this.CenterIdol[1], this.CenterIdol[2])
	
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
end