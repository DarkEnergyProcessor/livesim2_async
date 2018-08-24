-- Beatmap processing thread
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
love._version = love._version or love.getVersion()
require("love.event")
require("love.system")
require("love.image")
require("love.filesystem")

local util = require("util")

local commandChannel = ...
local beatmap = {
	fileLoader = {},
	folderLoader = {},
	list = {},
}
package.loaded.beatmap = beatmap

-- LOVE 0.10.2 backward compatibility
-- Thread has JIT enabled by default. Disable if needed.
if jit and (love._os == "Android" or love._os == "iOS") then
	jit.off()
end

if love._version >= "11.0" then
	function love.filesystem.isDirectory(filename)
		return not(not(love.filesystem.getInfo(filename, "directory")))
	end
end

local function sendBeatmapData(name, id, ...)
	return love.event.push("beatmapresponse", name, id, ...)
end

-- Beatmap-related code
function beatmap.findSuitableForFile(filename)
	local file, msg = love.filesystem.newFile(filename, "r")
	if not(file) then
		return nil, msg
	end

	for i = 1, #beatmap.fileLoader do
		file:seek(0)
		local status, value = pcall(beatmap.fileLoader[i], file)

		if status then
			return value
		else
			love.event.push("print", string.format("%s: %s", filename, value))
		end
	end

	return nil, "no file-based beatmap loader"
end

function beatmap.findSuitableForFolder(dir)
	for i = 1, #beatmap.fileLoader do
		local status, value = pcall(beatmap.folderLoader[i], dir)

		if status then
			return value
		else
			love.event.push("print", string.format("%s: %s", dir, value))
		end
	end

	return nil, "no folder-based beatmap loader"
end

function beatmap.findSuitable(path)
	if love.filesystem.isDirectory(path) then
		return beatmap.findSuitableForFolder(path), "folder"
	else
		return beatmap.findSuitableForFile(path), "file"
	end
end

----------------------------------
-- Main function past this line --
----------------------------------

local function enumerateBeatmap(id)
	local list = love.filesystem.getDirectoryItems("beatmap/")

	for i = 1, #list do
		local file = list[i]
		local beatmapObject, type = beatmap.findSuitable("beatmap/"..file)

		if beatmapObject then
			local value = {name = file, data = beatmapObject, type = type}
			beatmap.list[#beatmap.list + 1] = value
			beatmap.list[file] = value
			sendBeatmapData("enum", id,
				file,
				beatmapObject:getName() or file,
				(beatmapObject:getFormatName()),
				beatmapObject:getDifficultyString()
			)
		end

		if commandChannel:peek() == "quit" then
			sendBeatmapData("enum", id, "")
			return
		end
	end

	sendBeatmapData("enum", id, "")
end

local function substituteAudio(name, isdir)
	local value = util.substituteExtension("audio/"..name, util.getNativeAudioExtensions(), not(isdir))
	if value then
		return love.filesystem.newFileData(value)
	end
	return nil
end

local function getSummary(bv)
	local info = {}
	info.name = bv.data:getName() or bv.name
	info.format, info.formatInternal = bv.data:getFormatName()
	info.audio = bv.data:getAudio() or substituteAudio(bv.name, bv.type == "folder")
	info.difficulty = bv.data:getDifficultyString()
	info.coverArt = bv.data:getCoverArt()
	local score = bv.data:getScoreInformation()
	if score then
		info.scoreS, info.scoreA, info.scoreB, info.scoreC = score[4], score[3], score[2], score[1]
	end
	local combo = bv.data:getComboInformation()
	if combo then
		info.comboS, info.comboA, info.comboB, info.comboC = combo[4], combo[3], combo[2], combo[1]
	end

	return info
end

-- Initialize beatmap loaders
do
	local list = love.filesystem.getDirectoryItems("game/beatmap/loader")
	for _, v in ipairs(list) do
		if v:sub(-4) == ".lua" then
			local s, func = love.filesystem.load("game/beatmap/loader/"..v)

			if s then
				local type
				s, func, type = pcall(s)

				if s then
					if type == "file" then
						beatmap.fileLoader[#beatmap.fileLoader + 1] = func
					elseif type == "folder" then
						beatmap.folderLoader[#beatmap.fileLoader + 1] = func
					end
				else
					love.event.push("print", v..": "..func)
				end
			else
				love.event.push("print", v..": "..func)
			end
		end
	end
end

local function processCommand(chan, command)
	local arg = chan:demand()
	local id = table.remove(arg, 1)

	if command == "enum" then
		beatmap.list = {}
		collectgarbage()
		collectgarbage()
		enumerateBeatmap(id)
	elseif command == "summary" then
		-- see game/beatmap/list.lua for more information about the format
		if beatmap.list[arg[1]] then
			-- LOVE 0.10.1 and below: Cannot send table directly, so reconstruct it later.
			local summary = getSummary(beatmap.list[arg[1]])
			local throwawayChannel = love.thread.newChannel()
			for n, v in pairs(summary) do
				throwawayChannel:push(n)
				throwawayChannel:push(v)
			end
			sendBeatmapData("summary", id, throwawayChannel)
		else
			sendBeatmapData("error", id, "beatmap doesn't exist")
		end
	elseif command == "notes" then
		if beatmap.list[arg[1]] then
			local beatmapData = beatmap.list[arg[1]].data:getNotesList()
			local throwChan = love.thread.newChannel()
			-- amount of notes
			throwChan:push(#beatmapData)
			-- note encoding data start
			for i = 1, #beatmapData do
				for k, v in pairs(beatmapData[i]) do
					throwChan:push(k)
					throwChan:push(v)
				end
				throwChan:push(throwChan) -- separator
			end
			-- send
			sendBeatmapData("notes", id, throwChan)
		else
			sendBeatmapData("error", id, "beatmap doesn't exist")
		end
	elseif command == "quit" then
		return "quit"
	end
	return ""
end

while true do
	local command = commandChannel:demand()
	if command == "quit" or processCommand(commandChannel, command) == "quit" then return end
end
