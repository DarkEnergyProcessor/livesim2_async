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
-- 2. Altered source versions must be plainly marked as such, and must not be
--    misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source distribution.
--]]---------------------------------------------------------------------------
-- luacheck: globals DEPLS_VERSION
-- luacheck: globals DEPLS_VERSION_NUMBER

local love = require("love")
local vires = require("vires")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

-- Version string
DEPLS_VERSION = "3.0.0-beta5"
-- Version number
-- In form xxyyzzww. x = major, y = minor, z = patch, w = pre-release counter (99 = not a pre release)
DEPLS_VERSION_NUMBER = 02030000

local function initWindow()
	love.window.setMode(960, 640, {
		resizable = true,
		minwidth = 320,
		minheight = 240,
		highdpi = true,
		fullscreen = love._os == "iOS",
		fullscreentype = "desktop",
	})
	love.window.setTitle("Live Simulator: 2")
	love.window.setIcon(love.image.newImageData("assets/image/icon/icon.png"))
	vires.init(960, 640)
	vires.update(love.graphics.getDimensions())
end

local function registerGamestates()
	loadingInstance.set(gamestate.newLoadingScreen(require("game.states.loading")))
	gamestate.register("dummy", require("game.states.dummy"))
	gamestate.register("splash", require("game.states.splash"))
	gamestate.register("mainMenu", require("game.states.main_menu"))
end

function love.load()
	math.randomseed(os.time())
	initWindow()
	registerGamestates()
	gamestate.enter(nil, "dummy")
end
