-- Very legacy DEPLS project beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local love = require("love")
local util = require("util")
local baseLoader = require("game.beatmap.base")
local beatmap = require("beatmap")

-------------------------
-- DEPLS Beatmap Class --
-------------------------

local deplsLoader = Luaoop.class("beatmap.DEPLS", baseLoader)

function deplsLoader:__construct(path)
	local internal = Luaoop.class.data(self)
	internal.path = path

	-- get list of files named "beatmap"
	local possibleBeatmapCandidate = {}
	for _, file in ipairs(love.filesystem.getDirectoryItems(path)) do
		if util.removeExtension(file) == "beatmap" then
			possibleBeatmapCandidate[#possibleBeatmapCandidate + 1] = path..file
		end
	end

	if #possibleBeatmapCandidate == 0 then
		error("cannot find beatmap file candidate")
	end

	-- make sure beatmap.json has highest priority, then ls2
	for i = 1, #possibleBeatmapCandidate do
		if util.getExtension(possibleBeatmapCandidate[i]):lower() == "ls2" then
			table.insert(possibleBeatmapCandidate, 1, table.remove(possibleBeatmapCandidate, i))
			break
		end
	end
	for i = 1, #possibleBeatmapCandidate do
		if util.getExtension(possibleBeatmapCandidate[i]):lower() == "json" then
			table.insert(possibleBeatmapCandidate, 1, table.remove(possibleBeatmapCandidate, i))
			break
		end
	end

	-- test all file candidates
	for i = 1, #possibleBeatmapCandidate do
		local file = love.filesystem.newFile(possibleBeatmapCandidate[i], "r")
		if file then
			for j = 1, #beatmap.fileLoader do
				file:seek(0)
				local s, v = pcall(beatmap.fileLoader[j], file)

				if s then
					assert(Luaoop.class.instanceof(v, "beatmap.Base"), "invalid beatmap object returned")
					internal.beatmap = v
					return
				end
			end
		end
	end

	error("cannot find beatmap file candidate")
end

function deplsLoader:getFormatName()
	local internal = Luaoop.class.data(self)
	local s1, s2 = internal.beatmap:getFormatName()
	return "DEPLS: "..s1, "depls_"..s2
end

function deplsLoader:getHash()
	local internal = Luaoop.class.data(self)
	return internal.beatmap:getHash()
end

function deplsLoader:getNotesList()
	local internal = Luaoop.class.data(self)
	return internal.beatmap:getNotesList()
end

local customUnitPossibleExt = {".png", ".tga", ".txt"}
function deplsLoader:getCustomUnitInformation()
	local internal = Luaoop.class.data(self)
	local beatmapUnitInfo = internal.beatmap:getCustomUnitInformation()
	local imageCache = {}
	local res = {}

	for i = 1, 9 do
		if beatmapUnitInfo[i] then
			res[i] = beatmapUnitInfo[i]
		else
			local filename = util.substituteExtension(internal.path.."unit_pos_"..i, customUnitPossibleExt)

			if filename then
				if util.getExtension(filename) == "txt" then
					local imageFile = love.filesystem.read(filename)

					if not(imageCache[imageFile]) then
						local s, v = pcall(love.image.newImageData, internal.path..imageFile)
						if s then
							imageCache[imageFile] = v
						end
					end

					if imageCache[imageFile] then
						res[i] = imageCache[imageFile]
					end
				else
					if not(imageCache[filename]) then
						local s, v = pcall(love.image.newImageData, filename)
						if s then
							imageCache[filename] = v
						end
					end

					if imageCache[filename] then
						res[i] = imageCache[filename]
					end
				end
			end
		end
	end

	return res
end

local coverArtExtensions = {".png", ".jpg", ".jpeg", ".tga", ".bmp"}
function deplsLoader:getCoverArt()
	local internal = Luaoop.class.data(self)
	local coverInfo = internal.beatmap:getCoverArt()

	if coverInfo then
		return coverInfo
	else
		local coverName = internal.path.."cover.txt"
		local coverImage = util.substituteExtension(internal.path.."cover", coverArtExtensions)

		if util.fileExists(coverName) and coverImage then
			local cover = {}
			local lineIter = love.filesystem.lines(coverName)

			cover.title = lineIter()
			cover.info = lineIter()
			cover.image = love.image.newImageData(coverImage)

			return cover
		end
	end
end

function deplsLoader:getAudioPathList()
	local internal = Luaoop.class.data(self)
	return {internal.path.."songFile"}
end

function deplsLoader:getAudio()
	local internal = Luaoop.class.data(self)
	local beatmapAudio = internal.beatmap:getAudio()

	if beatmapAudio then
		return beatmapAudio
	else
		return baseLoader.getAudio(self)
	end
end

return deplsLoader, "folder"
