-- Main game
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local async = require("async")
local assetCache = require("asset_cache")
local timer = require("libs.hump.timer")
local log = require("logging")
local setting = require("setting")
local util = require("util")

local audioManager = require("audio_manager")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local tapSound = require("game.tap_sound")
local beatmapList = require("game.beatmap.list")
local backgroundLoader = require("game.background_loader")
local note = require("game.live.note")
local pause = require("game.live.pause")
local liveUI = require("game.live.ui")
local BGM = require("game.bgm")

local DEPLS = gamestate.create {
	fonts = {
		main = {"fonts/MTLmr3m.ttf", 12},
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

local staminaJudgmentDamage = {
	perfect = 0,
	great = 0,
	good = 0.5,
	bad = 1,
	miss = 2
}

local pauseGame

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

function DEPLS:load(arg)
	-- sanity check
	assert(arg.summary, "summary data missing")
	assert(arg.beatmapName, "beatmap name id missing")
	self.persist.beatmapDisplayName = assert(arg.summary.name)

	-- autoplay
	local autoplay = arg.autoplay
	if autoplay == nil then
		autoplay = setting.get("AUTOPLAY") == 1
	end

	-- window dimensions
	self.persist.windowWidth, self.persist.windowHeight = love.graphics.getDimensions()
	-- dim delay
	self.persist.liveDelay = math.max(setting.get("LIVESIM_DELAY") * 0.001, 1)
	self.persist.liveDelayCounter = self.persist.liveDelay
	self.persist.dimValue = util.clamp(setting.get("LIVESIM_DIM") * 0.01, 0, 1)
	-- score and stamina
	self.persist.tapScore = setting.get("SCORE_ADD_NOTE")
	self.persist.stamina = setting.get("STAMINA_DISPLAY")
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
	}
	-- Create new note manager
	self.data.noteManager = note.newNoteManager({
		image = self.assets.images.note,
		trailImage = self.assets.images.longNoteTrail,
		noteSpawningPosition = self.data.liveUI:getNoteSpawnPosition(),
		lane = self.persist.lane,
		accuracy = {16, 40, 64, 112, 128},
		autoplay = autoplay,
		callback = function(object, lane, position, judgement, releaseFlag)
			log.debugf(
				"livesim2", "note cb (%s), lane: %d, position: %s, relmode: %d",
				judgement, lane, tostring(position), releaseFlag
			)
			-- judgement
			self.data.liveUI:comboJudgement(judgement, releaseFlag ~= 1)
			if releaseFlag ~= 1 then
				if judgement ~= "miss" then
					local scoreMulType = releaseFlag == 2 and 1.25 or (object.swing and 0.5 or 1)
					local scoreMul = scoreMulType * (object.scoreMultipler or 1)
					self.data.liveUI:addScore(math.ceil(scoreMul * scoreMultipler[judgement] * self.persist.tapScore))
					self.data.liveUI:addTapEffect(position.x, position.y, 255, 255, 255, 1)
				end

				-- counter
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
			if judgement ~= "perfect" and judgement ~= "great" and object.star then
				playTapSFXSound(self.data.tapSFX, "starExplode", false)
			end

			-- damage
			self.data.liveUI:addStamina(-math.floor(staminaJudgmentDamage[judgement] * (object.star and 2 or 1)))
			if self.data.liveUI:getStamina() == 0 then
				-- fail
				pauseGame(self, true)
			end
		end,
	})

	-- Load notes data
	local isBeatmapInit = 0
	beatmapList.getNotes(arg.beatmapName, function(notes)
		local fullScore = 0
		for i = 1, #notes do
			local t = notes[i]
			self.data.noteManager:addNote(t)
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
end

function DEPLS:exit()
	timer.cancel(self.persist.debugTimer)
	if self.data.song then
		self.data.song:pause()
	end
end

function DEPLS:update(dt)
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
			self.data.noteManager:update(updtDt)
		end
	end

	self.data.liveUI:update(dt)
end

function DEPLS:draw()
	-- draw background
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	-- draw dim
	local dimVal = (self.persist.liveDelay - math.max(self.persist.liveDelayCounter, 0)) / self.persist.liveDelay
	love.graphics.push()
	love.graphics.origin()
	love.graphics.setColor(color.compat(0, 0, 0, dimVal * self.persist.dimValue))
	love.graphics.rectangle("fill", 0, 0, self.persist.windowWidth, self.persist.windowHeight)
	love.graphics.pop()

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
end

function pauseGame(self, fail)
	if self.data.song then
		self.data.song:pause()
	end
	self.data.pauseObject:pause(self.persist.beatmapDisplayName, fail)
end

local function livesimInputPressed(self, id, x, y)
	-- id 0 is mouse
	if self.data.pauseObject:isPaused() then return end

	return self.data.noteManager:touchPressed(id, x, y)
end

local function livesimInputMoved(self, id, x, y)
	if self.data.pauseObject:isPaused() then return end

	return self.data.noteManager:touchMoved(id, x, y)
end

local function livesimInputReleased(self, id, x, y)
	if self.data.pauseObject:isPaused() then
		return self.data.pauseObject:mouseReleased(x, y)
	end

	if self.data.liveUI:checkPause(x, y) then
		return pauseGame(self)
	end

	return self.data.noteManager:touchReleased(id, x, y)
end

DEPLS:registerEvent("resize", function(self, w, h)
	self.persist.windowWidth, self.persist.windowHeight = w, h
end)

DEPLS:registerEvent("keypressed", function(self, key, _, rep)
	log.debugf("livesim2", "keypressed, key: %s, repeat: %s", key, tostring(rep))
	if not(rep) and not(self.data.pauseObject:isPaused()) and self.persist.keymap[key] then
		return self.data.noteManager:setTouch(self.persist.keymap[key], key)
	end
end)

DEPLS:registerEvent("keyreleased", function(self, key)
	log.debugf("livesim2", "keypressed, key: %s", key)
	if key == "escape" then
		return gamestate.leave(loadingInstance.getInstance())
	elseif key == "pause" then
		return pauseGame(self)
	end

	if not(self.data.pauseObject:isPaused()) and self.persist.keymap[key] then
		return self.data.noteManager:setTouch(self.persist.keymap[key], key, true)
	end
end)

DEPLS:registerEvent("mousepressed", function(self, x, y, b, ist)
	if ist or b > 1 then return end -- handled separately/handle left click only
	return livesimInputPressed(self, 0, x, y)
end)

DEPLS:registerEvent("mousemoved", function(self, x, y, _, _, ist)
	if ist or not(love.mouse.isDown(1)) then return end
	return livesimInputMoved(self, 0, x, y)
end)

DEPLS:registerEvent("mousereleased", function(self, x, y, b, ist)
	if ist or b > 1 then return end
	return livesimInputReleased(self, 0, x, y)
end)

DEPLS:registerEvent("touchpressed", livesimInputPressed)
DEPLS:registerEvent("touchmoved", livesimInputMoved)
DEPLS:registerEvent("touchreleased", livesimInputReleased)

return DEPLS
