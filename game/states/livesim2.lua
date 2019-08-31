-- Main game
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local timer = require("libs.hump.timer")

local color = require("color")
local async = require("async")
local assetCache = require("asset_cache")
local log = require("logging")
local mainFont = require("font")
local setting = require("setting")
local util = require("util")
local audioManager = require("audio_manager")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local render = require("render")
local vires = require("vires")

local glow = require("game.afterglow")
local tapSound = require("game.tap_sound")
local beatmapList = require("game.beatmap.list")
local backgroundLoader = require("game.background_loader")
local srtParse = require("game.srt")
local storyLoader = require("game.storyboard.loader")
local note = require("game.live.note")
local lyrics = require("game.live.lyrics")
local pause = require("game.live.pause")
local liveUI = require("game.live.ui")
local skill = require("game.live.skill")
local replay = require("game.live.replay")
local BGM = require("game.bgm")
local beatmapRandomizer = require("game.live.randomizer3")

local DEPLS = gamestate.create {
	fonts = {},
	images = {
		note = {"noteImage:assets/image/tap_circle/notes.png", {mipmaps = true}},
		longNoteTrail = {"assets/image/ef_326_000.png"},
		dummyUnit = {"assets/image/dummy.png", {mipmaps = true}},
		random = {"assets/image/live/l_win_32.png", {mipmaps = true}}
	}
}

local validJudgement = {"perfect", "great", "good", "bad", "miss"}

local scoreMultipler = {
	perfect = 1,
	great = 0.88,
	good = 0.8,
	bad = 0.4,
	miss = 0
}

local accuracyGraphValue = {
	perfect = 1,
	great = 0.75,
	good = 0.5,
	bad = 0.25,
	miss = 0
}

local staminaJudgmentDamage = {
	perfect = 0,
	great = 0,
	good = 0.5,
	bad = 1,
	miss = 2
}

local function getBackgroundImageDebug(t, _)
	--local p = table.remove(t, 2)
	--p:encode("png", "background_dump-".._..".png")
	--return p
	return table.remove(t, 2)
end

local function pickLowestJudgement(j1, j2)
	if j1 and j2 then
		return validJudgement[math.max(
			assert(util.isValueInArray(validJudgement, j1)),
			assert(util.isValueInArray(validJudgement, j2))
		)]
	else
		return j1 or j2
	end
end

local function pauseGame(self, fail)
	if self.data.liveUI:isPauseEnabled() and not(self.data.pauseObject:isPaused()) then
		if self.data.song then
			self.data.song:pause()
		end
		if self.data.video then
			self.data.video.drawable:pause()
		end
		self.data.pauseObject:pause(self.persist.beatmapDisplayName, fail)
	end
end

local function playTapSFXSound(tapSFX, name, nsAccumulation)
	local list = tapSFX[tapSFX[name]]
	if list.alreadyPlayed == false then
		-- first element should be the least played
		local audio
		if audioManager.isPlaying(list[1]) then
			-- ok no more space
			audio = audioManager.clone(tapSFX[name])
		else
			audio = table.remove(list, 1)
		end

		audioManager.play(audio)
		list[#list + 1] = audio

		if nsAccumulation then
			list.alreadyPlayed = true
		end
	end
end

local function isLiveClear(self)
	return
		self.data.noteManager:getRemainingNotes() == 0 and
		not(self.data.pauseObject:isPaused()) and
		(self.data.song and not(self.data.song:isPlaying()) or not(self.data.song))
end

local function liveClearCallback(self)
	if self.persist.render then
		love.event.quit()
	end

	local noteInfo = self.persist.noteInfo
	noteInfo.maxCombo = self.data.liveUI:getMaxCombo()
	noteInfo.score = self.data.liveUI:getScore()

	local replayData = self.persist.replayMode or {
		-- General
		score = noteInfo.score,
		maxCombo = noteInfo.maxCombo,
		totalNotes = noteInfo.totalNotes,
		perfect = noteInfo.perfect,
		great = noteInfo.great,
		good = noteInfo.good,
		bad = noteInfo.bad,
		miss = noteInfo.miss,
		token = noteInfo.token,
		tokenAmount = noteInfo.tokenAmount,
		perfectNote = noteInfo.perfectNote,
		perfectSwing = noteInfo.perfectSwing,
		perfectSimultaneous = noteInfo.perfectSimultaneous,
		scorePerTap = self.persist.tapScore,
		stamina = self.persist.stamina,
		vanish = self.persist.vanishType,
		randomSeed = self.persist.randomGeneratedSeed,
		timestamp = self.persist.startTimestamp,

		-- flags
		beatmapRandomized = self.persist.beatmapRandomized,
		storyboardLoaded = not(not(self.data.storyboard)),
		customUnitLoaded = self.persist.customUnitLoaded,

		accuracy = self.persist.accuracyData,
		events = replay.getEventData(),
	}

	gamestate.replace(nil, "result", {
		name = self.persist.beatmapName,
		summary = self.persist.summary,
		replay = replayData,
		livesim2 = self.persist.arg,
		allowRetry = not(self.persist.arg.allowRetry),
		allowSave = not(self.persist.directLoad),
		autoplay = self.persist.autoplay,
		comboRange = self.persist.comboRange,
		background = self.data.background
	})
end

local function safeAreaScaling(self)
	-- iOS and Android always runs game in fullscreen
	-- regardless of t.window.width and t.window.height
	-- specified
	local scale = vires.getScaling()
	local vYOffset = scale * select(2, vires.getOffset())
	local gameHeight = 640 * scale + vYOffset
	local safeHeight

	if (love._os == "iOS" or love._os == "Android") and love.window.getSafeArea then
		safeHeight = select(4, love.window.getSafeArea())
	else
		safeHeight = gameHeight
	end

	local affectedSafe = math.min(safeHeight, gameHeight) - vYOffset
	self.safeScale = math.min(affectedSafe / (gameHeight - vYOffset), 1)
end

local function rescalePosition(self, x, y)
	-- the center is 480,0
	return (x - 480) / self.safeScale + 480, y / self.safeScale
end

local function safeAreaReposition(scale)
	if scale then
		love.graphics.push()
		love.graphics.translate(480 * (1 - scale), 0)
		love.graphics.scale(scale)
	else
		love.graphics.pop()
	end
end

function DEPLS:load(arg)
	glow.clear()

	-- sanity check
	assert(arg.summary, "summary data missing")
	assert(arg.beatmapName, "beatmap name id missing")
	self.persist.summary = arg.summary
	self.persist.beatmapName = arg.beatmapName
	self.persist.beatmapDisplayName = assert(arg.summary.name)
	self.persist.arg = arg
	self.persist.directLoad = arg.direct

	self.data.infoArtFont, self.data.titleArtFont = mainFont.get(16, 40)

	-- safe area
	safeAreaScaling(self)

	-- autoplay
	local autoplay
	if arg.replay then
		autoplay = false
	elseif arg.autoplay == nil then
		autoplay = setting.get("AUTOPLAY") == 1
	else
		autoplay = not(not(arg.autoplay))
	end
	self.persist.autoplay = autoplay

	-- replay
	self.persist.replayMode = false
	self.persist.replayKeyOverlay = {false, false, false, false, false, false, false, false, false}
	replay.clear()
	if arg.replay then
		self.persist.replayMode = arg.replay
		replay.setEventData(arg.replay.events)
	end

	-- note vanish type
	local vanishType
	if arg.replay then
		vanishType = self.persist.replayMode.vanish
	else
		vanishType = assert(tonumber(setting.get("VANISH_TYPE")), "invalid vanish setting")
	end
	self.persist.vanishType = vanishType

	-- dim delay
	self.persist.liveDelay = math.max(setting.get("LIVESIM_DELAY") * 0.001, 1)
	self.persist.liveDelayCounter = self.persist.liveDelay
	self.persist.dimValue = util.clamp(setting.get("LIVESIM_DIM") * 0.01, 0, 1)

	-- score and stamina
	self.persist.tapScore = arg.replay and self.persist.replayMode.scorePerTap or arg.summary.scorePerTap or 0
	if self.persist.tapScore == 0 then
		self.persist.tapScore = setting.get("SCORE_ADD_NOTE")
	end
	assert(self.persist.tapScore > 0, "invalid score/tap, check setting!")
	self.persist.stamina = arg.replay and self.persist.replayMode.stamina or arg.summary.stamina or 0
	if self.persist.stamina == 0 then
		self.persist.stamina = setting.get("STAMINA_DISPLAY")
	end
	self.persist.noFail = setting.get("STAMINA_FUNCTIONAL") == 0

	-- load live UI
	local currentLiveUI = setting.get("PLAY_UI")
	self.data.liveUI = liveUI.newLiveUI(currentLiveUI, autoplay, setting.get("MINIMAL_EFFECT") == 1)
	self.data.liveUI:setMaxStamina(self.persist.stamina)
	self.data.liveUI:setTextScaling(setting.get("TEXT_SCALING"))
	if arg.summary.liveClear then
		self.data.liveUI:setLiveClearVoice(audioManager.newAudioDirect(arg.summary.liveClear, "voice"))
	end

	-- Lane definition
	self.persist.lane = self.data.liveUI:getLanePosition()

	-- Counter
	self.persist.noteInfo = {
		totalNotes = 0,
		perfect = 0,
		great = 0,
		good = 0,
		bad = 0,
		miss = 0,
		token = 0,
		perfectNote = 0,
		perfectSwing = 0,
		perfectSimultaneous = 0,
		maxCombo = 0,
		tokenAmount = 0,
		score = 0,
		fullCombo = true -- by default
	}
	self.persist.accuracyData = {}
	self.persist.comboRange = {0, 0, 0, 0}

	-- Create new note manager
	self.data.noteManager = note.newNoteManager({
		image = self.assets.images.note,
		trailImage = self.assets.images.longNoteTrail,
		noteSpawningPosition = self.data.liveUI:getNoteSpawnPosition(),
		lane = self.persist.lane,
		accuracy = {16, 40, 64, 112, 128},
		autoplay = autoplay,
		timingOffset = -setting.get("TIMING_OFFSET"), -- inverted for some reason
		beatmapOffset = setting.get("GLOBAL_OFFSET") * 0.001,
		vanish = vanishType,
		spawn = function()
			return self.data.skill:noteSpawnCallback()
		end,
		callback = function(object, lane, position, judgement, releaseFlag)
			log.debugf(
				"livesim2", "note cb (%s), lane: %d, position: %s, relmode: %d",
				judgement, lane, tostring(position), releaseFlag
			)
			local release = releaseFlag == 2

			-- judgement
			self.data.liveUI:comboJudgement(judgement, releaseFlag ~= 1)
			if releaseFlag ~= 1 then
				local lowestJudgement = pickLowestJudgement(judgement, object.previousJudgement)

				-- Send skill
				self.data.skill:noteCallback(lowestJudgement, object.token, object.star)

				if judgement ~= "miss" then
					local scoreMulType = (release and 1.25 or 1) * (object.swing and 0.5 or 1)
					local scoreMul = scoreMulType * (object.scoreMultipler or 1) * self.data.liveUI:getScoreComboMultipler()
					local score = math.ceil(scoreMul * scoreMultipler[judgement] * self.persist.tapScore)
					self.data.liveUI:addScore(score)
					self.data.liveUI:addTapEffect(position.x, position.y, 255, 255, 255, 1)
					self.data.skill:scoreCallback(score)
				end

				-- counter
				self.persist.accuracyData[#self.persist.accuracyData + 1] = accuracyGraphValue[judgement]
				self.persist.noteInfo[judgement] = self.persist.noteInfo[judgement] + 1

				if judgement ~= "miss" and object.token then
					self.persist.noteInfo.token = self.persist.noteInfo.token + 1
				end

				if lowestJudgement == "perfect" then
					if release then
						self.persist.noteInfo.perfectSimultaneous = self.persist.noteInfo.perfectSimultaneous + 1
					elseif object.swing then
						self.persist.noteInfo.perfectSwing = self.persist.noteInfo.perfectSwing + 1
					else
						self.persist.noteInfo.perfectNote = self.persist.noteInfo.perfectNote + 1
					end
				end
			elseif judgement ~= "miss" then
				object.scoreMultipler = scoreMultipler[judgement]
				object.previousJudgement = judgement
			else
				-- in this case, the note is not pressed and it miss
				self.data.skill:noteCallback("miss", object.token, object.star)
			end

			-- play SFX
			if judgement ~= "miss" then
				playTapSFXSound(self.data.tapSFX, judgement, self.data.tapNoteAccumulation)
			end
			if judgement ~= "perfect" and judgement ~= "great" then
				if object.star then
					playTapSFXSound(self.data.tapSFX, "starExplode", self.data.tapNoteAccumulation)
				end
				self.persist.noteInfo.fullCombo = false
			end

			-- storyboard
			if self.data.storyboard then
				local info = {
					long = releaseFlag > 0,
					release = releaseFlag == 2,
					isStar = object.star,
					isSimultaneous = object.simul,
					isToken = object.token,
					isSwing = object.swing
				}
				self.data.storyboard:callback(
					"note",
					object.lanePosition,
					judgement,
					object:getDistance(release),
					info
				)
			end

			-- damage
			if not(self.persist.noFail or self.persist.replayMode) then
				self.data.liveUI:addStamina(-math.floor(staminaJudgmentDamage[judgement] * (object.star and 2 or 1)))
				if self.data.liveUI:getStamina() == 0 then
					-- fail
					pauseGame(self, true)
				end
			end
		end,
	})

	-- storyboard
	local storyboardData
	local loadStoryboard = true
	if self.persist.replayMode then
		loadStoryboard = self.persist.replayMode.storyboardLoaded
	elseif arg.storyboard ~= nil then
		loadStoryboard = arg.storyboard
	end

	-- Randomizer
	self.persist.beatmapRandomized = false
	-- too long for ternary operator
	if self.persist.replayMode then
		self.persist.beatmapRandomized = self.persist.replayMode.beatmapRandomized
	elseif arg.random then
		self.persist.beatmapRandomized = true
	end
	if self.persist.replayMode then
		self.persist.randomGeneratedSeed = self.persist.replayMode.randomSeed
	elseif arg.seed then
		self.persist.randomGeneratedSeed = arg.seed
	else
		self.persist.randomGeneratedSeed = {math.random(0, 4294967295), math.random(0, 4294967295)}
	end

	-- background
	local loadBackground = setting.get("AUTO_BACKGROUND") == 1
	-- custom unit
	local loadCustomUnit
	if self.persist.replayMode then
		loadCustomUnit = self.persist.replayMode.customUnitLoaded
	else
		loadCustomUnit = setting.get("CBF_UNIT_LOAD") == 1
	end
	self.persist.customUnitLoaded = loadCustomUnit
	-- video
	local loadVideo = arg.videoBG
	if loadVideo == nil then
		loadVideo = setting.get("VIDEOBG") == 1
	end

	-- Beatmap loading variables
	local isBeatmapInit = 0
	local desiredBeatmapInit = 1
	if loadCustomUnit then
		desiredBeatmapInit = desiredBeatmapInit + 1
	end
	if loadBackground then
		desiredBeatmapInit = desiredBeatmapInit + 1
	end
	if loadStoryboard then
		desiredBeatmapInit = desiredBeatmapInit + 1
	end
	-- Load notes data
	beatmapList.getNotes(arg.beatmapName, function(notes)
		local fullScore = 0

		if self.persist.beatmapRandomized then
			local newnotes = beatmapRandomizer(notes, self.persist.randomGeneratedSeed[1], self.persist.randomGeneratedSeed[2])
			if newnotes then
				self.persist.noteRandomized = true
				notes = newnotes
			else
				log.warnf("livesim2", "cannot randomize beatmap, using original beatmap")
			end
		end

		for i = 1, #notes do
			local t = notes[i]

			if self.data.noteManager:addNote(t) then
				self.persist.noteInfo.tokenAmount = self.persist.noteInfo.tokenAmount + 1
			end

			fullScore = fullScore + (t.effect > 10 and 370 or 739)
		end

		self.persist.noteInfo.totalNotes = #notes
		self.data.liveUI:setTotalNotes(#notes)
		self.data.noteManager:initialize()

		-- Set score range (c,b,a,s order)
		log.debugf("livesim2", "calculated s score is %d", fullScore)
		self.data.liveUI:setScoreRange(
			math.floor(fullScore * 211/739 + 0.5),
			math.floor(fullScore * 528/739 + 0.5),
			math.floor(fullScore * 633/739 + 0.5),
			fullScore
		)
		if not(self.persist.comboRange) then
			local len = #notes
			self.persist.comboRange[1] = math.ceil(len * 0.3)
			self.persist.comboRange[2] = math.ceil(len * 0.5)
			self.persist.comboRange[3] = math.ceil(len * 0.7)
			self.persist.comboRange[4] = len
		end
		isBeatmapInit = isBeatmapInit + 1
	end)
	if loadBackground then
		-- need to wrap in coroutine because
		-- there's no async access in the callback
		beatmapList.getBackground(arg.beatmapName, loadVideo, coroutine.wrap(function(value)
			log.debug("livesim2", "received background data")

			local tval = type(value)
			if tval == "table" then
				local bitval
				local m, l, r, t, b
				-- main background
				bitval = math.floor(value[1])
				if bitval % 2 > 0 then
					m = love.graphics.newImage(getBackgroundImageDebug(value, 0))
					bitval = math.floor(value[1] / 2)
					-- left & right
					if bitval % 2 > 0 then
						l = love.graphics.newImage(getBackgroundImageDebug(value, 1))
						r = love.graphics.newImage(getBackgroundImageDebug(value, 2))
					end
					bitval = math.floor(value[1] / 4)
					-- top & bottom
					if bitval % 2 > 0 then
						t = love.graphics.newImage(getBackgroundImageDebug(value, 3))
						b = love.graphics.newImage(getBackgroundImageDebug(value, 4))
					end
				else
					-- number
					m = table.remove(value, 2)
					if m > 0 then
						self.data.background = backgroundLoader.load(m)
					end
				end

				bitval = math.floor(value[1] / 8)
				if bitval % 2 > 0 then
					local v = {}
					v.drawable = love.graphics.newVideo(table.remove(value, 2))
					v.w, v.h = v.drawable:getDimensions()
					v.scale = math.max(960 / v.w, 640 / v.h)
					v.play = false
					self.data.video = v
				end

				if not(self.data.background) and type(m) == "userdata" then
					self.data.background = backgroundLoader.compose(m, l, r, t, b)
				end
			elseif tval == "number" and value > 0 then
				self.data.background = backgroundLoader.load(value)
			end
			isBeatmapInit = isBeatmapInit + 1
		end))
	end
	if loadCustomUnit then
		-- Load unit data too
		beatmapList.getCustomUnit(arg.beatmapName, function(unitData)
			self.data.customUnit = unitData
			log.debug("livesim2", "received unit data")
			isBeatmapInit = isBeatmapInit + 1
		end)
	end
	if loadStoryboard then
		-- Load storyboard
		beatmapList.getStoryboard(arg.beatmapName, function(story)
			-- Story can be nil
			if story then
				-- Parsed later
				storyboardData = story
			end
			isBeatmapInit = isBeatmapInit + 1
		end)
	end

	-- load tap SFX
	self.data.tapSFX = {accumulateTracking = {}}
	local tapSoundIndex = assert(tapSound[tonumber(setting.get("TAP_SOUND"))], "invalid tap sound")
	for k, v in pairs(tapSoundIndex) do
		if k ~= "name" and type(v) == "string" then
			local audio = audioManager.newAudio(v, "se")
			audioManager.setVolume(audio, tapSoundIndex.volumeMultipler)
			self.data.tapSFX[k] = audio

			local list = {
				alreadyPlayed = false, -- for note sound accumulation
				audioManager.clone(audio)
			} -- cloned things
			self.data.tapSFX[audio] = list
			self.data.tapSFX.accumulateTracking[#self.data.tapSFX.accumulateTracking + 1] = list
		end
	end
	self.data.tapNoteAccumulation = assert(tonumber(setting.get("NS_ACCUMULATION")), "invalid note sound accumulation")

	-- load pause system
	self.data.pauseObject = pause({
		quit = function()
			if self.persist.replayMode then
				-- assume replay data is used to fill information
				liveClearCallback(self)
			else
				gamestate.leave(loadingInstance.getInstance())
			end
		end,
		resume = function()
			local time = self.data.noteManager:getElapsedTime()

			if self.data.song then
				self.data.song:seek(time)
				self.data.song:play()
			end

			if self.data.video then
				self.data.video.drawable:seek(time)
				log.debugf("livesim2", "seek video to %.3f", time)
				if self.persist.render then
					self.data.video.play = true
				else
					self.data.video.drawable:play()
				end
				log.debug("livesim2", "play video")
			end
		end,
		restart = function()
			gamestate.replace(loadingInstance.getInstance(), "livesim2", arg)
		end
	}, nil, self.persist.replayMode and tostring(self.persist.replayMode.filename))

	-- load keymapping
	do
		local keymap = {}
		local i = 9

		for w in setting.get("IDOL_KEYS"):gmatch("[^\t]+") do
			-- keymap is leftmost, but sif is rightmost
			log.debugf("livesim2", "keymap: %q, lane: %d", w, i)
			keymap[w] = i
			i = i - 1
			if i == 0 then break end
		end

		assert(i == 0, "improper keymap setting")
		self.persist.keymap = keymap
	end

	-- load cover art system
	self.persist.coverArtDisplayDone = true
	if arg.summary.coverArt then
		local w
		local x = arg.summary.coverArt
		local y = {
			image = love.graphics.newImage(x.image, {mipmaps = true}),
			scaleX = 0,
			scaleY = 0,
			title = love.graphics.newText(self.data.titleArtFont),
			info = love.graphics.newText(self.data.infoArtFont),
			script = nil,
			time = 0
		}
		self.persist.coverArtDisplayDone = false
		y.scaleX = 400/y.image:getWidth()
		y.scaleY = 400/y.image:getHeight()

		w = self.data.titleArtFont:getWidth(x.title)
		y.title:add({color.black, x.title}, -w*0.5-2, 507)
		y.title:add({color.black, x.title}, -w*0.5+2, 509)
		y.title:add({color.white, x.title}, -w*0.5, 508)

		if x.info and #x.info > 0 then
			w = self.data.infoArtFont:getWidth(x.info)
			y.info:add({color.black, x.info}, -w*0.5-1, 553)
			y.info:add({color.black, x.info}, -w*0.5+1, 555)
			y.info:add({color.white, x.info}, -w*0.5, 554)
		end

		self.data.coverArtDisplay = y
	end

	-- wait until notes are loaded
	while isBeatmapInit < desiredBeatmapInit do
		async.wait()
	end
	log.debug("livesim2", "beatmap init wait done")

	-- if there's no background, load default
	if not(self.data.background) then
		local num = self.persist.beatmapRandomized and arg.summary.randomStar or arg.summary.star
		self.data.background = backgroundLoader.load(util.clamp(
			(loadBackground and num > 0) and num or assert(tonumber(setting.get("BACKGROUND_IMAGE"))),
			1, 12
		))
	end

	-- Try to load audio
	if arg.summary.audio then
		self.data.song = BGM.newSong(arg.summary.audio)
	end

	-- Set score range when available
	if arg.summary.scoreS then -- only check one
		self.data.liveUI:setScoreRange(
			arg.summary.scoreC,
			arg.summary.scoreB,
			arg.summary.scoreA,
			arg.summary.scoreS
		)
	end

	-- Set combo range when available
	if arg.summary.comboS then
		self.persist.comboRange[1] = arg.summary.comboC
		self.persist.comboRange[2] = arg.summary.comboB
		self.persist.comboRange[3] = arg.summary.comboA
		self.persist.comboRange[4] = arg.summary.comboS
	end

	-- Initialize unit icons
	self.data.unitIcons = {}
	local unitDefaultName = {}
	local unitImageCache = {}
	local idolName = setting.get("IDOL_IMAGE")
	log.debug("livesim2", "default idol name: "..string.gsub(idolName, "\t", "\\t"))
	for w in string.gmatch(idolName, "[^\t]+") do
		unitDefaultName[#unitDefaultName + 1] = w
	end
	assert(#unitDefaultName == 9, "IDOL_IMAGE setting is not valid")
	log.debug("livesim2", "initializing units")
	for i = 1, 9 do
		local image

		if self.data.customUnit and self.data.customUnit[i] then
			image = unitImageCache[self.data.customUnit[i]]
			if not(image) then
				image = love.graphics.newImage(self.data.customUnit[i], {mipmaps = true})
				unitImageCache[self.data.customUnit[i]] = image
			end
		else
			-- Default unit name are in left to right order
			-- but SIF units are in right to left order
			image = unitImageCache[unitDefaultName[10 - i]]
			if not(image) then
				if unitDefaultName[10 - i] == " " then
					image = assert(self.assets.images.dummyUnit)
				else
					local file = "unit_icon/"..unitDefaultName[10 - i]
					if util.fileExists(file) then
						image = assetCache.loadImage("unit_icon/"..unitDefaultName[10 - i])
					else
						image = assert(self.assets.images.dummyUnit)
					end
				end

				unitImageCache[unitDefaultName[10 - i]] = image
			end
		end

		if not(image) then
			error(string.format(
				"image not exist. index: %d, custom: %s, name: %s",
				i,
				self.data.customUnit[i] or "false",
				unitDefaultName[10 - i] or "null"
			))
		end
		self.data.unitIcons[i] = image
	end

	-- Initialize skill system
	self.data.skill = skill(
		setting.get("SKILL_POPUP") == 1,
		self.data.liveUI,
		self.data.noteManager,
		self.persist.randomGeneratedSeed
	)

	-- Initialize storyboard
	if loadStoryboard and storyboardData then
		log.debugf("livesim2", "trying to load storyboard")
		local s, msg = storyLoader.load(
			storyboardData.type,
			storyboardData.storyboard,
			{
				path = storyboardData.path,
				data = storyboardData.data,
				background = self.data.background,
				unit = self.data.unitIcons,
				song = self.data.song,
				seed = self.persist.randomGeneratedSeed,
				ui = currentLiveUI,
				skill = function(kind, ...)
					-- do not register/trigger any skill if custom unit is disabled
					if loadCustomUnit then
						if kind == "trigger" then
							if not(isLiveClear(self)) then
								local type, value, unitIndex, rarity, image, audio = ...
								self.data.skill:triggerDirectly(type, value, unitIndex, rarity, image, audio)
							end
						elseif kind == "register" then
							local skillData, condition = ...
							self.data.skill:register(skillData, condition)
						end
					end
				end,
			}
		)
		if s == nil then
			log.errorf("livesim2", "failed to load storyboard: %s", msg)
		else
			self.data.storyboard = s
		end
	end

	if arg.summary.lyrics then
		log.debug("livesim2", "loading song lyrics data")
		local str = arg.summary.lyrics:getString():gsub("\r\n", "\n")
		self.data.lyrics = lyrics(srtParse(str:gmatch("([^\n]*)\n?")))
	end

	async.wait()
	log.debug("livesim2", "ready")
end

function DEPLS:start(arg)
	if log.getLevel() >= 4 then
		self.persist.debugTimer = timer.every(1, function()
			-- note debug
			log.debug("livesim2", "note remaining "..#self.data.noteManager.notesList)
			-- song debug
			if self.data.song then
				local audiotime = self.data.song:tell() * 1000
				local notetime = self.data.noteManager.elapsedTime * 1000
				log.debugf(
					"livesim2", "audiotime: %.2fms, notetime: %.2fms, diff: %.2fms",
					audiotime, notetime, math.abs(audiotime - notetime)
				)
			end
		end)
	end

	self.persist.startTimestamp = os.time()
	self.persist.render = arg.render
	self.persist.averageNoteDelta = assert(tonumber(setting.get("IMPROVED_SYNC"))) == 1
	self.persist.audioNoteTimer = 0

	-- window dimensions
	if arg.render then
		self.persist.windowWidth, self.persist.windowHeight = render.getDimensions()
	else
		self.persist.windowWidth, self.persist.windowHeight = love.graphics.getDimensions()
	end
end

function DEPLS:exit()
	if self.persist.debugTimer then
		timer.cancel(self.persist.debugTimer)
		self.persist.debugTimer = nil
	end

	if self.data.song then
		self.data.song:pause()
	end

	if self.data.video then
		self.data.video.drawable:pause()
		log.debug("livesim2", "stop video")
	end

	if self.persist.render then
		render.done()
	end
end

function DEPLS:update(dt)
	local paused = self.data.pauseObject:isPaused()

	if self.persist.render then
		dt = render.getStep()
	end

	if self.persist.coverArtDisplayDone then
		local liveClear = isLiveClear(self)

		self.persist.liveDelayCounter = self.persist.liveDelayCounter - dt
		if paused and self.persist.liveDelayCounter ~= -math.huge then
			self.persist.liveDelayCounter = math.max(self.persist.liveDelayCounter, 0)
		end

		for i = 1, #self.data.tapSFX.accumulateTracking do
			self.data.tapSFX.accumulateTracking[i].alreadyPlayed = false
		end

		-- update pause object first
		self.data.pauseObject:update(dt)
		if not(paused) then
			if self.persist.liveDelayCounter <= 0 then
				-- update storyboard
				if self.data.storyboard and not(liveClear) then
					self.data.storyboard:update(dt)
				end

				-- update lyrics
				if self.data.lyrics then
					self.data.lyrics:update(dt)
				end

				-- update skill
				self.data.skill:update(dt, liveClear)

				-- play song if it's not played
				local updtDt = dt
				if self.persist.liveDelayCounter ~= -math.huge then
					updtDt = -self.persist.liveDelayCounter
					self.persist.liveDelayCounter = -math.huge
					if self.data.song then
						self.data.song:seek(updtDt)
						self.data.song:play()
					end

					if self.data.video then
						self.data.video.drawable:seek(updtDt)
						log.debugf("livesim2", "seek video to %.3f", updtDt)
						if self.persist.render then
							self.data.video.play = true
						else
							self.data.video.drawable:play()
						end
						log.debug("livesim2", "play video")
					end
				end

				if not(self.persist.render) and self.persist.averageNoteDelta and self.data.song and self.data.song:isPlaying() then
					local sourceT = self.data.song:tell()
					updtDt = sourceT - self.persist.audioNoteTimer
					self.persist.audioNoteTimer = sourceT
				end

				if self.persist.replayMode then
					-- replay update rate is 5ms
					local timeUpdt = updtDt
					while timeUpdt > 0 do
						replay.update(math.min(timeUpdt, 0.005))
						timeUpdt = timeUpdt - 0.005
						for ev in replay.pull() do
							if ev.type == "keyboard" then
								if ev.mode == "pressed" then
									self.persist.replayKeyOverlay[ev.key] = true
									self.data.noteManager:setTouch(ev.key, "l"..ev.key)
								elseif ev.mode == "released" then
									self.persist.replayKeyOverlay[ev.key] = false
									self.data.noteManager:setTouch(ev.key, "l"..ev.key, true)
								end
							elseif ev.type == "touch" then
								if ev.mode == "pressed" then
									self.data.noteManager:touchPressed(ev.id, ev.x, ev.y)
								elseif ev.mode == "moved" then
									self.data.noteManager:touchMoved(ev.id, ev.x, ev.y)
								elseif ev.mode == "released" then
									self.data.noteManager:touchReleased(ev.id, ev.x, ev.y)
								end
							end
						end
					end
				else
					replay.update(updtDt)
				end

				while updtDt > 0 do
					self.data.noteManager:update(math.min(updtDt, 0.02))
					updtDt = updtDt - 0.02
				end

				if self.persist.render and self.data.video and self.data.video.play then
					self.data.video.drawable:seek(self.data.noteManager:getElapsedTime())
				end
			end
		end

		self.data.liveUI:update(dt, paused)

		if liveClear then
			if self.data.video and self.data.video.play then
				self.data.video.play = false
			end
			self.data.liveUI:startLiveClearAnimation(self.persist.noteInfo.fullCombo, liveClearCallback, self)
		end
	else
		self.data.coverArtDisplay.time = self.data.coverArtDisplay.time + dt
		if self.data.coverArtDisplay.time >= 3 then
			self.persist.coverArtDisplayDone = true
		end
	end
end

local function draw(self)
	-- draw background
	local drawBackground = true

	love.graphics.setColor(color.white)
	if self.persist.liveDelayCounter <= 0 and self.persist.coverArtDisplayDone then
		if self.data.storyboard then
			self.data.storyboard:draw()
			drawBackground = false
		elseif self.data.video then
			love.graphics.setBlendMode("replace", "alphamultiply")
			love.graphics.draw(
				self.data.video.drawable,
				480, 320, 0,
				self.data.video.scale, self.data.video.scale,
				self.data.video.w * 0.5, self.data.video.h * 0.5
			)
			love.graphics.setBlendMode("alpha", "alphamultiply")
			drawBackground = false
		end
	end

	if drawBackground then
		love.graphics.setBlendMode("replace", "alphamultiply")
		love.graphics.draw(self.data.background)
		love.graphics.setBlendMode("alpha", "alphamultiply")
	end

	if self.persist.coverArtDisplayDone == false then
		local x = self.data.coverArtDisplay
		local fOpacity
		local fTextPos = math.min(x.time, 0.25) * 1920
		if x.time >= 2.7 then
			-- Second transition
			fOpacity = 1 - math.min(x.time - 2.7, 0.3) * 10/3
		else
			-- First transition
			fOpacity = math.min(x.time, 0.25) * 4
		end

		-- Draw image
		love.graphics.setColor(color.compat(255, 255, 255, fOpacity))
		love.graphics.draw(x.image, 280, 80, 0, x.scaleX, x.scaleY)
		if self.persist.beatmapRandomized then
			love.graphics.draw(self.assets.images.random, 280, 80, 0, 400/272, 400/272)
		end
		-- Text aura
		if x.time >= 0.25 and x.time < 0.75 then
			local val = math.min(x.time - 0.25, 1) * 2
			love.graphics.setColor(color.compat(255, 255, 255, (1 - val) * 0.5))
			-- title
			love.graphics.draw(x.title, 480 + val * 100, 0)
			-- information
			love.graphics.draw(x.info, 480 + val * 100, 0)
		end
		-- title and info color (non aura)
		if x.time >= 2.7 then
			love.graphics.setColor(color.compat(255, 255, 255, fOpacity))
		else
			love.graphics.setColor(color.white)
		end
		-- Draw title
		love.graphics.draw(x.title, fTextPos, 0)
		-- Draw information
		love.graphics.draw(x.info, fTextPos, 0)

		return
	end

	-- draw dim
	local dimVal = (self.persist.liveDelay - math.max(self.persist.liveDelayCounter, 0)) / self.persist.liveDelay
	love.graphics.push()
	love.graphics.origin()
	love.graphics.setColor(color.compat(0, 0, 0, dimVal * self.persist.dimValue))
	love.graphics.rectangle("fill", 0, 0, self.persist.windowWidth, self.persist.windowHeight)
	love.graphics.pop()

	if self.persist.liveDelayCounter <= 0 then
		-- draw skill flash
		self.data.skill:drawUnder()

		-- enable safe area reposition
		safeAreaReposition(self.safeScale)
		-- draw live header
		self.data.liveUI:drawHeader()
		-- draw unit icons
		love.graphics.setColor(color.white)
		for i, v in ipairs(self.persist.lane) do
			love.graphics.draw(self.data.unitIcons[i], v.x, v.y, 0, 1, 1, 64, 64)
		end
		-- draw unit skill indicator
		self.data.skill:drawUpper()
		-- draw notes
		self.data.noteManager:draw()
		-- draw live status
		self.data.liveUI:drawStatus()
		-- draw lyrics
		if self.data.lyrics then
			self.data.lyrics:draw()
		end
		-- disable safe area reposition
		safeAreaReposition()
		-- draw pause overlay
		self.data.pauseObject:draw()
	end

	-- draw replay keyboard overlay
	safeAreaReposition(self.safeScale)
	for i = 1, 9 do
		love.graphics.setColor(color.red)
		if self.persist.replayKeyOverlay[i] then
			local x = self.persist.lane[i]
			love.graphics.draw(self.assets.images.dummyUnit, x.x, x.y, 0, 1, 1, 64, 64)
		end
	end
	-- draw replay touch overlay
	replay.drawTouchLine()
	safeAreaReposition()
end

function DEPLS:draw()
	if self.persist.render then
		render.begin()
		draw(self)
		render.commit()
	else
		return draw(self)
	end
end

local function livesimInputPressed(self, id, x, y)
	if self.persist.render then return end
	-- id 0 is mouse
	if
		self.data.pauseObject:isPaused() or
		self.data.liveUI:checkPause(x, y)
	then
		return
	end

	x, y = rescalePosition(self, x, y)
	if not(self.persist.autoplay or self.persist.replayMode) then
		replay.recordTouchpressed(id, x, y)
	end
	if not(self.persist.replayMode) then
		return self.data.noteManager:touchPressed(id, x, y)
	end
end

local function livesimInputMoved(self, id, x, y)
	if self.persist.render then return end
	if self.data.pauseObject:isPaused() then return end

	x, y = rescalePosition(self, x, y)
	if not(self.persist.autoplay or self.persist.replayMode) then
		replay.recordTouchmoved(id, x, y)
	end
	if not(self.persist.replayMode) then
		return self.data.noteManager:touchMoved(id, x, y)
	end
end

local function livesimInputReleased(self, id, x, y)
	if self.data.pauseObject:isPaused() then
		return self.data.pauseObject:mouseReleased(x, y)
	end

	x, y = rescalePosition(self, x, y)
	if not(self.persist.autoplay or self.persist.replayMode) then
		replay.recordTouchreleased(id, x, y)
	end

	if self.data.liveUI:checkPause(x, y) and type(id) ~= "string" then
		return pauseGame(self)
	end

	if not(self.persist.replayMode) then
		return self.data.noteManager:touchReleased(id, x, y)
	end
end

DEPLS:registerEvent("resize", function(self, w, h)
	safeAreaScaling(self)
	if not(self.persist.render) then
		self.persist.windowWidth, self.persist.windowHeight = w, h
	end
end)

DEPLS:registerEvent("keypressed", function(self, key, _, rep)
	if self.persist.render then return end
	if not(self.persist.coverArtDisplayDone) then return end
	log.debugf("livesim2", "keypressed, key: %s, repeat: %s", key, tostring(rep))

	if
		not(rep) and
		not(self.persist.replayMode) and
		not(self.data.pauseObject:isPaused()) and
		self.persist.keymap[key]
	then
		if not(self.persist.autoplay) then
			replay.recordKeypressed(self.persist.keymap[key])
		end
		return self.data.noteManager:setTouch(self.persist.keymap[key], key)
	end
end)

DEPLS:registerEvent("keyreleased", function(self, key)
	if self.persist.render then return end
	if not(self.persist.coverArtDisplayDone) then return end
	log.debugf("livesim2", "keypressed, key: %s", key)

	local isPaused = self.data.pauseObject:isPaused()

	if key == "escape" then
		if love._os == "Android" then
			if self.persist.liveDelayCounter <= 0 and not(isPaused) then
				return pauseGame(self)
			elseif isLiveClear(self) then
				return gamestate.leave(loadingInstance.getInstance())
			end
		else
			return gamestate.leave(loadingInstance.getInstance())
		end
	elseif key == "pause" then
		if isPaused then
			return self.data.pauseObject:fastResume()
		elseif self.persist.liveDelayCounter <= 0 then
			return pauseGame(self)
		end
	end

	if not(self.persist.replayMode) and not(isPaused) and self.persist.keymap[key] then
		if not(self.persist.autoplay) then
			replay.recordKeyreleased(self.persist.keymap[key])
		end
		return self.data.noteManager:setTouch(self.persist.keymap[key], key, true)
	end
end)

local mouseIsDown = false

DEPLS:registerEvent("mousepressed", function(self, x, y, b, ist)
	if self.persist.render then return end
	if not(self.persist.coverArtDisplayDone) then return end
	if ist or b > 1 then return end -- handled separately/handle left click only
	mouseIsDown = true
	return livesimInputPressed(self, 0, x, y)
end)

DEPLS:registerEvent("mousemoved", function(self, x, y, _, _, ist)
	if not(self.persist.coverArtDisplayDone) then return end
	if ist or not(mouseIsDown) then return end
	return livesimInputMoved(self, 0, x, y)
end)

DEPLS:registerEvent("mousereleased", function(self, x, y, b, ist)
	if self.persist.render then return end
	if not(self.persist.coverArtDisplayDone) then return end
	if ist or b > 1 then return end
	mouseIsDown = false
	return livesimInputReleased(self, 0, x, y)
end)

DEPLS:registerEvent("touchpressed", livesimInputPressed)
DEPLS:registerEvent("touchmoved", livesimInputMoved)
DEPLS:registerEvent("touchreleased", livesimInputReleased)

DEPLS:registerEvent("focus", function(self)
	if util.isMobile() then
		pauseGame(self)
	end
end)

return DEPLS
