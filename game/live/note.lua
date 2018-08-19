-- Note management
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local bit = require("bit")
local love = require("love")
local rendering = require("rendering")
local Luaoop = require("libs.Luaoop")
local vector = require("libs.hump.vector")
local setting = require("setting")
local color = require("color")
local note = {}

local colDiv = love._version >= "11.0" and 1/255 or 1

local function region(x, y, s)
	s = s or 128
	return love.graphics.newQuad(x * 128, y * 128, s, s, 2048, 2048)
end

note.quadRegion = {
	-- Utils
	region(15, 15), -- star icon
	region(14, 15), -- token icon
	region(13, 15), -- end note icon
	-- Default note frame
	region(0, 0), -- smile (4)
	region(1, 0), -- pure
	region(2, 0), -- cool
	region(3, 0), -- blue
	region(4, 0), -- yellow
	region(5, 0), -- orange
	region(6, 0), -- pink
	region(7, 0), -- purple
	region(8, 0), -- gray
	region(9, 0), -- rainbow
	region(10, 0), -- black
	region(11, 0), -- swing
	region(12, 0), -- simultaneous mark
	-- Neon note base frame
	region(13, 0), -- smile (17)
	region(14, 0), -- pure
	region(15, 0), -- cool
	region(3, 1), -- blue
	region(5, 1), -- yellow
	region(4, 1), -- orange
	region(9, 1), -- pink
	region(11, 1), -- purple
	region(10, 1), -- gray
	region(15, 1), -- rainbow
	region(0, 2), -- black
	region(14, 2), -- simultaneous
	-- Neon note base frame with swing
	region(0, 1), -- smile (29)
	region(1, 1), -- pure
	region(2, 1), -- cool
	region(6, 1), -- blue
	region(8, 1), -- yellow
	region(7, 1), -- orange
	region(12, 1), -- pink
	region(14, 1), -- purple
	region(13, 1), -- gray
	region(1, 2), -- rainbow
	region(2, 2), -- black
	-- Neon note swing icon only
	region(3, 2), -- smile (40)
	region(4, 2), -- pure
	region(5, 2), -- cool
	region(9, 2), -- blue
	region(8, 2), -- yellow
	region(7, 2), -- orange
	region(6, 2), -- pink
	region(10, 2), -- purple
	region(11, 2), -- gray
	region(12, 2), -- rainbow
	region(13, 2), -- black
	-- Matte note base frame
	region(15, 2), -- smile (51)
	region(0, 3), -- pure
	region(1, 3), -- cool
	region(5, 3), -- blue
	region(4, 3), -- yellow
	region(3, 3), -- orange
	region(2, 3), -- pink
	region(6, 3), -- purple
	region(7, 3), -- gray
	region(8, 3), -- rainbow
	region(9, 3), -- black
	region(14, 3, 256), -- simultaneous
	-- Matte note swing icon only
	region(10, 3), -- smile (63)
	region(11, 3), -- pure
	region(12, 3), -- cool
	region(2, 4), -- blue
	region(1, 4), -- yellow
	region(0, 4), -- orange
	region(13, 3), -- pink
	region(3, 4), -- purple
	region(4, 4), -- gray
	region(5, 4), -- rainbow
	region(6, 4), -- black
}

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

	-- Other properties
	-- opacity
	self.opacity = 1

	-- Note style needs additional parsing
	local noteStyle = setting.get("NOTE_STYLE")
	-- bit pattern for note style: 00000000 iiiiiiss ssssffff ffpppppp
	--
	-- Any values there range from 1-63 (0 is invalid)
	-- 1 = default, 2 = neon, 3 = matter
	--
	-- p = note style preset. If 63 then see below
	-- f = note style frame (base)
	-- s = note style swing
	-- i = note style simultaneous mark
	local preset = bit.band(noteStyle, 63)
	local MAX_NOTE_STYLE = 4 -- const
	assert(preset ~= 63 and preset > 0 and preset < MAX_NOTE_STYLE, "Invalid note style")
	if preset == 63 then
		local value = bit.band(bit.rshift(noteStyle, 6), 63)
		self.noteStyleFrame = assert(value > 0 and value < MAX_NOTE_STYLE and value, "Invalid note style frame")
		value = bit.band(bit.rshift(noteStyle, 12), 63)
		self.noteStyleSwing = assert(value > 0 and value < MAX_NOTE_STYLE and value, "Invalid note style swing")
		value = bit.band(bit.rshift(noteStyle, 18), 63)
		self.noteStyleSimul = assert(value > 0 and value < MAX_NOTE_STYLE and value, "Invalid note style simul")
	else
		self.noteStyleFrame, self.noteStyleSwing, self.noteStyleSimul = preset, preset, preset
	end
end

function noteManager:getLayer(attribute, simul, swing, token, star)
	local layer = {}
	local defCol = color.white
	if bit.band(attribute, 15) == 15 then
		-- Custom Beatmap Festival extension attribute.
		-- Bit pattern: rrrrrrrr rggggggg ggbbbbbb bbb0nnnn
		-- If n is 15 then color is r, g, b
		defCol = {
			bit.band(bit.rshift(attribute, 23), 511) * colDiv,
			bit.band(bit.rshift(attribute, 14), 511) * colDiv,
			bit.band(bit.rshift(attribute, 5), 511) * colDiv,
		}
		attribute = 9
	end

	---------------------
	-- Base Note Frame --
	---------------------
	-- Default note style
	if self.noteStyleFrame == 1 then
		layer[#layer + 1] = 3 + attribute

		if token then
			layer[#layer + 1] = 2
		end
		if star then
			layer[#layer + 1] = 1
		end
	-- Neon note style
	elseif self.noteStyleFrame == 2 then
		-- There's special case for neon note style.
		-- If frame and swing is neon, then don't use the base frame
		if not(swing and self.noteStyleSwing == 2) then
			layer[#layer + 1] = 16 + attribute

			if token then
				layer[#layer + 1] = 2
			end
			if star then
				layer[#layer + 1] = 1
			end
		end
	-- Matte note style
	elseif self.noteStyleFrame == 3 then
		layer[#layer + 1] = 50 + attribute

		if token then
			layer[#layer + 1] = 2
		end
		if star then
			layer[#layer + 1] = 1
		end
	end
	----------------------
	-- Swing note style --
	----------------------
	if swing then
		-- Default note style
		if self.noteStyleSwing == 1 then
			layer[#layer + 1] = 15
		-- Neon note style
		elseif self.noteStyleSwing == 2 then
			if self.noteStyleFrame == 2 then
				-- The token & star layer is not set, so check here.
				layer[#layer + 1] = 28 + attribute

				if token then
					layer[#layer + 1] = 2
				end
				if star then
					layer[#layer + 1] = 1
				end
			else
				-- The frame is either default or matte.
				layer[#layer + 1] = 39 + attribute
			end
		-- Matte note style
		elseif self.noteStyleSwing == 3 then
			layer[#layer + 1] = 62 + attribute
		end
	end
	-----------------------------
	-- Simultaneous note style --
	-----------------------------
	if simul then
		-- Default note style
		if self.noteStyleSimul == 1 then
			layer[#layer + 1] = 16
		-- Neon note style
		elseif self.noteStyleSimul == 2 then
			layer[#layer + 1] = 28
		-- Matte note style
		elseif self.noteStyleSimul == 3 then
			layer[#layer + 1] = 62
		end
	end

	layer.color = defCol
	return layer
end

local function isSwingLayer(layerIndex)
	return
		layerIndex == 15 or
		(layerIndex >= 29 and layerIndex <= 50) or
		(layerIndex >= 63 and layerIndex <= 73)
end

local function isUncolorableLayer(layerIndex)
	return
		(layerIndex >= 1 and layerIndex <= 3) or
		layerIndex == 16 or
		layerIndex == 28 or
		layerIndex == 62
end

function noteManager:drawNote(layers, position, scale, rotation)
	for i = 1, #layers do
		local layer = layers[i]
		local quad = note.quadRegion[layer]
		if isUncolorableLayer(layer) then
			rendering.setColor(color.get(255, 255, 255, self.opacity))
		else
			rendering.setColor(color.get(layers.color[1], layers.color[2], layers.color[3], self.opacity))
		end

		local w, h = select(3, quad:getViewport())
		rendering.draw(
			self.noteImage, quad, -- texture, quad
			position.x, position.y, -- position
			isSwingLayer(layer) and rotation or 0, -- rotation
			scale, scale, -- scaling
			-w*0.5, -h*0.5 -- offset
		)
	end
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
	return "judgement string"
end

function baseMovingNote.draw()
	error("pure virtual method 'draw'", 2)
end

function baseMovingNote.tap()
	error("pure virtual method 'tap'", 2)
	-- 2nd return is whetever the note should be destroyed
	return "judgement string", true or false
end

function baseMovingNote.unTap()
	error("pure virtual method 'unTap'", 2)
	return "judgement string"
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
	self.position = param.noteSpawningPosition + self.elapsedTime / self.noteSpeed * self.distance * self.direction
	-- time needed to mark note as miss
	self.missTime = self.noteSpeed * self.accuracy.miss[2]
	-- time needed to make the note able to receive keypress
	self.eventTime = self.noteSpeed * self.accuracy.miss[1]
	-- token flag
	self.token = definition.effect == 2
	-- star note
	self.star = definition.effect == 4
	-- swing note
	self.swing = definition.effect > 10
	-- swing note group
	self.swingGroup = self.swing and definition.notes_level or 0
	-- simultaneous note
	self.simul = false -- set later
	-- swing rotation
	self.rotation = 0 -- set later
	-- vanish type (1 = hidden, 2 = sudden)
	self.vanishType = definition.vanish or 0
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
	return self.manager:drawNote(self.noteLayers, self.position, self.elapsedTime / self.noteSpeed, self.rotation)
end

-----------------------------
-- Long Moving Note object --
-----------------------------

local longMovingNote = Luaoop.class("livesim2.LongMovingNote", normalMovingNote)

function longMovingNote:__construct(definition, param)
	normalMovingNote.__construct(self, definition, param)

	-- Long note properties
	-- long note vertices
	self.lnVertices = {
		{40, 0, 1, 0.0625, 255 * colDiv, 255 * colDiv, 255 * colDiv, 255 * colDiv},
		{40, 0, 1, 0.9375, 255 * colDiv, 255 * colDiv, 255 * colDiv, 255 * colDiv},
		{-1, -1, 0, 0.9375, 255 * colDiv, 255 * colDiv, 255 * colDiv, 255 * colDiv},
		{-1, -1, 0, 0.0625, 255 * colDiv, 255 * colDiv, 255 * colDiv, 255 * colDiv},
	}
	-- long note mesh
	self.lnMesh = love.graphics.newMesh(4, "strip", "stream")
	-- long note target time
	self.lnTargetTime = self.targetTime + definition.effect_value
	-- end note position
	local ndist = math.max(self.noteSpeed - self.lnTargetTime, 0)
	self.lnPosition = param.noteSpawningPosition + ndist / self.noteSpeed * self.distance * self.direction
	-- long note rotation
	self.lnRotation = param.lnRotation[definition.position] + math.pi/2
	-- additional data for full effect mode
	if not(param.minimalEffect) then
		-- long note tap effect
		self.lnFlashEffect = param:getLongNoteAnimation()
		-- flash rotation
		self.lnFlashRotation = param.lnRotation[definition.position]
	end
end

----------------
-- Public API --
----------------

function note.newNoteManager(param)
	return noteManager(param)
end

return note
