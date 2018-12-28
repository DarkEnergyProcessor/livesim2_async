-- Live Simulator: 2 binary beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local bit = require("bit")
local love = require("love")
local Luaoop = require("libs.Luaoop")
local ls2 = require("libs.ls2")
local util = require("util")
local log = require("logging")
local md5 = require("game.md5")
local baseLoader = require("game.beatmap.base")

-- String to little endian dword (signed)
local function string2dword(str)
	return bit.bor(
		str:byte(),
		bit.lshift(str:sub(2,2):byte(), 8),
		bit.lshift(str:sub(3,3):byte(), 16),
		bit.lshift(str:sub(4,4):byte(), 24)
	)
end

------------------------------
-- Setup LS2 Stream Wrapper --
------------------------------
ls2.setstreamwrapper {
	read = function(stream, val)
		return (stream:read(assert(val)))
	end,
	write = function(stream, data)
		return stream:write(data)
	end,
	seek = function(stream, whence, offset)
		local set = 0

		if whence == "cur" then
			set = stream:tell()
		elseif whence == "end" then
			set = stream:getSize()
		elseif whence ~= "set" then
			error("Invalid whence")
		end

		stream:seek(set + (offset or 0))
		return stream:tell()
	end
}

-----------------------
-- LS2 Beatmap Class --
-----------------------

local ls2Loader = Luaoop.class("beatmap.LS2", baseLoader)

function ls2Loader:__construct(file)
	local internal = Luaoop.class.data(self)
	internal.ls2 = ls2.loadstream(file)
	internal.file = file
end

function ls2Loader:getFormatName()
	local internal = Luaoop.class.data(self)
	return string.format("Live Simulator: 2 v%s Beatmap", internal.ls2.version_2 and "2.0" or "1.x"), "ls2"
end

function ls2Loader:getHash()
	local internal = Luaoop.class.data(self)

	if internal.ls2.sections.BMPM or internal.ls2.sections.BMPT then
		-- hash the beatmap data
		local data = {0, 0, 0, 0}

		local function xorCycle(int)
			data[1] = bit.bxor(int, data[4])
			data[2] = bit.bxor(data[2], data[1])
			data[3] = bit.bxor(data[3], data[2])
			data[4] = bit.bxor(data[4], data[3])
		end

		if internal.ls2.sections.BMPM then
			for _, v in ipairs(internal.ls2.sections.BMPM) do
				internal.file:seek(v)
				local amount = string2dword(internal.file:read(4))
				for _ = 1, amount do
					local d = internal.file:read(12)
					xorCycle(string2dword(d))
					xorCycle(string2dword(d:sub(4)))
					xorCycle(string2dword(d:sub(8)))
				end
			end
		end

		if internal.ls2.sections.BMPT then
			for _, v in ipairs(internal.ls2.sections.BMPT) do
				internal.file:seek(v)
				local amount = string2dword(internal.file:read(4))
				for _ = 1, amount do
					local d = internal.file:read(12)
					xorCycle(string2dword(d))
					xorCycle(string2dword(d:sub(4)))
					xorCycle(string2dword(d:sub(8)))
				end
			end
		end

		local story = ""
		if internal.ls2.sections.SRYL then
			internal.file:seek(internal.ls2.sections.SRYL[1])
			story = md5(ls2.section_processor.SRYL[1](internal.file))
		end

		return md5(table.concat(data, ",")..story)
	else
		-- Should not happen for valid LS2 beatmap
		log.warning("noteloader.livesim2", "Hashing full beatmap file")
		return md5(love.filesystem.newFileData(internal.file:getFilename()))
	end
end

function ls2Loader:getNotesList()
	local internal = Luaoop.class.data(self)
	local nlist = {}

	-- Select and process BMPM and BMPT sections
	-- We don't have to check if notes data were
	-- empty or not, since it's already handled when
	-- loading the beatmap file.
	if internal.ls2.sections.BMPM then
		for _, v in ipairs(internal.ls2.sections.BMPM) do
			local notes_data

			internal.file:seek(v)
			notes_data = ls2.section_processor.BMPM[1](internal.file, internal.ls2.version_2)

			for _, n in ipairs(notes_data) do
				nlist[#nlist + 1] = n
			end
		end
	end

	if internal.ls2.sections.BMPT then
		for _, v in ipairs(internal.ls2.sections.BMPT) do
			local notes_data

			internal.file:seek(v)
			notes_data = ls2.section_processor.BMPT[1](internal.file, internal.ls2.version_2)

			for _, n in ipairs(notes_data) do
				nlist[#nlist + 1] = n
			end
		end
	end

	table.sort(nlist, function(a, b) return a.timing_sec < b.timing_sec end)
	return nlist
end

function ls2Loader:_getMetadata()
	local internal = Luaoop.class.data(self)

	if not(internal.metadata) then
		if internal.ls2.sections.MTDT then
			internal.file:seek(internal.ls2.sections.MTDT[1])
			internal.metadata = ls2.section_processor.MTDT[1](internal.file, internal.ls2.version_2)
		else
			internal.metadata = {}
		end
	end

	return assert(internal.metadata)
end

function ls2Loader:getName()
	local metadata = self:_getMetadata()

	if metadata.name then
		return metadata.name
	end

	local cover = self:getCoverArt()
	if cover and cover.title then
		return cover.title
	end

	return nil
end

function ls2Loader:getCoverArt()
	local internal = Luaoop.class.data(self)

	if not(internal.coverArtLoaded) then
		if internal.ls2.sections.COVR then
			internal.file:seek(internal.ls2.sections.COVR[1])
			local val = ls2.section_processor.COVR[1](internal.file, internal.ls2.version_2)
			internal.coverArt = {
				title = val.title,
				info = val.arrangement,
				image = love.filesystem.newFileData(val.image, "")
			}
		end
		internal.coverArtLoaded = true
	end

	return internal.coverArt
end

function ls2Loader:getScoreInformation()
	local internal = Luaoop.class.data(self)
	local metadata = self:_getMetadata()

	-- Try to get from metadata first (v1 or v2)
	if internal.ls2.version_2 or metadata.score then
		return metadata.score
	-- For version 1 (only), get from SCRI
	elseif internal.ls2.sections.SCRI and internal.ls2.sections.SCRI[1] then
		internal.file:seek(internal.ls2.sections.SCRI[1])
		return ls2.section_processor.SCRI[1](internal.file)
	end
end

function ls2Loader:getComboInformation()
	return self:_getMetadata().combo
end

function ls2Loader:getStarDifficultyInfo()
	local metadata = self:_getMetadata()

	if metadata.star then
		if metadata.random_star and metadata.random_star ~= metadata.star then
			return metadata.star, metadata.random_star
		end
		return metadata.star
	end

	return 0
end

function ls2Loader:getAudio()
	local internal = Luaoop.class.data(self)

	if internal.ls2.sections.ADIO then
		internal.file:seek(internal.ls2.sections.ADIO[1])
		local ext, data = ls2.section_processor.ADIO[1](internal.file, internal.ls2.version_2)
		if ext then
			return love.filesystem.newFileData(data, "_."..ext)
		end
	end

	return baseLoader.getAudio(self)
end

function ls2Loader:getAudioPathList()
	local metadata = self:_getMetadata()
	local paths = {nil, nil}

	if metadata.song_file then
		paths[1] = util.removeExtension("audio/"..metadata.song_file)
		paths[2] = util.removeExtension(metadata.song_file)
	end

	return paths
end

function ls2Loader:getBackground()
	-- if nil or 0, let livesim2 decide
	-- if number, predefined one
	-- if table, {mode, ...}
	-- where mode are bitwise:
	-- 1. main background only (index 2)
	-- 2. has left right background (index 3 and 4)
	-- 4. has top bottom background (index 5 and 6)
	-- 8. has video background, refer to File object (index 7)
	-- If main background (bit 0) is false, then index 2 is assumed
	-- to be number and only bit 4 is allowed to set if it really
	-- contains video.
	-- background refer to ImageData object
	local internal = Luaoop.class.data(self)

	if internal.ls2.sections.BIMG then
		local backgrounds = {}

		for _, v in ipairs(internal.ls2.sections.BIMG) do
			internal.file:seek(v)
			local idx, img = ls2.section_processor.BIMG[1](internal.file, internal.ls2.version_2)

			backgrounds[idx] = love.image.newImageData(love.filesystem.newFileData(img, ""))
		end

		-- verify backgrounds
		local bits = 1
		local realBack = {0}
		if backgrounds[0] == nil then
			log.warning("noteloader.livesim2", "missing main background. Fallback to background ID!")
			return internal.ls2.background_id
		else
			realBack[2] = backgrounds[0]
		end
		if backgrounds[1] and backgrounds[2] then
			bits = bits + 2
			realBack[#realBack + 1] = backgrounds[1]
			realBack[#realBack + 1] = backgrounds[2]
		elseif not(backgrounds[1]) ~= not(backgrounds[2]) then
			log.warning("noteloader.livesim2", "missing left or right background. Discard both!")
		end
		if backgrounds[3] and backgrounds[4] then
			bits = bits + 4
			realBack[#realBack + 1] = backgrounds[3]
			realBack[#realBack + 1] = backgrounds[4]
		elseif not(backgrounds[3]) ~= not(backgrounds[4]) then
			log.warning("noteloader.livesim2", "missing top or bottom background. Discard both!")
		end
		realBack[1] = bits
		return realBack
	end

	return internal.ls2.background_id
end

function ls2Loader:getCustomUnitInformation()
	local internal = Luaoop.class.data(self)
	local unitData = {}

	if internal.ls2.sections.UNIT and internal.ls2.sections.UIMG then
		local uimgs = {}

		for _, v in ipairs(internal.ls2.sections.UIMG) do
			local idx, img
			internal.file:seek(v)

			idx, img = ls2.section_processor.UIMG[1](internal.file, internal.ls2.version_2)
			uimgs[idx] = love.image.newImageData(love.filesystem.newFileData(img, ""))
		end

		for _, v in ipairs(internal.ls2.sections.UNIT) do
			internal.file:seek(v)

			for _, u in ipairs(ls2.section_processor.UNIT[1](internal.file, internal.ls2.version_2)) do
				unitData[u[1]] = uimgs[u[2]]
			end
		end
	end

	return unitData
end

local function decompress(fmt, data)
	if love._version >= "11.0" then
		return love.data.decompress("string", fmt, data)
	else
		return love.math.decompress(data, fmt)
	end
end

function ls2Loader:getStoryboardData()
	local internal = Luaoop.class.data(self)
	if internal.ls2.sections.SRYL then
		internal.file:seek(internal.ls2.sections.SRYL[1])
		local storyData = ls2.section_processor.SRYL[1](internal.file)

		-- Attempt to decompress storyboard script
		do
			local status, newStory = pcall(decompress, "zlib", storyData)
			if status then
				storyData = newStory
			end
		end

		-- Enumerate all DATA
		local datalist = {}
		if internal.ls2.sections.DATA then
			for _, v in ipairs(internal.ls2.sections.DATA) do
				internal.file:seek(v)
				local name, cont = ls2.section_processor.DATA[1](internal.file)
				datalist[#datalist + 1] = love.filesystem.newFileData(cont, name)
			end
		end

		local type = storyData:find("---", 1, true) == 1 and "yaml" or "lua"
		if type == "yaml" then
			storyData = storyData:gsub("\r\n", "\n")
		end
		return {
			type = type,
			storyboard = storyData,
			data = datalist
		}
	end
end

function ls2Loader:getLiveClearVoice()
	local internal = Luaoop.class.data(self)
	if internal.ls2.sections.LCLR then
		-- Embedded audio available
		internal.file:seek(internal.ls2.sections.LCLR[1])
		local ext, data = ls2.section_processor.LCLR[1](internal.file, internal.ls2.version_2)
		local fdata = love.filesystem.newFileData(data, "_."..ext)

		-- May not supported
		local s, msg = pcall(util.newDecoder, fdata)
		if s then
			return msg
		else
			log.errorf("noteloader.livesim2", "live clear sound not supported: %s", msg)
			return nil
		end
	end

	return nil
end

return ls2Loader, "file"
