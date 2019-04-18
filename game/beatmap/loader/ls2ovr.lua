-- Live Simulator: 2 "Over the Rainbow" beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua


local love = require("love")
local Luaoop = require("libs.Luaoop")
local nbt = require("libs.nbt")
local util = require("util")
local log = require("logging")
local md5 = require("game.md5")
local baseLoader = require("game.beatmap.base")

local function readDword(f)
	local a, b, c, d
	if type(f) == "string" then
		a, b, c, d = f:byte(1, 4)
	else
		a, b, c, d = (f:read(4) or ""):byte(1, 4)
	end

	assert(a and b and c and d, "unexpected eof")

	if a >= 128 then
		a, b, c, d = a - 255, b - 255, c - 255, d - 256
	end

	return a * 16777216 + b * 65536 + c * 256 + d
end

local function readWord(f)
	local a, b
	if type(f) == "string" then
		a, b = f:byte(1, 2)
	else
		a, b = (f:read(2) or ""):byte(1, 2)
	end

	assert(a and b, "unexpected eof")

	if a >= 128 then
		a, b = a - 255, b - 256
	end

	return a * 256 + b
end

local function readByte(f)
	local a = (type(f) == "string" and f or (f:read(1) or "")):byte()
	if not(a) then
		error("unexpected eof")
	elseif a >= 128 then
		return a - 255
	else
		return a
	end
end

-----------------------
-- LS2OVR base class --
-----------------------

local ls2ovrLoader = Luaoop.class("beatmap.LS2OVRBase", baseLoader)

function ls2ovrLoader:__construct(metadata, beatmapData, hashList, additionalFile)
	local internal = Luaoop.class.data(self)

	internal.metadata = metadata
	internal.hash = hashList
	internal.fileDatabase = additionalFile
	internal.beatmapData = beatmapData
	-- TODO: field check
end

function ls2ovrLoader.getFormatName()
	return "Live Simulator: 2 v4.0 Beatmap", "ls2ovr"
end

function ls2ovrLoader:getHash()
	return md5(Luaoop.class.data(self).hash)
end

function ls2ovrLoader:getNotesList()
	local beatmapData = Luaoop.class.data(self).beatmapData
	local notes = {}

	for i, v in ipairs(beatmapData.map) do
		-- Ignore beatmap if either one of these is met:
		-- 1. Missing 1 or more required fields
		if not(v.time) or not(v.position) or not(v.attribute) or not(v.flags) then
			log.errorf("noteloader.LS2OVR", "map index %d missing required fields", i)
		-- 2. The "time" field is negative, +/-infinity, or NaN.
		elseif v.time <= 0 or v.time ~= v.time or v.time == math.huge then
			log.errorf("noteloader.LS2OVR", "map index %d has invalid time", i)
		-- 3. Having "position" field outside of the range.
		elseif v.position < 1 or v.position > 9 then
			log.errorf("noteloader.LS2OVR", "map index %d note position out of range", i)
		else
			local mode = v.flags % 4
			local isSwingNote = math.floor(v.flags / 4) % 2 == 1

			-- 4. Missing "noteGroup" field but "s" bit in "flags" is set.
			-- 5. The "noteGroup" field is 0 or less.
			if isSwingNote and (not(v.noteGroup) or v.noteGroup <= 0) then
				log.errorf("noteloader.LS2OVR", "map index %d is swing note but has invalid note group", i)
			-- 6. Missing "length" field but "t" value in "flags" is 3.
			-- 7. The "length" field is negative, +/-infinity, or NaN.
			elseif mode == 3 and (not(v.length) or v.length ~= v.length or v.length <= 0 or v.length == math.huge) then
				log.errorf("noteloader.LS2OVR", "map index %d is long note but has invalid note length", i)
			else
				-- Process attribute
				local attribute = v.attribute % 2147483648

				if attribute % 16 == 15 then
					-- Custom color attribute. Live Simulator: 2 expect bit pattern
					-- rrrrrrrr rggggggg ggbbbbbb bbb01111 but LS2OVR uses
					-- bit pattern 0rrrrrrr rrgggggg gggbbbbb bbbbssss.
					attribute = attribute % 16 + math.floor(attribute / 16) * 32
				end

				-- Process effect value
				local effect, effectValue = isSwingNote and 10 or 0, 2

				if mode == 0 then
					-- Normal note.
					effect = effect + 1
				elseif mode == 1 then
					-- Token note.
					effect = effect + 2
				elseif mode == 2 then
					-- Star note. Swing and star note can't co-exist together
					-- so ignore swing note
					effect = 4
				elseif mode == 2 then
					-- Long note.
					effect = effect + 3
					effectValue = v.length
				end

				notes[#notes + 1] = {
					timing_sec = v.time,
					notes_attribute = attribute,
					notes_level = isSwingNote and v.noteGroup or 0,
					effect = effect,
					effect_value = effectValue,
					position = v.position
				}
			end
		end
	end

	return notes
end

function ls2ovrLoader:getName()
	return Luaoop.class.data(self).metadata.title
end

function ls2ovrLoader:getCustomUnitInformation()
	local internal = Luaoop.class.data(self)
	local customUnits = {}

	if internal.beatmapData.customUnitList then
		local cache = {}

		for _, v in ipairs(internal.beatmapData.customUnitList) do
			if v.position > 0 and v.position < 10 and internal.fileDatabase[v.filename] then
				local x = cache[v.filename]
				if not(x) then
					local s
					s, x = pcall(love.image.newImageData, internal.fileDatabase[v.filename])
					if s then
						cache[v.filename] = x
					else
						x = nil
					end
				end

				if x then
					customUnits[v.position] = x
				end
			end
		end
	end

	return customUnits
end

function ls2ovrLoader:getDifficultyString()
	local internal = Luaoop.class.data(self)

	if internal.beatmapData.difficultyName then
		return internal.beatmapData.difficultyName
	else
		return baseLoader.getDifficultyString(self)
	end
end

function ls2ovrLoader:getAudio()
	local internal = Luaoop.class.data(self)

	if internal.metadata.audio then
		return internal.fileDatabase[internal.metadata.audio]
	end

	return nil
end

function ls2ovrLoader:getCoverArt()
	local internal = Luaoop.class.data(self)

	if internal.metadata.artwork and internal.fileDatabase[internal.metadata.artwork] then
		local s, imagedata = pcall(love.image.newImageData, internal.fileDatabase[internal.metadata.artwork])

		if s then
			local descriptionString = nil

			if internal.metadata.composers and #internal.metadata.composers > 0 then
				local strb = {}

				for i, v in ipairs(internal.metadata.composers) do
					strb[i] = string.format("%s: %s", v.role, v.name)
				end

				descriptionString = table.concat(strb, "  ")
			end

			return {
				title = internal.metadata.title,
				info = descriptionString,
				image = imagedata
			}
		end
	end

	return nil
end

function ls2ovrLoader:_getScoreOrComboInformation(type)
	local internal = Luaoop.class.data(self)

	if internal.beatmapData[type] and #internal.beatmapData[type] >= 4 then
		local list = {}

		for i = 1, 4 do
			local v = internal.beatmapData[type]

			if v > 0 then
				if i >= 2 then
					if v > list[i - 1] then
						list[i] = v
					else
						-- Last value is bigger. Discard everything
						return nil
					end
				else
					list[i] = v
				end
			else
				-- Invalid value passed. Discard everything
				return nil
			end
		end
	end
end

function ls2ovrLoader:getScoreInformation()
	return self:_getScoreOrComboInformation("scoreInfo")
end

function ls2ovrLoader:getComboInformation()
	return self:_getScoreOrComboInformation("comboInfo")
end

function ls2ovrLoader:getStoryboardData()
	local internal = Luaoop.class.data(self)
	local storyData, storyType

	if internal.fileDatabase["storyboard.yml.gz"] then
		-- gzip compressed storyboard data
		storyData = util.decompressToString(internal.fileDatabase["storyboard.yml.gz"], "gzip")
		storyType = "yaml"
	elseif internal.fileDatabase["storyboard.yml"] then
		-- uncompressed storyboard data
		storyData = internal.fileDatabase["storyboard.yml.gz"]:getString()
		storyType = "yaml"
	end
	-- TODO: support more storyboard formats by Lovewing?

	if not(storyData) then
		return nil
	elseif storyType == "yaml" then
		storyData = storyData:gsub("\r\n", "\n")
	end

	return {
		type = storyType,
		storyboard = storyData,
		data = internal.fileDatabase
	}
end

function ls2ovrLoader:getBackground()
	local internal = Luaoop.class.data(self)
	local bgtype = type(internal.beatmapData.background)

	if bgtype == "table" then
		local bglist = internal.beatmapData.background
		-- {mode, ...}
		-- where mode are bitwise:
		-- 1. main background only (index 2)
		-- 2. has left right background (index 3 and 4)
		-- 4. has top bottom background (index 5 and 6)
		-- If main background (bit 0) is false, then index 2 is assumed
		-- to be number.
		local mode = {1, nil, nil, nil, nil, nil}

		if bglist.main and internal.fileDatabase[bglist.main] then
			local s, tempIData = pcall(love.image.newImageData, internal.fileDatabase[bglist.main])

			if s then
				local isCombinationOK = false
				mode[2] = tempIData

				-- Left and right background
				if
					bglist.left and bglist.right and
					internal.fileDatabase[bglist.left] and
					internal.fileDatabase[bglist.right]
				then
					s, tempIData = pcall(love.image.newImageData, internal.fileDatabase[bglist.left])

					if s then
						mode[3] = tempIData
						s, tempIData = pcall(love.image.newImageData, internal.fileDatabase[bglist.right])

						if s then
							mode[1] = mode[1] + 2
							isCombinationOK = true
							mode[4] = tempIData
						end
					end
				end

				if not(isCombinationOK) then
					mode[3], mode[4] = nil, nil
				else
					isCombinationOK = false
				end

				-- Top and bottom background
				if
					bglist.top and bglist.bottom and
					internal.fileDatabase[bglist.top] and
					internal.fileDatabase[bglist.bottom]
				then
					s, tempIData = pcall(love.image.newImageData, internal.fileDatabase[bglist.top])

					if s then
						mode[5] = tempIData
						s, tempIData = pcall(love.image.newImageData, internal.fileDatabase[bglist.bottom])

						if s then
							mode[1] = mode[1] + 4
							isCombinationOK = true
							mode[6] = tempIData
						end
					end
				end

				if not(isCombinationOK) then
					mode[5], mode[6] = nil, nil
				end

				return mode
			end
		end
	elseif bgtype == "string" then
		local bg = internal.beatmapData.background
		if bg:sub(1, 1) == ":" then
			return tonumber(bg:sub(2)) or 0
		elseif internal.fileDatabase[bg] then
			local s, id = pcall(love.image.newImageData, bg)

			if s then
				return {1, id}
			end
		end
	end

	return 0
end

function ls2ovrLoader:getScorePerTap()
	return Luaoop.class.data(self).beatmapData.baseScorePerTap or 0
end

function ls2ovrLoader:getStamina()
	return Luaoop.class.data(self).beatmapData.stamina or 0
end

function ls2ovrLoader:getStarDifficultyInfo()
	local internal = Luaoop.class.data(self)
	return internal.beatmapData.star, internal.beatmapData.starRandom
end

function ls2ovrLoader:getLyrics()
	local internal = Luaoop.class.data(self)

	if internal.fileDatabase["lyrics.srt.gz"] then
		return util.decompressToData(internal.fileDatabase["lyrics.srt.gz"], "gzip")
	elseif internal.fileDatabase["lyrics.srt"] then
		return internal.fileDatabase["lyrics.srt"]
	else
		return nil
	end
end

return function(file)
	-- Read signature
	assert(file:read(8) == "livesim3", "invalid LS2OVR beatmap file")

	-- Read format version
	local format = readDword(file)
	assert(format % 2147483648 ~= format, "file must be transfered with 8-bit transmission")
	assert(format == -2147483648, "file format is too new")

	-- Detect EOL conversion
	assert(file:read(4) == "\26\10\13\10", "unexpected EOL translation detected")

	-- Read metadata
	local metadataNBTLen = readDword(file)
	assert(metadataNBTLen > 0, "invalid metadata length")
	local metadataNBT = file:read(metadataNBTLen)
	local metadataMD5 = file:read(16)
	assert(md5(metadataNBT) == metadataMD5, "MD5 metadata mismatch")
	local metadata = nbt.decode(metadataNBT, "plain")

	-- Read beatmap data
	local compressionType = readByte(file)
	local compressedSize = readDword(file)
	local uncompressedSize = readDword(file)
	local beatmapDataString

	if compressionType == 0 then
		assert(compressedSize == uncompressedSize, "beatmap data size mismatch")
		beatmapDataString = file:read(uncompressedSize)
	elseif compressionType == 1 then
		beatmapDataString = util.decompressToString(file:read(compressedSize), "gzip")
	elseif compressionType == 2 then
		beatmapDataString = util.decompressToString(file:read(compressedSize), "zlib")
	else
		error("unsupported compression mode")
	end

	local beatmapList = {}
	local beatmapStr = beatmapDataString
	local beatmapAmount = readByte(beatmapStr) beatmapStr = beatmapStr:sub(2)
	assert(beatmapAmount > 0, "no beatmaps inside file")

	for i = 1, beatmapAmount do
		local currentBeatmapSize = readDword(beatmapStr) beatmapStr = beatmapStr:sub(5)
		local beatmapData = beatmapStr:sub(1, currentBeatmapSize)
		beatmapStr = beatmapStr:sub(currentBeatmapSize + 1)
		local hash = beatmapStr:sub(1, 16)
		if md5(beatmapStr) == hash then
			-- insert to beatmap list
			beatmapList[#beatmapList + 1] = {
				data = nbt.decode(beatmapData, "plain"),
				hash = hash
			}
		else
			log.errorf("noteloader.LS2OVR", "beatmap index #%d has invalid MD5 hash", i)
		end
	end

	local additionalDataSize = readDword(file)
	local additionalDataInfo = nbt.decode(file:read(additionalDataSize), "plain")
	local additionalData = {}

	-- Check EOF
	assert(file:read(8) == "overrnbw", "EOF marker not found")

	for _, v in ipairs(additionalDataInfo) do
		if v.offset > 0 then
			if v.offset % 16 == 0 then
				file:seek(v.offset)
				local x = love.filesystem.newFileData(file:read(v.size), v.name)
				additionalData[v.name] = x
				additionalData[#additionalData + 1] = x
			else
				log.errorf("noteloader.LS2OVR", "file '%s' is not aligned in 16-byte boundary", v.name)
			end
		else
			log.errorf("noteloader.LS2OVR", "file '%s' has invalid size", v.name)
		end
	end

	if #beatmapList == 1 then
		return ls2ovrLoader(metadata, beatmapList[1].data, metadataMD5..beatmapList[1].hash, additionalData)
	else
		local ret = {}

		for i = 1, #beatmapList do
			local v = beatmapList[i]
			ret[i] = ls2ovrLoader(metadata, v.data, metadataMD5..v.hash, additionalData)
		end

		return ret
	end
end, "file"
