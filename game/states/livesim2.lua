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

	-- load live UI
	self.data.liveUI = liveUI.newLiveUI("sif")
	-- Lane definition
	self.persist.lane = self.data.liveUI:getLanePosition()
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
			self.data.liveUI:comboJudgement(judgement, releaseFlag ~= 1)
			if releaseFlag ~= 1 then
				if judgement ~= "miss" then
					self.data.liveUI:addScore(math.random(256, 1024))
					self.data.liveUI:addTapEffect(position.x, position.y, 255, 255, 255, 1)
				end
			end

			-- play SFX
			if judgement ~= "miss" then
				playTapSFXSound(self.data.tapSFX, judgement, self.data.tapNoteAccumulation)
			end
			if judgement ~= "perfect" and judgement ~= "great" and object.star then
				playTapSFXSound(self.data.tapSFX, "starExplode", false)
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
	if self.data.song then
		self.data.song:play()
	end
end

function DEPLS:exit()
	timer.cancel(self.persist.debugTimer)
	if self.data.song then
		self.data.song:pause()
	end
end

function DEPLS:update(dt)
	for i = 1, #self.data.tapSFX.accumulateTracking do
		self.data.tapSFX.accumulateTracking[i].alreadyPlayed = false
	end

	-- update pause object first
	self.data.pauseObject:update(dt)
	if not(self.data.pauseObject:isPaused()) then
		self.data.noteManager:update(dt)
	end

	self.data.liveUI:update(dt)
end

function DEPLS:draw()
	-- draw background
	love.graphics.setColor(color.compat(255, 255, 255, 0.25))
	love.graphics.draw(self.data.background)
	self.data.liveUI:drawHeader()
	love.graphics.setColor(color.white)
	for i, v in ipairs(self.persist.lane) do
		love.graphics.draw(self.data.unitIcons[i], v.x, v.y, 0, 1, 1, 64, 64)
	end

	self.data.noteManager:draw()
	self.data.liveUI:drawStatus()
	self.data.pauseObject:draw()
end

local function pauseGame(self)
	if self.data.song then
		self.data.song:pause()
	end
	self.data.pauseObject:pause(self.persist.beatmapDisplayName)
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

DEPLS:registerEvent("keypressed", function(self, key, _, rep)
	log.debugf("livesim2", "keypressed, key: %s, repeat: %s", key, tostring(rep))
	if not(rep) and self.persist.keymap[key] then
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

	if self.persist.keymap[key] then
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
