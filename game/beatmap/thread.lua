-- Beatmap processing thread
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
love._version = love._version or love.getVersion()
require("love.event")
require("love.system")
require("love.image")
require("love.filesystem")

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
		return beatmap.findSuitableForFolder(path)
	else
		return beatmap.findSuitableForFile(path)
	end
end

local function enumerateBeatmap()
	local list = love.filesystem.getDirectoryItems("beatmap/")

	for i = 1, #list do
		local file = list[i]
		local beatmapObject = beatmap.findSuitable(file)

		if beatmapObject then
			beatmap.list[#beatmap.list + 1] = beatmapObject
			beatmap.list[file] = beatmapObject
			love.event.push("beatmaploaded", file, beatmapObject:getSummary())
		end
	end
end

while true do
	local command = commandChannel:demand()

	if command == "enum" then
		beatmap.list = {}
		collectgarbage()
		collectgarbage()
		enumerateBeatmap()
	elseif command == "quit" then
		return
	end
end
