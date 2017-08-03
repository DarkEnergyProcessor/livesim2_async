-- Live Simulator: 2
-- High-performance LL!SIF Live Simulator
-- See copyright notice in main.lua

local love = love
local AquaShine = ...
local tween = require("tween")
local EffectPlayer = require("effect_player")
local JSON = require("JSON")
local Yohane = require("Yohane")
local DEPLS = {
	ElapsedTime = 0,            -- Elapsed time, in milliseconds
	DebugDisplay = false,
	SaveDirectory = "",         -- DEPLS Save Directory
	BeatmapAudioVolume = 0.8,   -- The audio volume
	PlaySpeed = 1.0,            -- Play speed factor. 1 = normal
	PlaySpeedAlterDisabled = false, -- Disallow alteration of DEPLS play speed factor
	HasCoverImage = false,      -- Used to get livesim delay
	CoverShown = 0,             -- Cover shown if this value starts at 3167
	CoverData = {},
	
	BackgroundOpacity = 255,    -- User background opacity set from storyboard
	BackgroundImage = {         -- Index 0 is the main background
		-- {handle, logical x, logical y, x size, y size}
		{nil, -88, 0},
		{nil, 960, 0},
		{nil, 0, -43},
		{nil, 0, 640},
		[0] = {nil, 0, 0}
	},
	LiveOpacity = 255,	-- Live opacity
	AutoPlay = false,	-- Autoplay?
	
	LiveShowCleared = Yohane.newFlashFromFilename("flash/live_clear.flsh"),
	FullComboAnim = Yohane.newFlashFromFilename("flash/live_fullcombo.flsh"),
	
	StoryboardFunctions = {},	-- Additional function to be added in sandboxed lua storyboard
	Routines = {},			-- Table to store all DEPLS effect routines
	
	IdolPosition = {	-- Idol position. 9 is leftmost
		{816, 96 }, {785, 249}, {698, 378},
		{569, 465}, {416, 496}, {262, 465},
		{133, 378}, {46 , 249}, {16 , 96 },
	},
	IdolImageData = {	-- [idol positon] = {image handle, opacity}
		{nil, 255}, {nil, 255}, {nil, 255},
		{nil, 255}, {nil, 255}, {nil, 255},
		{nil, 255}, {nil, 255}, {nil, 255}
	},
	MinimalEffect = nil,		-- True means decreased dynamic effects
	NoteAccuracy = {16, 40, 64, 112, 128},	-- Note accuracy
	NoteManager = nil,
	NoteLoader = nil,
	NoteRandomized = false,
	Stamina = 32,
	NotesSpeed = 800,
	ScoreBase = 500,
	ScoreData = {		-- Contains C score, B score, A score, S score data, in order.
		1,
		2,
		3,
		4
	},
	
	Images = {		-- Lists of loaded images
		Note = {},
		ScoreNode = {},
		ComboNumbers = AquaShine.LoadModule("combo_num")
	},
	Sound = {}
}

local EllipseRot = {
	0,
	math.pi / 8,
	math.pi / 4,
	3 * math.pi / 8,
	math.pi / 2,
	5 * math.pi / 8,
	3 * math.pi / 4,
	7 * math.pi / 8,
	math.pi,
}

-----------------------
-- Private functions --
-----------------------
--! @brief Function to calculate distance of 2 position.
--! @code distance(x2 - x1, y2 - y1)
--! @endcode
local function distance(a, b)
	return math.sqrt(a ^ 2 + b ^ 2)
end

--! Function to calculate angle of 2 position
local function angle_from(x1, y1, x2, y2)
	return math.atan2(y2 - y1, x2 - x1) - math.pi / 2
end

------------------------
-- Animation routines --
------------------------

-- Circletap aftertap effect namespace
DEPLS.Routines.CircleTapEffect = assert(love.filesystem.load("livesim/circletap_effect.lua"))(DEPLS, AquaShine)
-- Combo counter effect namespace
DEPLS.Routines.ComboCounter = assert(love.filesystem.load("livesim/combocounter.lua"))(DEPLS, AquaShine)
-- Tap accuracy display routine
DEPLS.Routines.PerfectNode = assert(love.filesystem.load("livesim/judgement.lua"))(DEPLS, AquaShine)
-- Score flash animation routine
DEPLS.Routines.ScoreEclipseF = assert(love.filesystem.load("livesim/score_eclipsef.lua"))(DEPLS, AquaShine)
-- Note icon (note spawn pos) animation
DEPLS.Routines.NoteIcon = assert(love.filesystem.load("livesim/noteicon.lua"))(DEPLS, AquaShine)
-- Score display routine
DEPLS.Routines.ScoreUpdate = assert(love.filesystem.load("livesim/scoreupdate.lua"))(DEPLS, AquaShine)
-- Score bar routine. Depends on score display
DEPLS.Routines.ScoreBar = assert(love.filesystem.load("livesim/scorebar.lua"))(DEPLS, AquaShine)
-- Added score, update routine effect
DEPLS.Routines.ScoreNode = assert(love.filesystem.load("livesim/scorenode_effect.lua"))(DEPLS, AquaShine)
-- Spot effect
DEPLS.Routines.SpotEffect = assert(love.filesystem.load("livesim/spot_effect.lua"))(DEPLS, AquaShine)
-- Live show complete animation routine (incl. FULLCOMBO)
DEPLS.Routines.LiveClearAnim = assert(love.filesystem.load("livesim/live_clear.lua"))(DEPLS, AquaShine)
-- Image cover preview routines. Takes 3167ms to complete.
DEPLS.Routines.CoverPreview = assert(love.filesystem.load("livesim/cover_art.lua"))(DEPLS, AquaShine)
-- Skill popups management
DEPLS.Routines.SkillPopups = assert(love.filesystem.load("livesim/skill_popups.lua"))(DEPLS, AquaShine)
-- Starry background (combo cheer)
DEPLS.Routines.ComboCheer = assert(love.filesystem.load("livesim/combo_cheer.lua"))(DEPLS, AquaShine)
-- Result screen
DEPLS.Routines.ResultScreen = assert(love.filesystem.load("livesim/reward.lua"))(DEPLS, AquaShine)
-- Pause info
DEPLS.Routines.PauseScreen = assert(love.filesystem.load("livesim/pause.lua"))(DEPLS, AquaShine)

--------------------------------
-- Another public functions   --
-- Some is part of storyboard --
--------------------------------

--! @brief Add score
--! @param score The score value
function DEPLS.AddScore(score)
	local ComboCounter = DEPLS.Routines.ComboCounter
	local added_score = score
	
	if ComboCounter.CurrentCombo < 50 then
		-- noop
	elseif ComboCounter.CurrentCombo < 100 then
		added_score = added_score * 1.1
	elseif ComboCounter.CurrentCombo < 200 then
		added_score = added_score * 1.15
	elseif ComboCounter.CurrentCombo < 400 then
		added_score = added_score * 1.2
	elseif ComboCounter.CurrentCombo < 600 then
		added_score = added_score * 1.25
	elseif ComboCounter.CurrentCombo < 800 then
		added_score = added_score * 1.3
	else
		added_score = added_score * 1.35
	end
	
	added_score = math.floor(added_score)
	
	DEPLS.Routines.ScoreUpdate.CurrentScore = DEPLS.Routines.ScoreUpdate.CurrentScore + added_score
	DEPLS.Routines.ScoreEclipseF.Replay = true
	
	if not(DEPLS.MinimalEffect) then
		EffectPlayer.Spawn(DEPLS.Routines.ScoreNode.Create(added_score))
	end
end

do
	local dummy_image
	local list = {}
	
	--! @brief Loads image, specialized for unit icon
	--! @param path The unit image path, relative to save_dir/unit_icon folder
	--! @returns Requested unit icon or placeholder unit icon (dummy.png)
	DEPLS.LoadUnitIcon = function(path)
		if list[path] then
			return list[path]
		end
		
		if dummy_image == nil then
			dummy_image = AquaShine.LoadImage("assets/image/dummy.png")
		end
		
		if path == nil then return dummy_image end
		
		local _, img = pcall(love.graphics.newImage, "unit_icon/"..path)
		
		if _ == false then
			return dummy_image
		end
		
		list[path] = img
		return img
	end
end

--------------------------------------
-- Functions exported to storyboard --
--------------------------------------

--! @brief Sets foreground live opacity
--! @param opacity Transparency. 255 = opaque, 0 = invisible
function DEPLS.StoryboardFunctions.SetLiveOpacity(opacity)
	opacity = math.max(math.min(opacity or 255, 255), 0)
	
	DEPLS.LiveOpacity = opacity
end

--! @brief Sets background blackness
--! @param opacity Transparency. 0 = full black, 255 = full light
function DEPLS.StoryboardFunctions.SetBackgroundDimOpacity(opacity)
	opacity = math.max(math.min(opacity or 255, 255), 0)
	
	DEPLS.BackgroundOpacity = 255 - opacity
end

--! @brief Gets current elapsed time
--! @returns Elapsed time, in milliseconds. Negative value means simulator is not started yet
function DEPLS.StoryboardFunctions.GetCurrentElapsedTime()
	return DEPLS.ElapsedTime
end

--! @brief Gets live simulator delay. Delay before live simulator is shown
--! @param nocover Don't take cover image display time into account?
--! @returns Live simulator delay, in milliseconds
function DEPLS.StoryboardFunctions.GetLiveSimulatorDelay(nocover)
	if DEPLS.HasCoverImage then
		if nocover then
			return DEPLS.LiveDelay
		else
			return DEPLS.LiveDelay + 3167
		end
	else
		return DEPLS.LiveDelay
	end
end

--! @brief Spawn spotlight effect in the specificed idol position and with specificed color
--! @param pos The idol position. 9 is the leftmost
--! @param r The RGB red value
--! @param g The RGB green value
--! @param b The RGB blue value
function DEPLS.StoryboardFunctions.SpawnSpotEffect(pos, r, g, b)
	r = r or 255
	g = g or 255
	b = b or 255
	
	local obj = DEPLS.Routines.SpotEffect.Create(pos, r, g, b)
	EffectPlayer.Spawn(obj)
end

--! @brief Spawn circletap effect in the specificed idol position and with specificed color
--! @param pos The idol position. 9 is the leftmost
--! @param r The RGB red value
--! @param g The RGB green value
--! @param b The RGB blue value
function DEPLS.StoryboardFunctions.SpawnCircleTapEffect(pos, r, g, b)
	local x, y = DEPLS.IdolPosition[pos][1] + 64, DEPLS.IdolPosition[pos][2] + 64
	local effect = DEPLS.Routines.CircleTapEffect.Create(x, y, r, g, b)
	
	EffectPlayer.Spawn(effect)
end

--! @brief Set unit visibility
--! @param pos The unit position (9 is leftmost)
--! @param opacity The desired opacity. 0 is fully transparent, 255 is fully opaque (255 default)
function DEPLS.StoryboardFunctions.SetUnitOpacity(pos, opacity)
	local data = DEPLS.IdolImageData[pos]
	
	if data == nil then
		error("Invalid pos specificed")
	end
	
	data[2] = math.min(math.max(opacity or 255, 0), 255)
end

do
	local channels
	
	local function getsample_safe(sound_data, pos)
		local _, sample = pcall(sound_data.getSample, sound_data, pos)
		
		if _ == false then
			return 0
		end
		
		return sample
	end
	
	--! @brief Gets current playing audio sample with specificed size
	--! @param size The sample size (1 default = 1 sample)
	--! @returns table containing the samples with size `size`
	--! @note This function handles mono/stereo input and this function still works even
	--!       if no audio is found, where in that case the sample is simply 0
	function DEPLS.StoryboardFunctions.GetCurrentAudioSample(size)
		size = size or 1
		
		local audio = DEPLS.Sound.BeatmapAudio
		local sample_list = {}
		
		if not(audio) then
			for i = 1, size do
				sample_list[#sample_list + 1] = {0, 0}
			end
			
			return sample_list
		end
		
		if not(channels) then
			channels = audio:getChannels()
		end
		
		local pos = DEPLS.Sound.LiveAudio:tell("samples")
		
		if channels == 1 then
			for i = pos, pos + size - 1 do
				-- Mono
				local sample = getsample_safe(audio, i)
				
				sample_list[#sample_list + 1] = {sample, sample}
			end
		elseif channels == 2 then
			for i = pos, pos + size - 1 do
				-- Stereo
				sample_list[#sample_list + 1] = {
					getsample_safe(audio, i * 2),
					getsample_safe(audio, i * 2 + 1),
				}
			end
		end
		
		return sample_list
	end
end

--! @brief Get current audio sample rate
--! @returns Audio sample rate (or 22050 if there's no sound)
function DEPLS.StoryboardFunctions.GetCurrentAudioSampleRate()
	local a = DEPLS.Sound.BeatmapAudio
	
	if not(a) then
		return 22050
	end
	
	local _, v = pcall(a.getSampleRate, a)
	
	if _ == false then
		return 22050
	end
	
	return v * 0.5
end

--! @brief Loads Live Simulator: 2 image file
--! @param path The image path
--! @returns Image handle or nil on failure
function DEPLS.StoryboardFunctions.LoadDEPLS2Image(path)
	local _, a = pcall(love.graphics.newImage, path)
	
	if _ then
		return a
	end
	
	return nil
end

--! @brief Disable play speed alteration and set play speed to 1
--! @note This function should be called on storyboard initialization, as calling it
--!       multiple times is a waste of CPU
function DEPLS.StoryboardFunctions.DisablePlaySpeedAlteration()
	DEPLS.PlaySpeedAlterDisabled = true
	
	if DEPLS.Sound.LiveAudio then
		DEPLS.Sound.LiveAudio:setPitch(1)
	end
end

--! @brief Get or set play speed. This affects how fast the live simulator are
--! @param speed_factor The speed factor, in decimals. 1 means 100% speed (runs normally)
--! @returns Previous play speed factor
--! @warning This function throws error if speed_factor is zero
function DEPLS.StoryboardFunctions.SetPlaySpeed(speed_factor)
	assert(not(DEPLS.RenderingMode), "SetPlaySpeed can't be used in rendering mode")
	
	if speed_factor then
		assert(speed_factor > 0, "speed_factor can't be zero")
	end
	
	local factorrest = speed_factor or DEPLS.PlaySpeed
	
	DEPLS.PlaySpeed = factorrest
	
	if DEPLS.Sound.LiveAudio then
		DEPLS.Sound.LiveAudio:setPitch(factorrest)
	end
end

--! @brief Force set the note style between old ones and new ones
--! @param new_style Force new style (true) or force old style (false)
--! @note This function can only be called in pre-initialize or in Initialize function
function DEPLS.StoryboardFunctions.ForceNewNoteStyle(new_style)
	DEPLS.ForceNoteStyle = new_style and 2 or 1
end

--! @brief Check if current storyboard is under rendering mode
--! @returns In rendering mode (true) or live mode (false)
function DEPLS.StoryboardFunctions.IsRenderingMode()
	return not(not(DEPLS.RenderingMode))
end

DEPLS.StoryboardFunctions.SkillPopup = DEPLS.Routines.SkillPopups.Spawn

--! @brief Allow combo cheer/star effects in the background
function DEPLS.StoryboardFunctions.AllowComboCheer()
	DEPLS.ComboCheerForced = true
end

--! Source: https://love2d.org/forums/viewtopic.php?t=2126
function DEPLS.StoryboardFunctions.HSL(h, s, l)
	if s == 0 then return l,l,l end
	h, s, l = h/256*6, s/255, l/255
	local c = (1-math.abs(2*l-1))*s
	local x = (1-math.abs(h%2-1))*c
	local m,r,g,b = (l-.5*c), 0,0,0
	if h < 1     then r,g,b = c,x,0
	elseif h < 2 then r,g,b = x,c,0
	elseif h < 3 then r,g,b = 0,c,x
	elseif h < 4 then r,g,b = 0,x,c
	elseif h < 5 then r,g,b = x,0,c
	else              r,g,b = c,0,x
	end
   return math.ceil((r+m)*256),math.ceil((g+m)*256),math.ceil((b+m)*256)
end

--! @brief Check if current renderer is OpenGLES
--! @returns `true` if running under OpenGLES, `false` otherwise
function DEPLS.StoryboardFunctions.IsOpenGLES()
	return AquaShine.RendererInfo[1] == "OpenGL ES"
end

--! @brief Check if the current system supports FFmpeg extension
--!        which allows loading of video other than Theora
--! @returns `true` if FFmpeg extension is supported, `false` otherwise
function DEPLS.StoryboardFunctions.MultiVideoFormatSupported()
	return not(not(AquaShine.FFmpegExt))
end

-----------------------------
-- The Live simuator logic --
-----------------------------

--! @brief Call storyboard callback
--! @param name Callback name
--! @param ... Additional arguments passed to callback function
function DEPLS.StoryboardCallback(name, ...)
	if DEPLS.StoryboardHandle then
		DEPLS.StoryboardHandle:Callback(name, ...)
	end
end

--! @brief Draws debug information
function DEPLS.DrawDebugInfo()
	local status = love.graphics.getStats()
	local sample = DEPLS.StoryboardFunctions.GetCurrentAudioSample()[1]
	local text = string.format([[
%d FPS
RENDERER = %s %s
DRAWCALLS = %d
TEXTUREMEMORY = %d Bytes
LOADED_IMAGES = %d
LOADED_CANVAS = %d
LOADED_FONTS = %d
ELAPSED_TIME = %d ms
SPEED_FACTOR = %.2f%%
CURRENT_COMBO = %d
PLAYING_EFFECT = %d
LIVE_OPACITY = %.2f
BACKGROUND_BLACKNESS = %.2f
AUDIO_SAMPLE = (%.2f) %5.2f, %5.2f
REMAINING_NOTES = %d
PERFECT = %d GREAT = %d GOOD = %d BAD = %d MISS = %d
AUTOPLAY = %s
]]		, love.timer.getFPS(), AquaShine.RendererInfo[1], AquaShine.RendererInfo[2], status.drawcalls, status.texturememory
		, status.images, status.canvases, status.fonts, DEPLS.ElapsedTime, DEPLS.PlaySpeed * 100
		, DEPLS.Routines.ComboCounter.CurrentCombo, #EffectPlayer.list, DEPLS.LiveOpacity, DEPLS.BackgroundOpacity
		, DEPLS.BeatmapAudioVolume, sample[1], sample[2], DEPLS.NoteManager.NoteRemaining, DEPLS.NoteManager.Perfect
		, DEPLS.NoteManager.Great, DEPLS.NoteManager.Good, DEPLS.NoteManager.Bad, DEPLS.NoteManager.Miss, tostring(DEPLS.AutoPlay))
	love.graphics.setFont(DEPLS.MTLmr3m)
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print(text, 1, 1)
	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.print(text)
end

-- Pause Live Simulator: 2
function DEPLS.Pause()
	if DEPLS.VideoBackgroundData then
		DEPLS.VideoBackgroundData[1]:pause()
	end
	
	if DEPLS.StoryboardHandle then
		DEPLS.StoryboardCallback("Pause")
		DEPLS.StoryboardHandle:Pause()
	end
	
	if DEPLS.Sound.LiveAudio then
		DEPLS.Sound.LiveAudio:pause()
	end
	
	DEPLS.Routines.PauseScreen.InitiatePause(DEPLS.Resume)
end

-- Resume Live Simulator: 2
function DEPLS.Resume()
	if DEPLS.VideoBackgroundData then
		DEPLS.VideoBackgroundData[1]:play()
	end
	
	if DEPLS.StoryboardHandle then
		DEPLS.StoryboardHandle:Resume()
		DEPLS.StoryboardCallback("Resume")
	end
	
	if DEPLS.Sound.LiveAudio then
		DEPLS.Sound.LiveAudio:seek(DEPLS.ElapsedTime * 0.001)
		DEPLS.Sound.LiveAudio:play()
	end
end

function DEPLS.IsLiveEnded()
	return (not(DEPLS.Sound.LiveAudio) or
			DEPLS.Sound.LiveAudio:isPlaying() == false) and
			DEPLS.NoteManager.NoteRemaining == 0
end

--! @brief DEPLS Initialization function
--! @param argv The arguments passed to the game via command-line
function DEPLS.Start(argv)
	DEPLS.Arg = argv
	AquaShine.DisableSleep()
	AquaShine.DisableTouchEffect()
	EffectPlayer.Clear()
	
	-- Load tap sound. High priority
	local se_volume = AquaShine.LoadConfig("SE_VOLUME", 80) * 0.008
	DEPLS.Sound.PerfectTap = AquaShine.GetCachedData("sound/SE_306.ogg", love.audio.newSource, "sound/SE_306.ogg", "static")
	DEPLS.Sound.PerfectTap:setVolume(se_volume)
	DEPLS.Sound.GreatTap = AquaShine.GetCachedData("sound/SE_307.ogg", love.audio.newSource, "sound/SE_307.ogg", "static")
	DEPLS.Sound.GreatTap:setVolume(se_volume)
	DEPLS.Sound.GoodTap = AquaShine.GetCachedData("sound/SE_308.ogg", love.audio.newSource, "sound/SE_308.ogg", "static")
	DEPLS.Sound.GoodTap:setVolume(se_volume)
	DEPLS.Sound.BadTap = AquaShine.GetCachedData("sound/SE_309.ogg", love.audio.newSource, "sound/SE_309.ogg", "static")
	DEPLS.Sound.BadTap:setVolume(se_volume)
	DEPLS.Sound.StarExplode = AquaShine.GetCachedData("sound/SE_326.ogg", love.audio.newSource, "sound/SE_326.ogg", "static")
	DEPLS.Sound.StarExplode:setVolume(se_volume)
	
	-- Load notes image. High Priority
	DEPLS.Images.Note = {
		NoteEnd = AquaShine.LoadImage("assets/image/tap_circle/end_note.png"),
		Token = AquaShine.LoadImage("assets/image/tap_circle/e_icon_01.png"),
		LongNote = AquaShine.LoadImage("assets/image/ef_326_000.png"),
	}
	DEPLS.Images.Spotlight = AquaShine.LoadImage("assets/image/live/popn.png")
	DEPLS.SaveDirectory = love.filesystem.getSaveDirectory()
	DEPLS.NoteImageLoader = love.filesystem.load("noteimage.lua")(DEPLS, AquaShine)
	
	-- Load configuration
	local BackgroundID = AquaShine.LoadConfig("BACKGROUND_IMAGE", 11)
	local GlobalOffset = AquaShine.LoadConfig("GLOBAL_OFFSET", 0)
	local Keys = AquaShine.LoadConfig("IDOL_KEYS", "a\ts\td\tf\tspace\tj\tk\tl\t;")
	DEPLS.AutoPlay = assert(tonumber(AquaShine.LoadConfig("AUTOPLAY", 0))) == 1
	DEPLS.LiveDelay = math.max(AquaShine.LoadConfig("LIVESIM_DELAY", 1000), 1000)
	DEPLS.ElapsedTime = -DEPLS.LiveDelay
	DEPLS.NotesSpeed = math.max(AquaShine.LoadConfig("NOTE_SPEED", 800), 400)
	DEPLS.Stamina = math.min(AquaShine.LoadConfig("STAMINA_DISPLAY", 32) % 100, 99)
	DEPLS.TextScaling = assert(tonumber(AquaShine.LoadConfig("TEXT_SCALING", 1)))
	DEPLS.ScoreBase = AquaShine.LoadConfig("SCORE_ADD_NOTE", 1024)
	DEPLS.Keys = {}
	assert(DEPLS.LiveDelay > 0, "LIVESIM_DELAY must be positive and not zero")
	assert(DEPLS.ScoreBase > 0, "SCORE_ADD_NOTE must be positive and not zero")
	do
		local i = 9
		for w in Keys:gmatch("[^\t]+") do
			DEPLS.Keys[i] = w
			
			i = i - 1
		end
	end
	
	if DEPLS.MinimalEffect == nil then
		DEPLS.MinimalEffect = AquaShine.LoadConfig("MINIMAL_EFFECT", 0) == 1
	end
	
	-- Load modules
	DEPLS.NoteManager = assert(love.filesystem.load("note.lua"))(DEPLS, AquaShine)
	
	-- Load beatmap
	local noteloader_data = argv.Beatmap
	local notes_list = noteloader_data:GetNotesList()
	local custom_background = false
	DEPLS.StoryboardHandle = noteloader_data:GetStoryboard()
	DEPLS.Sound.BeatmapAudio = noteloader_data:GetBeatmapAudio()
	DEPLS.Sound.LiveClear = noteloader_data:GetLiveClearSound()
	
	-- Live Show! Cleared voice
	if DEPLS.Sound.LiveClear then DEPLS.Sound.LiveClear = love.audio.newSource(DEPLS.Sound.LiveClear) end
	
	-- Normalize song volume
	-- Enabled on fast system by default
	if DEPLS.Sound.BeatmapAudio and (not(AquaShine.IsSlowSystem()) and not(AquaShine.GetCommandLineConfig("norg"))) or AquaShine.GetCommandLineConfig("forcerg") then
		require("volume_normalizer")(DEPLS.Sound.BeatmapAudio)
	end
	
	-- Randomize note
	if argv.Random or AquaShine.GetCommandLineConfig("random") then
		local new_notes_list, msg = (require("randomizer2"))(notes_list)
		
		if not(new_notes_list) then
			AquaShine.Log("livesim2", "Can't be randomized: %s", msg)
		else
			DEPLS.NoteRandomized = true
			notes_list = new_notes_list
		end
	end
	
	-- Load background
	if  AquaShine.LoadConfig("AUTO_BACKGROUND", 1) == 0 then
		-- Background always default one
		noteloader_data.background = nil
	end
	
	local noteloader_background = noteloader_data:GetBackgroundID()
	
	if noteloader_background > 0 then
		BackgroundID = noteloader_backgroundid
	elseif noteloader_background == -1 then
		local cbackground = noteloader_data:GetCustomBackground()
		DEPLS.BackgroundImage[0][1] = cbackground[0]
		DEPLS.BackgroundImage[0][4] = 960 / cbackground[0]:getWidth()
		DEPLS.BackgroundImage[0][5] = 640 / cbackground[0]:getHeight()
		DEPLS.BackgroundImage[1][1] = cbackground[1]
		DEPLS.BackgroundImage[2][1] = cbackground[2]
		DEPLS.BackgroundImage[3][1] = cbackground[3]
		DEPLS.BackgroundImage[4][1] = cbackground[4]
		custom_background = true
	end
	
	DEPLS.ScoreBase = noteloader_data.scoretap or DEPLS.ScoreBase
	DEPLS.Stamina = noteloader_data.staminadisp or DEPLS.Stamina
	
	local noteloader_coverdata = noteloader_data:GetCoverArt()
	if noteloader_coverdata then
		local new_coverdata = {}
		
		DEPLS.HasCoverImage = true
		DEPLS.CoverShown = 3167
		DEPLS.ElapsedTime = DEPLS.ElapsedTime - 3167
		
		new_coverdata.arrangement = noteloader_coverdata.arrangement
		new_coverdata.title = noteloader_coverdata.title or argv[1]
		new_coverdata.image = noteloader_coverdata.image
		
		AquaShine.Log("livesim2", "Cover art init")
		DEPLS.Routines.CoverPreview.Initialize(new_coverdata)
	end
	
	-- Initialize storyboard
	if DEPLS.StoryboardHandle then
		AquaShine.Log("livesim2", "Storyboard init")
		DEPLS.StoryboardHandle:Initialize(DEPLS.StoryboardFunctions)
	else
		local video = noteloader_data:GetVideoBackground()
		
		if video then
			-- We have video. Letterbox the video accordingly
			local w, h = video:getDimensions()
			DEPLS.VideoBackgroundData = {video, w * 0.5, h * 0.5, math.max(960 / w, 640 / h)}
		end
	end
	
	-- If note style forcing is not enabled, get from config
	if not(DEPLS.ForceNoteStyle) then
		local ns = noteloader_data:GetNotesStyle()
		DEPLS.ForceNoteStyle = ns > 0 and ns or AquaShine.LoadConfig("NOTE_STYLE", 1)
	end
	
	-- Add to note manager
	AquaShine.Log("livesim2", "Note data init")
	do
		for i = 1, #notes_list do
			DEPLS.StoryboardCallback("AddNote", notes_list[i])
			DEPLS.NoteManager.Add(notes_list[i], GlobalOffset)
		end
	end
	DEPLS.NoteManager.InitializeImage()
	
	-- Initialize flash animation
	DEPLS.LiveShowCleared:setMovie("ef_311")
	DEPLS.FullComboAnim:setMovie("ef_329")
	
	-- Calculate score bar
	local score_info = noteloader_data:GetScoreInformation()
	if score_info then
		for i = 1, 4 do
			-- Use info from beatmap
			DEPLS.ScoreData[i] = score_info[i]
		end
	else
		-- Calculate using master difficulty preset
		local s_score = #notes_list * 739
		
		DEPLS.ScoreData[1] = math.floor(s_score * 0.285521 + 0.5)
		DEPLS.ScoreData[2] = math.floor(s_score * 0.71448 + 0.5)
		DEPLS.ScoreData[3] = math.floor(s_score * 0.856563 + 0.5)
		DEPLS.ScoreData[4] = s_score
	end
	
	-- BeatmapAudio is actually SoundData, LiveAudio is the real Source
	if DEPLS.Sound.BeatmapAudio then
		DEPLS.Sound.LiveAudio = love.audio.newSource(DEPLS.Sound.BeatmapAudio)
	end
	
	----------------------
	-- Load image start --
	----------------------
	
	-- Load background if no storyboard present
	if not(DEPLS.StoryboardHandle) and not(custom_background) then
		DEPLS.BackgroundImage[0][1] = AquaShine.LoadImage("assets/image/background/liveback_"..BackgroundID..".png")
		
		for i = 1, 4 do
			DEPLS.BackgroundImage[i][1] = AquaShine.LoadImage(string.format("assets/image/background/b_liveback_%03d_%02d.png", BackgroundID, i))
		end
	end
	
	-- Tap circle effect
	DEPLS.Images.ef_316_000 = AquaShine.LoadImage("assets/image/live/ef_316_000.png")
	DEPLS.Images.ef_316_001 = AquaShine.LoadImage("assets/image/live/ef_316_001.png")
	
	-- Load live header images
	DEPLS.Images.Header = AquaShine.LoadImage("assets/image/live/live_header.png")
	DEPLS.Images.ScoreGauge = AquaShine.LoadImage("assets/image/live/live_gauge_03_02.png")
	DEPLS.Images.Pause = AquaShine.LoadImage("assets/image/live/live_pause.png")
	
	-- Load unit icons
	local noteloader_units = noteloader_data:GetCustomUnitInformation()
	local IdolImagePath = {}
	do
		local idol_img = AquaShine.LoadConfig("IDOL_IMAGE", "dummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy")
		
		for w in idol_img:gmatch("[^\t]+") do
			IdolImagePath[#IdolImagePath + 1] = w
		end
	end
	for i = 1, 9 do
		DEPLS.IdolImageData[i][1] = noteloader_units[i] or DEPLS.LoadUnitIcon(IdolImagePath[10 - i])
	end
	
	-- Load stamina image (bar and number)
	DEPLS.Images.StaminaRelated = {
		Bar = AquaShine.LoadImage("assets/image/live/live_gauge_02_02.png")
	}
	do
		local stamina_display_str = tostring(DEPLS.Stamina)
		local matcher = stamina_display_str:gmatch("%d")
		local temp
		local temp_num
		local stamina_number_image = {}
		
		for i = 1, #stamina_display_str do
			temp = matcher()
			temp_num = tonumber(temp)
			
			if DEPLS.Images.StaminaRelated[temp_num] == nil then
				DEPLS.Images.StaminaRelated[temp_num] = AquaShine.LoadImage("assets/image/live/hp_num/live_num_"..temp..".png")
			end
			
			stamina_number_image[i] = DEPLS.Images.StaminaRelated[temp_num]
		end
		
		DEPLS.Images.StaminaRelated.DrawTarget = stamina_number_image
	end
	
	-- Load score eclipse related image
	DEPLS.Routines.ScoreEclipseF.Img = AquaShine.LoadImage("assets/image/live/l_etc_46.png")
	DEPLS.Routines.ScoreEclipseF.Img2 = AquaShine.LoadImage("assets/image/live/l_gauge_17.png")
	
	-- Load score node number
	for i = 21, 30 do
		DEPLS.Images.ScoreNode[i - 21] = AquaShine.LoadImage("assets/image/live/score_num/l_num_"..i..".png")
	end
	DEPLS.Images.ScoreNode.Plus = AquaShine.LoadImage("assets/image/live/score_num/l_num_31.png")
	
	-- Tap accuracy image
	DEPLS.Images.Perfect = AquaShine.LoadImage("assets/image/live/ef_313_004_w2x.png")
	DEPLS.Images.Great = AquaShine.LoadImage("assets/image/live/ef_313_003_w2x.png")
	DEPLS.Images.Good = AquaShine.LoadImage("assets/image/live/ef_313_002_w2x.png")
	DEPLS.Images.Bad = AquaShine.LoadImage("assets/image/live/ef_313_001_w2x.png")
	DEPLS.Images.Miss = AquaShine.LoadImage("assets/image/live/ef_313_000_w2x.png")
		DEPLS.Routines.PerfectNode.Center = {
		[DEPLS.Images.Perfect] = {198, 38},
		[DEPLS.Images.Great] = {147, 35},
		[DEPLS.Images.Good] = {127, 35},
		[DEPLS.Images.Bad] = {86, 33},
		[DEPLS.Images.Miss] = {93, 30}
	}
	DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
	-- Initialize tap accuracy routine
	DEPLS.Routines.PerfectNode.Draw()
	
	-- Load NoteIcon image
	DEPLS.Images.NoteIcon = AquaShine.LoadImage("assets/image/live/ef_308_000.png")
	DEPLS.Images.NoteIconCircle = AquaShine.LoadImage("assets/image/live/ef_308_001.png")
	
	-- Load Font
	DEPLS.MTLmr3m = AquaShine.LoadFont("MTLmr3m.ttf", 24)
	
	-- Set NoteLoader object
	DEPLS.NoteLoaderObject = noteloader_data
end

-- Used internally
local persistent_bg_opacity = 0
local audioplaying = false
local audiodeltaT = 0
local audiolasttime = 0

--! @brief DEPLS Update function. It is separated to allow offline rendering
--! @param deltaT Delta-time in milliseconds
function DEPLS.Update(deltaT)
	deltaT = deltaT * DEPLS.PlaySpeed
	
	if not(DEPLS.Routines.PauseScreen.IsPaused()) then
		DEPLS.ElapsedTime = DEPLS.ElapsedTime + deltaT
	end
	
	local ElapsedTime = DEPLS.ElapsedTime
	local Routines = DEPLS.Routines
	
	if DEPLS.CoverShown > 0 then
		DEPLS.Routines.CoverPreview.Update(deltaT)
		DEPLS.CoverShown = DEPLS.CoverShown - deltaT
	end
	
	if ElapsedTime <= 0 then
		persistent_bg_opacity = (ElapsedTime + DEPLS.LiveDelay) / DEPLS.LiveDelay * 191
	end
	
	if ElapsedTime > 0 then
		if DEPLS.Sound.LiveAudio and audioplaying == false then
			DEPLS.Sound.LiveAudio:setVolume(DEPLS.BeatmapAudioVolume)
			DEPLS.Sound.LiveAudio:play()
			DEPLS.Sound.LiveAudio:seek(ElapsedTime * 0.001)
			audioplaying = true
		end
		
		if DEPLS.VideoBackgroundData and not(DEPLS.VideoBackgroundData[5]) then
			DEPLS.VideoBackgroundData[1]:play()
		end
		
		-- Update note if it's not paused
		if not(DEPLS.Routines.PauseScreen.IsPaused()) then
			DEPLS.NoteManager.Update(deltaT)
		end
		
		-- Update combo cheer if no storyboard or storyboard allows it
		if not(DEPLS.StoryboardHandle) or DEPLS.ComboCheerForced then
			Routines.ComboCheer.Update(deltaT)
		end
		
		-- Update routines
		Routines.ComboCounter.Update(deltaT)
		Routines.NoteIcon.Update(deltaT)
		Routines.ScoreEclipseF.Update(deltaT)
		Routines.ScoreUpdate.Update(deltaT)
		Routines.ScoreBar.Update(deltaT)
		Routines.SkillPopups.Update(deltaT)
		Routines.PerfectNode.Update(deltaT)
		
		-- Update effect player
		EffectPlayer.Update(deltaT)
		
		if DEPLS.IsLiveEnded() then
			Routines.LiveClearAnim.Update(deltaT)
		end
		
		Routines.PauseScreen.Update(deltaT)
	end
end

--! @brief DEPLS Draw function. It is separated to allow offline rendering
--! @param deltaT Delta-time in milliseconds
function DEPLS.Draw(deltaT)
	deltaT = deltaT * DEPLS.PlaySpeed
	-- Localize love functions
	local graphics = love.graphics
	local rectangle = graphics.rectangle
	local draw = graphics.draw
	local setColor = graphics.setColor
	local Images = DEPLS.Images
	
	local Routines = DEPLS.Routines
	local ElapsedTime = DEPLS.ElapsedTime
	local AllowedDraw = DEPLS.ElapsedTime > 0 
	
	if AquaShine.FFmpegExt then
		AquaShine.FFmpegExt.Update(deltaT * 0.001)
	end
	
	-- If there's storyboard, draw the storyboard instead.
	if DEPLS.StoryboardHandle then
		DEPLS.StoryboardHandle:Draw(deltaT)
	elseif DEPLS.VideoBackgroundData and AllowedDraw then
		-- Draw video if available
		love.graphics.draw(
			DEPLS.VideoBackgroundData[1],
			480, 320, 0,
			DEPLS.VideoBackgroundData[4],
			DEPLS.VideoBackgroundData[4],
			DEPLS.VideoBackgroundData[2],
			DEPLS.VideoBackgroundData[3]
		)
	else
		-- No storyboard & video still not allowed to draw. Draw background
		local BackgroundImage = DEPLS.BackgroundImage
		
		draw(
			BackgroundImage[0][1],
			BackgroundImage[0][2],
			BackgroundImage[0][3],
			0,
			BackgroundImage[0][4] or 1,
			BackgroundImage[0][5] or 1
		)
		
		for i = 1, 4 do
			if BackgroundImage[i][1] then
				draw(BackgroundImage[i][1], BackgroundImage[i][2], BackgroundImage[i][3])
			end
		end
	end
	
	-- Draw background blackness
	if DEPLS.CoverShown > 0 then
		DEPLS.Routines.CoverPreview.Draw()
	else
		setColor(0, 0, 0, DEPLS.BackgroundOpacity * persistent_bg_opacity / 255)
		rectangle("fill", -88, -43, 1136, 726)
		setColor(255, 255, 255, 255)
	end
		
	if AllowedDraw then
		-- Draw combo cheer
		if not(DEPLS.StoryboardHandle) or DEPLS.ComboCheerForced then
			Routines.ComboCheer.Draw()
		end
		
		-- Draw cut-in
		Routines.SkillPopups.Draw()
		
		-- Draw header
		setColor(255, 255, 255, DEPLS.LiveOpacity)
		draw(Images.Header, 0, 0)
		draw(Images.ScoreGauge, 5, 8, 0, 0.99545454, 0.86842105)
		
		draw(Images.StaminaRelated.Bar, 14, 60)
		for i = 1, #Images.StaminaRelated.DrawTarget do
			draw(Images.StaminaRelated.DrawTarget[i], 290 + 16 * i, 66)
		end
		
		-- Draw idol unit
		local IdolData = DEPLS.IdolImageData
		local IdolPos = DEPLS.IdolPosition
		
		for i = 1, 9 do
			setColor(255, 255, 255, DEPLS.LiveOpacity * IdolData[i][2] / 255)
			draw(IdolData[i][1], IdolPos[i][1], IdolPos[i][2])
		end
		
		-- Update note
		DEPLS.NoteManager.Draw()
		
		-- Draw routines
		Routines.ComboCounter.Draw()
		Routines.NoteIcon.Draw()
		Routines.ScoreBar.Draw()
		Routines.ScoreEclipseF.Draw()
		Routines.ScoreUpdate.Draw()
		Routines.PerfectNode.Draw()
		
		-- Update effect player
		EffectPlayer.Draw()

		-- Live clear animation
		if DEPLS.IsLiveEnded() then
			Routines.LiveClearAnim.Draw()
		else
			draw(Images.Pause, 916, 5, 0, 0.6)
		end
		
		-- Pause overlay
		Routines.PauseScreen.Draw()
	end
	
	if DEPLS.DebugDisplay then
		DEPLS.DrawDebugInfo()
	end
end

-- LOVE2D mouse/touch pressed
local TouchTracking = {}
local isMousePress = false
local TouchXRadius = 132
local TouchYRadius = 74
function DEPLS.MousePressed(x, y, button, touch_id)
	if DEPLS.Routines.PauseScreen.IsPaused() then
		return DEPLS.Routines.PauseScreen.MousePressed(x, y, button, touch_id)
	end
	
	if DEPLS.ElapsedTime <= 0 or DEPLS.AutoPlay then return end
	
	touch_id = touch_id or 0
	isMousePress = touch_id == 0 and button == 1
	
	-- Calculate idol position
	for i = 1, 9 do
		local idolpos = DEPLS.IdolPosition[i]
		local xp = (math.cos(EllipseRot[i]) * (x - (idolpos[1] + 64)) + math.sin(EllipseRot[i]) * (y - (idolpos[2] + 64))) / TouchXRadius
		local yp = (math.sin(EllipseRot[i]) * (x - (idolpos[1] + 64)) - math.cos(EllipseRot[i]) * (y - (idolpos[2] + 64))) / TouchYRadius
		
		if xp * xp + yp * yp <= 1 then
			TouchTracking[touch_id] = i
			DEPLS.NoteManager.SetTouch(i, touch_id)
			break
		end
	end
end

function DEPLS.MouseMoved(x, y, dx, dy, touch_id)
	if DEPLS.Routines.PauseScreen.IsPaused() then
		return DEPLS.Routines.PauseScreen.MouseMoved(x, y, dx, dy, touch_id)
	end
	
	if DEPLS.AutoPlay then return end
	if isMousePress or touch_id then
		touch_id = touch_id or 0
		
		local lastpos = TouchTracking[touch_id]
		
		for i = 1, 9 do
			if i ~= lastpos then
				local idolpos = DEPLS.IdolPosition[i]
				local xp = (math.cos(EllipseRot[i]) * (x - (idolpos[1] + 64)) + math.sin(EllipseRot[i]) * (y - (idolpos[2] + 64))) / TouchXRadius
				local yp = (math.sin(EllipseRot[i]) * (x - (idolpos[1] + 64)) - math.cos(EllipseRot[i]) * (y - (idolpos[2] + 64))) / TouchYRadius
				
				if xp * xp + yp * yp <= 1 then
					TouchTracking[touch_id] = i
					DEPLS.NoteManager.SetTouch(i, touch_id, false, lastpos)
					
					break
				end
			end
		end
	end
end

function DEPLS.MouseReleased(x, y, button, touch_id)
	if DEPLS.Routines.PauseScreen.IsPaused() then
		return DEPLS.Routines.PauseScreen.MouseReleased(x, y, button, touch_id)
	end
	
	if DEPLS.ElapsedTime <= 0 then return end
	
	if isMousePress and touch_id == false and button == 1 then
		isMousePress = false
	end
	
	touch_id = touch_id or 0
	
	-- Send unset touch message
	TouchTracking[touch_id] = nil
	DEPLS.NoteManager.SetTouch(nil, touch_id, true)
	
	if DEPLS.Routines.ResultScreen.CanExit then
		-- Back
		AquaShine.LoadEntryPoint("beatmap_select.lua", {Random = DEPLS.Arg.Random})
	end
	
	if not(DEPLS.IsLiveEnded()) and x >= 916 and y >= 6 and x < 952 and y < 42 then
		DEPLS.Pause()
	end
end

local function update_audio_volume()
	if DEPLS.Sound.LiveAudio then
		DEPLS.Sound.LiveAudio:setVolume(DEPLS.BeatmapAudioVolume)
	end
end

function DEPLS.KeyPressed(key, scancode, repeat_bit)
	if DEPLS.Routines.PauseScreen.IsPaused() then return end
	
	if key == "f6" then
		DEPLS.BeatmapAudioVolume = math.min(DEPLS.BeatmapAudioVolume + 0.05, 1)
		update_audio_volume()
	elseif key == "f5" then
		DEPLS.BeatmapAudioVolume = math.max(DEPLS.BeatmapAudioVolume - 0.05, 0)
		update_audio_volume()
	elseif key == "pause" and DEPLS.ElapsedTime > 0 then
		DEPLS.Pause()
	elseif DEPLS.ElapsedTime >= 0 then
		for i = 1, 9 do
			if key == DEPLS.Keys[i] then
				DEPLS.NoteManager.SetTouch(i, key)
				break
			end
		end
	end
end

function DEPLS.KeyReleased(key)
	if key == "escape" then
		-- Back
		AquaShine.LoadEntryPoint("beatmap_select.lua", {Random = DEPLS.Arg.Random})
	elseif key == "backspace" then
		-- Restart
		AquaShine.LoadEntryPoint("livesim.lua", DEPLS.Arg)
		DEPLS.NoteLoaderObjectNoRelease = true
	elseif key == "lshift" then
		DEPLS.DebugDisplay = not(DEPLS.DebugDisplay)
	elseif key == "lctrl" then
		DEPLS.AutoPlay = not(DEPLS.AutoPlay)
	elseif key == "lalt" then
		DEPLS.DebugNoteDistance = not(DEPLS.DebugNoteDistance)
	elseif key == "pageup" and not(DEPLS.PlaySpeedAlterDisabled) and DEPLS.PlaySpeed < 4 then
		-- Increase play speed
		DEPLS.StoryboardFunctions.SetPlaySpeed(DEPLS.PlaySpeed * 2)
	elseif key == "pagedown" and not(DEPLS.PlaySpeedAlterDisabled) and DEPLS.PlaySpeed > 0.0625 then
		-- Decrease play speed
		DEPLS.StoryboardFunctions.SetPlaySpeed(DEPLS.PlaySpeed * 0.5)
	elseif DEPLS.ElapsedTime >= 0 and not(DEPLS.Routines.PauseScreen.IsPaused()) then
		for i = 1, 9 do
			if key == DEPLS.Keys[i] then
				DEPLS.NoteManager.SetTouch(nil, key, true)
				break
			end
		end
	end
end

function DEPLS.Exit()
	-- Stop audio
	if DEPLS.Sound.LiveAudio then
		DEPLS.Sound.LiveAudio:stop()
	end
	
	-- Cleanup storyboard
	if DEPLS.StoryboardHandle then
		DEPLS.StoryboardHandle:Cleanup()
	end
	
	-- Cleanup note object if necessary
	if not(DEPLS.NoteLoaderObjectNoRelease) then
		DEPLS.NoteLoaderObject:ReleaseBeatmapAudio()
		DEPLS.NoteLoaderObject:Release()
	end
	
	if DEPLS.VideoBackgroundData then
		DEPLS.VideoBackgroundData[1]:pause()
		DEPLS.VideoBackgroundData = nil
		love.handlers.lowmemory()
	end
end

function DEPLS.Focus(focus)
	if not(AquaShine.IsDesktopSystem()) and focus and DEPLS.Sound.LiveAudio and DEPLS.ElapsedTime >= 0 then
		DEPLS.Sound.LiveAudio:seek(DEPLS.ElapsedTime * 0.001)
	end
end

DEPLS.Distance = distance
DEPLS.AngleFrom = angle_from

return DEPLS, "Playing"
