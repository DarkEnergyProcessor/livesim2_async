-- Very legacy DEPLS project beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local yaml = require("libs.tinyyaml")

local log = require("logging")
local love = require("love")
local Util = require("util")
local beatmap = require("beatmap")
local md5 = require("game.md5")
local baseLoader = require("game.beatmap.base")

-------------------------
-- DEPLS Beatmap Class --
-------------------------

local deplsLoader = Luaoop.class("beatmap.DEPLS", baseLoader)

function deplsLoader:__construct(path, beatmap)
	local internal = Luaoop.class.data(self)
	internal.path = path
	internal.beatmap = beatmap
end

function deplsLoader:getFormatName()
	local internal = Luaoop.class.data(self)
	local s1, s2 = internal.beatmap:getFormatName()
	return "DEPLS: "..s1, "depls_"..s2
end

function deplsLoader:getHash()
	local internal = Luaoop.class.data(self)
	return md5(internal.beatmap:getHash()..self:getFormatName())
end

function deplsLoader:getNotesList()
	local internal = Luaoop.class.data(self)
	return internal.beatmap:getNotesList()
end

function deplsLoader:getName()
	local internal = Luaoop.class.data(self)
	local name = internal.beatmap:getName()

	if not(name) then
		local coverArt = self:getCoverArt(true)
		if coverArt then
			name = coverArt.title
		end
	end

	return name
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
			local filename = Util.substituteExtension(internal.path.."unit_pos_"..i, customUnitPossibleExt)

			if filename then
				if Util.getExtension(filename) == "txt" then
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
function deplsLoader:getCoverArt(noimage)
	local internal = Luaoop.class.data(self)
	local coverInfo = internal.beatmap:getCoverArt()

	if coverInfo then
		return coverInfo
	else
		local coverName = internal.path.."cover.txt"
		local coverImage = Util.substituteExtension(internal.path.."cover", coverArtExtensions)

		if Util.fileExists(coverName) and coverImage then
			local cover = {}
			local lineIter = love.filesystem.lines(coverName)

			cover.title = lineIter()
			cover.info = lineIter()

			if not(noimage) then
				cover.image = love.image.newImageData(coverImage)
			end

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

local VIDEO_EXTENSION = Util.hasExtendedVideoSupport() and
	{".ogg", ".ogv", ".mp4", ".webm", ".mkv", ".avi"} or
	{".ogg", ".ogv"}

local ASPECT_RATIO = {16/9, 16/10, 3/2, 4/3}

function deplsLoader:getBackground(video)
	local internal = Luaoop.class.data(self)
	local mode = internal.beatmap:getBackground() -- file loader can't load video
	local videoObj

	if video then
		local f = Util.substituteExtension(internal.path.."video_background", VIDEO_EXTENSION)
		if f then
			videoObj = Util.newVideoStream(f)
		end
	end

	if mode == nil or mode == 0 then
		local bgfile = Util.substituteExtension(internal.path.."background", coverArtExtensions)
		if bgfile then
			local mode = {1}
			local backgrounds = {}
			local image = love.image.newImageData(bgfile)

			mode[#mode + 1] = image

			for i = 1, 4 do
				bgfile = Util.substituteExtension(internal.path.."background-"..i, coverArtExtensions)
				if bgfile then
					backgrounds[i] = love.image.newImageData(bgfile)
				end
			end

			if backgrounds[1] and backgrounds[2] then
				mode[1] = mode[1] + 2
				mode[#mode + 1] = backgrounds[1]
				mode[#mode + 1] = backgrounds[2]
			elseif not(backgrounds[1]) ~= not(backgrounds[2]) then
				log.warning("noteloader.depls", "missing left or right background. Discard both!")
			end

			if backgrounds[3] and backgrounds[4] then
				mode[1] = mode[1] + 4
				mode[#mode + 1] = backgrounds[3]
				mode[#mode + 1] = backgrounds[4]
			elseif not(backgrounds[3]) ~= not(backgrounds[4]) then
				log.warning("noteloader.depls", "missing top or bottom background. Discard both!")
			end

			if mode[1] == 1 then
				-- Looks like no background-n file present, try to cut it
				local w, h = image:getDimensions()
				local ratio = w / h

				-- Calculate aspect ratio
				local aspectIndex = 0
				local aspectRatioDiff = math.huge
				for i, v in ipairs(ASPECT_RATIO) do
					local diff = math.abs(ratio - v)

					if diff < aspectRatioDiff then
						aspectIndex = i
						aspectRatioDiff = diff
					end
				end

				if aspectIndex == 1 then
					-- We can make the background to be 16:9
					local calculatedMain = math.floor(88 * w / 1136)
					local calculatedEndMain = math.floor(1048 * w / 1136)
					local calculatedWidth = calculatedEndMain - calculatedMain

					-- left
					local imgl = love.image.newImageData(calculatedMain, h)
					imgl:paste(image, 0, 0, 0, 0, calculatedMain, h)
					-- center
					local imgc = love.image.newImageData(calculatedWidth, h)
					imgc:paste(image, 0, 0, calculatedMain, 0, calculatedWidth, h)
					-- right
					local imgr = love.image.newImageData(w - calculatedEndMain, h)
					imgr:paste(image, 0, 0, calculatedEndMain, 0, w - calculatedEndMain, h)

					mode[2] = imgc
					mode[#mode + 1] = imgl
					mode[#mode + 1] = imgr
					mode[1] = mode[1] + 2
				elseif aspectIndex == 2 then
					-- 16:10, 1136x710
					local calculatedMain = math.floor(88 * w / 1136)
					local calculatedEndMain = math.floor(1048 * w / 1136)
					local calculatedWidth = calculatedEndMain - calculatedMain
					local calculatedStartHeight = math.floor(35 * h / 710)
					local calculatedEndHeight = math.floor(675 * h / 710)
					local calculatedHeight = calculatedEndHeight - calculatedStartHeight

					-- left
					local imgl = love.image.newImageData(calculatedMain, calculatedHeight)
					imgl:paste(image, 0, 0, 0, 0, calculatedMain, calculatedHeight)
					-- center
					local imgc = love.image.newImageData(calculatedWidth, calculatedHeight)
					imgc:paste(image, 0, 0, calculatedMain, 0, calculatedWidth, calculatedHeight)
					-- right
					local imgr = love.image.newImageData(w - calculatedEndMain, calculatedHeight)
					imgr:paste(image, 0, 0, calculatedEndMain, 0, w - calculatedEndMain, calculatedHeight)

					mode[2] = imgc
					mode[#mode + 1] = imgl
					mode[#mode + 1] = imgr
					mode[1] = mode[1] + 2
				elseif aspectIndex == 3 then
					-- 2:3 ratio. Put it as-is
					mode[2] = image -- noop
				elseif aspectIndex == 4 then
					-- We can make the background to be 4:3
					local calculatedMain = math.floor(43 * h / 726)
					local calculatedEndMain = math.floor(683 * h / 726)
					local calculatedHeight = calculatedEndMain - calculatedMain
					-- top
					local imgt = love.image.newImageData(w, calculatedMain)
					imgt:paste(image, 0, 0, 0, 0, w, calculatedMain)
					-- center
					local imgc = love.image.newImageData(w, calculatedHeight)
					imgc:paste(image, 0, 0, 0, calculatedMain, w, calculatedHeight)
					-- bottom
					local imgb = love.image.newImageData(w, h - calculatedEndMain)
					imgb:paste(image, 0, 0, 0, calculatedEndMain, w, h - calculatedEndMain)

					mode[2] = imgc
					mode[#mode + 1] = imgt
					mode[#mode + 1] = imgb
					mode[1] = mode[1] + 4
				end
			end

			if videoObj then
				mode[1] = mode[1] + 8
				mode[#mode + 1] = videoObj
			end

			return mode
		elseif Util.fileExists(internal.path.."background.txt") then
			-- love.filesystem.read returns 2 values, and it can be problem
			-- for background ID 10 and 11, so pass "nil" as 2nd argument of tonumber
			local n = tonumber(love.filesystem.read(internal.path.."background.txt"), nil)
			if videoObj then
				return {8, n, videoObj}
			else
				return n
			end
		end
	elseif videoObj then
		return {8, mode, videoObj}
	else
		return mode
	end

	if videoObj then
		return {8, 0, videoObj}
	else
		return 0
	end
end

function deplsLoader:getStoryboardData()
	local internal = Luaoop.class.data(self)
	local embeddedStory = internal.beatmap:getStoryboardData()

	if embeddedStory then
		embeddedStory.path = internal.path
		return embeddedStory
	end
	local file = Util.substituteExtension(internal.path.."storyboard", {".yaml", ".yml"}, false)

	if file then
		return {
			type = "yaml",
			storyboard = love.filesystem.read(file):gsub("\r\n", "\n"),
			path = internal.path
		}
	end

	file = internal.path.."storyboard.lua"
	if Util.fileExists(file) then
		local script = love.filesystem.read(file)
		-- Do not load bytecode
		if script:find("\27", 1, true) == nil and loadstring(script) then
			return {
				type = "lua",
				storyboard = script,
				path = internal.path
			}
		end
	end

	return nil
end

function deplsLoader:getLiveClearVoice()
	local internal = Luaoop.class.data(self)
	local audio = internal.beatmap:getLiveClearVoice()

	if not(audio) then
		local file = Util.substituteExtension(internal.path.."live_clear", Util.getNativeAudioExtensions())
		if file then
			local s, msg = pcall(Util.newDecoder, file)
			if s then
				audio = msg
			else
				log.errorf("noteloader.depls", "live clear sound not supported: %s", msg)
			end
		end
	end

	return audio
end

function deplsLoader:getDifficultyString()
	return Luaoop.class.data(self).beatmap:getDifficultyString()
end

function deplsLoader:getScorePerTap()
	return Luaoop.class.data(self).beatmap:getScorePerTap()
end

function deplsLoader:getStamina()
	return Luaoop.class.data(self).beatmap:getStamina()
end

function deplsLoader:getLyrics()
	local internal = Luaoop.class.data(self)
	local lyrics = internal.beatmap:getLyrics()

	if not(lyrics) then
		if Util.fileExists(internal.path.."lyrics.srt") then
			lyrics = love.filesystem.newFileData(internal.path.."lyrics.srt")
		elseif Util.fileExists(internal.path.."lyrics.srt.gz") then
			local temp = love.filesystem.newFileData(internal.path.."lyrics.srt")
			lyrics = Util.decompressToData(temp, "gzip")
		end
	end

	return lyrics
end

return function(path)
	-- if there's beatmaplist.yml then use that
	if Util.fileExists(path.."beatmaplist.yml") then
		-- multi-beatmap
		local beatmaps = yaml.parse((love.filesystem.read(path.."beatmaplist.yml")))
		local tempt = {}
		local ret = {}

		for k, v in pairs(beatmaps) do
			tempt[#tempt + 1] = {k, v}
		end
		table.sort(tempt, function(a, b) return a[1] < b[1] end)

		for _, v in ipairs(tempt) do
			local file = Util.newFileCompat(v[2], "r")
			if file then
				for j = 1, #beatmap.fileLoader do
					file:seek(0)
					local s, p = pcall(beatmap.fileLoader[j], file)

					if s then
						if getmetatable(p) == nil then
							-- multi-beatmap in a multi beatmap
							for k = 1, #p do
								ret[#ret + 1] = deplsLoader(path, p[k])
							end

							return ret
						else
							-- single beatmap
							ret[#ret + 1] = deplsLoader(path, v)
						end
					end
				end
			end
		end

		return ret
	else
		-- get list of files named "beatmap"
		local possibleBeatmapCandidate = {}
		for _, file in ipairs(love.filesystem.getDirectoryItems(path)) do
			if Util.removeExtension(file) == "beatmap" then
				possibleBeatmapCandidate[#possibleBeatmapCandidate + 1] = path..file
			end
		end

		if #possibleBeatmapCandidate == 0 then
			error("cannot find beatmap file candidate")
		end

		-- make sure beatmap.json has highest priority, then ls2
		for i = 1, #possibleBeatmapCandidate do
			if Util.getExtension(possibleBeatmapCandidate[i]):lower() == "ls2" then
				table.insert(possibleBeatmapCandidate, 1, table.remove(possibleBeatmapCandidate, i))
				break
			end
		end

		for i = 1, #possibleBeatmapCandidate do
			if Util.getExtension(possibleBeatmapCandidate[i]):lower() == "json" then
				table.insert(possibleBeatmapCandidate, 1, table.remove(possibleBeatmapCandidate, i))
				break
			end
		end
		-- test all file candidates
		for i = 1, #possibleBeatmapCandidate do
			local file = Util.newFileCompat(possibleBeatmapCandidate[i], "r")
			if file then
				for j = 1, #beatmap.fileLoader do
					file:seek(0)
					local s, v = pcall(beatmap.fileLoader[j], file)

					if s then
						if getmetatable(v) == nil then
							-- multi-beatmap
							local ret = {}
							for k = 1, #v do
								ret[k] = deplsLoader(path, v[k])
							end

							return ret
						else
							-- single beatmap
							return deplsLoader(path, v)
						end
					end
				end

				file:close()
			end
		end
	end

	error("cannot find beatmap file candidate")
end, "folder"
