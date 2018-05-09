-- Live Simulator: 2
-- High-performance LL!SIF Live Simulator
-- See copyright notice in main.lua

local love = require("love")
local AquaShine = ...
local EffectPlayer = require("effect_player")
local Yohane = require("Yohane")
local TapSound = require("tap_sound")
local BackgroundLoader = AquaShine.LoadModule("background_loader")
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

	DefaultColorMode = 255,     -- Color range
	BackgroundOpacity = 1,      -- User background opacity set from storyboard
	BackgroundImage = {         -- Index 0 is the main background
		-- {handle, logical x, logical y, x size, y size}
		{nil, -88, 0},
		{nil, 960, 0},
		{nil, 0, -43},
		{nil, 0, 640},
		[0] = {nil, 0, 0}
	},
	LiveOpacity = 1,	-- Live opacity
	AutoPlay = false,	-- Autoplay?

	LiveShowClearedReal = AquaShine.GetCachedData("lclrflsh", Yohane.newFlashFromFilename, "flash/live_clear.flsh"),
	FullComboAnimReal = AquaShine.GetCachedData("fcflsh", Yohane.newFlashFromFilename, "flash/live_fullcombo.flsh"),

	StoryboardErrorMsg = "",
	StoryboardFunctions = {},	-- Additional function to be added in sandboxed lua storyboard
	Routines = {},			-- Table to store all DEPLS effect routines

	IdolPosition = {	-- Idol position. 9 is leftmost. Relative to top-left corner
		{816, 96 }, {785, 249}, {698, 378},
		{569, 465}, {416, 496}, {262, 465},
		{133, 378}, {46 , 249}, {16 , 96 },
	},
	IdolQuads = {},
	IdolImageData = {	-- [idol positon] = {image handle, opacity, spritebatch id}
		{nil, 1, 0}, {nil, 1, 0}, {nil, 1, 0},
		{nil, 1, 0}, {nil, 1, 0}, {nil, 1, 0},
		{nil, 1, 0}, {nil, 1, 0}, {nil, 1, 0}
	},
	MinimalEffect = nil,		-- True means decreased dynamic effects
	NoteManager = nil,
	NoteLoader = nil,
	NoteRandomized = false,
	Stamina = 32,
	TimingOffset = 0,
	NotesSpeed = 800,
	ScoreBase = 500,
	ScoreData = {		-- Contains C score, B score, A score, S score data, in order.
		1,
		2,
		3,
		4
	},

	Images = {		-- Lists of loaded images
		Note = {}
	},
	Sound = {},

	-- Contains audio information
	AudioInfo = {
		SampleRate = 44100,
		Depth = 16,
		Channels = 2
	}
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

for i = 1, #DEPLS.IdolPosition do
	DEPLS.IdolQuads[i] = love.graphics.newQuad(DEPLS.IdolPosition[i][1], DEPLS.IdolPosition[i][2], 128, 128, 960, 640)
end

-----------------------
-- Private functions --
-----------------------

local function distance(a, b)
	return math.sqrt(a * a + b * b)
end

local function angle_from(x1, y1, x2, y2)
	return math.atan2(y2 - y1, x2 - x1) - math.pi / 2
end

------------------------
-- Animation routines --
------------------------

-- These are base routines which does cause problem when
-- loaded late. But it doesn't affect UI (Lovewing or SIF)
-- so it's good to load it early.

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

function DEPLS.LoadRoutinesSIF()
	-- Live header
	DEPLS.Routines.LiveHeader = assert(love.filesystem.load("livesim/liveheader.lua"))(DEPLS, AquaShine)
	-- Tap accuracy display routine
	DEPLS.Routines.PerfectNode = assert(love.filesystem.load("livesim/judgement.lua"))(DEPLS, AquaShine)
	-- Circletap aftertap effect namespace
	DEPLS.Routines.CircleTapEffect = assert(love.filesystem.load("livesim/circletap_effect.lua"))(DEPLS, AquaShine)
	-- Combo counter effect namespace
	DEPLS.Routines.ComboCounter = assert(love.filesystem.load("livesim/combocounter.lua"))(DEPLS, AquaShine)
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

	DEPLS.Routines.ScoreEclipseF.ScoreBar = DEPLS.Routines.ScoreBar
end

function DEPLS.LoadRoutinesLovewing()
	-- Live header
	DEPLS.Routines.LiveHeader = assert(love.filesystem.load("lovewing/liveheader.lua"))(DEPLS, AquaShine)
	-- Tap accuracy display routine
	DEPLS.Routines.PerfectNode = assert(love.filesystem.load("lovewing/judgement.lua"))(DEPLS, AquaShine)
	-- Circletap aftertap effect namespace
	DEPLS.Routines.CircleTapEffect = assert(love.filesystem.load("lovewing/circletap_effect.lua"))(DEPLS, AquaShine)
	-- Combo counter effect namespace
	DEPLS.Routines.ComboCounter = assert(love.filesystem.load("lovewing/combocounter.lua"))(DEPLS, AquaShine)
	-- Note icon (note spawn pos) animation
	DEPLS.Routines.NoteIcon = assert(love.filesystem.load("lovewing/noteicon.lua"))(DEPLS, AquaShine)
	-- Score display routine
	DEPLS.Routines.ScoreUpdate = assert(love.filesystem.load("lovewing/scoreupdate.lua"))(DEPLS, AquaShine)
	-- Score bar routine. Depends on score display
	DEPLS.Routines.ScoreBar = assert(love.filesystem.load("lovewing/scorebar.lua"))(DEPLS, AquaShine)
	-- Score flash animation routine
	DEPLS.Routines.ScoreEclipseF = assert(love.filesystem.load("lovewing/score_eclipsef.lua"))(DEPLS, AquaShine)
	DEPLS.Routines.ScoreEclipseF.ScoreBar = DEPLS.Routines.ScoreBar
end

function DEPLS.Routines.UpdateSIF(deltaT)
	DEPLS.Routines.LiveHeader.Update(deltaT)
	DEPLS.Routines.ComboCounter.Update(deltaT)
	DEPLS.Routines.NoteIcon.Update(deltaT)
	DEPLS.Routines.ScoreEclipseF.Update(deltaT)
	DEPLS.Routines.ScoreUpdate.Update(deltaT)
	DEPLS.Routines.ScoreBar.Update(deltaT)
	DEPLS.Routines.SkillPopups.Update(deltaT)
	DEPLS.Routines.PerfectNode.Update(deltaT)
end

function DEPLS.Routines.DrawSIF()
	DEPLS.Routines.ComboCounter.Draw()
	DEPLS.Routines.NoteIcon.Draw()
	DEPLS.Routines.ScoreBar.Draw()
	DEPLS.Routines.ScoreEclipseF.Draw()
	DEPLS.Routines.ScoreUpdate.Draw()
	DEPLS.Routines.PerfectNode.Draw()
end

function DEPLS.Routines.CheckPausePosSIF(x, y)
	return x >= 898 and y >= -12 and x < 970 and y < 60
end

function DEPLS.Routines.UpdateLovewing(deltaT)
	DEPLS.Routines.LiveHeader.Update(deltaT)
	DEPLS.Routines.ComboCounter.Update(deltaT)
	DEPLS.Routines.NoteIcon.Update(deltaT)
	DEPLS.Routines.ScoreEclipseF.Update(deltaT)
	DEPLS.Routines.ScoreUpdate.Update(deltaT)
	DEPLS.Routines.ScoreBar.Update(deltaT)
	DEPLS.Routines.SkillPopups.Update(deltaT)
	DEPLS.Routines.PerfectNode.Update(deltaT)
end

function DEPLS.Routines.DrawLovewing()
	DEPLS.Routines.ComboCounter.Draw()
	DEPLS.Routines.NoteIcon.Draw()
	DEPLS.Routines.ScoreBar.Draw()
	DEPLS.Routines.ScoreUpdate.Draw()
	DEPLS.Routines.ScoreEclipseF.Draw()
	DEPLS.Routines.PerfectNode.Draw()
end

function DEPLS.Routines.CheckPausePosLovewing(x, y)
	return x >= 34 and y >= 17 and x < 63 and y < 46
end

function DEPLS.LoadRoutines()
	if DEPLS.LiveUI == "lovewing" then
		DEPLS.Routines.Update = DEPLS.Routines.UpdateLovewing
		DEPLS.Routines.Draw = DEPLS.Routines.DrawLovewing
		DEPLS.Routines.CheckPausePos = DEPLS.Routines.CheckPausePosLovewing
		return DEPLS.LoadRoutinesLovewing()
	else
		DEPLS.Routines.Update = DEPLS.Routines.UpdateSIF
		DEPLS.Routines.Draw = DEPLS.Routines.DrawSIF
		DEPLS.Routines.CheckPausePos = DEPLS.Routines.CheckPausePosSIF
		return DEPLS.LoadRoutinesSIF()
	end
end

--------------------------------
-- Another public functions   --
-- Some is part of storyboard --
--------------------------------

--! @brief Add score, additionally adding some bonus based on combo
--! @param score The score value
function DEPLS.AddScore(score)
	local ComboCounter = DEPLS.Routines.ComboCounter
	local added_score = score

	if ComboCounter.CurrentCombo < 50 then
		added_score = added_score
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

	return DEPLS.AddScoreDirect(math.floor(added_score))
end

--! @brief Add score, directly without additional calculation
--! @param score The score value
function DEPLS.AddScoreDirect(score)
	score = math.floor(score)

	DEPLS.Routines.ScoreUpdate.CurrentScore = DEPLS.Routines.ScoreUpdate.CurrentScore + score

	if DEPLS.Routines.ScoreEclipseF then
		DEPLS.Routines.ScoreEclipseF.Replay = true
	end

	if not(DEPLS.MinimalEffect) and DEPLS.Routines.ScoreNode then
		EffectPlayer.Spawn(DEPLS.Routines.ScoreNode.Create(score))
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
	opacity = math.max(math.min(opacity or DEPLS.DefaultColorMode, DEPLS.DefaultColorMode), 0)
	DEPLS.LiveOpacity = opacity / DEPLS.DefaultColorMode
end

--! @brief Sets background blackness
--! @param opacity Transparency. 0 = full black, 255 = full light
function DEPLS.StoryboardFunctions.SetBackgroundDimOpacity(opacity)
	opacity = math.max(math.min(opacity or DEPLS.DefaultColorMode, DEPLS.DefaultColorMode), 0)
	DEPLS.BackgroundOpacity = 1 - opacity / DEPLS.DefaultColorMode
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

	return EffectPlayer.Spawn(effect)
end

--! @brief Set unit visibility
--! @param pos The unit position (9 is leftmost)
--! @param opacity The desired opacity. 0 is fully transparent, 255 is fully opaque (255 default)
function DEPLS.StoryboardFunctions.SetUnitOpacity(pos, opacity)
	local data = assert(DEPLS.IdolImageData[pos], "Invalid pos specificed")
	data[2] = math.min(math.max(opacity or DEPLS.DefaultColorMode, 0), DEPLS.DefaultColorMode) / DEPLS.DefaultColorMode
	DEPLS.IdolImageSpriteBatch:setColor(1, 1, 1, data[2])
	DEPLS.IdolImageSpriteBatch:set(
		data[3], DEPLS.IdolQuads[pos],
		DEPLS.IdolPosition[pos][1], DEPLS.IdolPosition[pos][2]
	)
end

do
	-- Wrapper function to return empty sample if it's out of range
	local function getsample_safe(sound_data, pos)
		local s, sample = pcall(sound_data.getSample, sound_data, pos)

		if s == false then
			return 0
		end

		return sample
	end

	local function getSampleSoundData(size)
		-- Default size
		size = size or 512

		local audio = DEPLS.Sound.BeatmapAudio
		local sample_list = {}

		if not(audio) then
			-- There's no audio. Fill it with empty samples
			for i = 1, size do
				sample_list[#sample_list + 1] = {0, 0}
			end

			return sample_list
		end

		local pos = DEPLS.Sound.LiveAudio:tell("samples")

		if DEPLS.AudioInfo.Channels == 1 then
			for i = pos, pos + size - 1 do
				-- Mono
				local sample = getsample_safe(audio, i)

				sample_list[#sample_list + 1] = {sample, sample}
			end
		elseif DEPLS.AudioInfo.Channels == 2 then
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

	local function getSampleQueue(size)
		size = size or 512
		local sample_list = {}

		-- If there are no sound data, fill with empty.
		-- This check must be as early as possible.
		if not(DEPLS.Sound.LiveAudio) then
			for _ = 1, size do
				sample_list[#sample_list + 1] = {0, 0}
			end

			return sample_list
		end

		local currentIndex = DEPLS.Sound.LiveAudio:getFreeBufferCount() + 1
		local curPos = DEPLS.Sound.LiveAudio:tell("samples")
		local sample = DEPLS.Sound.QueueBuffer[currentIndex]

		-- If there are no decoder, or there are no more samples
		-- then fill with empty
		if not(DEPLS.Sound.BeatmapDecoder) or sample == nil then
			for _ = 1, size do
				sample_list[#sample_list + 1] = {0, 0}
			end

			return sample_list
		end

		-- From my observation, in queued audio source, Source:tell("samples") returns
		-- the internal buffer sample position.
		local sampleLen = sample:getSampleCount()
		for i = 1, size do
			if DEPLS.AudioInfo.Channels == 1 then
					local smp = getsample_safe(sample, curPos)

					sample_list[#sample_list + 1] = {smp, smp}
			elseif DEPLS.AudioInfo.Channels == 2 then
					-- Stereo
					sample_list[#sample_list + 1] = {
						getsample_safe(sample, curPos * 2),
						getsample_safe(sample, curPos * 2 + 1),
					}
			end

			curPos = curPos + 1
			if curPos >= sampleLen then
				-- Fetch next sample
				currentIndex = currentIndex + 1
				sample = DEPLS.Sound.QueueBuffer[currentIndex]
				curPos = 0
			end

			if sample == nil then
				-- No more samples. Fill with zeros and we're done
				for _ = i + 1, size do
					sample_list[#sample_list + 1] = {0, 0}
				end
				break
			end
		end

		return sample_list
	end

	--! @brief Gets current playing audio sample with specificed size
	--! @param size The sample size (1 default = 1 sample)
	--! @returns table containing the samples with size `size`
	--! @note This function handles mono/stereo input and this function still works even
	--!       if no audio is found, where in that case the sample is simply 0
	function DEPLS.StoryboardFunctions.GetCurrentAudioSample(size)
		if DEPLS.Sound.BeatmapAudio then
			return getSampleSoundData(size)
		else
			return getSampleQueue(size)
		end
	end
end

--! @brief Get current audio sample rate
--! @returns Audio sample rate (or 44100 if there's no sound)
function DEPLS.StoryboardFunctions.GetCurrentAudioSampleRate()
	return DEPLS.AudioInfo.SampleRate
end

--! @brief Loads Live Simulator: 2 image file
--! @param path The image path
--! @returns Image handle or nil on failure
function DEPLS.StoryboardFunctions.LoadDEPLS2Image(path)
	local s, a = pcall(love.graphics.newImage, path)

	if s then
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

--! @brief Force set the note style
--! @param note_style Force note style (1, 2, or 3)
--! @note This function can only be called in pre-initialize or in Initialize function
function DEPLS.StoryboardFunctions.ForceNoteStyle(note_style)
	note_style = assert(tonumber(note_style), "Invalid note style ID")
	note_style = assert(note_style > 0 and note_style < 4 and note_style, "Invalid note style ID")
	DEPLS.ForceNoteStyle = note_style
end

-- Backward compatibility
function DEPLS.StoryboardFunctions.ForceNewNoteStyle(ns)
	return DEPLS.StoryboardFunctions.ForceNoteStyle(ns and 2 or 1)
end

--! @brief Check if current storyboard is under rendering mode
--! @returns In rendering mode (true) or live mode (false)
function DEPLS.StoryboardFunctions.IsRenderingMode()
	return not(not(DEPLS.RenderingMode))
end

function DEPLS.StoryboardFunctions.SkillPopup(...)
	return DEPLS.Routines.SkillPopups.Spawn(select(1, ...))
end

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

--! @brief Get the current beatmap background
--! @returns LOVE `Mesh` object which can be drawn for full background
function DEPLS.StoryboardFunctions.GetCurrentBackgroundImage()
	return DEPLS.StockBackgroundImage
end

--! @brief Get the current unit image
--! @param idx The unit index to retrieve it's image. 1 is rightmost, 9 is leftmost.
--! @returns LOVE `Image` object
function DEPLS.StoryboardFunctions.GetCurrentUnitImage(idx)
	assert(idx > 0 and idx < 10, "Invalid index")
	return DEPLS.IdolImageData[idx][1]
end

--! @brief Add score
--! @param score The score value (must be bigger than 0)
function DEPLS.StoryboardFunctions.AddScore(score)
	return DEPLS.AddScoreDirect(assert(score > 0 and score, "Score must be bigger than 0"))
end

--! @brief Activates or sets the Timing Window++ skill (Red) timer
--! @param dur The duration in milliseconds
--! @note If the current timing duration is higher than `dur`, this function has no effect
function DEPLS.StoryboardFunctions.SetRedTimingDuration(dur)
	return DEPLS.NoteManager.TimingRed(dur)
end

--! @brief Activates or sets the Timing Window+ skill (Yellow) timer
--! @param dur The duration in milliseconds
--! @note If the current duration is higher than `dur`, this function has no effect
function DEPLS.StoryboardFunctions.SetYellowTimingDuration(dur)
	return DEPLS.NoteManager.TimingYellow(dur)
end

function DEPLS.StoryboardFunctions.IsLiveEnded()
	return DEPLS.IsLiveEnded()
end

--! @brief Check whenever the notes is randomized
--! @returns `false` if the notes is not randomized, `true` otherwise.
function DEPLS.StoryboardFunctions.IsRandomMode()
	return not(not(DEPLS.NoteRandomized))
end

--! Internal function
function DEPLS.StoryboardFunctions._SetColorRange(r)
	DEPLS.DefaultColorMode = r
end

--! @brief Set post-processing shaders
--! @param ... New shaders to be used as post-processing
--! @returns Previous shaders
function DEPLS.StoryboardFunctions.SetPostProcessingShader(...)
	local arg = {...}
	local prev = DEPLS.PostShader

	if #arg == 0 then
		DEPLS.PostShader = nil
	else
		for i = 1, #arg do
			assert(type(arg[i]) == "userdata" and arg[i]:typeOf("Shader"), "bad argument to SetPostProcessingShader (invalid value passed)")
		end

		DEPLS.PostShader = arg
	end

	DEPLS.UpdatePostProcessingCanvas()
	if prev then
		return unpack(prev)
	else
		return nil
	end
end

--! @brief Get the screen dimensions
--! @returns Screen dimensions
function DEPLS.StoryboardFunctions.GetScreenDimensions()
	return AquaShine.MainCanvas:getDimensions()
end

--! @brief Get the current live user interface
--! @return Live user interface string
function DEPLS.StoryboardFunctions.GetLiveUI()
	return DEPLS.LiveUI
end

--! @brief Check if current simulator runs in desktop
--! @return boolean
DEPLS.StoryboardFunctions.IsDesktopSystem = AquaShine.IsDesktopSystem

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
%d FPS LOVE %s
RENDERER = %s %s
DRAWCALLS = %d (BATCHED %d)
TEXTUREMEMORY = %d Bytes
LOADED_IMAGES = %d
LOADED_CANVAS = %d (SWITCHES = %d)
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
]]		, love.timer.getFPS(), love._version, AquaShine.RendererInfo[1], AquaShine.RendererInfo[2], status.drawcalls
		, status.drawcallsbatched, status.texturememory, status.images, status.canvases, status.canvasswitches, status.fonts
		, DEPLS.ElapsedTime, DEPLS.PlaySpeed * 100, DEPLS.Routines.ComboCounter.CurrentCombo, #EffectPlayer.list
		, DEPLS.LiveOpacity, DEPLS.BackgroundOpacity * 255, DEPLS.BeatmapAudioVolume, sample[1], sample[2]
		, DEPLS.NoteManager.NoteRemaining, DEPLS.NoteManager.Perfect, DEPLS.NoteManager.Great, DEPLS.NoteManager.Good
		, DEPLS.NoteManager.Bad, DEPLS.NoteManager.Miss, tostring(DEPLS.AutoPlay))
	love.graphics.setFont(DEPLS.MTLmr3m)
	love.graphics.setColor(0, 0, 0)
	love.graphics.print(text, 1, 1)
	love.graphics.setColor(1, 1, 1)
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
		if not(DEPLS.AudioLowMemory) then
			DEPLS.Sound.LiveAudio:seek(DEPLS.ElapsedTime * 0.001)
		end

		DEPLS.Sound.LiveAudio:play()
	end

	if DEPLS.VideoBackgroundData then
		DEPLS.VideoBackgroundData[1]:seek(DEPLS.ElapsedTime * 0.001)
		DEPLS.VideoBackgroundData[1]:play()
	end
end

--! @brief Check whenever the live has cleared/ended
--! @returns `true` if live has ended, `false` otherwise.
function DEPLS.IsLiveEnded()
	return  not(DEPLS.Routines.PauseScreen.IsPaused()) and
			(not(DEPLS.Sound.LiveAudio) or
			DEPLS.Sound.LiveAudio:isPlaying() == false) and
			DEPLS.NoteManager.NoteRemaining == 0
end

--! @brief Update audio in low memory mode
function DEPLS.UpdateAudioLowMemory()
	if not(DEPLS.Sound.BeatmapAudio) and DEPLS.Sound.LiveAudio then
		local freebufcount = DEPLS.Sound.LiveAudio:getFreeBufferCount()

		for _ = 1, freebufcount do
			local buf = DEPLS.Sound.BeatmapDecoder:decode()
			if not(buf) then return end
			table.remove(DEPLS.Sound.QueueBuffer, 1)
			DEPLS.Sound.QueueBuffer[#DEPLS.Sound.QueueBuffer + 1] = buf
			DEPLS.Sound.LiveAudio:queue(buf)
		end
	end
end

--! @brief Load audio, normal mode
function DEPLS.FinalizeAudio()
	-- Normalize song volume
	-- Enabled on fast system by default
	-- Disabled if "low memory" mode is on to provide consistency.
	if not(DEPLS.Sound.BeatmapDecoder) then return end

	DEPLS.AudioInfo.SampleRate = DEPLS.Sound.BeatmapDecoder:getSampleRate()
	DEPLS.AudioInfo.Depth = DEPLS.Sound.BeatmapDecoder:getBitDepth()
	DEPLS.AudioInfo.Channels = DEPLS.Sound.BeatmapDecoder:getChannelCount()

	if DEPLS.AudioLowMemory and not(DEPLS.RenderingMode) then
		-- Low memory mode "streams" the Decoder!
		-- This path won't be used when rendering.
		DEPLS.Sound.LiveAudio = love.audio.newQueueableSource(
			DEPLS.AudioInfo.SampleRate,
			DEPLS.AudioInfo.Depth,
			DEPLS.AudioInfo.Channels,
			16
		)
		DEPLS.Sound.QueueBuffer = {}
		DEPLS.Sound.QueueCount = DEPLS.Sound.LiveAudio:getFreeBufferCount()

		for _ = 1, DEPLS.Sound.QueueCount do
			local buf = DEPLS.Sound.BeatmapDecoder:decode()
			DEPLS.Sound.QueueBuffer[#DEPLS.Sound.QueueBuffer + 1] = buf
			DEPLS.Sound.LiveAudio:queue(buf)
		end
		return
	end

	DEPLS.Sound.BeatmapAudio = love.sound.newSoundData(DEPLS.Sound.BeatmapDecoder)

	if
		(
			not(AquaShine.IsSlowSystem()) and
			not(AquaShine.GetCommandLineConfig("norg"))
		) or
		AquaShine.GetCommandLineConfig("forcerg")
	then
		require("volume_normalizer")(DEPLS.Sound.BeatmapAudio)
	end

	DEPLS.Sound.LiveAudio = love.audio.newSource(DEPLS.Sound.BeatmapAudio)
end

function DEPLS.UpdateIdolIcon()
	love.graphics.push("all")
	love.graphics.setCanvas(DEPLS.IdolCanvas)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.origin()
	love.graphics.clear()

	-- Draw idol unit
	local IdolData = DEPLS.IdolImageData
	local IdolPos = DEPLS.IdolPosition

	for i = 1, 9 do
		love.graphics.setColor(1, 1, 1, IdolData[i][2])
		love.graphics.draw(IdolData[i][1], IdolPos[i][1], IdolPos[i][2])
	end
	love.graphics.pop()
end

--! @brief DEPLS Initialization function
--! @param argv The arguments passed to the game via command-line
function DEPLS.Start(argv)
	DEPLS.Arg = argv
	AquaShine.DisableSleep()
	AquaShine.DisableTouchEffect()
	EffectPlayer.Clear()
	DEPLS.LiveUI = AquaShine.LoadConfig("PLAY_UI", "sif")

	-- Create canvas
	DEPLS.Resize()

	-- Load tap sound. High priority
	local tapIdx = TapSound[AquaShine.LoadConfig("TAP_SOUND", TapSound.Default)]
	local se_volume = AquaShine.LoadConfig("SE_VOLUME", 80) * 0.01 * tapIdx.VolumeMultipler
	DEPLS.Sound.PerfectTap = AquaShine.GetCachedData(tapIdx.Perfect, love.audio.newSource, tapIdx.Perfect, "static")
	DEPLS.Sound.PerfectTap:setVolume(se_volume * (DEPLS.RenderingMode and 0.5 or 1))
	DEPLS.Sound.GreatTap = AquaShine.GetCachedData(tapIdx.Great, love.audio.newSource, tapIdx.Great, "static")
	DEPLS.Sound.GreatTap:setVolume(se_volume)
	DEPLS.Sound.GoodTap = AquaShine.GetCachedData(tapIdx.Good, love.audio.newSource, tapIdx.Good, "static")
	DEPLS.Sound.GoodTap:setVolume(se_volume)
	DEPLS.Sound.BadTap = AquaShine.GetCachedData(tapIdx.Bad, love.audio.newSource, tapIdx.Bad, "static")
	DEPLS.Sound.BadTap:setVolume(se_volume)
	DEPLS.Sound.StarExplode = AquaShine.GetCachedData(tapIdx.StarExplode, love.audio.newSource, tapIdx.StarExplode, "static")
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
	DEPLS.AudioLowMemory = AquaShine.LoadConfig("AUDIO_LOWMEM", 0) == 1
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

	-- Load beatmap
	local noteloader_data = argv.Beatmap
	local notes_list = noteloader_data:GetNotesList()
	local custom_background = false
	DEPLS.Sound.BeatmapDecoder = noteloader_data:GetBeatmapAudio()
	DEPLS.Sound.LiveClear = noteloader_data:GetLiveClearSound()
	DEPLS.FinalizeAudio()

	if noteloader_data:GetScorePerTap() > 0 then
		DEPLS.ScoreBase = noteloader_data:GetScorePerTap()
	end

	if noteloader_data:GetStamina() > 0 then
		DEPLS.Stamina = noteloader_data:GetStamina()
	end

	-- Load modules
	DEPLS.NoteManager = assert(love.filesystem.load("note.lua"))(DEPLS, AquaShine)

	-- Live Show! Cleared voice
	if DEPLS.Sound.LiveClear then DEPLS.Sound.LiveClear = love.audio.newSource(DEPLS.Sound.LiveClear) end

	-- Normalize song volume
	-- Enabled on fast system by default
	if DEPLS.Sound.BeatmapAudio and (not(AquaShine.IsSlowSystem()) and not(AquaShine.GetCommandLineConfig("norg"))) or AquaShine.GetCommandLineConfig("forcerg") then
		require("volume_normalizer")(DEPLS.Sound.BeatmapAudio)
	end

	-- Randomize note
	if argv.Random or AquaShine.GetCommandLineConfig("random") then
		local new_notes_list, msg = (require("randomizer3"))(notes_list)

		if not(new_notes_list) then
			AquaShine.Log("livesim2", "Can't be randomized: %s", msg)
		else
			DEPLS.NoteRandomized = true
			notes_list = new_notes_list
		end
	end

	-- Load background
	if  AquaShine.LoadConfig("AUTO_BACKGROUND", 1) == 1 then
		local noteloader_background = noteloader_data:GetBackgroundID(DEPLS.NoteRandomized)

		if noteloader_background > 0 then
			BackgroundID = noteloader_background
		elseif noteloader_background == -1 then
			local cbackground = noteloader_data:GetCustomBackground()
			DEPLS.StockBackgroundImage = BackgroundLoader.Compose(
				cbackground[0],
				cbackground[1],
				cbackground[2],
				cbackground[3],
				cbackground[4]
			)
			custom_background = true
		end
	end

	-- Load background if no custom background present
	if not(custom_background) then
		DEPLS.StockBackgroundImage = assert(BackgroundLoader.Load(BackgroundID))
	end

	-- Load unit icons
	local noteloader_units = noteloader_data:GetCustomUnitInformation()
	local IdolImagePath = {}
	DEPLS.IdolImageSpriteBatch = love.graphics.newSpriteBatch(DEPLS.IdolCanvas, 9, "dynamic")
	do
		local idol_img = AquaShine.LoadConfig("IDOL_IMAGE", "dummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy")

		for w in idol_img:gmatch("[^\t]+") do
			IdolImagePath[#IdolImagePath + 1] = w
		end
	end
	for i = 1, 9 do
		DEPLS.IdolImageData[i][1] = noteloader_units[i] or DEPLS.LoadUnitIcon(IdolImagePath[10 - i])
		DEPLS.IdolImageData[i][3] = DEPLS.IdolImageSpriteBatch:add(
			DEPLS.IdolQuads[i],
			DEPLS.IdolPosition[i][1], DEPLS.IdolPosition[i][2]
		)
	end
	DEPLS.UpdateIdolIcon()
	DEPLS.IdolImageSpriteBatch:flush()

	-- Load storyboard
	if not(AquaShine.GetCommandLineConfig("nostory")) and not(argv.NoStoryboard) then
		local s, msg = pcall(noteloader_data.GetStoryboard, noteloader_data)

		if s then
			DEPLS.StoryboardHandle = msg
		else
			DEPLS.StoryboardErrorMsg = msg
			AquaShine.Log("livesim2", msg)
		end
	end

	-- Load cover art
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
		local s, msg = pcall(DEPLS.StoryboardHandle.Initialize, DEPLS.StoryboardHandle, DEPLS.StoryboardFunctions)

		if not(s) then
			DEPLS.StoryboardHandle = nil
			DEPLS.StoryboardErrorMsg = msg
			AquaShine.Log("livesim2", "Storyboard error: %s", msg)
		end
	end

	if not(DEPLS.StoryboardHandle) and not(argv.NoVideo) then
		local video = noteloader_data:GetVideoBackground()

		if video then
			-- We have video. Letterbox the video accordingly
			local w, h = video:getDimensions()
			video:seek(0)
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
	DEPLS.LiveShowCleared = DEPLS.LiveShowClearedReal:clone()
	DEPLS.LiveShowCleared:setMovie("ef_311")
	DEPLS.FullComboAnim = DEPLS.FullComboAnimReal:clone()
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
		local s_score = 0

		for i = 1, #notes_list do
			s_score = s_score + (notes_list[i].effect > 10 and 370 or 739)
		end

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

	-- Load base routines, handles whenever it uses SIF or Lovewing UI
	DEPLS.LoadRoutines()

	-- Load Font
	DEPLS.MTLmr3m = AquaShine.LoadFont("MTLmr3m.ttf", 24)
	DEPLS.ErrorFont = AquaShine.LoadFont("MTLmr3m.ttf", 14)

	-- Set NoteLoader object
	DEPLS.NoteLoaderObject = noteloader_data

	-- Clean
	return collectgarbage()
end

-- Used internally
local persistent_bg_opacity = 0
local audioplaying = false

--! @brief DEPLS Update function. It is separated to allow offline rendering
--! @param deltaT Delta-time in milliseconds
function DEPLS.Update(deltaT)
	deltaT = deltaT * DEPLS.PlaySpeed

	if AquaShine.FFmpegExt then
		AquaShine.FFmpegExt.Update(deltaT)
	end

	if not(DEPLS.Routines.PauseScreen.IsPaused()) then
		DEPLS.ElapsedTime = DEPLS.ElapsedTime + deltaT
	end

	local ElapsedTime = DEPLS.ElapsedTime
	local Routines = DEPLS.Routines

	if DEPLS.CoverShown > 0 then
		DEPLS.Routines.CoverPreview.Update(deltaT)
		DEPLS.CoverShown = DEPLS.CoverShown - deltaT
	end

	persistent_bg_opacity = math.min(ElapsedTime + DEPLS.LiveDelay, DEPLS.LiveDelay) / DEPLS.LiveDelay * 0.7451

	if ElapsedTime > 0 then
		if DEPLS.Sound.LiveAudio and audioplaying == false then
			DEPLS.Sound.LiveAudio:setVolume(DEPLS.BeatmapAudioVolume)
			DEPLS.Sound.LiveAudio:play()
			DEPLS.Sound.LiveAudio:seek(ElapsedTime * 0.001)
			audioplaying = true
		end

		if DEPLS.VideoBackgroundData and not(DEPLS.VideoBackgroundData[5]) then
			DEPLS.VideoBackgroundData[5] = true
			DEPLS.VideoBackgroundData[1]:play()
		end

		if deltaT > 100 then
			-- We can get out of sync when the dT is very high
			if DEPLS.Sound.LiveAudio and audioplaying and not(DEPLS.AudioLowMemory) then
				DEPLS.Sound.LiveAudio:seek(ElapsedTime * 0.001)
				DEPLS.Sound.LiveAudio:play()
			end

			if DEPLS.VideoBackgroundData and DEPLS.VideoBackgroundData[5] then
				DEPLS.VideoBackgroundData[1]:seek(ElapsedTime * 0.001)
				DEPLS.VideoBackgroundData[1]:play()
			end
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
		DEPLS.Routines.Update(deltaT)

		-- Update effect player
		EffectPlayer.Update(deltaT)

		if DEPLS.IsLiveEnded() then
			Routines.LiveClearAnim.Update(deltaT)
		end

		Routines.PauseScreen.Update(deltaT)
	end
end

-- Used to setting up framebuffer
function DEPLS.BeforeDrawSetup()
	local fbo = love.graphics.getCanvas()
	if fbo or (DEPLS.PostShader and #DEPLS.PostShader > 0) then
		DEPLS.PreviousFBO = fbo
		love.graphics.setCanvas(DEPLS.MainCanvas)
	end
end

--! @brief DEPLS Draw function.
--! @param deltaT Delta-time in milliseconds
function DEPLS.Draw(deltaT)
	deltaT = deltaT * DEPLS.PlaySpeed

	local Routines = DEPLS.Routines
	local AllowedDraw = DEPLS.ElapsedTime > 0

	love.graphics.push("all")
	DEPLS.BeforeDrawSetup()
	love.graphics.clear()

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
		if DEPLS.StockBackgroundImage then
			love.graphics.draw(DEPLS.StockBackgroundImage)
		end
	end

	-- Draw background blackness
	if DEPLS.CoverShown > 0 then
		DEPLS.Routines.CoverPreview.Draw()
	else
		love.graphics.setColor(0, 0, 0, DEPLS.BackgroundOpacity * persistent_bg_opacity)
		love.graphics.rectangle("fill", -88, -43, 1136, 726)
		love.graphics.setColor(1, 1, 1)
	end

	if DEPLS.ElapsedTime < 0 and #DEPLS.StoryboardErrorMsg > 0 then
		local y = 638 - (select(2, DEPLS.StoryboardErrorMsg:gsub("\n", "")) + 1) * 14
		love.graphics.setFont(DEPLS.ErrorFont)
		love.graphics.setColor(0, 0, 0)
		love.graphics.print(DEPLS.StoryboardErrorMsg, 1, y + 1)
		love.graphics.setColor(1, 1, 1)
		love.graphics.print(DEPLS.StoryboardErrorMsg, 0, y)
	end

	if AllowedDraw then
		-- Draw combo cheer
		if not(DEPLS.StoryboardHandle) or DEPLS.ComboCheerForced then
			Routines.ComboCheer.Draw()
		end

		-- Draw cut-in
		Routines.SkillPopups.Draw()

		-- Draw header
		DEPLS.Routines.LiveHeader.Draw()

		-- Draw idol unit
		love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity)
		love.graphics.draw(DEPLS.IdolImageSpriteBatch)

		-- Draw timing icon
		DEPLS.NoteManager.TimingIconDraw()

		-- Update note
		DEPLS.NoteManager.Draw()

		-- Draw routines
		DEPLS.Routines.Draw()

		-- Update effect player
		EffectPlayer.Draw()

		-- Live clear animation
		if DEPLS.IsLiveEnded() then
			Routines.LiveClearAnim.Draw()
		else
			Routines.LiveHeader.DrawPause()
		end
	end

	-- Post-processing draw first so the pause overlay
	-- and the debug display doesn't affected.
	DEPLS.PostProcessingDraw()
	love.graphics.pop()

	-- Pause overlay
	Routines.PauseScreen.Draw()

	if DEPLS.DebugDisplay then
		DEPLS.DrawDebugInfo()
	end

	return DEPLS.UpdateAudioLowMemory()
end

-- Post-processing draw. Shaders can be chained here
-- 13/04/2018: I don't know how slow will be this one
-- in A cruel Angel Thesis beatmap. Those canvas switching
-- hell must be done every frame.
function DEPLS.PostProcessingDraw()
	if DEPLS.PostShader and #DEPLS.PostShader > 0 then
		love.graphics.push("all")
		love.graphics.setBlendMode("alpha", "premultiplied")
		love.graphics.origin()

		for i = 1, #DEPLS.PostShader do
			love.graphics.setCanvas(DEPLS.SecondaryCanvas)
			love.graphics.clear()
			love.graphics.setShader(DEPLS.PostShader[i])
			love.graphics.draw(DEPLS.MainCanvas)
			DEPLS.MainCanvas, DEPLS.SecondaryCanvas = DEPLS.SecondaryCanvas, DEPLS.MainCanvas
		end
		love.graphics.setCanvas(DEPLS.PreviousFBO)
		love.graphics.clear()
		love.graphics.draw(DEPLS.MainCanvas)
		love.graphics.pop()
	elseif DEPLS.PreviousFBO then
		love.graphics.push("all")
		love.graphics.setBlendMode("alpha", "premultiplied")
		love.graphics.origin()
		love.graphics.setCanvas(DEPLS.PreviousFBO)
		love.graphics.draw(DEPLS.MainCanvas)
		love.graphics.pop()
	end

	DEPLS.PreviousFBO = nil
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

	if x < 0 and y >= 480 then
		DEPLS.DebugDisplay = not(DEPLS.DebugDisplay)
		return
	end

	-- Send unset touch message
	TouchTracking[touch_id] = nil
	DEPLS.NoteManager.SetTouch(nil, touch_id, true)

	if DEPLS.Routines.ResultScreen.CanExit then
		-- Back
		AquaShine.LoadEntryPoint(":beatmap_select", {Random = DEPLS.Arg.Random})
	end

	if not(DEPLS.IsLiveEnded()) and DEPLS.Routines.CheckPausePos(x, y) then
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
	elseif key == "pause" and DEPLS.ElapsedTime > 0 and not(DEPLS.IsLiveEnded()) then
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
		AquaShine.LoadEntryPoint(":beatmap_select", {Random = DEPLS.Arg.Random})
	elseif key == "backspace" then
		-- Restart
		AquaShine.LoadEntryPoint("livesim.lua", DEPLS.Arg)
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

function DEPLS.UpdatePostProcessingCanvas()
	if DEPLS.PostShader then
		DEPLS.SecondaryCanvas = love.graphics.newCanvas()
	else
		DEPLS.SecondaryCanvas = nil
	end
end

function DEPLS.Resize()
	DEPLS.IdolCanvas = love.graphics.newCanvas(960, 640) DEPLS.IdolCanvasDirty = true
	DEPLS.MainCanvas = love.graphics.newCanvas()
	DEPLS.UpdatePostProcessingCanvas()
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

	if DEPLS.VideoBackgroundData then
		DEPLS.VideoBackgroundData[1]:pause()
		DEPLS.VideoBackgroundData = nil
		love.handlers.lowmemory()
	end
end

function DEPLS.Focus(focus)
	if
		not(DEPLS.AudioLowMemory) and
		not(AquaShine.IsDesktopSystem()) and
		not(DEPLS.Routines.PauseScreen.IsPaused()) and
		focus and
		DEPLS.Sound.LiveAudio and
		DEPLS.ElapsedTime >= 0
	then
		DEPLS.Sound.LiveAudio:seek(DEPLS.ElapsedTime * 0.001)
	end
end

DEPLS.Distance = distance
DEPLS.AngleFrom = angle_from

return DEPLS, "Playing"
