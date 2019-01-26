-- Note management
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local bit = require("bit")
local love = require("love")
local Yohane = require("libs.Yohane")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local assetCache = require("asset_cache")
local setting = require("setting")
local util = require("util")

local note = {}

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
	region(15, 0), -- pure
	region(14, 0), -- cool
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
	region(2, 1), -- pure
	region(1, 1), -- cool
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

local swingRotationTable = {
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

local redTimingQuad = love.graphics.newQuad(64, 0, 32, 32, 128, 64)
local yellowTimingQuad = love.graphics.newQuad(32, 0, 32, 32, 128, 64)

-------------------------
-- Note Manager object --
-------------------------

local noteManager = Luaoop.class("Livesim2.NoteManager")

function noteManager:__construct(param)
	-- luacheck: push no unused args
	-- current elapsed time
	self.elapsedTime = 0
	-- note image used
	self.noteImage = param.image
	-- long note trail image
	self.lnTrailImage = param.trailImage
	-- note speed
	self.noteSpeed = param.noteSpeed or setting.get("NOTE_SPEED") * 0.001
	-- list of notes
	self.notesList = {}
	-- list of notes, ordered by event handling
	self.notesListByEvent = {}
	-- list of notes, ordered by their draw order
	self.notesListByDraw = {}
	-- list of swing notes
	self.swingNotesList = {}
	-- touch input note list
	self.touchInput = {}
	-- touch input position list
	self.touchTrack = {}
	-- on note triggered
	self.callback = param.callback or function(object, lane, position, judgement, releaseFlag)
		-- object: note object
		-- lane: desired idol position (1 is rightmost, 9 is leftmost)
		-- position: position (in pixels) as hump.vector object
		-- judgement: judgement string (perfect, great, good, bad, miss)
		-- releaseFlag: release note information (0 = normal note, 1 = hold note, 2 = release note)
	end
	-- on note spawned
	self.spawn = param.spawn or function(object, lane)
		-- object: note object
		-- lane: desired idol position (1 is rightmost, 9 is leftmost)
	end
	-- timing offset
	self.timingOffset = param.timingOffset or 0
	-- lane data
	self.lane = param.lane
	-- lane direction vector
	self.laneDirection = {}
	-- lane distance length
	self.laneDistance = {}
	-- long note rotation
	self.lnRotation = {}
	-- per-lane accuracy
	self.laneAccuracy = {}
	for i = 1, 9 do
		local di = param.lane[i] - param.noteSpawningPosition
		local dist = di:len()
		self.laneDirection[i] = di:normalized()
		self.lnRotation[i] = math.atan2(di.y, di.x) + math.pi
		self.laneDistance[i] = dist
		self.laneAccuracy[i] = {
			exact = dist,
			perfect = {
				(dist - param.accuracy[1] + self.timingOffset) / dist,
				(dist + param.accuracy[1] + self.timingOffset) / dist
			},
			great = {
				(dist - param.accuracy[2] + self.timingOffset) / dist,
				(dist + param.accuracy[2] + self.timingOffset) / dist
			},
			good = {
				(dist - param.accuracy[3] + self.timingOffset) / dist,
				(dist + param.accuracy[3] + self.timingOffset) / dist
			},
			bad = {
				(dist - param.accuracy[4] + self.timingOffset) / dist,
				(dist + param.accuracy[4] + self.timingOffset) / dist
			},
			miss = {
				(dist - param.accuracy[5] + self.timingOffset) / dist,
				(dist + param.accuracy[5] + self.timingOffset) / dist
			}
		}
	end
	-- beatmap offset
	self.beatmapOffset = param.beatmapOffset or 0
	-- note spawning position
	self.noteSpawningPosition = param.noteSpawningPosition
	-- hitbox rotation
	self.hitboxRotation = {0, 0, 0, 0, 0, 0, 0, 0, 0}
	for i = 1, 9 do
		local x = self.noteSpawningPosition - self.lane[i]
		self.hitboxRotation[i] = math.atan2(x.y, x.x)
	end
	-- flash object
	self.lnFlashAnimation = Yohane.newFlashFromFilename("flash/live_notes_hold_effect.flsh", "ef_326_effect")
	-- opacity
	self.opacity = 1
	-- autoplay flag
	self.autoplay = not(not(param.autoplay))
	-- timing window image
	self.timingImage = assetCache.loadImage("assets/image/live/skill_icon.png", {mipmaps = true})
	-- timing window++ parameters
	self.redTimingWindow = {duration = 0, rotation = 0}
	-- timing window+ parameters
	self.yellowTimingWindow = {duration = 0, rotation = 0}
	-- timing window next rotation
	self.timingWindowRotation = math.random(0, 11)

	-- Note style needs additional parsing
	local noteStyle = setting.get("NOTE_STYLE")
	-- bit pattern for note style: 00000000 iiiiiiss ssssffff ffpppppp
	--
	-- Any values there range from 1-63 (0 is invalid)
	-- 1 = default, 2 = neon, 3 = matte
	--
	-- p = note style preset. If 63 then:
	-- f = note style frame (base)
	-- s = note style swing
	-- i = note style simultaneous mark
	local preset = bit.band(noteStyle, 63)
	local MAX_NOTE_STYLE = 3 -- const
	assert(preset == 63 or (preset > 0 and preset <= MAX_NOTE_STYLE), "Invalid note style")
	if preset == 63 then
		local value = bit.band(bit.rshift(noteStyle, 6), 63)
		self.noteStyleFrame = assert(value > 0 and value <= MAX_NOTE_STYLE and value, "Invalid note style frame")
		value = bit.band(bit.rshift(noteStyle, 12), 63)
		self.noteStyleSwing = assert(value > 0 and value <= MAX_NOTE_STYLE and value, "Invalid note style swing")
		value = bit.band(bit.rshift(noteStyle, 18), 63)
		self.noteStyleSimul = assert(value > 0 and value <= MAX_NOTE_STYLE and value, "Invalid note style simul")
	else
		self.noteStyleFrame, self.noteStyleSwing, self.noteStyleSimul = preset, preset, preset
	end
	-- luacheck: pop
end

local white = {255, 255, 255}

function noteManager:getLayer(attribute, simul, swing, token, star)
	local layer = {}
	local defCol = white
	if bit.band(attribute, 15) == 15 then
		-- Custom Beatmap Festival extension attribute.
		-- Bit pattern: rrrrrrrr rggggggg ggbbbbbb bbb0nnnn
		-- If n is 15 then color is r, g, b
		defCol = {
			bit.band(bit.rshift(attribute, 23), 511),
			bit.band(bit.rshift(attribute, 14), 511),
			bit.band(bit.rshift(attribute, 5), 511),
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
		if swing then
			if self.noteStyleSwing == 2 then
				layer[#layer + 1] = 28 + attribute
			else
				layer[#layer + 1] = 16 + attribute
			end
		else
			layer[#layer + 1] = 16 + attribute
		end

		if token then
			layer[#layer + 1] = 2
		end
		if star then
			layer[#layer + 1] = 1
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
		elseif self.noteStyleSwing == 2 and self.noteStyleFrame ~= 2 then
			-- The base frame is either default or matte.
			layer[#layer + 1] = 39 + attribute
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

function noteManager:drawNote(layers, opacity, position, scale, rotation)
	for i = 1, #layers do
		local layer = layers[i]
		local quad = note.quadRegion[layer]
		if isUncolorableLayer(layer) then
			love.graphics.setColor(color.get(255, 255, 255, self.opacity * opacity))
		else
			love.graphics.setColor(color.compat(layers.color[1], layers.color[2], layers.color[3], self.opacity * opacity))
		end

		local w, h = select(3, quad:getViewport())
		love.graphics.draw(
			self.noteImage, quad, -- texture, quad
			position.x, position.y, -- position
			isSwingLayer(layer) and rotation or 0, -- rotation
			scale, scale, -- scaling
			w*0.5, h*0.5 -- offset
		)
	end
end

function noteManager:getLongNoteAnimation()
	return self.lnFlashAnimation:clone()
end

function noteManager:getYellowTimingWindow()
	return self.yellowTimingWindow.duration
end

function noteManager:setYellowTimingWindow(duration)
	if self.yellowTimingWindow.duration == 0 then
		-- Retrieve new rotation sequence
		self.yellowTimingWindow.rotation = self.timingWindowRotation
		self.timingWindowRotation = (self.timingWindowRotation + 1) % 12

		-- If it's same rotation sequence, re-retrieve
		if self.yellowTimingWindow.rotation == self.redTimingWindow.rotation and self.redTimingWindow.duration > 0 then
			self.yellowTimingWindow.rotation = self.timingWindowRotation
			self.timingWindowRotation = (self.timingWindowRotation + 1) % 12
		end
	end

	self.yellowTimingWindow.duration = math.max(duration, self.yellowTimingWindow.duration)
end

function noteManager:getRedTimingWindow()
	return self.redTimingWindow.duration
end

function noteManager:setRedTimingWindow(duration)
	if self.redTimingWindow.duration == 0 then
		-- Retrieve new rotation sequence
		self.redTimingWindow.rotation = self.timingWindowRotation
		self.timingWindowRotation = (self.timingWindowRotation + 1) % 12

		-- If it's same rotation sequence, re-retrieve
		if self.yellowTimingWindow.rotation == self.redTimingWindow.rotation and self.yellowTimingWindow.duration > 0 then
			self.redTimingWindow.rotation = self.timingWindowRotation
			self.timingWindowRotation = (self.timingWindowRotation + 1) % 12
		end
	end

	self.redTimingWindow.duration = math.max(duration, self.redTimingWindow.duration)
end

-----------------------------
-- Base Moving Note object --
-----------------------------

local baseMovingNote = Luaoop.class("Livesim2.BaseMovingNote")

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

function baseMovingNote.getDistance(release)
	error("pure virtual method 'getDistance'", 2)
end

function baseMovingNote.tap()
	error("pure virtual method 'tap'", 2)
	return "judgement string"
end

function baseMovingNote.unTap()
	error("pure virtual method 'unTap'", 2)
	return "judgement string"
end

-------------------------------
-- Normal Moving Note object --
-------------------------------

local normalMovingNote = Luaoop.class("Livesim2.NormalMovingNote", baseMovingNote)

function normalMovingNote:__construct(definition, param)
	-- Note target time
	self.targetTime = definition.timing_sec + param.beatmapOffset
	-- Note speed
	self.noteSpeed = param.noteSpeed / (definition.speed or 1)
	-- Note spawn time
	self.spawnTime = self.targetTime - self.noteSpeed
	-- Elapsed time. If it's equal to self.noteSpeed then it's "perfect" judgement
	self.elapsedTime = math.max(self.noteSpeed - self.targetTime, 0)
	-- note distance to tap lane
	self.distance = param.laneDistance[assert(definition.position)]
	-- note direction to tap lane
	self.direction = param.laneDirection[definition.position]
	-- note accuracy timing
	self.accuracy = param.laneAccuracy[definition.position]
	-- note current position
	self.position = param.noteSpawningPosition + self.elapsedTime / self.noteSpeed * self.distance * self.direction
	-- note lane position
	self.lanePosition = definition.position
	-- time needed for specific accuracy
	self.accuracyTime = {
		perfect = {
			self.accuracy.perfect[1] * self.noteSpeed,
			self.accuracy.perfect[2] * self.noteSpeed
		},
		great = {
			self.accuracy.great[1] * self.noteSpeed,
			self.accuracy.great[2] * self.noteSpeed
		},
		good = {
			self.accuracy.good[1] * self.noteSpeed,
			self.accuracy.good[2] * self.noteSpeed
		},
		bad = {
			self.accuracy.bad[1] * self.noteSpeed,
			self.accuracy.bad[2] * self.noteSpeed
		},
	}
	-- event time
	self.eventTime = self.accuracy.miss[1] * self.noteSpeed
	-- miss time
	self.missTime = self.accuracy.miss[2] * self.noteSpeed
	-- attribute
	self.attribute = assert(definition.notes_attribute)
	-- note layers (set later)
	self.noteLayers = false
	-- token flag
	self.token = assert(definition.effect) == 2
	-- star note
	self.star = definition.effect == 4
	-- swing note
	self.swing = definition.effect > 10
	-- swing note group
	self.swingGroup = self.swing and definition.notes_level or 0
	-- simultaneous note
	self.simul = false -- set later
	-- swing rotation
	self.rotation = false -- set later
	-- vanish type (1 = hidden, 2 = sudden)
	self.vanishType = definition.vanish or 0
	-- opacity
	self.opacity = 1
	-- remove?
	self.delete = false
	-- oof
	self.long = false
	-- is ever updated
	self.spawned = false
	-- Current note manager
	self.manager = param
end

function normalMovingNote:update(dt)
	self.elapsedTime = self.elapsedTime + dt
	self.position = self.position + (dt * self.distance / self.noteSpeed) * self.direction

	if self.elapsedTime >= self.missTime then
		-- Mark note as "miss"
		self.delete = true
		return "miss"
	end

	-- calculate opacity for "vanish" note
	if self.vanishType > 0 then
		if self.vanishType == 1 then
			-- Hidden note
			self.opacity = util.clamp((self.noteSpeed * 2/3 - self.elapsedTime) / self.noteSpeed * 5, 0, 1)
		elseif self.vanishType == 2 then
			-- Sudden note
			self.opacity = util.clamp((self.elapsedTime - self.noteSpeed * 0.4) / self.noteSpeed * 5, 0, 1)
		end
	end

	if self.manager.autoplay and self.elapsedTime >= self.noteSpeed then
		self.delete = true
		return "perfect"
	end
end

function normalMovingNote:draw()
	return self.manager:drawNote(
		self.noteLayers,
		self.opacity,
		self.position,
		self.elapsedTime / self.noteSpeed,
		self.rotation
	)
end

function normalMovingNote:getDistance()
	return math.abs(self.elapsedTime - self.noteSpeed) / self.noteSpeed * self.accuracy.exact
end

local function judgementCheck(t, accuracy, swing, rtiming, ytiming)
	if swing then
		-- Start checking from great accuracy for swing notes
		if t > accuracy.great[1] and t < accuracy.great[2] then
			return "perfect"
		elseif t > accuracy.good[1] and t < accuracy.good[2] then
			return (ytiming or rtiming) and "perfect" or "great"
		elseif t > accuracy.bad[1] and t < accuracy.bad[2] then
			return rtiming and "perfect" or "good"
		else
			return "good" -- swing is never "bad"
		end
	else
		-- Start checking from perfect
		if t > accuracy.perfect[1] and t < accuracy.perfect[2] then
			return "perfect"
		elseif t > accuracy.great[1] and t < accuracy.great[2] then
			return (ytiming or rtiming) and "perfect" or "great"
		elseif t > accuracy.good[1] and t < accuracy.good[2] then
			return rtiming and "perfect" or "good"
		elseif t > accuracy.bad[1] and t < accuracy.bad[2] then
			return "bad"
		else
			return "bad" -- shouldn't happen unless tap is called early.
		end
	end
end

function normalMovingNote:tap()
	-- Unlike previous note manager, the touch identifier
	-- is handled entirely by NoteManager class, so the
	-- only task remain for NormalMovingNote class is to
	-- return the judgement string
	self.delete = true
	return judgementCheck(
		self.elapsedTime,
		self.accuracyTime,
		self.swing,
		self.manager.redTimingWindow.duration > 0,
		self.manager.yellowTimingWindow.duration > 0
	)
end

function normalMovingNote.unTap()
	-- nothing
end

-----------------------------
-- Long Moving Note object --
-----------------------------

local longMovingNote = Luaoop.class("Livesim2.LongMovingNote", normalMovingNote)

function longMovingNote:__construct(definition, param)
	normalMovingNote.__construct(self, definition, param)
	self.long = true

	-- Long note properties
	-- flag to determine whetever the note is in hold
	self.lnHolding = false
	-- long note vertices
	self.lnVertices = {
		{40, 0, 1, 0.0625, color.compat(255, 255, 255)},
		{40, 0, 1, 0.9375, color.compat(255, 255, 255)},
		{-1, -1, 0, 0.9375, color.compat(255, 255, 255)},
		{-1, -1, 0, 0.0625, color.compat(255, 255, 255)},
	}
	-- long note mesh
	self.lnMesh = love.graphics.newMesh(4, "strip", "stream")
	self.lnMesh:setTexture(param.lnTrailImage)
	-- long note opacity
	self.lnOpacity = 1
	-- long note target time
	self.lnTargetTime = self.targetTime + definition.effect_value
	-- long note spawn time (elapsed time)
	self.lnSpawnTime = definition.effect_value
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

function longMovingNote:update(dt)
	self.elapsedTime = self.elapsedTime + dt
	local velocity = dt * self.distance / self.noteSpeed
	if not(self.lnHolding) then
		self.position = self.position + velocity * self.direction
	end

	if self.elapsedTime >= self.missTime and not(self.lnHolding) then
		-- Mark note as "miss" as whole
		self.delete = true
		return "miss"
	end

	if self.elapsedTime >= self.lnSpawnTime then
		-- Calculating the dT is bit difficult, because it must take
		-- previous time into account. If this case is not handled,
		-- at worse case it can gives about 1000/framerate ms inaccuracy.
		-- The other problem is that this check is only taken at most once
		-- and can hurt processor which does branch prediction.
		if self.elapsedTime - dt < self.lnSpawnTime then
			local v = (self.elapsedTime - self.lnSpawnTime) * self.distance / self.noteSpeed
			self.lnPosition = self.lnPosition + v * self.direction
		else
			self.lnPosition = self.lnPosition + velocity * self.direction
		end
	end

	if self.elapsedTime - self.lnSpawnTime >= self.missTime then
		-- If the end note is missed, make it miss too
		self.delete = true
		return "miss"
	end

	-- calculate opacity for "vanish" note
	if self.vanishType > 0 then
		local x = self.elapsedTime - self.lnSpawnTime
		if self.vanishType == 1 then
			-- Hidden note
			self.opacity = util.clamp((self.noteSpeed * 2/3 - self.elapsedTime) * 5, 0, 1)
			self.lnOpacity = util.clamp((self.noteSpeed * 2/3 - x) * 5, 0, 1)
		elseif self.vanishType == 2 then
			-- Sudden note
			self.opacity = util.clamp((self.elapsedTime - self.noteSpeed * 0.4) * 5, 0, 1)
			self.lnOpacity = util.clamp((x - self.noteSpeed * 0.4) * 5, 0, 1)
		end
	end

	-- calculate vertices
	local s1 = self.lnHolding and 1 or self.elapsedTime / self.noteSpeed
	local s2 = math.max(self.elapsedTime - self.lnSpawnTime, 0) / self.noteSpeed
	local op = select(4, color.compat(0, 0, 0, self.opacity))
	-- First position
	self.lnVertices[4][1] = self.position.x + (s1 * 62) * math.cos(self.lnRotation)
	self.lnVertices[4][2] = self.position.y + (s1 * 62) * math.sin(self.lnRotation)
	self.lnVertices[4][8] = op
	self.lnVertices[3][1] = self.position.x + (s1 * 62) * math.cos(self.lnRotation - math.pi)
	self.lnVertices[3][2] = self.position.y + (s1 * 62) * math.sin(self.lnRotation - math.pi)
	self.lnVertices[3][8] = op
	op = select(4, color.compat(0, 0, 0, self.lnOpacity))
	self.lnVertices[1][1] = self.lnPosition.x + (s2 * 62) * math.cos(self.lnRotation - math.pi)
	self.lnVertices[1][2] = self.lnPosition.y + (s2 * 62) * math.sin(self.lnRotation - math.pi)
	self.lnVertices[1][8] = op
	self.lnVertices[2][1] = self.lnPosition.x + (s2 * 62) * math.cos(self.lnRotation)
	self.lnVertices[2][2] = self.lnPosition.y + (s2 * 62) * math.sin(self.lnRotation)
	self.lnVertices[2][8] = op
	-- Update vertices
	self.lnMesh:setVertices(self.lnVertices)
	-- Update flash
	if self.lnHolding and self.lnFlashEffect then
		self.lnFlashEffect:update(dt * 1000)
	end

	if self.manager.autoplay then
		if self.lnHolding and self.elapsedTime - self.lnSpawnTime >= self.noteSpeed then
			self.delete = true
			return "perfect"
		elseif not(self.lnHolding) and self.elapsedTime >= self.noteSpeed then
			self.position = self.manager.noteSpawningPosition + self.distance * self.direction
			self.lnHolding = true
			return "perfect"
		end
	end
end

function longMovingNote:draw()
	-- 1. draw note trail
	local trailOpacity = self.lnHolding and math.abs(math.sin(((self.elapsedTime - self.noteSpeed) % 1) * 2*math.pi)) or 1
	love.graphics.setColor(color.compat(255, 255, self.lnHolding and 127 or 255, self.manager.opacity * trailOpacity))
	love.graphics.draw(self.lnMesh)
	-- 2. draw end note circle
	if self.elapsedTime - self.lnSpawnTime > 0 then
		local s = (self.elapsedTime - self.lnSpawnTime) / self.noteSpeed
		love.graphics.setColor(color.compat(255, 255, 255, self.manager.opacity * self.lnOpacity))
		love.graphics.draw(
			self.manager.noteImage, note.quadRegion[3],
			self.lnPosition.x, self.lnPosition.y, 0,
			s, s, 64, 64
		)
	end
	-- 3. draw main note
	self.manager:drawNote(
		self.noteLayers,
		self.opacity,
		self.position,
		self.lnHolding and 1 or self.elapsedTime / self.noteSpeed,
		self.rotation
	)
	-- 4. draw flash effect
	if self.lnHolding and self.lnFlashEffect then
		love.graphics.push()
		love.graphics.translate(self.position:unpack())
		love.graphics.rotate(self.lnFlashRotation)
		self.lnFlashEffect:setOpacity(self.manager.opacity * 255)
		self.lnFlashEffect:draw()
		love.graphics.pop()
	end
end

function longMovingNote:getDistance(rel)
	if rel then
		return math.abs(self.elapsedTime - self.lnSpawnTime - self.noteSpeed) / self.noteSpeed * self.accuracy.exact
	else
		return math.abs(self.elapsedTime - self.noteSpeed) / self.noteSpeed * self.accuracy.exact
	end
end

function longMovingNote:tap()
	if self.lnHolding then
		return
	else
		self.position = self.manager.noteSpawningPosition + self.distance * self.direction
		self.lnHolding = true
		return judgementCheck(
			self.elapsedTime,
			self.accuracyTime,
			self.swing,
			self.manager.redTimingWindow.duration > 0,
			self.manager.yellowTimingWindow.duration > 0
		)
	end
end

function longMovingNote:unTap()
	if self.lnHolding then
		local t = self.elapsedTime - self.lnSpawnTime
		self.delete = true
		if t <= self.eventTime then
			return "miss"
		else
			return judgementCheck(
				t,
				self.accuracyTime,
				self.swing,
				self.manager.redTimingWindow.duration > 0,
				self.manager.yellowTimingWindow.duration > 0
			)
		end
	else
		return
	end
end

----------------
-- Public API --
----------------

function note.newNoteManager(param)
	return noteManager(param)
end

function noteManager:getElapsedTime()
	return self.elapsedTime
end

function noteManager:getRemainingNotes()
	return #self.notesList
end

-- return true if token, false if not
function noteManager:addNote(definition)
	local v
	if definition.effect % 10 == 3 then
		v = longMovingNote(definition, self)
	else
		v = normalMovingNote(definition, self)
	end

	local i = #self.notesList + 1
	self.notesList[i] = v
	self.notesListByEvent[i] = v
	self.notesListByDraw[i] = v

	if v.swing then
		self.swingNotesList[#self.swingNotesList + 1] = {definition, v, i}
	end

	return v.token
end

function noteManager:initialize()
	-- You should really call this at most once.
	-- It doesn't perform any sanity check whetever it's
	-- already called previously or not!
	table.sort(self.notesList, function(a, b)
		-- Sort by targetTime
		return a.targetTime < b.targetTime
	end)
	table.sort(self.notesListByEvent, function(a, b)
		-- Sort by eventTime
		return a.eventTime + a.spawnTime < b.eventTime + b.spawnTime
	end)
	table.sort(self.notesListByDraw, function(a, b)
		-- Sort by their spawnTime
		return a.spawnTime < b.spawnTime
	end)

	-- Swing note & simultaneous note detection
	local lastTimingSw = -32767
	for i = 1, #self.notesList do
		local v = self.notesList[i]

		-- Check for simultaneous note
		if math.abs(lastTimingSw - v.targetTime) <= 0.001 then
			v.simul = true
			self.notesList[i-1].simul = true
		end
		lastTimingSw = v.targetTime
	end

	for i = 1, #self.swingNotesList do
		local swing = self.swingNotesList[i]

		if swing[2].rotation == false then
			local lastLevel = swing[1].notes_level
			local lastPost2 = swing[1].position
			local lastTiming = swing[1].timing_sec
			local lastPos = swing[1].position
			local lastObj = swing[2]
			local lastIndex = swing[3]

			if swing[1].effect == 13 then
				lastTiming = lastTiming + swing[1].effect_value
			end

			local function applyswing(chainSwing)
				lastObj.rotation = (lastPos - chainSwing[1].position > 0 and 0 or math.pi) + swingRotationTable[lastPos]

				lastPost2 = lastPos
				lastTiming = chainSwing[1].timing_sec
				lastPos = chainSwing[1].position
				lastObj = chainSwing[2]
				lastIndex = chainSwing[3]

				if chainSwing[1].effect == 13 then
					lastTiming = lastTiming + chainSwing[1].effect_value
				end
			end

			for j = i + 1, #self.swingNotesList do
				local chainSwing = self.swingNotesList[j]

				if chainSwing[2].rotation == false then
					if chainSwing[1].notes_level and chainSwing[1].notes_level > 1 then
						if chainSwing[1].notes_level - lastLevel == 0 then
							applyswing(chainSwing)
						end
					elseif
						chainSwing[1].timing_sec + 0.001 >= lastTiming and
						math.abs(chainSwing[3] - lastIndex) < 3 and
						math.abs(chainSwing[1].position - lastPos) == 1
					then
						applyswing(chainSwing)
					end

					if (chainSwing[1].effect == 13 and
							chainSwing[1].timing_sec  + chainSwing[1].effect_value or
							chainSwing[1].timing_sec
						) - lastTiming > 0.25
					then
						break
					end
				end
			end

			lastObj.rotation = (lastPost2 - lastPos > 0 and 0 or math.pi) + swingRotationTable[lastPos]
		end
	end

	for _, v in ipairs(self.notesList) do
		v.noteLayers = self:getLayer(v.attribute, v.simul, v.swing, v.token, v.star)
	end
end

local function touchHitboxCheck(o, x, y, rot)
	local xp = (math.cos(rot) * (x - o.x) + math.sin(rot) * (y - o.y)) / 132
	local yp = (math.sin(rot) * (x - o.x) - math.cos(rot) * (y - o.y)) / 74
	return xp*xp + yp*yp <= 1
end

function noteManager:touchPressed(id, x, y)
	if self.autoplay then return end -- why bother
	for i = 1, 9 do
		if touchHitboxCheck(self.lane[i], x, y, self.hitboxRotation[i]) then
			self.touchTrack[id] = i
			return self:setTouch(i, id)
		end
	end
end

function noteManager:touchMoved(id, x, y)
	if self.autoplay  then return end

	local track = self.touchTrack[id]
	for i = 1, 9 do
		if i ~= track and touchHitboxCheck(self.lane[i], x, y, self.hitboxRotation[i]) then
			self.touchTrack[id] = i
			return self:setTouch(i, id, false, track)
		end
	end
end

function noteManager:touchReleased(id)
	self.touchTrack[id] = nil
	return self:setTouch(nil, id, true)
end

function noteManager:setTouch(pos, id, rel, prev)
	if self.autoplay then return end
	if rel and not(self.touchInput[id]) then return end
	if self.touchInput[id] and not(prev) and not(rel) then
		-- are we paused somehow?
		if self.touchInput[id].position == pos then
			return
		else
			rel = true
		end
	end

	if rel and self.touchInput[id].note then
		local v = self.touchInput[id].note
		if v.long and not(v.delete) then
			local judgement = v:unTap()
			self.callback(v, v.lanePosition, v.position:clone(), judgement, 2)
		end
		self.touchInput[id] = nil
	else
		for _, v in ipairs(self.notesListByEvent) do
			if self.elapsedTime >= v.eventTime + v.spawnTime then
				if not(v.delete) and v.lanePosition == pos then
					if prev and v.swing or not(prev) then
						-- process new note
						local judgement = v:tap()
						if judgement then
							self.callback(v, v.lanePosition, v.position:clone(), judgement, v.lnHolding and 1 or 0)

							if self.touchInput[id] then
								-- if prev exists, that means we're sliding
								if self.touchInput[id].position == prev and self.touchInput[id].note then
									-- process old note
									local vold = self.touchInput[id].note
									if vold and vold.long then
										-- release long note
										judgement = vold:unTap()
										self.callback(v, v.lanePosition, v.position:clone(), judgement, 2)
									end
								end
								-- set note
								self.touchInput[id].position = pos
								self.touchInput[id].note = v
							else
								self.touchInput[id] = {
									position = pos,
									note = v
								}
							end
						end
					end

					return
				end
			else
				-- not found
				return
			end
		end
	end
end

-- Positive07's super fast in-place table filtering
-- Beats naive table.remove implementation by many
-- orders of magnitude
local function filterTableInPlace(t)
	local length = #t
	local index = 1
	local left = length
	for i = 1, length do
		if t[i] and t[i].delete then
			left = left - 1
		else
			t[index] = t[i]
			index = index + 1
		end
	end

	for i = left + 1, length do
		t[i] = nil
	end
end

function noteManager:update(dt)
	-- Note update is based on how notes are drawn
	self.elapsedTime = self.elapsedTime + dt

	-- Recalculate timing window position
	self.redTimingWindow.duration = math.max(self.redTimingWindow.duration - dt, 0)
	self.yellowTimingWindow.duration = math.max(self.yellowTimingWindow.duration - dt, 0)

	for _, v in ipairs(self.notesListByDraw) do
		if self.elapsedTime >= v.spawnTime then
			if not(v.delete) then
				local judgement
				if self.elapsedTime - dt < v.spawnTime then
					judgement = v:update(self.elapsedTime - v.spawnTime)
				else
					judgement = v:update(dt)
				end

				-- ever updated flag
				if not(v.spawned) then
					self.spawn(v, v.lanePosition)
					v.spawned = true
				end

				if judgement then
					-- function(object, lane, position, judgement, releaseFlag)
					local relflg = v.long and (v.lnHolding and (v.delete and 2) or 1) or 0
					self.callback(v, v.lanePosition, v.position:clone(), judgement, relflg)
				end
			end
		else
			break
		end
	end

	-- Remove all notes that are marked as "deleted" here
	-- Thanks to Positive07 for the super fast table filtering
	-- algorithm (see `filterTableInPlace` function above)
	filterTableInPlace(self.notesList)
	filterTableInPlace(self.notesListByEvent)
	filterTableInPlace(self.notesListByDraw)
end

function noteManager:draw()
	-- draw timing window
	if math.max(self.yellowTimingWindow.duration, self.redTimingWindow.duration) > 0 then
		local xpy = math.sin(math.pi * self.yellowTimingWindow.rotation / 6) * 64
		local ypy = math.cos(math.pi * self.yellowTimingWindow.rotation / 6) * 64
		local xpr = math.sin(math.pi * self.redTimingWindow.rotation / 6) * 64
		local ypr = math.cos(math.pi * self.redTimingWindow.rotation / 6) * 64

		love.graphics.setColor(color.compat(255, 255, 255, self.opacity))

		for i = 1, 9 do
			local pos = self.lane[i]

			if self.yellowTimingWindow.duration > 0 then
				love.graphics.draw(self.timingImage, yellowTimingQuad, pos.x + xpy, pos.y + ypy, 0, 1, 1, 16, 16)
			end

			if self.redTimingWindow.duration > 0 then
				love.graphics.draw(self.timingImage, redTimingQuad, pos.x + xpr, pos.y + ypr, 0, 1, 1, 16, 16)
			end
		end
	end

	-- draw notes
	for _, v in ipairs(self.notesListByDraw) do
		if not(self.delete) and self.elapsedTime >= v.spawnTime then
			-- Well, just call draw method
			v:draw()
		else
			return
		end
	end
end

note.manager = noteManager
return note
