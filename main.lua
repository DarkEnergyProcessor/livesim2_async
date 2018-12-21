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
DEPLS_VERSION = "3.0.0-RC1"
-- Version number
-- In form xxyyzzww. x = major, y = minor, z = patch, w = pre-release counter (99 = not a pre release)
DEPLS_VERSION_NUMBER = 02050000

local love = require("love")
local Yohane = require("libs.Yohane")
local JSON = require("libs.JSON")
local ls2 = require("libs.ls2")
local lsr = require("libs.lsr")

local assetCache = require("asset_cache")
local vires = require("vires")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local postExit = require("post_exit")
local language = require("language")
local util = require("util")
local setting = require("setting")
local log = require("logging")
local volume = require("volume")
local audioManager = require("audio_manager")

local beatmapList = require("game.beatmap.list")
local beatmapRandomizer = require("game.live.randomizer3")

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
		-- Use adaptive vsync (driver dependent)
		vsync = -1,
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
	gamestate.register("beatmapDownload", require("game.states.download_list"))
	gamestate.register("beatmapInfoDL", require("game.states.download_beatmap"))
	gamestate.register("beatmapInsert", require("game.states.beatmap_process"))
	gamestate.register("beatmapSelect", require("game.states.beatmap_select"))
	gamestate.register("changeUnits", require("game.states.change_units"))
	gamestate.register("dummy", require("game.states.dummy"))
	gamestate.register("language", require("game.states.gamelang"))
	gamestate.register("livesim2", require("game.states.livesim2"))
	gamestate.register("livesim2Preload", require("game.states.play_preloader"))
	gamestate.register("mainMenu", require("game.states.main_menu"))
	gamestate.register("result", require("game.states.result_summary"))
	gamestate.register("selectUnits", require("game.states.select_units"))
	gamestate.register("settings", require("game.states.gamesetting"))
	gamestate.register("splash", require("game.states.splash"))
	gamestate.register("systemInfo", require("game.states.systeminfo"))
	gamestate.register("viewReplay", require("game.states.view_replays"))
end

local function initializeSetting()
	log.debug("main", "initializing settings")
	setting.define("AUTOPLAY", 0)
	setting.define("AUTO_BACKGROUND", 1)
	setting.define("BACKGROUND_IMAGE", 10)
	setting.define("CBF_UNIT_LOAD", 1)
	setting.define("GLOBAL_OFFSET", 0)
	setting.define("IDOL_IMAGE", " \t \t \t \t \t \t \t \t ")
	setting.define("IDOL_KEYS", "a\ts\td\tf\tspace\tj\tk\tl\t;")
	setting.define("LANGUAGE", "en")
	setting.define("LIVESIM_DELAY", 1000) -- backward compatibility
	setting.define("LIVESIM_DIM", 75)
	setting.define("LLP_SIFT_DEFATTR", 10)
	setting.define("MASTER_VOLUME", 80)
	setting.define("MINIMAL_EFFECT", 0)
	setting.define("NOTE_SPEED", 800) -- backward compatibility
	setting.define("NOTE_STYLE", 1)
	setting.define("NS_ACCUMULATION", 0)
	setting.define("PLAY_UI", "sif")
	setting.define("SE_VOLUME", 80)
	setting.define("SCORE_ADD_NOTE", 1024)
	setting.define("SKILL_POPUP", 1)
	setting.define("SONG_VOLUME", 80)
	setting.define("STAMINA_DISPLAY", 32)
	setting.define("STAMINA_FUNCTIONAL", 0)
	setting.define("STORYBOARD", util.isMobile() and 0 or 1)
	setting.define("TAP_SOUND", 1)
	setting.define("TEXT_SCALING", 1)
	setting.define("TIMING_OFFSET", 0)
	setting.define("VIDEOBG", 0)
	setting.define("VOICE_VOLUME", 80)
end

local function createDirectories()
	log.debug("main", "making directories")
	assert(love.filesystem.createDirectory("audio"), "Failed to create directory \"audio\"")
	assert(love.filesystem.createDirectory("beatmap"), "Failed to create directory \"beatmap\"")
	assert(love.filesystem.createDirectory("live_icon"), "Failed to create directory \"live_icon\"")
	assert(love.filesystem.createDirectory("replays"), "Failed to create directory \"replays\"")
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
		return assetCache.loadImage(path, {mipmaps = true})
	end

	function Yohane.Platform.ResolveAudio(path)
		local v = util.substituteExtension(path, util.getNativeAudioExtensions())
		if v then
			return audioManager.newAudio(v, "se")
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

local function initLSR()
	function lsr.file.openRead(path)
		return love.filesystem.newFile(path, "r")
	end

	function lsr.file.openWrite(path)
		return love.filesystem.newFile(path, "w")
	end

	function lsr.file.read(file, n)
		return file:read(n)
	end

	function lsr.file.write(file, data)
		return file:write(data)
	end

	function lsr.file.close(file)
		return file:close()
	end
end

local function initLS2()
	-- LOVE File object to be FILE*-like object
	ls2.setstreamwrapper {
		read = function(stream, val)
			return (stream:read(assert(val)))
		end,
		write = function(stream, data)
			return stream:write(data)
		end,
		seek = function(stream, whence, offset)
			local set = 0

			if whence == "cur" then
				set = stream:tell()
			elseif whence == "end" then
				set = stream:getSize()
			elseif whence ~= "set" then
				assert(false, "Invalid whence")
			end

			stream:seek(set + (offset or 0))
			return stream:tell()
		end
	}
end

local function initVolume()
	love.audio.setVolume(1)
	volume.set("master", setting.get("MASTER_VOLUME") * 0.01)
	volume.define("se", setting.get("SE_VOLUME") * 0.01)
	volume.define("music", setting.get("SONG_VOLUME") * 0.01)
	volume.define("voice", setting.get("VOICE_VOLUME") * 0.01)
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
* -dumpformat llp            Dump beatmap as LLP beatmap.
* -dumpformat ls2            Dump beatmap as Live Simulator: 2 v2.0 binary
                             beatmap. If this is used, -dumpout must be
                             specified for Windows (unimplemented).

* -fullscreen                Start Live Simulator: 2 fullscreen.

* -license                   Show the license text then exit.

* -list <which>              Lists various things then exit. 'which' can be:
  -list beatmaps             Lists available beatmaps.
  -list loaders              Lists availabe beatmap loaders.

* -help                      Show this message then exit.

* -height <height>           Set window height. Ignored if used with command
                             that operates without window. Default is 640

* -play <beatmap>            Play specified beatmap name in beatmap directory.
                             This argument takes precedence of passed beatmap
                             path as 1st argument.

* -random                    Enable note randomization when possible. Can be
                             used with -dump option.

* -replay <file>             Use replay file for preview. Replay file is
                             stored in replays/<beatmap_filename>/<file>.lsr

* -seed <seedlo>,<seedhi>    Set random number generator seed. This allows
                             consistent beatmap randomization and skill
                             trigger timing.

* -storyboard <on/off|1/0>   Enable/disable storyboard system.

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
	-- Early initialization (crash on failure which means serious error)
	createDirectories()
	initializeSetting()
	initLS2()
	initLSR()
	language.init()
	language.set(setting.get("LANGUAGE"))
	-- Try to load command line
	if (love._os == "Android" or love._os == "iOS") and util.fileExists("commandline.txt") then
		argv = {}
		for line in love.filesystem.lines("commandline.txt") do
			argv[#argv + 1] = line
		end
	end
	-- Process command line
	local absolutePlayBeatmapName
	local playBeatmapName
	local autoplayOverride
	local storyboardOverride
	local listingMode
	local fullscreen = false
	local windowWidth = 960
	local windowHeight = 640
	local dumpBeatmap = false
	local replayFile = nil
	local dumpFormat = "json"
	local randomizeBeatmap
	local randomSeed
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
			elseif arg == "-dumpformat" then
				dumpFormat = assert(argv[i+1], "please specify correct height"):lower()
				i = i + 1
			elseif arg == "-fullscreen" then
				fullscreen = true
				windowWidth, windowHeight = love.window.getDesktopDimensions()
			elseif arg == "-license" then
				print(license)
				return love.event.quit()
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
			elseif arg == "-random" then
				randomizeBeatmap = true
			elseif arg == "-seed" then
				local seed = assert(argv[i+1], "please specify seed in format <low>,<hi>")
				local slo, shi = seed:match("(%d+),(%d+)")
				slo, shi = tonumber(slo), tonumber(shi)
				assert(slo and shi, "please specify seed in format <low>,<hi>")
				randomSeed = {slo%4294967296, shi%4294967296}

				i = i + 1
			elseif arg == "-replay" then
				replayFile = assert(argv[i+1], "please specify replay file")
				i = i + 1
			elseif arg == "-storyboard" then
				local u = assert(argv[i+1], "please specify storyboard mode"):lower()
				assert(u == "on" or u == "off" or u == "1" or u == "0", "invalid storyboard mode")
				storyboardOverride = u
				i = i + 1
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
		local dumpFunc

		-- TODO: Dump to LS2 beatmap
		if dumpFormat == "json" then
			dumpFunc = function(data)
				if randomizeBeatmap then
					local rndout
					if randomSeed then
						rndout = beatmapRandomizer(data, randomSeed[1], randomSeed[2])
					else
						rndout = beatmapRandomizer(data)
					end

					if rndout then
						data = rndout
					else
						log.warnf("main", "cannot randomize beatmap, using original beatmap")
					end
				end
				io.write(JSON:encode(data))
				love.event.quit()
			end
		elseif dumpFormat == "llp" then
			local function checkSimul(lane, timing)
				for i = 1, 9 do
					if lane[i] then
						local n = lane[i]

						for j = 1, #n do
							if math.abs(n[j].starttime - timing) <= 0.01 then
								return true
							end
						end
					end
				end
			end

			dumpFunc = function(data)
				if randomizeBeatmap then
					local rndout
					if randomSeed then
						rndout = beatmapRandomizer(data, randomSeed[1], randomSeed[2])
					else
						rndout = beatmapRandomizer(data)
					end

					if rndout then
						data = rndout
					else
						log.warnf("main", "cannot randomize beatmap, using original beatmap")
					end
				end

				local llpdata = {}
				llpdata.lane = {}

				for _, v in ipairs(data) do
					local laneidx = 10 - v.position
					local lane = llpdata.lane[laneidx]

					if not(lane) then
						lane = {}
						llpdata.lane[laneidx] = lane
					end

					local long = v.effect % 10 == 3
					-- time units is in ms for LLP
					local note = {
						starttime = v.timing_sec * 1000,
						longnote = long,
						lane = laneidx - 1,
						hold = false,
					}
					note.endtime = note.starttime + (long and v.effect_value or 0) * 1000
					note.parallel = checkSimul(llpdata.lane, note.starttime)

					lane[#lane + 1] = note
				end

				io.write(JSON:encode(llpdata), "\n")
				love.event.quit()
			end
		else
			error("invalid dump format")
		end

		beatmapList.push()
		if playBeatmapName then
			beatmapList.registerRelative(playBeatmapName, function(id)
				beatmapList.getNotes(id, dumpFunc)
			end)
		else
			beatmapList.registerAbsolute(absolutePlayBeatmapName, function(id)
				beatmapList.getNotes(id, dumpFunc)
			end)
		end
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
		if autoplayOverride then
			autoplayMode = autoplayOverride == "on" or autoplayOverride == "1"
		end

		local storyboardMode
		if storyboardOverride then
			storyboardMode = storyboardOverride == "on" or storyboardOverride == "1"
		end

		if replayFile then
			if autoplayMode then
				error("cannot use -replay with -autoplay")
			elseif not(playBeatmapName) then
				error("cannot use -replay without -play")
			end
		end

		-- Initialize audio module
		require("love.audio")
		-- Initialize volume
		initVolume()
		-- Initialize window
		initWindow(windowWidth, windowHeight, fullscreen)
		-- Initialize Yohane
		initializeYohane()
		-- Register all gamestates
		registerGamestates()

		if playBeatmapName then
			-- Play beatmap directly
			gamestate.enter(loadingInstance.getInstance(), "livesim2Preload", {
				playBeatmapName,
				false,

				autoplay = autoplayMode,
				replay = replayFile,
				random = randomizeBeatmap,
				seed = randomSeed,
				storyboard = storyboardMode,
			})
		elseif absolutePlayBeatmapName then
			-- Play beatmap from specified path
			gamestate.enter(loadingInstance.getInstance(), "livesim2Preload", {
				absolutePlayBeatmapName,
				true,

				autoplay = autoplayMode,
				random = randomizeBeatmap,
				seed = randomSeed,
				storyboard = storyboardMode,
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
