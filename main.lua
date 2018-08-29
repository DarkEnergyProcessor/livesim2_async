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
local assetCache = require("asset_cache")
local vires = require("vires")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local postExit = require("post_exit")
local Yohane = require("libs.Yohane")
local util = require("util")
local setting = require("setting")
local log = require("logging")

-- Version string
DEPLS_VERSION = "3.0.0-beta5"
-- Version number
-- In form xxyyzzww. x = major, y = minor, z = patch, w = pre-release counter (99 = not a pre release)
DEPLS_VERSION_NUMBER = 02030000

local function initWindow()
	-- Our window is 960x640 by default.
	log.info("main", "creating window")
	love.window.setMode(960, 640, {
		resizable = true,
		minwidth = 320,
		minheight = 240,
		highdpi = true,
		--RayFirefist: Please make iOS fullscreen so the status bar is not shown.
		fullscreen = love._os == "iOS",
		fullscreentype = "desktop",
		vsync = true,
	})
	love.window.setTitle("Live Simulator: 2")
	love.window.setIcon(love.image.newImageData("assets/image/icon/icon.png"))
	-- Initialize virtual resolution
	log.debug("main", "initializing virtual resolution")
	vires.init(960, 640)
	-- Update virtual resolution but using love.graphics.getDimensions value
	-- because we can't be sure that 960x640 is supported in mobile or
	-- in lower resolutions.
	vires.update(love.graphics.getDimensions())
end

local function registerGamestates()
	log.debug("main", "loading gamestates")
	-- Loading screen singleton init (enable sync asset loading for loading screen)
	assetCache.enableSync = true
	loadingInstance.set(gamestate.newLoadingScreen(require("game.states.loading")))
	assetCache.enableSync = false
	postExit.add(loadingInstance.exit)
	-- Load all gamestates.
	gamestate.register("dummy", require("game.states.dummy"))
	gamestate.register("splash", require("game.states.splash"))
	gamestate.register("mainMenu", require("game.states.main_menu"))
	gamestate.register("beatmapSelect", require("game.states.beatmap_select"))
	gamestate.register("livesim2", require("game.states.livesim2"))
end

local function initializeSetting()
	log.debug("main", "initializing settings")
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
	setting.define("SE_VOLUME", 80)
end

local function createDirectories()
	log.debug("main", "making directories")
	assert(love.filesystem.createDirectory("audio"), "Failed to create directory \"audio\"")
	assert(love.filesystem.createDirectory("beatmap"), "Failed to create directory \"beatmap\"")
	assert(love.filesystem.createDirectory("live_icon"), "Failed to create directory \"live_icon\"")
	assert(love.filesystem.createDirectory("screenshots"), "Failed to create directory \"screenshots\"")
	assert(love.filesystem.createDirectory("unit_icon"), "Failed to create directory \"unit_icon\"")
end

local function initializeYohane()
	local color = require("color")
	log.debug("main", "initializing Yohane")

	function Yohane.Platform.UpdateSEVolume()
		Yohane.Platform.SEVolume = assert(tonumber(setting.get("SE_VOLUME")))
	end

	function Yohane.Platform.ResolveImage(path)
		return assetCache.loadImage(path..":"..path, {mipmaps = true})
	end

	function Yohane.Platform.ResolveAudio(path)
		local v = util.substituteExtension(path, util.getNativeAudioExtensions())
		if v then
			local s = love.audio.newSource(v, "static")
			s:setVolume(Yohane.Platform.SEVolume * 0.008)
			return s
		end

		return nil
	end

	function Yohane.Platform.CloneImage(image_handle)
		return image_handle
	end

	function Yohane.Platform.CloneAudio(audio)
		if audio then
			return audio:clone()
		end

		return nil
	end

	function Yohane.Platform.PlayAudio(audio)
		if audio then
			audio:stop()
			audio:play()
		end
	end

	function Yohane.Platform.Draw(drawdatalist)
		local r, g, b, a = love.graphics.getColor()

		for _, dd in ipairs(drawdatalist) do
			if dd.image then
				love.graphics.setColor(color.compat(dd.r, dd.g, dd.b, dd.a / 255))
				if type(dd.image) == "table" then
					-- Quad + Image
					love.graphics.draw(dd.image[1], dd.image[2], dd.x, dd.y, dd.rotation, dd.scaleX, dd.scaleY)
				else
					love.graphics.draw(dd.image, dd.x, dd.y, dd.rotation, dd.scaleX, dd.scaleY)
				end
			end
		end

		love.graphics.setColor(r, g, b, a)
	end

	function Yohane.Platform.OpenReadFile(fn)
		return assert(love.filesystem.newFile(fn, "r"))
	end

	Yohane.Init(love.filesystem.load, "libs")
end

function love.load()
	log.dbg = true
	log.info("main", "logging check (info)")
	log.warning("main", "loging check (warning)")
	log.error("main", "logging check (error)")
	log.debug("main", "logging check (debug)")
	log.info("main", "logging check (info)")
	-- Most codes in livesim2 uses math.random instead of love.math.random
	math.randomseed(os.time())
	-- Early initialization (crash on failure)
	createDirectories()
	initializeSetting()
	-- TODO: command-line processing.
	-- Initialize window
	initWindow()
	-- Initialize Yohane
	initializeYohane()
	-- Register all gamestates
	registerGamestates()
	-- Jump to default game state
	--gamestate.enter(nil, "dummy")
	gamestate.enter(loadingInstance.getInstance(), "livesim2", {})
end
