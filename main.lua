-- Live Simulator: 2
--[[---------------------------------------------------------------------------
-- Copyright (c) 2041 Dark Energy Processor
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
-- luacheck: globals DEPLS_VERSION_CODENAME

-- Version string
DEPLS_VERSION = "4.0.0-beta5"
-- Version number
-- In form xxyyzzww. x = major, y = minor, z = patch, w = pre-release counter (99 = not a pre release)
DEPLS_VERSION_NUMBER = 03030201
-- Version codename
DEPLS_VERSION_CODENAME = "Over the Rainbow"

local love = require("love")
local AudioRender = require("libs.audiorender")
local Yohane = require("libs.Yohane")
local JSON = require("libs.JSON")
local ls2 = require("libs.ls2")
local lsr = require("libs.lsr")

local AssetCache = require("asset_cache")
local Vires = require("vires")
local Gamestate = require("gamestate")
local LoadingInstance = require("loading_instance")
local PostExit = require("post_exit")
local Language = require("language")
local Util = require("util")
local Setting = require("setting")
local log = require("logging")
local Volume = require("volume")
local AudioManager = require("audio_manager")

local ColorTheme = require("game.color_theme")
local BeatmapList = require("game.beatmap.list")
local BeatmapRandomizer = require("game.live.randomizer3")

local function initWindow(w, h, f, v, m)
	local vsync, highdpi

	if Util.compareLOVEVersion(12, 0) < 0 then
		highdpi = true
	end

	local android = love._os == "Android"

	if Util.compareLOVEVersion(11, 0) >= 0 then
		vsync = v and -1 or 0
	else
		vsync = v
	end

	log.infof("main", "creating window, width: %d, height: %d", w, h)
	love.window.setTitle("Live Simulator: 2")
	love.window.setMode(w, h, {
		resizable = not android, -- do not allow freely-set orientation
		minwidth = 320,
		minheight = 240,
		highdpi = highdpi,
		msaa = m,
		-- RayFirefist: Please make iOS fullscreen so the status bar is not shown.
		-- Marty: having fullscreen true in conf.lua make sure the soft buttons not appear
		fullscreen = love._os == "iOS" or android or f,
		fullscreentype = "desktop",
		borderless = f,
		-- Use adaptive vsync (driver dependent)
		vsync = vsync,
	})
	love.window.setTitle("Live Simulator: 2 ("..love.graphics.getRendererInfo()..")")
	local icon
	if love._os == "OS X" then
		icon = love.image.newImageData("assets/image/icon/new_icon_1024x1024_macos.png")
	else
		icon = love.image.newImageData("assets/image/icon/new_icon_32x32_windows.png")
	end
	love.window.setIcon(icon)
	-- Detect bad AMD driver
	local version, vendor = select(2, love.graphics.getRendererInfo())
	if
		love._os == "Windows" and vendor == "ATI Technologies Inc." and
		(version:find("22.7.1", 1, true) or version:find("2207", 1, true)) then
		love.window.showMessageBox(
			"AMD driver 22.7.1 detected",
			"AMD driver 22.7.1 is known to have problems with running LÖVE (this includes Live Simulator: 2). If the game fails to render its visuals, it is recommended to upgrade or downgrade your AMD GPU drivers.",
			"warning"
		)
	end
	-- Initialize virtual resolution
	log.debug("main", "initializing virtual resolution")
	Vires.init(960, 640)
	-- Update virtual resolution but using love.graphics.getDimensions value
	-- because we can't be sure that 960x640 is supported in mobile or
	-- in lower resolutions.
	Vires.update(love.graphics.getDimensions())
end

local function registerGamestates()
	log.debug("main", "loading gamestates")

	-- Loading screen singleton init (enable sync asset loading for loading screen)
	AssetCache.enableSync = true
	LoadingInstance.set(Gamestate.newLoadingScreen(require("game.states.loading")))
	AssetCache.enableSync = false
	PostExit.add(LoadingInstance.exit)

	-- Load all gamestates.
	Gamestate.register("beatmapDownload", require("game.states.download_list"))
	Gamestate.register("beatmapInfoDL", require("game.states.download_beatmap"))
	Gamestate.register("beatmapInsert", require("game.states.beatmap_process"))
	Gamestate.register("beatmapSelect", require("game.states.beatmap_select"))
	Gamestate.register("changeUnits", require("game.states.change_units"))
	Gamestate.register("dummy", require("game.states.dummy"))
	Gamestate.register("language", require("game.states.gamelang"))
	Gamestate.register("livesim2", require("game.states.livesim2"))
	Gamestate.register("livesim2Preload", require("game.states.play_preloader"))
	Gamestate.register("mainMenu", require("game.states.main_menu_v31"))
	Gamestate.register("result", require("game.states.result_summary"))
	Gamestate.register("selectUnits", require("game.states.select_units"))
	Gamestate.register("settings", require("game.states.gamesetting"))
	Gamestate.register("splash", require("game.states.splash"))
end

local SETTING_LIST = {
	AUTOPLAY = 0,
	AUTO_BACKGROUND = 1,
	BACKGROUND_IMAGE = 10,
	CBF_UNIT_LOAD = 1,
	COLOR_THEME = 1,
	GLOBAL_OFFSET = 0,
	IDOL_IMAGE = " \t \t \t \t \t \t \t \t ",
	IDOL_KEYS = "a\ts\td\tf\tspace\tj\tk\tl\t;",
	IMPROVED_SYNC = 0,
	LANGUAGE = "en",
	LIVESIM_DELAY = 1000,
	LIVESIM_DIM = 75,
	LLP_SIFT_DEFATTR = 10,
	MASTER_VOLUME = 80,
	MINIMAL_EFFECT = 0,
	NOTE_SPEED = 800,
	NOTE_STYLE = 1,
	NS_ACCUMULATION = 0,
	PLAY_UI = "sif",
	SE_VOLUME = 80,
	SCORE_ADD_NOTE = 1024,
	SKILL_POPUP = 1,
	SONG_VOLUME = 80,
	STAMINA_DISPLAY = 32,
	STAMINA_FUNCTIONAL = 0,
	STORYBOARD = Util.isMobile() and 0 or 1,
	TAP_SOUND = 1,
	TEXT_SCALING = 1,
	TIMING_OFFSET = 0,
	VANISH_TYPE = 0,
	VIDEOBG = 0,
	VOICE_VOLUME = 80,
	DOWNLOAD_OFFSET = -50,
	-- DEBUG v4.0.0-beta3: remove this later
	PERFECT_ACCURACY = 16,
	GREAT_ACCURACY = 40,
	GOOD_ACCURACY = 64,
	BAD_ACCURACY = 112,
}

local function initializeSetting()
	log.debug("main", "initializing settings")
	for k, v in pairs(SETTING_LIST) do
		Setting.define(k, v)
	end
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
		return AssetCache.loadImage(path, {mipmaps = true})
	end

	function Yohane.Platform.ResolveAudio(path)
		local v = Util.substituteExtension(path, Util.getNativeAudioExtensions())
		if v then
			return AudioManager.newAudio(v, "se")
		end

		return nil
	end

	function Yohane.Platform.CloneImage(image_handle)
		return image_handle
	end

	function Yohane.Platform.CloneAudio(audio)
		if audio then
			return AudioManager.clone(audio)
		end

		return nil
	end

	function Yohane.Platform.PlayAudio(audio)
		if audio then
			AudioManager.stop(audio)
			AudioManager.play(audio)
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
		return assert(Util.newFileCompat(fn, "r"))
	end

	Yohane.Init(love.filesystem.load, "libs")
end

local function initLSR()
	function lsr.file.openRead(path)
		return Util.newFileCompat(path, "r")
	end

	function lsr.file.openWrite(path)
		return Util.newFileCompat(path, "w")
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
	Volume.set("master", Setting.get("MASTER_VOLUME") * 0.01)
	Volume.define("se", Setting.get("SE_VOLUME") * 0.01)
	Volume.define("music", Setting.get("SONG_VOLUME") * 0.01)
	Volume.define("voice", Setting.get("VOICE_VOLUME") * 0.01)
end

-- https://stackoverflow.com/q/52206212
local function testCaseSensitiveWin32()
	local ffi = require("ffi")
	local ntdll = ffi.load("ntdll")

	-- TODO: Convert to wchar_t
	if ffi.C.GetACP() ~= 65001 then
		error("UTF-8 mode is not enabled")
	end

	local INVALID_HANDLE = ffi.cast("void*", ffi.cast(ffi.abi("64bit") and "int64_t" or "int32_t", -1))
	local main = love.filesystem.getSource():gsub("/", "\\")
	-- The magic number means:
	-- * No permission
	-- * FILE_SHARE_READ | FILE_SHARE_WRITE
	-- * OPEN_EXISTING
	-- * FILE_FLAG_BACKUP_SEMANTICS
	local dir = ffi.C.CreateFileA(main, 0, 3, nil, 3, 0x2000000, nil)
	if dir == INVALID_HANDLE then
		error("GetLastError() "..ffi.C.GetLastError())
	end

	local iosb = ffi.new("struct IO_STATUS_BLOCK[1]")
	local flags = ffi.new("uint32_t[1]")
	-- 71 = FileCaseSensitiveInformation 
	local status = ntdll.NtQueryInformationFile(dir, iosb, flags, ffi.sizeof("uint32_t"), 71)
	if status ~= 0 then
		-- Case-sensitive impossible
		return false
	end

	return flags[0] % 2 == 1
end

local function testCaseSensitive()
	if love.filesystem.isFused() or love._os ~= "Windows" then
		-- Assume case sensitive
		return true
	end

	-- TODO: Windows on ARM64 support by running `fsutil` directly.
	local ffi = require("ffi")

	ffi.cdef[[
		struct IO_STATUS_BLOCK
		{
			size_t status;
			uint32_t information;
		};

		void* __stdcall CreateFileA(const char*, uint32_t, uint32_t, void*, uint32_t, uint32_t, void*);
		bool __stdcall CloseHandle(void*);
		uint32_t __stdcall NtQueryInformationFile(void*, struct IO_STATUS_BLOCK*, void*, uint32_t, int);
		uint32_t __stdcall GetLastError();
	]]

	local status, result = pcall(testCaseSensitiveWin32)
	if status then
		return result
	else
		log.info("main", "Unable to test for case-sensitive info: "..result)
		return true
	end
end

local usage = [[
Live Simulator: 2
Usage: %s [options] [absolute beatmap path]

If 1 argument is passed (beatmap file), then Live Simulator: 2 will try to
load that beatmap instead.

Options:
* -autoplay <on/off|1/0>     Enable/disable live simulator autoplay.

* -dump                      Dump beatmap data to stdout instead of playing
                             the game. It will output SIF-compatible JSON
                             beatmap format by default.

* -dumpformat <format>       Set the format of the beatmap dump for -dump
                             option.
* -dumpformat json           Dump beatmap as JSON beatmap. This is default.

* -fullscreen                Start Live Simulator: 2 fullscreen.

* -height <height>           Set window height. Ignored if used with command
                             that operates without window. Default is 640

* -help                      Show this message then exit.

* -license                   Show the license text then exit.

* -list <which>              Lists various things then exit. 'which' can be:
  -list beatmaps             Lists available beatmaps.
  -list loaders              Lists availabe beatmap loaders.
  -list settings             Lists current settings.

* -msaa <num>                Set Multi-Sample Anti-Aliasing steps. <num> must
                             be power of 2, rounded down to nearest POT
							 otherwise. May not supported on older systems.
                             This does not affect render mode output!

* -play <beatmap>            Play specified beatmap name in beatmap directory.
                             This argument takes precedence of passed beatmap
                             path as 1st argument.

* -random                    Enable note randomization when possible. Can be
                             used with -dump option.

* -render <video> <audio>    Render beatmap to <video> and <audio>. Video
                             will be either H.264, vp9, or mpeg4 in Matroska
                             container and audio is in WAV format. FFmpeg
                             libraries must be installed to use this feature!

* -renderfps <fps>           Set the render frames per second. FPS must be
                             able to divide 48000 as whole integer. Default
                             is 60.

* -renderfxaa                Apply Fast Approximate Anti-Aliasing to the whole
                             screen while rendering to video file.

* -rendersrate <rate>        Set audio sample rate for rendering. Default to
                             48000 Hz if not specified. Must be at least
                             8000 Hz if one is specified.

* -renderheight <height>     Set video rendering height. Defaults to window
                             height if not specified.

* -renderwidth <width>       Set video rendering width. Defaults to window
                             width if not specified.

* -replay <file>             Use replay file for preview. Replay file is
                             stored in replays/<beatmap_filename>/<file>.lsr

* -seed <seedlo>,<seedhi>    Set random number generator seed. This allows
                             consistent beatmap randomization and skill
                             trigger timing if same seed is used.

* -storyboard <on/off|1/0>   Enable/disable storyboard system.

* -version                   Show Live Simulator: 2 version and exit.

* -vsync <on/off|1/0>        Enable or disable vsync. Defaults to enabled.

* -width <width>             Set window width. Ignored if used with command
                             that operates without window. Default is 960
]]

local license = [[
Live Simulator: 2 v3.0 and later is licensed under zLib license

Copyright (c) 2041 Dark Energy Processor
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
	if Util.compareLOVEVersion(11, 0) < 0 then
		log.warn("main", "LOVE 0.10.x support for Live Simulator: 2 has been deprecated!")
	end

	if love._os == "Windows" then
		local ffi = require("ffi")
		log.debug("main", "Active code page: "..ffi.C.GetACP())
	end

	local isCaseSensitive = testCaseSensitive()
	log.info("main", "Case sensitive? "..tostring(isCaseSensitive))
	if not isCaseSensitive then
		love.window.showMessageBox("Case-Sensitivity", "Live Simulator: 2 detects the project folder is not case sensitive.\nCase-sensitive directory is required for development!", "error")
		error("project directory must be case sensitive")
	end

	-- Enable key repeat
	love.keyboard.setKeyRepeat(true)
	-- Most codes in livesim2 uses math.random instead of love.math.random
	math.randomseed(os.time())
	-- Early initialization (crash on failure which means serious error)
	createDirectories()
	initializeSetting()
	initLS2()
	initLSR()
	Language.init()
	ColorTheme.init(assert(tonumber(Setting.get("COLOR_THEME"))))
	Language.set(Setting.get("LANGUAGE"))
	-- Try to load command line
	if (love._os == "Android" or love._os == "iOS") and Util.fileExists("commandline.txt") then
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
	local useVsync = true
	local windowWidth = 960
	local windowHeight = 640
	local dumpBeatmap = false
	local overrideReplayHashCheck = false
	local replayFile = nil
	local dumpFormat = "json"
	local desiredMSAA = 0
	local randomizeBeatmap
	local randomSeed
	local render
	local alwaysSplash = false
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
			elseif arg == "-forceloadreplay" then
				overrideReplayHashCheck = true
			elseif arg == "-license" then
				print(license)
				return love.event.quit()
			elseif arg == "-list" then
				local which = assert(argv[i+1], "which to list?"):lower()
				assert(
					which == "beatmaps" or
					which == "loaders" or
					which == "settings",
					"invalid which or unimplemented yet"
				)
				listingMode = which
			elseif arg == "-height" then
				windowHeight = assert(tonumber(argv[i+1]), "please specify correct height")
				i = i + 1
			elseif arg == "-help" then
				print(string.format(usage, love.arg.getLow(gameargv) or "livesim2.exe"))
				return love.event.quit()
			elseif arg == "-msaa" then
				local msaa = math.floor(assert(tonumber(argv[i+1]), "please specify correct MSAA"))
				assert(msaa >= 0, "MSAA cannot be negative")

				if msaa > 0 then
					local roundmsaa = 2^math.floor(math.log(msaa)/math.log(2))
					if roundmsaa ~= msaa then
						log.warnf("main", "MSAA is not power of 2 (previous %d, used %d instead)", msaa, roundmsaa)
						msaa = roundmsaa
					end

					desiredMSAA = msaa
				end
				i = i + 1
			elseif arg == "-play" then
				playBeatmapName = assert(argv[i+1], "please specify beatmap name")
				i = i + 1
			elseif arg == "-random" then
				randomizeBeatmap = true
			elseif arg == "-render" then
				render = {}
				render.output = assert(argv[i+1], "please specify output file")
				render.audio = assert(argv[i+2], "please specify audio output file")
				i = i + 2
			elseif arg == "-renderfps" then
				local fps = assert(tonumber(argv[i+1]), "please specify valid FPS")

				if render then
					render.fps = fps
				end

				i = i + 1
			elseif arg == "-renderfxaa" and render then
				render.fxaa = true
			elseif arg == "-rendersrate" and render then
				render.rate = assert(tonumber(argv[i+1]), "please specify valid rate")
				assert(render.rate >= 8000, "please specify valid rate")
			elseif arg == "-renderwidth" then
				local width = assert(tonumber(argv[i+1]), "please specify correct width")

				if render then
					render.width = width
				end

				i = i + 1
			elseif arg == "-renderheight" then
				local height = assert(tonumber(argv[i+1]), "please specify correct height")

				if render then
					render.height = height
				end

				i = i + 1
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
			elseif arg == "-splash" then
				alwaysSplash = true
			elseif arg == "-storyboard" then
				local u = assert(argv[i+1], "please specify storyboard mode"):lower()
				assert(u == "on" or u == "off" or u == "1" or u == "0", "invalid storyboard mode")
				storyboardOverride = u
				i = i + 1
			elseif arg == "-version" then
				local capabilities = require("capabilities")
				print(string.format(
					"Live Simulator: 2 v%s \"%s\" (%08d)",
					DEPLS_VERSION,
					DEPLS_VERSION_CODENAME,
					DEPLS_VERSION_NUMBER
				))
				print("Capabilities: "..capabilities())
				love.event.quit()
				return
			elseif arg == "-vsync" then
				local u = assert(argv[i+1], "please specify vsync"):lower()
				assert(u == "on" or u == "off" or u == "1" or u == "0", "invalid vsync value")
				useVsync = u == "on" or u == "1"
				i = i + 1
			elseif arg == "-width" then
				windowWidth = assert(tonumber(argv[i+1]), "please specify correct width")
				i = i + 1
			elseif arg == "-NSDocumentRevisionsDebugMode" then
				local mode = assert(argv[i+1], "missing value for NSDocumentRevisionsDebugMode"):lower()
				if mode == "yes" then
					log.warning("main", "-NSDocumentRevisionsDebugMode is no-op. Use LIVESIM2_LOGLEVEL environment variable instead.")
				end
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
		if dumpFormat == "json" or dumpFormat == "json_pretty" then
			dumpFunc = function(data)
				if randomizeBeatmap then
					local rndout
					if randomSeed then
						rndout = BeatmapRandomizer(data, randomSeed[1], randomSeed[2])
					else
						rndout = BeatmapRandomizer(data)
					end

					if rndout then
						data = rndout
					else
						log.warnf("main", "cannot randomize beatmap, using original beatmap")
					end
				end

				io.write(JSON[dumpFormat == "json_pretty" and "encode_pretty" or "encode"](JSON, data))
				love.event.quit()
			end
		elseif dumpFormat == "llp" or dumpFormat == "llp_pretty" then
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
						rndout = BeatmapRandomizer(data, randomSeed[1], randomSeed[2])
					else
						rndout = BeatmapRandomizer(data)
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

				io.write(JSON[dumpFormat == "json_pretty" and "encode_pretty" or "encode"](JSON, llpdata), "\n")
				love.event.quit()
			end
		else
			error("invalid dump format")
		end

		BeatmapList.push()
		if playBeatmapName then
			BeatmapList.registerRelative(playBeatmapName, function(id)
				BeatmapList.getNotes(id, dumpFunc)
			end)
		else
			BeatmapList.registerAbsolute(absolutePlayBeatmapName, function(id)
				BeatmapList.getNotes(id, dumpFunc)
			end)
		end
	elseif listingMode then
		BeatmapList.push()

		if listingMode == "beatmaps" then
			BeatmapList.enumerate(function(bname, name, fmt, diff, fmtInt)
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
			BeatmapList.enumerateLoaders(function(name, type)
				if name == "" then
					love.event.quit()
					return false
				end
				print(type..": "..name)
				return true
			end)
		elseif listingMode == "settings" then
			for k, _ in pairs(SETTING_LIST) do
				print(k.."="..Setting.get(k))
			end
			love.event.quit()
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

		if render then
			assert(
				playBeatmapName or absolutePlayBeatmapName,
				"render requires beatmap to be specified, either absolute path or -play switch"
			)
			render.width = render.width or windowWidth
			render.height = render.height or windowHeight
			render.fps = render.fps or 60
			render.rate = render.rate or 48000
			render.audioRenderOk, render.audioRenderMsg = AudioRender.push(render.rate, "stereo", "short")
			autoplayMode = true
		end

		-- Initialize audio module
		require("love.audio")

		if render then
			if render.audioRenderOk then
				AudioRender.pop()
				log.info("main", "Using OpenAL-soft audio loopback")
			else
				log.errorf("main", "AudioRender: %s", render.audioRenderMsg)
				assert(48000 / render.fps % 1 == 0, "FPS must be divisible by 48000")
			end
		end

		-- Initialize volume
		initVolume()
		-- Initialize window
		initWindow(windowWidth, windowHeight, fullscreen, not(render) and useVsync, desiredMSAA)
		-- Initialize Yohane
		initializeYohane()
		-- Register all gamestates
		registerGamestates()

		if playBeatmapName then
			-- Play beatmap directly
			Gamestate.enter(LoadingInstance.getInstance(), "livesim2Preload", {
				playBeatmapName,
				false,

				autoplay = autoplayMode,
				replay = replayFile,
				checkHash = not overrideReplayHashCheck,
				random = randomizeBeatmap,
				seed = randomSeed,
				storyboard = storyboardMode,
				render = render
			})
		elseif absolutePlayBeatmapName then
			-- Play beatmap from specified path
			Gamestate.enter(LoadingInstance.getInstance(), "livesim2Preload", {
				absolutePlayBeatmapName,
				true,

				autoplay = autoplayMode,
				random = randomizeBeatmap,
				seed = randomSeed,
				storyboard = storyboardMode,
				render = render
			})
		else
			-- Jump to default game state
			if love.filesystem.isFused() or alwaysSplash then
				Gamestate.enter(nil, "splash")
			else
				Gamestate.enter(LoadingInstance.getInstance(), "mainMenu")
			end
		end
	end
end

-- Override love.run
love.filesystem.load("run.lua")()
-- Override love.errhand
love.filesystem.load("errorhandler.lua")()
