-- osu! folder beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local log = require("logging")
local util = require("util")
local osuLoader = require("game.beatmap.loader.osu")

return function(path)
	-- List all files containing *.osu extension
	local files = {}
	for _, file in ipairs(love.filesystem.getDirectoryItems(path)) do
		if util.getExtension(file) == "osu" then
			files[#files + 1] = path..file
		end
	end

	assert(#files > 0, "no osu! beatmap found")

	-- Load all of files
	local ret = {}
	for i = 1, #files do
		local file = love.filesystem.newFile(files[i], "r")
		if file then
			local status, beatmap = pcall(osuLoader, file, path)

			if status then
				ret[#ret + 1] = beatmap
			else
				log.debugf("noteloader.osuf", "%s: %s", files[i], beatmap)
			end
		end
	end

	assert(#ret > 0, "no beatmaps loaded")
	return ret
end, "folder"
