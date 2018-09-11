-- Main game
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local async = require("async")
local timer = require("libs.hump.timer")
local log = require("logging")
local setting = require("setting")

local audioManager = require("audio_manager")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local tapSound = require("game.tap_sound")
local beatmapList = require("game.beatmap.list")
local backgroundLoader = require("game.background_loader")
local note = require("game.live.note")
local liveUI = require("game.live.ui")
local BGM = require("game.bgm")

local DEPLS = gamestate.create {
	fonts = {
		main = {"fonts/MTLmr3m.ttf", 12},
	},
	images = {
		note = {"noteImage:assets/image/tap_circle/notes.png", {mipmaps = true}},
		longNoteTrail = {"assets/image/ef_326_000.png"}
	},
	audios = {}
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
		autoplay = true, -- Testing only
		callback = function(object, lane, position, judgement, releaseFlag)
			self.data.liveUI:comboJudgement(judgement, releaseFlag ~= 1)
			if releaseFlag ~= 1 then
				self.data.liveUI:addScore(math.random(256, 1024))
				self.data.liveUI:addTapEffect(position.x, position.y, 255, 255, 255, 1)
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
	beatmapList.getNotes(arg.beatmapName, function(chan)
		local amount = chan:pop()
		local fullScore = 0
		for _ = 1, amount do
			local t = {}
			while chan:peek() ~= chan do
				local k = chan:pop()
				t[k] = chan:pop()
			end

			-- pop separator
			chan:pop()
			fullScore = fullScore + t.effect > 10 and 370 or 739
			self.data.noteManager:addNote(t)
		end

		self.data.noteManager:initialize()
		isBeatmapInit = isBeatmapInit + 1
		-- Set score range (c,b,a,s order)
		self.data.liveUI:setScoreRange(
			math.floor(fullScore * 211/739 + 0.5),
			math.floor(fullScore * 528/739 + 0.5),
			math.floor(fullScore * 633/739 + 0.5),
			fullScore
		)
	end)
	-- need to wrap in coroutine because
	-- there's no async access in the callback
	beatmapList.getBackground(arg.beatmapName, coroutine.wrap(function(value)
		local tval = type(value)
		if tval == "table" then
			local bitval
			local m, l, r, t, b
			-- main background
			m = table.remove(value, 2)
			bitval = math.floor(value[1] / 4)
			-- left & right
			if bitval % 2 > 0 then
				l = table.remove(value, 2)
				r = table.remove(value, 2)
			end
			bitval = math.floor(value[1] / 2)
			-- top & bottom
			if bitval % 2 > 0 then
				t = table.remove(value, 2)
				b = table.remove(value, 2)
			end
			-- TODO: video
			self.data.background = backgroundLoader.compose(m, l, r, t, b)
		elseif tval == "number" and value > 0 then
			self.data.background = backgroundLoader.load(value)
		end
		isBeatmapInit = isBeatmapInit + 1
	end))
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
	-- wait until notes are loaded
	while isBeatmapInit < 2 do
		async.wait()
	end
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
end

function DEPLS:start()
	self.persist.debugTimer = timer.every(1, function()
		log.debug("livesim2", "note remaining "..#self.data.noteManager.notesList)
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

	self.data.noteManager:update(dt)
	self.data.liveUI:update(dt)
end

function DEPLS:draw()
	-- draw background
	love.graphics.setColor(color.compat(255, 255, 255, 0.25))
	love.graphics.draw(self.data.background)
	self.data.liveUI:drawHeader()
	love.graphics.setColor(color.white)
	for _, v in ipairs(self.persist.lane) do
		love.graphics.circle("fill", v.x, v.y, 64)
		--love.graphics.circle("line", v.x, v.y, 64)
	end

	self.data.noteManager:draw()
	self.data.liveUI:drawStatus()
end

DEPLS:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return gamestate.leave(loadingInstance.getInstance())
	end
end)

return DEPLS
