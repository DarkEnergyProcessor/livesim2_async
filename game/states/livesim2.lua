-- Main game
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local async = require("async")
local vector = require("libs.hump.vector")
local timer = require("libs.hump.timer")
local log = require("logging")
local setting = require("setting")

local audioManager = require("audio_manager")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local tapSound = require("game.tap_sound")
local beatmapList = require("game.beatmap.list")
local note = require("game.live.note")
local liveUI = require("game.live.ui")

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
	local isInit = false
	log.debug("livesim2", "loading notes data for test beatmap")
	beatmapList.push()
	beatmapList.enumerate(function() end)
	beatmapList.getSummary("senbonzakura.json", function(data)
		local v = {}
		while data:getCount() > 0 do
			local k = data:pop()
			v[k] = data:pop()
		end
		arg.beatmapName = "senbonzakura.json"
		arg.summary = v
		beatmapList.getNotes(arg.beatmapName, function(chan)
			local amount = chan:pop()
			for _ = 1, amount do
				local t = {}
				while chan:peek() ~= chan do
					local k = chan:pop()
					t[k] = chan:pop()
				end

				-- pop separator
				chan:pop()
				self.data.noteManager:addNote(t)
			end

			self.data.noteManager:initialize()
			isInit = true
		end)
	end)
	self.data.liveUI:setScoreRange(12500, 36000, 92200, 125000)
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
	while isInit == false do
		async.wait()
	end
end

function DEPLS:start()
	self.persist.debugTimer = timer.every(1, function()
		log.debug("livesim2", "note remaining "..#self.data.noteManager.notesList)
	end)
end

function DEPLS:exit()
	timer.cancel(self.persist.debugTimer)
end

function DEPLS:update(dt)
	for i = 1, #self.data.tapSFX.accumulateTracking do
		self.data.tapSFX.accumulateTracking[i].alreadyPlayed = false
	end

	self.data.noteManager:update(dt)
	self.data.liveUI:update(dt)
end

function DEPLS:draw()
	self.data.liveUI:drawHeader()
	love.graphics.setColor(color.white)
	for _, v in ipairs(self.persist.lane) do
		love.graphics.circle("fill", v.x, v.y, 64)
		--love.graphics.circle("line", v.x, v.y, 64)
	end

	self.data.noteManager:draw()
	self.data.liveUI:drawStatus()
end

DEPLS:registerEvent("keypressed", function(_, key)
	if key == "escape" then
		return gamestate.leave(loadingInstance.getInstance())
	end
end)

return DEPLS
