-- Main game
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local async = require("async")
local assetCache = require("asset_cache")
local log = require("logging")
local setting = require("setting")
local util = require("util")
local L = require("language")

local timer = require("libs.hump.timer")
local lsr = require("libs.lsr")

local audioManager = require("audio_manager")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local glow = require("game.afterglow")
local tapSound = require("game.tap_sound")
local beatmapList = require("game.beatmap.list")
local backgroundLoader = require("game.background_loader")
local note = require("game.live.note")
local pause = require("game.live.pause")
local result = require("game.live.result")
local liveUI = require("game.live.ui")
local replay = require("game.live.replay")
local BGM = require("game.bgm")

local DEPLS = gamestate.create {
	fonts = {
		main = {"fonts/MTLmr3m.ttf", 12},
		titleArt = {"fonts/MTLmr3m.ttf", 40},
		infoArt = {"fonts/MTLmr3m.ttf", 16},
	},
	images = {
		note = {"noteImage:assets/image/tap_circle/notes.png", {mipmaps = true}},
		longNoteTrail = {"assets/image/ef_326_000.png"},
		dummyUnit = {"assets/image/dummy.png", {mipmaps = true}}
	}
}

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

local function pauseGame(self, fail)
	if self.data.liveUI:isPauseEnabled() then
		if self.data.song then
			self.data.song:pause()
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
	local accuracyData = self.persist.replayMode and self.persist.replayMode.accuracy or self.persist.accuracyData
	local noteInfo = self.persist.noteInfo
	noteInfo.maxCombo = self.data.liveUI:getMaxCombo()
	noteInfo.score = self.data.liveUI:getScore()

	local replayData = self.persist.replayMode or {
		storyboardSeed = 0,
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
		timestamp = self.persist.startTimestamp,
		accuracy = self.persist.accuracyData,
		events = replay.getEventData(),
		scorePerTap = self.persist.tapScore
	}

	self.data.resultObject:setReplayCallback(function()
		if not(self.persist.autoplay) then
			gamestate.replace(loadingInstance.getInstance(), "livesim2", {
				summary = self.persist.summary,
				beatmapName = self.persist.beatmapName,
				replay = replayData
			})
		end
	end)
	self.data.resultObject:setSaveReplayCallback(function()
		if self.persist.autoplay then
			return L"livesim2:replay:errorAutoplay"
		end

		local name
		if not(love.filesystem.createDirectory("replays/"..self.persist.beatmapName)) then
			return L"livesim2:replay:errorDirectory"
		end

		if self.persist.replayMode then
			if self.persist.replayMode.filename then
				return L"livesim2:replay:errorAlreadySaved"
			end

			name = "replays/"..self.persist.beatmapName.."/"..self.persist.replayMode.timestamp..".lsr"
			if util.fileExists(name) then
				return L"livesim2:replay:errorAlreadySaved"
			end
		end

		name = "replays/"..self.persist.beatmapName.."/"..self.persist.startTimestamp..".lsr"
		if util.fileExists(name) then
			return L"livesim2:replay:errorAlreadySaved"
		end

		local s = lsr.saveReplay(
			name,
			self.persist.summary.hash,
			0,
			replayData,
			replayData.accuracy,
			replayData.events
		)
		if s then
			replayData.filename = name
			return L"livesim2:replay:saved"
		else
			return L"livesim2:replay:errorSaveGeneric"
		end
	end)
	self.data.resultObject:setInformation(replayData, accuracyData, self.persist.comboRange)
	self.persist.showLiveResult = true
end

function DEPLS:load(arg)
	glow.clear()

	-- sanity check
	assert(arg.summary, "summary data missing")
	assert(arg.beatmapName, "beatmap name id missing")
	self.persist.summary = arg.summary
	self.persist.beatmapName = arg.beatmapName
	self.persist.beatmapDisplayName = assert(arg.summary.name)

	-- autoplay
	local autoplay
	if arg.autoplay == nil then
		autoplay = setting.get("AUTOPLAY") == 1
	elseif arg.replay then
		autoplay = false
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
	-- window dimensions
	self.persist.windowWidth, self.persist.windowHeight = love.graphics.getDimensions()
	-- dim delay
	self.persist.liveDelay = math.max(setting.get("LIVESIM_DELAY") * 0.001, 1)
	self.persist.liveDelayCounter = self.persist.liveDelay
	self.persist.dimValue = util.clamp(setting.get("LIVESIM_DIM") * 0.01, 0, 1)
	-- score and stamina
	self.persist.tapScore = arg.replay and self.persist.replayMode.scorePerTap or 0
	if self.persist.tapScore == 0 then
		self.persist.tapScore = setting.get("SCORE_ADD_NOTE")
	end
	assert(self.persist.tapScore > 0, "invalid score/tap, check setting!")
	self.persist.stamina = setting.get("STAMINA_DISPLAY")
	self.persist.noFail = setting.get("STAMINA_FUNCTIONAL") == 0
	-- load live UI
	self.data.liveUI = liveUI.newLiveUI("sif")
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
		timingOffset = setting.get("TIMING_OFFSET"),
		beatmapOffset = setting.get("GLOBAL_OFFSET") * 0.001,
		callback = function(object, lane, position, judgement, releaseFlag)
			log.debugf(
				"livesim2", "note cb (%s), lane: %d, position: %s, relmode: %d",
				judgement, lane, tostring(position), releaseFlag
			)
			-- judgement
			self.data.liveUI:comboJudgement(judgement, releaseFlag ~= 1)
			if releaseFlag ~= 1 then
				if judgement ~= "miss" then
					local scoreMulType = (releaseFlag == 2 and 1.25 or 1) * (object.swing and 0.5 or 1)
					local scoreMul = scoreMulType * (object.scoreMultipler or 1)
					self.data.liveUI:addScore(math.ceil(scoreMul * scoreMultipler[judgement] * self.persist.tapScore))
					self.data.liveUI:addTapEffect(position.x, position.y, 255, 255, 255, 1)
				end

				-- counter
				self.persist.accuracyData[#self.persist.accuracyData + 1] = accuracyGraphValue[judgement]
				self.persist.noteInfo.totalNotes = self.persist.noteInfo.totalNotes + 1
				self.persist.noteInfo[judgement] = self.persist.noteInfo[judgement] + 1
				if judgement ~= "miss" and object.token then
					self.persist.noteInfo.token = self.persist.noteInfo.token + 1
				end
				if judgement == "perfect" then
					if releaseFlag == 2 then
						self.persist.noteInfo.perfectSimultaneous = self.persist.noteInfo.perfectSimultaneous + 1
					elseif object.swing then
						self.persist.noteInfo.perfectSwing = self.persist.noteInfo.perfectSwing + 1
					else
						self.persist.noteInfo.perfectNote = self.persist.noteInfo.perfectNote + 1
					end
				end
			elseif judgement ~= "miss" then
				object.scoreMultipler = scoreMultipler[judgement]
			end

			-- play SFX
			if judgement ~= "miss" then
				playTapSFXSound(self.data.tapSFX, judgement, self.data.tapNoteAccumulation)
			end
			if judgement ~= "perfect" and judgement ~= "great" then
				if object.star then
					playTapSFXSound(self.data.tapSFX, "starExplode", false)
				end
				self.persist.noteInfo.fullCombo = false
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

	-- Load notes data
	local isBeatmapInit = 0
	beatmapList.getNotes(arg.beatmapName, function(notes)
		local fullScore = 0
		for i = 1, #notes do
			local t = notes[i]
			if self.data.noteManager:addNote(t) then
				self.persist.noteInfo.tokenAmount = self.persist.noteInfo.tokenAmount + 1
			end
			fullScore = fullScore + (t.effect > 10 and 370 or 739)
		end
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
	-- need to wrap in coroutine because
	-- there's no async access in the callback
	beatmapList.getBackground(arg.beatmapName, coroutine.wrap(function(value)
		log.debug("livesim2", "received background data")
		local tval = type(value)
		if tval == "table" then
			local bitval
			local m, l, r, t, b
			-- main background
			m = love.graphics.newImage(table.remove(value, 2))
			bitval = math.floor(value[1] / 4)
			-- left & right
			if bitval % 2 > 0 then
				l = love.graphics.newImage(table.remove(value, 2))
				r = love.graphics.newImage(table.remove(value, 2))
			end
			bitval = math.floor(value[1] / 2)
			-- top & bottom
			if bitval % 2 > 0 then
				t = love.graphics.newImage(table.remove(value, 2))
				b = love.graphics.newImage(table.remove(value, 2))
			end
			-- TODO: video
			self.data.background = backgroundLoader.compose(m, l, r, t, b)
		elseif tval == "number" and value > 0 then
			self.data.background = backgroundLoader.load(value)
		end
		isBeatmapInit = isBeatmapInit + 1
	end))
	-- Load unit data too
	beatmapList.getCustomUnit(arg.beatmapName, function(unitData)
		self.data.customUnit = unitData
		log.debug("livesim2", "received unit data")
		isBeatmapInit = isBeatmapInit + 1
	end)

	-- load tap SFX
	self.data.tapSFX = {accumulateTracking = {}}
	local tapSoundIndex = assert(tapSound[tonumber(setting.get("TAP_SOUND"))], "invalid tap sound")
	for k, v in pairs(tapSoundIndex) do
		if type(v) == "string" then
			local audio = audioManager.newAudio(v)

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
			gamestate.leave(loadingInstance.getInstance())
		end,
		resume = function()
			if self.data.song then
				self.data.song:seek(self.data.noteManager:getElapsedTime())
				self.data.song:play()
			end
		end,
		restart = function()
			gamestate.replace(loadingInstance.getInstance(), "livesim2", arg)
		end
	})

	-- result screen
	self.data.resultObject = result(arg.summary.name)
	self.data.resultObject:setReturnCallback(function(opaque, restart)
		if restart then
			return gamestate.replace(loadingInstance.getInstance(), "livesim2", opaque)
		else
			return gamestate.leave(loadingInstance.getInstance())
		end
	end, arg)

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
			title = love.graphics.newText(self.assets.fonts.titleArt),
			info = love.graphics.newText(self.assets.fonts.infoArt),
			script = nil,
			time = 0
		}
		self.persist.coverArtDisplayDone = false
		y.scaleX = 400/y.image:getWidth()
		y.scaleY = 400/y.image:getHeight()

		w = self.assets.fonts.titleArt:getWidth(x.title)
		y.title:add({color.black, x.title}, -w*0.5-2, 507)
		y.title:add({color.black, x.title}, -w*0.5+2, 509)
		y.title:add({color.white, x.title}, -w*0.5, 508)

		if x.info and #x.info > 0 then
			w = self.assets.fonts.infoArt:getWidth(x.info)
			y.info:add({color.black, x.info}, -w*0.5-1, 553)
			y.info:add({color.black, x.info}, -w*0.5+1, 555)
			y.info:add({color.white, x.info}, -w*0.5, 554)
		end

		self.data.coverArtDisplay = y
	end

	-- wait until notes are loaded
	while isBeatmapInit < 3 do
		async.wait()
	end
	log.debug("livesim2", "beatmap init wait done")

	-- if there's no background, load default
	if not(self.data.background) then
		self.data.background = backgroundLoader.load(assert(tonumber(setting.get("BACKGROUND_IMAGE"))))
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

		if self.data.customUnit[i] then
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

	log.debug("livesim2", "ready")
end

function DEPLS:start()
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
	self.persist.startTimestamp = os.time()
	self.persist.showLiveResult = false
end

function DEPLS:exit()
	timer.cancel(self.persist.debugTimer)
	if self.data.song then
		self.data.song:pause()
	end
end

function DEPLS:update(dt)
	if self.persist.showLiveResult then
		return self.data.resultObject:update(dt)
	elseif self.persist.coverArtDisplayDone then
		self.persist.liveDelayCounter = self.persist.liveDelayCounter - dt

		for i = 1, #self.data.tapSFX.accumulateTracking do
			self.data.tapSFX.accumulateTracking[i].alreadyPlayed = false
		end

		-- update pause object first
		self.data.pauseObject:update(dt)
		if not(self.data.pauseObject:isPaused()) then
			if self.persist.liveDelayCounter <= 0 then
				local updtDt = dt
				if self.persist.liveDelayCounter ~= -math.huge then
					updtDt = -self.persist.liveDelayCounter
					self.persist.liveDelayCounter = -math.huge
					if self.data.song then
						self.data.song:seek(updtDt)
						self.data.song:play()
					end
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
			end
		end

		self.data.liveUI:update(dt, self.data.pauseObject:isPaused())

		if isLiveClear(self) then
			self.data.liveUI:startLiveClearAnimation(self.persist.noteInfo.fullCombo, liveClearCallback, self)
		end
	else
		self.data.coverArtDisplay.time = self.data.coverArtDisplay.time + dt
		if self.data.coverArtDisplay.time >= 3 then
			self.persist.coverArtDisplayDone = true
		end
	end
end

function DEPLS:draw()
	-- draw background
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
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

	if self.persist.showLiveResult then
		return self.data.resultObject:draw()
	end

	if self.persist.liveDelayCounter <= 0 then
		-- draw live header
		self.data.liveUI:drawHeader()
		love.graphics.setColor(color.white)
		for i, v in ipairs(self.persist.lane) do
			love.graphics.draw(self.data.unitIcons[i], v.x, v.y, 0, 1, 1, 64, 64)
		end

		-- draw notes
		self.data.noteManager:draw()
		-- draw live status
		self.data.liveUI:drawStatus()
		-- draw pause overlay
		self.data.pauseObject:draw()
	end

	-- draw replay keyboard overlay
	for i = 1, 9 do
		love.graphics.setColor(color.red)
		if self.persist.replayKeyOverlay[i] then
			local x = self.persist.lane[i]
			love.graphics.draw(self.assets.images.dummyUnit, x.x, x.y, 0, 1, 1, 64, 64)
		end
	end
	-- draw replay touch overlay
	return replay.drawTouchLine()
end

local function livesimInputPressed(self, id, x, y)
	-- id 0 is mouse
	if
		self.persist.showLiveResult or
		self.data.pauseObject:isPaused() or
		self.data.liveUI:checkPause(x, y)
	then
		return
	end
	if not(self.persist.autoplay or self.persist.replayMode) then
		replay.recordTouchpressed(id, x, y)
	end
	if not(self.persist.replayMode) then
		return self.data.noteManager:touchPressed(id, x, y)
	end
end

local function livesimInputMoved(self, id, x, y)
	if self.persist.showLiveResult or self.data.pauseObject:isPaused() then return end
	if not(self.persist.autoplay or self.persist.replayMode) then
		replay.recordTouchmoved(id, x, y)
	end
	if not(self.persist.replayMode) then
		return self.data.noteManager:touchMoved(id, x, y)
	end
end

local function livesimInputReleased(self, id, x, y)
	if self.persist.showLiveResult then return end
	if self.data.pauseObject:isPaused() then
		return self.data.pauseObject:mouseReleased(x, y)
	end

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
	self.persist.windowWidth, self.persist.windowHeight = w, h
end)

DEPLS:registerEvent("keypressed", function(self, key, _, rep)
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
	if not(self.persist.coverArtDisplayDone) then return end
	log.debugf("livesim2", "keypressed, key: %s", key)
	if key == "escape" then
		if love._os == "Android" then
			if self.persist.liveDelayCounter <= 0 and not(self.data.pauseObject:isPaused()) then
				return pauseGame(self)
			elseif isLiveClear(self) then
				return gamestate.leave(loadingInstance.getInstance())
			end
		else
			return gamestate.leave(loadingInstance.getInstance())
		end
	elseif key == "pause" and self.persist.liveDelayCounter <= 0 then
		return pauseGame(self)
	end

	if not(self.persist.replayMode) and not(self.data.pauseObject:isPaused()) and self.persist.keymap[key] then
		if not(self.persist.autoplay) then
			replay.recordKeyreleased(self.persist.keymap[key])
		end
		return self.data.noteManager:setTouch(self.persist.keymap[key], key, true)
	end
end)

local mouseIsDown = false

DEPLS:registerEvent("mousepressed", function(self, x, y, b, ist)
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
	if not(self.persist.coverArtDisplayDone) then return end
	if ist or b > 1 then return end
	mouseIsDown = false
	return livesimInputReleased(self, 0, x, y)
end)

DEPLS:registerEvent("touchpressed", livesimInputPressed)
DEPLS:registerEvent("touchmoved", livesimInputMoved)
DEPLS:registerEvent("touchreleased", livesimInputReleased)

return DEPLS
