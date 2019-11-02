-- LS2OVR beatmap parsing
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local nbt = require("libs.nbt")

local log = require("logging")
local util = require("util")

local md5 = require("game.md5")

local beatmapData = require("game.ls2ovr.beatmap_data")

local TARGET_VERSION = 0

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

local beatmap = Luaoop.class("LS2OVR.Beatmap")

function beatmap.load(file)
	-- Read signature
	assert(file:read(8) == "livesim3", "invalid LS2OVR beatmap file")

	-- Read format version
	local format = readDword(file)
	local version = format % 2147483648
	assert(version ~= format, "file must be transfered with 8-bit transmission")
	assert(version >= TARGET_VERSION, "file format is too new")

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
		beatmapStr = beatmapStr:sub(17)
		if md5(beatmapData) == hash then
			-- insert to beatmap list
			beatmapList[#beatmapList + 1] = {
				data = beatmapData(nbt.decode(beatmapData, "plain")),
				hash = hash
			}
		else
			log.errorf("LS2OVR", "beatmap index #%d has invalid MD5 hash", i)
		end
	end

	-- TODO: Complete
end

return beatmap
