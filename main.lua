-- Live Simulator: 2
--[[---------------------------------------------------------------------------
-- Copyright (c) 2039 Dark Energy Processor
--
-- This software is provided 'as-is', without any express or implied
-- warranty. In no event will the authors be held liable for any damages
-- arising from the use of this software.
--
-- Permission is granted to anyone to use this software for any purpose,
-- including commercial applications, and to alter it and redistribute it
-- freely, subject to the following restrictions:
--
-- 1. The origin of this software must not be misrepresented; you must not
--    claim that you wrote the original software. If you use this software
--    in a product, an acknowledgment in the product documentation would be
--    appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not
--    be misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source
--    distribution.
--]]---------------------------------------------------------------------------
-- luacheck: globals DEPLS_VERSION
-- luacheck: globals DEPLS_VERSION_NUMBER

local love = require("love")
local vires = require("vires")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local postExit = require("post_exit")

-- Version string
DEPLS_VERSION = "3.0.0-beta5"
-- Version number
-- In form xxyyzzww. x = major, y = minor, z = patch, w = pre-release counter (99 = not a pre release)
DEPLS_VERSION_NUMBER = 02030000

local function initWindow()
	-- Our window is 960x640 by default.
	love.window.setMode(960, 640, {
		resizable = true,
		minwidth = 320,
		minheight = 240,
		highdpi = true,
		--RayFirefist: Please make iOS fullscreen so the status bar is not shown.
		fullscreen = love._os == "iOS",
		fullscreentype = "desktop",
	})
	love.window.setTitle("Live Simulator: 2")
	love.window.setIcon(love.image.newImageData("assets/image/icon/icon.png"))
	-- Initialize virtual resolution
	vires.init(960, 640)
	-- Update virtual resolution but using love.graphics.getDimensions value
	-- because we can't be sure that 960x640 is supported in mobile or
	-- in lower resolutions.
	vires.update(love.graphics.getDimensions())
end

local function registerGamestates()
	-- Loading screen singleton init
	loadingInstance.set(gamestate.newLoadingScreen(require("game.states.loading")))
	postExit.add(loadingInstance.exit)
	-- Load all gamestates.
	gamestate.register("dummy", require("game.states.dummy"))
	gamestate.register("splash", require("game.states.splash"))
	gamestate.register("mainMenu", require("game.states.main_menu"))
	gamestate.register("beatmapSelect", require("game.states.beatmap_select"))
end

local function initializeSetting()
	local setting = require("setting")
	setting.define("NOTE_STYLE", 1)
	setting.define("MINIMAL_EFFECT", 0)
	setting.define("BACKGROUND_IMAGE", 10)
	setting.define("NOTE_SPEED", 800) -- backward compatibility
	setting.define("LLP_SIFT_DEFATTR", 10)
	setting.define("NS_ACCUMULATION", 0)
	setting.define("AUTO_BACKGROUND", 1)
	setting.define("GLOBAL_OFFSET", 0)
	setting.define("TEXT_SCALING", 1)
	setting.define("TAP_SOUND", 1)
end

local function createDirectories()
	assert(love.filesystem.createDirectory("audio"), "Failed to create directory \"audio\"")
	assert(love.filesystem.createDirectory("beatmap"), "Failed to create directory \"beatmap\"")
	assert(love.filesystem.createDirectory("live_icon"), "Failed to create directory \"live_icon\"")
	assert(love.filesystem.createDirectory("screenshots"), "Failed to create directory \"screenshots\"")
	assert(love.filesystem.createDirectory("unit_icon"), "Failed to create directory \"unit_icon\"")
end

function love.load()
	-- Most codes in livesim2 uses math.random instead of love.math.random
	math.randomseed(os.time())
	-- Early initialization (crash on failure)
	createDirectories()
	initializeSetting()
	-- TODO: command-line processing.
	-- Initialize window
	initWindow()
	-- Register all gamestates
	registerGamestates()
	-- Jump to default game state
	gamestate.enter(nil, "dummy")
end
