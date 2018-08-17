-- Note management
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local rendering = require("rendering")
local Luaoop = require("libs.Luaoop")
local vector = require("libs.hump.vector")
local setting = require("setting")
local note = {}

-------------------------
-- Note Manager object --
-------------------------

local noteManager = Luaoop.class("livesim2.NoteManager")

function noteManager:__construct(param)
	-- note image used
	self.noteImage = param.image
	-- note speed
	self.noteSpeed = param.noteSpeed or setting.get("NOTE_SPEED") * 0.001
	-- list of notes
	self.notesList = {}
	-- list of notes, ordered by event handling
	self.notesListByEvent = {}
	-- list of notes, ordered by their draw order
	self.notesListByDraw = {}
	-- on note triggered
	self.callback = function(object, lane, position, judgement, releaseFlag)
		-- object: note object
		-- lane: desired idol position (1 is rightmost, 9 is leftmost)
		-- position: position (in pixels) as hump.vector object
		-- judgement: judgement string (perfect, great, good, bad, miss)
		-- releaseFlag: release note information (0 = normal note, 1 = hold note, 2 = release note)
	end
	-- lane direction vector
	self.laneDirection = {}
	-- lane distance length
	self.laneDistance = {}
	-- per-lane accuracy
	self.laneAccuracy = {}
	for i = 1, 9 do
		self.laneDirection[i] = vector(param.lane[i] - param.noteSpawningPosition):normalizeInplace()
		local dist = param.noteSpawningPosition:distance(param.lane[i])
		self.laneDistance[i] = dist
		self.laneAccuracy[i] = {
			perfect = {
				(dist - param.accuracy[1]) / dist,
				(dist + param.accuracy[1]) / dist
			},
			great = {
				(dist - param.accuracy[2]) / dist,
				(dist + param.accuracy[2]) / dist
			},
			good = {
				(dist - param.accuracy[3]) / dist,
				(dist + param.accuracy[3]) / dist
			},
			bad = {
				(dist - param.accuracy[4]) / dist,
				(dist + param.accuracy[4]) / dist
			},
			miss = {
				(dist - param.accuracy[5]) / dist,
				(dist + param.accuracy[5]) / dist
			},
		}
	end
	-- timing offset
	self.timingOffset = 0 -- TODO
	-- note spawning position
	self.noteSpawningPosition = param.noteSpawningPosition
end

-----------------------------
-- Base Moving Note object --
-----------------------------

local baseMovingNote = Luaoop.class("livesim2.BaseMovingNote")

function baseMovingNote.__construct()
	error("attempt to construct abstract class 'BaseMovingNote'", 2)
end

function baseMovingNote.update()
	error("pure virtual method 'update'", 2)
	return -- judgement string
end

function baseMovingNote.draw()
	error("pure virtual method 'draw'", 2)
end

-------------------------------
-- Normal Moving Note object --
-------------------------------

local normalMovingNote = Luaoop.class("livesim2.NormalMovingNote", baseMovingNote)

function normalMovingNote:__construct(definition, param)
	-- Note target time
	self.targetTime = definition.timing_sec + param.timingOffset
	-- Note speed
	self.noteSpeed = param.noteSpeed / (definition.speed or 1)
	-- Note spawn time
	self.spawnTime = self.targetTime - self.noteSpeed
	-- Elapsed time. If it's equal to self.noteSpeed then it's "perfect" judgement
	self.elapsedTime = math.max(self.noteSpeed - self.targetTime, 0)
	-- note distance to tap lane
	self.distance = param.laneDistance[definition.position]
	-- note direction to tap lane
	self.direction = param.laneDirection[definition.position]
	-- note accuracy timing
	self.accuracy = param.laneAccuracy[definition.position]
	-- note current position
	self.position = param.noteSpawningPosition + (self.elapsedTime / self.noteSpeed) * self.distance * self.direction
	-- time needed to mark note as miss
	self.missTime = self.noteSpeed * self.accuracy.miss[2]
	-- Current note manager
	self.manager = param
end

function normalMovingNote:update(dt)
	self.elapsedTime = self.elapsedTime + dt
	self.position = self.position + dt * self.distance * self.direction

	if self.elapsedTime >= self.missTime then
		-- Mark note as "miss"
		return "miss"
	end
end

function normalMovingNote:draw()
	-- TODO
end

----------------
-- Public API --
----------------

function note.newNoteManager(param)
	return noteManager(param)
end

return note
