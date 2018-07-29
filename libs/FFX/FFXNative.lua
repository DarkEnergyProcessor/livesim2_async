-- FFmpeg video extension loader, using LVEP
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- Unlike FFX2, this one is not standalone.
local AquaShine = ...
local love = require("love")
local lvep = require("lvep")
local FFXNative = {Native = true}

function FFXNative.LoadVideo(path)
	return love.graphics.newVideo(lvep.newVideoStream(path), {audio = false})
end

-- Actually loads to SoundData!
function FFXNative.LoadAudio(path)
	return love.sound.newSoundData(lvep.newDecoder(path))
end

function FFXNative.LoadAudioDecoder(path)
	return lvep.newDecoder(path)
end

function FFXNative.Update() end

AquaShine.FFmpegExt = FFXNative
