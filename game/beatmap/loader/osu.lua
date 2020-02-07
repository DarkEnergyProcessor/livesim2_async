-- osu!mania beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- References:
-- https://osu.ppy.sh/help/wiki/osu!_File_Formats/Osu_(file_format)

-- FIXME: Convert osu! beatmap to 9K osu!mania
-- https://github.com/ppy/osu/blob/master/osu.Game.Rulesets.Mania/Beatmaps/ManiaBeatmapConverter.cs

local love = require("love")
local bit = require("bit")
local Luaoop = require("libs.Luaoop")
local log = require("logging")
local setting = require("setting")
local util = require("util")
local md5 = require("game.md5")
local baseLoader = require("game.beatmap.base")

local osuLoader = Luaoop.class("beatmap.osu", baseLoader)

-- Too lazy to calculate the position
local positionMapping = setmetatable({
	{5},
	{6, 4},
	{6, 5, 4},
	{7, 6, 4, 3},
	{7, 6, 5, 4, 3},
	{8, 7, 6, 4, 3, 2},
	{8, 7, 6, 5, 4, 3, 2},
	{9, 8, 7, 6, 4, 3, 2, 1},
	{9, 8, 7, 6, 5, 4, 3, 2, 1}
}, {__index = function(_, i) error("unknown "..i.."K keys") end})

local function readLine(linef)
	local line
	repeat
		line = linef()
		if line then
			line = line:gsub("\r\n", ""):gsub("\r", ""):gsub("\n", "")
		end
	until line == nil or (#line > 0 and line:find("//", 1, true) ~= 1)

	return line
end

local function readKVSection(lines, dest, pattern)
	local line

	while true do
		line = assert(readLine(lines), "unexpected EOF")

		-- If there's [ at beginning, stop.
		if line:find("[", 1, true) == 1 then
			break
		end

		local key, value = line:match(pattern)
		dest[key] = tonumber(value) or value
	end

	return line
end

function osuLoader:__construct(f)
	local internal = Luaoop.class.data(self)
	local lines = f:lines()

	-- Format check
	assert(lines():gsub("\239\187\191", ""):find("osu file format", 1, true) == 1, "not osu beatmap file")
	local line = readLine(lines)

	-- [General] section
	assert(line == "[General]", "missing [General] section")
	local generalInfo = {}
	internal.general = generalInfo
	line = readKVSection(lines, generalInfo, "(%w+): (.+)")

	-- Check beatmap type
	if generalInfo.Mode == 1 then
		error("beatmap is osu!taiko")
	elseif generalInfo.Mode == 2 then
		error("beatmap is osu!catch")
	-- FIXME: Convert osu! beatmap to 9K osu!mania
	-- Once it's done, remove this check
	elseif generalInfo.Mode == 0 then
		error("osu!standard beatmap is currently unimplemented")
	end

	-- If there's [Editor] section, skip
	if line == "[Editor]" then
		repeat
			line = assert(readLine(lines), "unexpected EOF")
		until line:find("[", 1, true) == 1
	end

	-- [Metadata] section
	assert(line == "[Metadata]", "missing [Metadata] section")
	local metadataInfo = {}
	internal.metadata = metadataInfo
	line = readKVSection(lines, metadataInfo, "(%w+):(.+)")

	-- [Difficulty] section
	assert(line == "[Difficulty]", "missing [Difficulty] section")
	local diffInfo = {}
	internal.difficulty = diffInfo
	line = readKVSection(lines, diffInfo, "(%w+):(.+)")

	-- [Events] section
	assert(line == "[Events]", "missing [Events] section")
	internal.storyboardLine = {}
	while true do
		line = assert(readLine(lines), "unexpected EOF")

		-- If there's [ at beginning, stop.
		if line:find("[", 1, true) == 1 then
			break
		end

		if line:find("0,0,", 1, true) == 1 then
			-- Background
			local path = line:match("^0,0,(%b\"\")")
			if path == nil then
				local splitted = util.split(line, ",")
				path = assert(splitted[3], "background path not found")
			else
				path = path:sub(2, -2)
			end

			internal.background = path
		elseif line:find("1,") == 1 or line:find("Video,") == 1 then
			-- Video
			local path = line:match(",0,(%b\"\")")
			if path == nil then
				local splitted = util.split(line, ",")
				path = assert(splitted[3], "video path not found")
			else
				path = path:sub(2, -2)
			end

			internal.video = path
		elseif line:find("2,") ~= 1 and line:find("Break,") ~= 1 then
			-- Assume it's part of storyboard data
			internal.storyboardLine[#internal.storyboardLine + 1] = line
		end
	end

	-- If there's [TimingPoints] section, skip
	if line == "[TimingPoints]" then
		repeat
			line = assert(readLine(lines), "unexpected EOF")
		until line:find("[", 1, true) == 1
	end

	-- If there's [Colours] section, skip
	if line == "[Colours]" then
		repeat
			line = assert(readLine(lines), "unexpected EOF")
		until line:find("[", 1, true) == 1
	end

	-- [HitObjects] section
	assert(line == "[HitObjects]", "missing [HitObjects] section")
	local hitObjects = {}
	internal.beatmapData = hitObjects
	while true do
		line = readLine(lines)

		if line == nil or line:find("[", 1, true) == 1 then
			break
		end

		hitObjects[#hitObjects + 1] = line
	end
end

function osuLoader.getFormatName()
	-- FIXME: Change readable name once beatmap conversion code is complete
	return "osu!mania beatmap", "osu"
end

function osuLoader:getHash()
	return md5(table.concat(Luaoop.class.data(self).beatmapData))
end

function osuLoader:getNotesList()
	local internal = Luaoop.class.data(self)
	local beatmap = {}
	local offset = -(internal.general.AudioLeanIn or 0)
	local nkeys = internal.difficulty.CircleSize
	local attribute = setting.get("LLP_SIFT_DEFATTR")

	if internal.general.Mode == 3 then
		-- Beatmap is osu!mania, only need to convert representation
		for _, v in ipairs(internal.beatmapData) do
			local hitObject = util.split(v, ",")

			local positionMania = util.clamp(math.floor(assert(tonumber(hitObject[1])) * nkeys / 512), 0, nkeys - 1)
			local position = assert(positionMapping[nkeys][positionMania + 1])
			local objectType = assert(tonumber(hitObject[4]), "invalid object type")

			if bit.band(objectType, 0xA) == 0 then
				local isHold = bit.band(objectType, 0x80) > 0

				if isHold then
					local startTime = hitObject[3] + offset
					local endTime = hitObject[6]:sub(1, hitObject[6]:find(":", 1, true) - 1) + offset

					-- Long note
					beatmap[#beatmap + 1] = {
						timing_sec = startTime / 1000,
						notes_attribute = attribute,
						notes_level = 1,
						effect = 3,
						effect_value = (endTime - startTime) / 1000,
						position = position
					}
				else
					-- Normal note
					beatmap[#beatmap + 1] = {
						timing_sec = (hitObject[3] + offset) / 1000,
						notes_attribute = attribute,
						notes_level = 1,
						effect = 0,
						effect_value = 2,
						position = position
					}
				end
			end
		end
	elseif internal.general.Mode == 0 then
		error("FIXME")
	end

	return beatmap
end

function osuLoader:getDifficultyString()
	return Luaoop.class.data(self).metadata.Version
end

function osuLoader:getAudioPathList()
	-- FIXME: Provided filename is too generic.
	local internal = Luaoop.class.data(self)
	local file = util.stringToHex(md5(internal.metadata.Artist..internal.metadata.Title..internal.general.AudioFilename))

	log.debugf(
		"noteloader.osu", "%s - %s (%s) = %s",
		internal.metadata.Artist,
		internal.metadata.Title,
		internal.general.AudioFilename,
		file
	)
	return {"audio/"..file}
end

function osuLoader:getName()
	return Luaoop.class.data(self).metadata.Title
end

return osuLoader, "file"
