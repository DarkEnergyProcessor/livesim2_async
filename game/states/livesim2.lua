-- Main game
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local setting = require("setting")
local util = require("util")
local vector = require("libs.hump.vector")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local beatmapList = require("game.beatmap.list")
local note = require("game.live.note")

local DEPLS = gamestate.create {
	fonts = {
		main = {"fonts/MTLmr3m.ttf", 12},
	},
	images = {
		note = {"noteImage:assets/image/tap_circle/note.png", {mipmaps = true}},
	},
	audios = {}
}

function DEPLS:load(arg)
	local noteData = {}
	beatmapList.getNotes(arg.beatmapName, function(chan)
		local amount = chan:pop()
		for i = 1, amount do
			local t = {}
			while chan:peek() ~= chan do
				local k = chan:pop()
				t[k] = chan:pop()
			end

			-- pop separator
			chan:pop()
			noteData[i] = t
		end
	end)

	self.persist.noteManager = note.newNoteManager({
		image = self.assets.image.note,
		-- TODO: make it user-interface dependent
		noteSpawningPosition = vector(480, 160),
		lane = {
			vector(816+64, 96+64 ),
			vector(785+64, 249+64),
			vector(698+64, 378+64),
			vector(569+64, 465+64),
			vector(416+64, 496+64),
			vector(262+64, 465+64),
			vector(133+64, 378+64),
			vector(46+64 , 249+64),
			vector(16+64 , 96+64 ),
		},
		accuracy = {16, 40, 64, 112, 128}
	})
	local beatmapOffset = setting.get("GLOBAL_OFFSET") / 1000

end

return DEPLS
