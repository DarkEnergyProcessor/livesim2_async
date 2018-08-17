-- Main game
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local util = require("util")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local DEPLS = gamestate.create {
	fonts = {
		main = {"fonts/MTLmr3m.ttf", 12},
	},
	images = {
		note = {"noteImage:assets/image/tap_circle/note.png", {mipmaps = true}},
	},
	audios = {}
}

return DEPLS
