-- Beatmap processing thread
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
love._version = love._version or love.getVersion()
require("love.event")
require("love.filesystem")
require("love.image")
require("love.sound")
require("love.system")
require("love.timer")
require("love.video")

local util = require("util")
local log = require("logging")

math.randomseed(os.time())

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

local function createRandomString()
	local t = {}
	for _ = 1, 64 do
		t[#t + 1] = string.char(math.random(0, 255))
	end

	return table.concat(t)
end

local function sendBeatmapData(name, id, ...)
	log.debug("beatmap.thread", "sending beatmap data ("..name..")")
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
			log.debugf("beatmap.thread", "cannot load '%s' with '%s': %s", filename, beatmap.fileLoader[i].name, value)
		end
	end

	return nil, "unsupported beatmap format"
end

function beatmap.findSuitableForFolder(dir)
	-- make sure to guarantee path separator
	dir = dir:sub(-1) ~= "/" and dir.."/" or dir

	for i = 1, #beatmap.folderLoader do
		local status, value = pcall(beatmap.folderLoader[i], dir)

		if status then
			return value
		else
			log.debugf("beatmap.thread", "cannot load '%s' with '%s': %s", dir, beatmap.folderLoader[i].name, value)
		end
	end

	return nil, "unsupported beatmap project"
end

function beatmap.findSuitable(path)
	if util.directoryExist(path) then
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
			local fmt, fmtInt = beatmapObject:getFormatName()
			beatmap.list[#beatmap.list + 1] = value
			beatmap.list[file] = value
			sendBeatmapData("enum", id,
				file,
				beatmapObject:getName() or file,
				{fmtInt, fmt},
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
	info.hash = bv.data:getHash()
	info.audio = bv.data:getAudio() or substituteAudio(bv.name, bv.type == "folder")
	info.difficulty = bv.data:getDifficultyString()
	info.coverArt = bv.data:getCoverArt()
	info.star, info.randomStar = bv.data:getStarDifficultyInfo()
	info.liveClear = bv.data:getLiveClearVoice()
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

-- returns id, summary or nil, message
local function loadDirectly(path)
	local id
	repeat
		id = createRandomString()
	until beatmap.list[id] == nil

	local f, msg = util.newFileWrapper(path, "rb")
	if not(f) then return nil, msg end

	-- Enumerate file beatmap loaders
	for i = 1, #beatmap.fileLoader do
		f:seek(0)
		local status, value = pcall(beatmap.fileLoader[i], f)

		if status then
			local bv = {
				noEnum = true,
				name = path,
				type = "file",
				data = value
			}
			beatmap.list[id] = bv
			return id, getSummary(bv)
		else
			love.event.push("print", string.format("%s: %s", path, value))
		end
	end

	f:close()
	return nil, "unsupported beatmap format"
end

local loaderMeta = {
	__call = function(loader, ...)
		return rawget(loader, "func")(...)
	end
}

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
					local data = setmetatable({
						name = v:sub(1, -5),
						func = func
					}, loaderMeta)

					if type == "file" then
						beatmap.fileLoader[#beatmap.fileLoader + 1] = data
					elseif type == "folder" then
						beatmap.folderLoader[#beatmap.folderLoader + 1] = data
					end
				else
					log.errorf("beatmap.thread", "cannot register loader %s: %s", v, func)
				end
			else
				log.errorf("beatmap.thread", "cannot register loader %s: %s", v, func)
			end
		end
	end
end

local function processCommand(chan, command)
	local arg = chan:demand()
	local id = table.remove(arg, 1)
	log.debug("beatmap.thread", "received command: "..command)

	if command == "enum" then
		beatmap.list = {}
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
	elseif command == "background" then
		if beatmap.list[arg[1]] then
			local bg = beatmap.list[arg[1]].data:getBackground(arg[2])
			log.debug("beatmap.thread", "background: "..tostring(bg))
			sendBeatmapData("background", id, bg or 0)
		end
	elseif command == "unitinfo" then
		if beatmap.list[arg[1]] then
			local units = beatmap.list[arg[1]].data:getCustomUnitInformation()
			local c = love.thread.newChannel()

			for k, v in pairs(units) do
				c:push(k)
				c:push(v)
			end

			sendBeatmapData("unitinfo", id, c)
		end
	elseif command == "load" then
		-- load direct
		local path = arg[1]
		local beatmapID, summary = loadDirectly(path)
		if beatmapID then
			local c = love.thread.newChannel()
			for k, v in pairs(summary) do
				c:push(k)
				c:push(v)
			end

			sendBeatmapData("load", id, beatmapID, c)
		else
			sendBeatmapData("error", id, summary)
		end
	elseif command == "loadrel" then
		if beatmap.list[arg[1]] then
			local summary = getSummary(beatmap.list[arg[1]])
			local c = love.thread.newChannel()
			for k, v in pairs(summary) do
				c:push(k)
				c:push(v)
			end

			sendBeatmapData("load", id, arg[1], c)
		else
			local beatmapObject, type = beatmap.findSuitable("beatmap/"..arg[1])

			if beatmapObject then
				local value = {name = arg[1], data = beatmapObject, type = type}
				beatmap.list[#beatmap.list + 1] = value
				beatmap.list[arg[1]] = value

				local summary = getSummary(value)
				local c = love.thread.newChannel()
				for k, v in pairs(summary) do
					c:push(k)
					c:push(v)
				end

				sendBeatmapData("load", id, arg[1], c)
			else
				sendBeatmapData("error", id, "beatmap doesn't exist")
			end
		end
	elseif command == "loaders" then
		for i = 1, #beatmap.fileLoader do
			sendBeatmapData("loaders", id, beatmap.fileLoader[i].name, "file")
		end
		for i = 1, #beatmap.folderLoader do
			sendBeatmapData("loaders", id, beatmap.folderLoader[i].name, "folder")
		end
		sendBeatmapData("loaders", id, "")
	elseif command == "story" then
		if beatmap.list[arg[1]] then
			local storyboard = beatmap.list[arg[1]].data:getStoryboardData()
			if storyboard then
				local c = love.thread.newChannel()
				c:push(storyboard.type)
				c:push(storyboard.storyboard)
				if storyboard.path then
					c:push(true)
					c:push(storyboard.path)
				else
					c:push(false)
				end

				if storyboard.data then
					local c2 = love.thread.newChannel()
					for i = 1, #storyboard.data do
						c2:push(storyboard.data[i])
					end
					c:push(true)
					c:push(c2)
				else
					c:push(false)
				end

				sendBeatmapData("story", id, c)
			else
				sendBeatmapData("story", id, nil)
			end
		end
	elseif command == "quit" then
		return "quit"
	end
	return ""
end

while true do
	collectgarbage()
	local command = commandChannel:demand()
	if command == "quit" or processCommand(commandChannel, command) == "quit" then return end
end
