-- BGM management
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local async = require("async")
local lily = require("libs.lily")
local audioManager = require("audio_manager")
local util = require("util")
local Luaoop = require("libs.Luaoop")

local BGM = {}
local BGMClass = Luaoop.class("livesim2.BGM")

function BGMClass:__construct(sd)
	self.audio = audioManager.newAudioDirect(sd)
	self.channel = util.getChannelCount(sd)
end

function BGMClass:play()
	return audioManager.play(self.audio)
end

function BGMClass:pause()
	return audioManager.pause(self.audio)
end

function BGMClass:rewind()
	audioManager.stop(self.audio)
	return audioManager.play(self.audio)
end

-- interleaved samples (lr, lr, lr)
local tempSmp = {}
local tempSmpCount = 0

function BGMClass._getSampleSafe(sd, pos)
	local s, v = pcall(sd.getSample, sd, pos)
	return s and v or 0
end

function BGMClass:_populateSample(sd, pos, amount)
	if self.channel == 1 then
		-- mono
		for i = 1, amount do
			local smp = BGMClass._getSampleSafe(sd, pos)
			tempSmp[i * 2 + 1], tempSmp[i * 2 + 2] = smp, smp
		end
	else
		-- stereo
		for i = 1, amount do
			tempSmp[i * 2 + 1] = BGMClass._getSampleSafe(sd, pos * 2)
			tempSmp[i * 2 + 2] = BGMClass._getSampleSafe(sd, pos * 2 + 1)
		end
	end
end

function BGMClass:_getSamplesRender(amount)
	-- Use original sound data
	local sd, pos
	if self.audio.originalSoundData then
		-- Do position conversion
		sd = self.audio.originalSoundData
		pos = math.floor(sd:getSampleRate() * self.audio.pos / 48000 + 0.5)
	else
		sd = self.audio.soundData
		pos = self.audio.pos
	end

	return self:_populateSample(sd, pos, amount)
end

function BGMClass:getSamples(amount)
	if audioManager.renderRate > 0 then
		self:_getSamplesRender(amount)
	else
		self:_populateSample(self.audio.soundData, self.audio.source:tell("samples"), amount)
	end

	-- cleanup rest
	for i = (amount*2)+1, tempSmpCount*2 do
		tempSmp[i] = nil
	end
	tempSmpCount = amount

	return tempSmp
end

function BGMClass:seek(timepos)
	return audioManager.seek(self.audio, timepos)
end

function BGMClass:tell()
	if audioManager.renderRate > 0 then
		return self.audio.pos / 48000
	else
		return self.audio.source:tell()
	end
end

function BGM.newSong(decoder)
	local sync = async.syncLily(lily.newSoundData(decoder))
	return BGMClass(sync:getValues())
end

return BGM
