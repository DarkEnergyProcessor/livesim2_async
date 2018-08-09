-- Beatmap selection
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local gamestate = require("gamestate")
local async = require("async")
local color = require("color")
local timer = require("libs.hump.timer")

local backgroundLoader = require("game.background_loader")
local gui = require("libs.fusion-ui")

local beatmapSelect = gamestate.create {
	fonts = {
		status = {"fonts/MTLmr3m.ttf", 22}
	},
	images = {},
	audios = {},
}

return beatmapSelect
