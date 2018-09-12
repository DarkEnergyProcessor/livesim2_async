-- Custom Beatmap Festival Beatmap Loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local love = require("love")
local bit = require("bit")
local util = require("util")
local log = require("logging")
local setting = require("setting")
local baseLoader = require("game.beatmap.base")

local positionTranslate = {L4 = 9, L3 = 8, L2 = 7, L1 = 6, C = 5, R1 = 4, R2 = 3, R3 = 2, R4 = 1}

------------------------
-- CBF Beatmap Loader --
------------------------

local cbfLoader = Luaoop.class("beatmap.CBF", baseLoader)

function cbfLoader:__construct(path)
	local internal = cbfLoader^self

	if util.fileExists(path.."projectConfig.txt") and util.fileExists(path.."beatmap.txt") then
		-- load conf
		local conf = {}
		for key, value in love.filesystem.read(path.."projectConfig.txt"):gmatch("%[([^%]]+)%];([^;]+);") do
			conf[key] = tonumber(value) or value
		end

		internal.config = conf
		internal.path = path
	else
		error("directory is not CBF project")
	end
end

function cbfLoader.getFormatName()
	return "Custom Beatmap Festival", "cbf"
end

local function parseNote(str)
	local values = {}
	local curidx = 1
	local nextidx = str:find("/", 1, true)

	while nextidx do
		values[#values + 1] = str:sub(curidx, nextidx - 1)
		curidx = nextidx + 1
		nextidx = str:find("/", curidx, true)
	end

	local lastval = str:sub(curidx)
	if lastval:sub(-1) == ";" then
		lastval = lastval:sub(1, -2)
	end
	values[#values + 1] = lastval

	return unpack(values)
end

function cbfLoader:getNotesList()
	local internal = cbfLoader^self
	local notesData = {}
	local attribute

	if internal.config.SONG_ATTRIBUTE == "Smile" then
		attribute = 1
	elseif internal.config.SONG_ATTRIBUTE == "Pure" then
		attribute = 2
	elseif internal.config.SONG_ATTRIBUTE == "Cool" then
		attribute = 3
	else
		attribute = setting.get("LLP_SIFT_DEFATTR")
	end

	local readNotesData = {}
	local lineCount = 1
	for line in love.filesystem.lines(internal.path.."beatmap.txt") do
		if #line > 0 then
			readNotesData[#readNotesData + 1] = line
		else
			log.warning("noteloader.cbf", string.format("empty line at line %d ignored", lineCount))
		end

		lineCount = lineCount + 1
	end

	-- sort first
	table.sort(readNotesData, function(a, b)
		return tonumber(a:match("([^/]+)/")) < tonumber(b:match("([^/]+)/"))
	end)

	-- parse (very confusing code)
	local holdNoteQueue = {}
	for _, line in ipairs(readNotesData) do
		local time, pos, _, isHold, isRel, _, _, isStar, colInfo = parseNote(line)
		local r, g, b, isCustomcol = colInfo:match("([^,]+),([^,]+),([^,]+),([True|False]+)")

		if time and pos and isHold and isRel and isStar and r and g and b and isCustomcol then
			local numPos = positionTranslate[pos]
			local attr = attribute
			time = tonumber(time)

			if isCustomcol == "True" then
				-- CBF extension attribute as explained in livesim2 beatmap spec
				attr = bit.bor(
					bit.bor(
						bit.lshift(math.floor(tonumber(r) * 255), 23),
						bit.lshift(math.floor(tonumber(g) * 255), 14)
					),
					bit.bor(bit.lshift(math.floor(tonumber(b) * 255), 5), 31)
				)
			end

			if isRel == "True" then
				local last = assert(holdNoteQueue[numPos], "unbalanced release note")
				last.effect_value = time - last.timing_sec
				holdNoteQueue[numPos] = nil
			elseif isHold == "True" then
				local val = {
					timing_sec = time,
					notes_attribute = attr,
					notes_level = 1,
					effect = 3,
					effect_value = 0,
					position = numPos
				}

				assert(holdNoteQueue[numPos] == nil, "overlapped hold note")
				holdNoteQueue[numPos] = val
				notesData[#notesData + 1] = val
			else
				notesData[#notesData + 1] = {
					timing_sec = time,
					notes_attribute = attr,
					notes_level = 1,
					effect = isStar == "True" and 4 or 1,
					effect_value = 2,
					position = numPos
				}
			end
		else
			log.warning("noteloader.cbf", "ignored: "..line)
		end
	end

	-- sort again
	table.sort(notesData, function(a, b) return a.timing_sec < b.timing_sec end)
	return notesData
end

function cbfLoader:getName()
	local internal = cbfLoader^self
	return tostring(internal.config.SONG_NAME)
end

local supportedImages = {".png", ".jpg", ".jpeg", ".bmp"}
function cbfLoader:getCoverArt()
	local internal = cbfLoader^self
	local file = util.substituteExtension(internal.path.."cover", supportedImages)

	if file then
		return {
			title = tostring(internal.config.SONG_NAME),
			info = internal.config.COVER_COMMENT,
			image = love.filesystem.newFileData(file)
		}
	end

	return nil
end

function cbfLoader:getDifficultyString()
	local internal = cbfLoader^self
	return internal.config.DIFFICULTY_TEMPLATE
end

function cbfLoader:getAudioPathList()
	local internal = cbfLoader^self
	return {internal.path.."songFile"}
end

return cbfLoader, "folder"
