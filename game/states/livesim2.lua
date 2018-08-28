-- Main game
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local async = require("async")
local vector = require("libs.hump.vector")
local timer = require("libs.hump.timer")
local log = require("logging")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local beatmapList = require("game.beatmap.list")
local note = require("game.live.note")

local DEPLS = gamestate.create {
	fonts = {
		main = {"fonts/MTLmr3m.ttf", 12},
	},
	images = {
		note = {"noteImage:assets/image/tap_circle/notes.png", {mipmaps = true}},
		longNoteTrail = {"assets/image/ef_326_000.png"}
	},
	audios = {}
}

function DEPLS:load(arg)
	-- Lane definition
	self.persist.lane = {
		vector(816+64, 96+64 ),
		vector(785+64, 249+64),
		vector(698+64, 378+64),
		vector(569+64, 465+64),
		vector(416+64, 496+64),
		vector(262+64, 465+64),
		vector(133+64, 378+64),
		vector(46+64 , 249+64),
		vector(16+64 , 96+64 ),
	}
	-- Create new note manager
	self.persist.noteManager = note.newNoteManager({
		image = self.assets.images.note,
		trailImage = self.assets.images.longNoteTrail,
		-- TODO: make it user-interface dependent
		noteSpawningPosition = vector(480, 160),
		lane = self.persist.lane,
		accuracy = {16, 40, 64, 112, 128},
		autoplay = true -- Testing only
	})

	-- Load notes data
	local isInit = false
	log.debug("loading notes data")
	beatmapList.getNotes(arg.beatmapName, function(chan)
		local amount = chan:pop()
		for _ = 1, amount do
			local t = {}
			while chan:peek() ~= chan do
				local k = chan:pop()
				t[k] = chan:pop()
			end

			-- pop separator
			chan:pop()
			self.persist.noteManager:addNote(t)
		end

		self.persist.noteManager:initialize()
		isInit = true
	end)
	-- wait until all notes are ok
	while isInit == false do
		async.wait()
	end
end

function DEPLS:start()
	timer.every(1, function()
		log.debug("note remaining "..#self.persist.noteManager.notesList)
	end)
end

function DEPLS:update(dt)
	self.persist.noteManager:update(dt)
end

function DEPLS:draw()
	love.graphics.setColor(color.white)
	local t = love.timer.getTime()
	for _, v in ipairs(self.persist.lane) do
		love.graphics.circle("fill", v.x, v.y, 64)
		love.graphics.circle("line", v.x, v.y, 64)
	end

	self.persist.noteManager:draw()
end

DEPLS:registerEvent("keypressed", function(_, key)
	if key == "escape" then
		return gamestate.leave(loadingInstance.getInstance())
	end
end)

return DEPLS
