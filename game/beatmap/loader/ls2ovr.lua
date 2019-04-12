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

local function readLS2OVR(file)
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
				data = beatmapData,
				hash = hash
			}
		else
			log.errorf("noteloader.LS2OVR", "beatmap index #%d has invalid MD5 hash", i)
		end
	end

	local additionalDataSize = readDword(file)
	local additionalDataInfo = nbt.decode(file:read(additionalDataSize), "plain")
	local additionalData = {}

	for _, v in ipairs(additionalDataInfo) do
		if v.offset > 0 then
			if v.offset % 16 == 0 then
				file:seek(v.offset)
				additionalData[v.name] = love.filesystem.newFileData(file:read(v.size), v.name)
			else
				log.errorf("noteloader.LS2OVR", "file '%s' is not aligned in 16-byte boundary", v.name)
			end
		else
			log.errorf("noteloader.LS2OVR", "file '%s' has invalid size", v.name)
		end
	end

	-- TODO: load all difficulty
end
