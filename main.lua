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

-- Version string
DEPLS_VERSION = "3.0.0-beta5"
-- Version number
-- In form xxyyzzww. x = major, y = minor, z = patch, w = pre-release counter (99 = not a pre release)
DEPLS_VERSION_NUMBER = 02030000

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
local audioManager = require("audio_manager")
local JSON = require("libs.JSON")

local beatmapList = require("game.beatmap.list")

local function initWindow(w, h, f)
	log.infof("main", "creating window, width: %d, height: %d", w, h)
	love.window.setMode(w, h, {
		resizable = true,
		minwidth = 320,
		minheight = 240,
		highdpi = true,
		-- RayFirefist: Please make iOS fullscreen so the status bar is not shown.
		-- Marty: having fullscreen true in conf.lua make sure the soft buttons not appear
		fullscreen = love._os == "iOS" or love._os == "Android" or f,
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
	gamestate.register("livesim2Preload", require("game.states.play_preloader"))
	gamestate.register("changeUnits", require("game.states.change_units"))
	gamestate.register("settings", require("game.states.gamesetting"))
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
	setting.define("IDOL_IMAGE", " \t \t \t \t \t \t \t \t ")
	setting.define("AUTOPLAY", 0)
	setting.define("IDOL_KEYS", "a\ts\td\tf\tspace\tj\tk\tl\t;")
	setting.define("LIVESIM_DELAY", 1000) -- backward compatibility
	setting.define("LIVESIM_DIM", 75)
	setting.define("SCORE_ADD_NOTE", 1024)
	setting.define("STAMINA_DISPLAY", 32)
end

local function createDirectories()
	log.debug("main", "making directories")
	assert(love.filesystem.createDirectory("audio"), "Failed to create directory \"audio\"")
	assert(love.filesystem.createDirectory("beatmap"), "Failed to create directory \"beatmap\"")
	assert(love.filesystem.createDirectory("live_icon"), "Failed to create directory \"live_icon\"")
	assert(love.filesystem.createDirectory("screenshots"), "Failed to create directory \"screenshots\"")
	assert(love.filesystem.createDirectory("temp"), "Failed to create directory \"temp\"")
	assert(love.filesystem.createDirectory("unit_icon"), "Failed to create directory \"unit_icon\"")

	log.debug("main", "clearing temporary directory")
	for file in ipairs(love.filesystem.getDirectoryItems("temp")) do
		love.filesystem.remove("temp/"..file)
	end
end

local function initializeYohane()
	local color = require("color")
	log.debug("main", "initializing Yohane")

	function Yohane.Platform.ResolveImage(path)
		return assetCache.loadImage(path..":"..path, {mipmaps = true})
	end

	function Yohane.Platform.ResolveAudio(path)
		local v = util.substituteExtension(path, util.getNativeAudioExtensions())
		if v then
			local s = audioManager.newAudio(v)
			audioManager.setVolume(s, assert(tonumber(setting.get("SE_VOLUME"))) * 0.008)
			return s
		end

		return nil
	end

	function Yohane.Platform.CloneImage(image_handle)
		return image_handle
	end

	function Yohane.Platform.CloneAudio(audio)
		if audio then
			return audioManager.clone(audio)
		end

		return nil
	end

	function Yohane.Platform.PlayAudio(audio)
		if audio then
			audioManager.stop(audio)
			audioManager.play(audio)
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

local usage = [[
Usage: %s [options] [absolute beatmap path]

If 1 argument is passed (beatmap file), then Live Simulator: 2 will try to
load that beatmap instead.

Options:
* -autoplay <on/off|1/0>     Enable/disable live simulator autoplay.

* -dump                      Dump beatmap data to stdout instead of playing
                             the game. It will output SIF-compatible JSON
                             beatmap format.

* -dumpformat <format>       Set the format of the beatmap dump for -dump
                             option.
* -dumpformat json           Dump beatmap as JSON beatmap. This is default.
* -dumpformat ls2            Dump beatmap as Live Simulator: 2 v2.0 binary
                             beatmap. If this is used, -dumpout must be
                             specified (unimplemented).

* -fullscreen                Start Live Simulator: 2 fullscreen.

* -list <which>              Lists various things then exit. 'which' can be:
  -list beatmaps             Lists available beatmaps.
  -list loaders              Lists availabe beatmap loaders.

* -help                      Show this message then exit.

* -height <height>           Set window height. Ignored if used with command
                             that operates without window. Default is 640

* -play <beatmap>            Play specified beatmap name in beatmap directory.
                             This argument takes precedence of passed beatmap
                             path as 1st argument.

* -license                   Show the license text then exit.

* -width <width>             Set window width. Ignored if used with command
                             that operates without window. Default is 960

]]

local license = [[
Live Simulator: 2 v3.0 is licensed under zLib license

Copyright (c) 2039 Dark Energy Processor
This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.
Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:
1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not
   be misrepresented as being the original software.
3. This notice may not be removed or altered from any source
   distribution.
]]

function love.load(argv, gameargv)
	-- Most codes in livesim2 uses math.random instead of love.math.random
	math.randomseed(os.time())
	-- Early initialization (crash on failure)
	createDirectories()
	initializeSetting()
	-- Process command line
	local absolutePlayBeatmapName
	local playBeatmapName
	local autoplayOverride
	local listingMode
	local fullscreen = false
	local windowWidth = 960
	local windowHeight = 640
	local dumpBeatmap = false
	do
		local i = 1
		while i <= #argv do
			local arg = argv[i]

			if arg == "-autoplay" then
				local u = assert(argv[i+1], "please specify autoplay mode"):lower()
				assert(u == "on" or u == "off" or u == "1" or u == "0", "invalid autoplay mode")
				autoplayOverride = u
				i = i + 1
			elseif arg == "-dump" then
				dumpBeatmap = true
			elseif arg == "-fullscreen" then
				fullscreen = true
				windowWidth, windowHeight = love.window.getDesktopDimensions()
			elseif arg == "-list" then
				local which = assert(argv[i+1], "which to list?"):lower()
				assert(which == "beatmaps" or which == "loaders", "invalid which or unimplemented yet")
				listingMode = which
			elseif arg == "-height" then
				windowHeight = assert(tonumber(argv[i+1]), "please specify correct height")
				i = i + 1
			elseif arg == "-help" then
				print(string.format(usage, love.arg.getLow(gameargv) or "livesim3.exe"))
				return love.event.quit()
			elseif arg == "-play" then
				playBeatmapName = assert(argv[i+1], "please specify beatmap name")
				i = i + 1
			elseif arg == "-license" then
				print(license)
				return love.event.quit()
			elseif arg == "-width" then
				windowWidth = assert(tonumber(argv[i+1]), "please specify correct width")
				i = i + 1
			elseif not(absolutePlayBeatmapName) then
				absolutePlayBeatmapName = arg
			end

			i = i + 1
		end
	end

	if dumpBeatmap then
		assert(playBeatmapName or absolutePlayBeatmapName, "Please specify beatmap file to dump")
		-- TODO: Dump to LS2 beatmap

		beatmapList.push()
		if playBeatmapName then
			beatmapList.enumerate()
		else
			beatmapList.registerAbsolute(absolutePlayBeatmapName, function() end)
		end

		beatmapList.getNotes(playBeatmapName, function(data)
			io.write(JSON:encode(data))
			love.event.quit()
		end)
	elseif listingMode then
		beatmapList.push()

		if listingMode == "beatmaps" then
			beatmapList.enumerate(function(bname, name, fmt, diff, fmtInt)
				if bname == "" then
					love.event.quit()
					return false
				end
				print("========== "..bname)
				print(name)
				print("("..fmtInt..") "..fmt)
				print(diff or "*null*")
				return true
			end)
		elseif listingMode == "loaders" then
			beatmapList.enumerateLoaders(function(name, type)
				if name == "" then
					love.event.quit()
					return false
				end
				print(type..": "..name)
				return true
			end)
		end
	else
		local autoplayMode

		-- Initialize window
		initWindow(windowWidth, windowHeight, fullscreen)
		-- Initialize Yohane
		initializeYohane()
		-- Register all gamestates
		registerGamestates()

		if autoplayOverride then
			autoplayMode = autoplayOverride == "on" or autoplayOverride == "1"
		end

		if playBeatmapName then
			-- Play beatmap directly
			gamestate.enter(loadingInstance.getInstance(), "livesim2Preload", {
				playBeatmapName,
				false,

				autoplay = autoplayMode
			})
		elseif absolutePlayBeatmapName then
			-- Play beatmap from specified path
			gamestate.enter(loadingInstance.getInstance(), "livesim2Preload", {
				absolutePlayBeatmapName,
				true,

				autoplay = autoplayMode,
			})
		else
			-- Jump to default game state
			if love.filesystem.isFused() then
				gamestate.enter(nil, "splash")
			else
				gamestate.enter(loadingInstance.getInstance(), "mainMenu")
			end
		end
	end
end
