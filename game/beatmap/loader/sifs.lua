-- SIFs beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- TODO: support for new format https://twitter.com/yuyu0127_/status/823520047582748673

local love = require("love")
local Luaoop = require("libs.Luaoop")
local util = require("util")
local setting = require("setting")
local md5 = require("game.md5")
local baseLoader = require("game.beatmap.base")

local function sifsFetchNumber(iterator, name)
	return tonumber(iterator():match(string.format("^%s = (%%-?%%d+);", name)))
end

-------------------------
-- SIFs beatmap loader --
-------------------------

local sifsLoader = Luaoop.class("beatmap.SIFs", baseLoader)

function sifsLoader:__construct(file)
	local internal = Luaoop.class.data(self)
	internal.hash = md5(love.filesystem.newFileData(file))
	file:seek(0)

	local lines = file:lines()
	internal.bpm = sifsFetchNumber(lines, "BPM") or 120
	internal.offset = (sifsFetchNumber(lines, "OFFSET") or 0) * 1250 / internal.bpm
	lines()
	internal.attribute = (sifsFetchNumber(lines, "ATTRIBUTE") or 2) + 1
	internal.difficulty = assert(sifsFetchNumber(lines, "DIFFICULTY"))
	internal.audioFile = assert(util.basename(lines():match("^MUSIC = GetCurrentScriptDirectory~\"([^\"]+)\";")))
	lines()
	internal.coverImage = assert(util.basename(lines():match("^imgJacket = \"([^\"]+)\";")))
	internal.title = assert(lines():match("^TITLE = \"([^\"]+)\";"))
	internal.comment = assert(lines():match("^COMMENT = \"([^\"]+)\";"))
	lines()
	internal.beatmapData = lines()
end

function sifsLoader.getFormatName()
	return "SIFs Beatmap", "sifs"
end

function sifsLoader:getHash()
	return Luaoop.class.data(self).hash
end

function sifsLoader:getNotesList()
	local internal = Luaoop.class.data(self)
	local notesData = {}
	local speedMultipler = 1
	local stopTimeCount = 0
	local noteSpeed = setting.get("NOTE_SPEED") * 0.001
	local lastTimingSec = 0
	local lastTick = 0
	local attribute = internal.attribute

	for a, b, c in internal.beatmap_data:gmatch("([^,]+),([^,]+),([^,]+)") do
		a, b, c = assert(tonumber(a)) + stopTimeCount - lastTick, assert(tonumber(b)), assert(tonumber(c))

		if b == 10 then
			-- BPM change
			lastTimingSec = (a * 1250 / internal.bpm + lastTimingSec)
			lastTick = a
			internal.bpm = c
		elseif b == 18 then
			-- Note attribute change
			attribute = math.min(c + 1, 11)
		elseif b == 19 then
			-- Add stop time
			stopTimeCount = stopTimeCount + c
		elseif b == 20 then
			-- Note speed change
			-- We didn't support negative values, so check for it
			speedMultipler = c > 0 and c or 1
		elseif b < 10 then
			local effect = 1
			local effect_value = 2
			local c_abs = math.abs(c)

			if c == 2 or c == 3 then
				effect = 4
			elseif c_abs >= 4 then
				effect = 3
				effect_value = c_abs * 1.25 / internal.bpm
			end

			notesData[#notesData + 1] = {
				timing_sec = (a * 1250 / internal.bpm - internal.offset + lastTimingSec) * 0.001,
				notes_attribute = attribute,
				notes_level = 1,
				effect = effect,
				effect_value = effect_value,
				speed = noteSpeed / speedMultipler,
				position = 10 - b
			}
		end
	end

	return notesData
end

function sifsLoader:getName()
	return Luaoop.class.data(self).title
end

function sifsLoader:getCoverArt()
	local internal = Luaoop.class.data(self)
	local path = "live_icon/"..internal.cover_image

	if util.fileExists(path) then
		return {
			title = internal.title,
			info = internal.comment,
			image = love.image.newImageData(path)
		}
	end

	return nil
end

function sifsLoader:getAudioPathList()
	return {"audio/"..Luaoop.class.data(self).audio_file}
end

function sifsLoader:getStarDifficultyInfo()
	return Luaoop.class.data(self).difficulty
end

return sifsLoader, "file"
