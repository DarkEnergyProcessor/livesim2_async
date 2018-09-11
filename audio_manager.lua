-- Audio management system
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- The audio manager can be tuned either to
-- output the audio directly to OpenAL or
-- manually mixing the audio. Audio manager
-- mix audio automatically in 48000Hz sample
-- rate

local love = require("love")
local ls2x = require("libs.ls2x")
local lily = require("libs.lily")
local cache = require("cache")
local async = require("async")
local util = require("util")
local ffi

local audioManager = {
	renderRate = 0, -- not rendering
	samplesPerFrame = 0,
	tempBuffer = nil,
	playing = {}
}

-- must be called before any audio is loaded or the behaviour is undefined
function audioManager.setRenderFramerate(rate)
	if rate > 0 then
		local smpPerFrame = 48000/rate
		ffi = require("ffi")
		assert(ls2x.audiomix, "audiomix feature is unavailable")
		assert(smpPerFrame % 1 == 0, "cannot use specified framerate (48000 is not divisible by rate)")
		assert(ls2x.audiomix.startSession(0.8, 48000, smpPerFrame), "cannot start session")
		audioManager.tempBuffer = ffi.new("short[?]", smpPerFrame) -- for looping (emulate ringbuffer)
		audioManager.renderRate = rate
		audioManager.samplesPerFrame = smpPerFrame
	elseif rate == 0 and audioManager.renderRate > 0 then
		ls2x.audiomix.endSession()
		audioManager.tempBuffer = nil
		audioManager.renderRate = nil
		audioManager.samplesPerFrame = nil
	end
end

function audioManager.updateRender()
	assert(audioManager.rate > 0, "not in render mode")

	for i = #audioManager.playing, 1, -1 do
		local obj = audioManager.playing[i]

		if obj.pos + audioManager.samplesPerFrame >= obj.size and obj.looping then
			-- use temporary buffer for copying
			local remain = obj.size - obj.pos
			-- copy almost eof buffer
			ffi.copy(audioManager.tempBuffer, obj.soundDataPointer, remain * 4)
			obj.pos = (obj.pos + audioManager.samplesPerFrame) % obj.size
			-- copy start buffer
			ffi.copy(audioManager.tempBuffer + remain * 2, obj.soundDataPointer, obj.pos * 4)
			-- mix
			ls2x.audiomix.mixSample(obj.soundDataPointer + obj.pos, math.min(audioManager.samplesPerFrame, obj.size - obj.pos))
		else
			-- just mix
			ls2x.audiomix.mixSample(obj.soundDataPointer + obj.pos, math.min(audioManager.samplesPerFrame, obj.size - obj.pos))
			obj.pos = math.min(obj.size, obj.pos + audioManager.samplesPerFrame)

			if obj.pos >= obj.size then
				-- stop playback
				obj.pos = 0
				obj.playing = false
				table.remove(audioManager.playing, i)
			end
		end
	end

	-- get buffer
	local sound = love.sound.newSoundData(audioManager.samplesPerFrame, 48000, 16, 2)
	ls2x.audiomix.getSample(ffi.cast("short*", sound:getPointer()))
	return sound
end

function audioManager.newAudio(path)
	if type(path) == "string" then
		local sd = cache.get(path)
		if not(sd) then
			local sdAsync = async.syncLily(lily.newSoundData(path))
			sd = sdAsync:getValues() -- automatically sync
			cache.set(path, sd)
		end

		return audioManager.newAudioDirect(sd)
	else
		return audioManager.newAudioDirect(path)
	end
end

function audioManager.newAudioDirect(data)
	local obj = {
		pos = 0,
		size = 0,
		volume = 0.8,
		playing = false,
		looping = false,
		soundData = nil,
		soundDataPointer = nil,
		originalSoundData = nil,
		source = nil,
	}
	if audioManager.renderRate > 0 then
		-- render mode requires 48000Hz
		if type(data) == "userdata" and not(data:typeOf("SoundData")) then
			local sdAsync = async.syncLily(lily.newSoundData(data))
			data = sdAsync:getValues() -- automatically sync
		end

		-- check sample rate
		if data:getSampleRate() ~= 48000 then
			-- new sound data for resample
			local len = math.ceil(48000 * data:getSampleCount() / data:getSampleRate())
			local data2 = love.sound.newSoundData(len, 48000, 16, util.getChannelCount(data))
			ls2x.audiomix.resample(
				ffi.cast("short*", data:getPointer()),
				ffi.cast("short*", data2:getPointer()),
				data:getSampleCount(), len, util.getChannelCount(data)
			)
			obj.originalSoundData = data
			data = data2
		end

		-- populate object
		obj.size = data:getSampleCount()
		obj.soundData = data
		obj.soundDataPointer = ffi.cast("short*", data:getPointer())
		return obj
	else
		if type(data) == "userdata" and data:typeOf("SoundData") then
			obj.soundData = data
			obj.source = love.audio.newSource(data)
		end
		-- just new source
		obj.source = love.audio.newSource(data, "static")
		return obj
	end
end

function audioManager.clone(obj)
	local x = {
		pos = 0,
		size = obj.size,
		volume = obj.volume,
		playing = false,
		looping = false,
		soundData = obj.soundData,
		soundDataPointer = obj.soundDataPointer,
		originalSoundData = obj.originalSoundData,
		source = obj.source,
	}
	if x.source then x.source = x.source:clone() end

	return x
end

function audioManager.play(obj)
	if audioManager.renderRate > 0 then
		if obj.playing then return end
		audioManager.playing[#audioManager.playing + 1] = obj
		obj.playing = true
	else
		return obj.source:play()
	end
end

function audioManager.pause(obj)
	if audioManager.renderRate > 0 then
		if not(obj.playing) then return end

		for i = 1, #audioManager.playing do
			if audioManager.playing[i] == obj then
				table.remove(audioManager.playing, i)
				obj.playing = false
				return
			end
		end
	else
		return obj.source:pause()
	end
end

function audioManager.stop(obj)
	if audioManager.renderRate > 0 then
		audioManager.pause(obj)
		obj.pos = 0
	else
		return obj.source:stop()
	end
end

function audioManager.isLooping(obj)
	if audioManager.renderRate > 0 then
		return obj.looping
	else
		return obj.source:isLooping()
	end
end

function audioManager.setLooping(obj, loop)
	if audioManager.renderRate > 0 then
		obj.looping = loop
	else
		obj.source:setLooping(loop)
	end
end

function audioManager.isPlaying(obj)
	if audioManager.renderRate > 0 then
		return obj.playing
	else
		return obj.source:isPlaying()
	end
end

function audioManager.setVolume(obj, vol)
	if audioManager.renderRate > 0 then
		obj.volume = vol
	else
		return obj.source:setVolume(vol)
	end
end

function audioManager.seek(obj, seconds)
	if audioManager.renderRate > 0 then
		obj.pos = 48000 * seconds
	else
		return obj.source:seek(seconds, "seconds")
	end
end

return audioManager
