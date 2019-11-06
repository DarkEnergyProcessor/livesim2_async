-- Live Simulator: 2 "Over the Rainbow" beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local util = require("util")

local ls2ovrBeatmap = require("game.ls2ovr.beatmap")
local baseLoader = require("game.beatmap.base")

-----------------------
-- LS2OVR base class --
-----------------------

local ls2ovrLoader = Luaoop.class("beatmap.LS2OVRBase", baseLoader)

function ls2ovrLoader:__construct(beatmapObject, index)
	local internal = Luaoop.class.data(self)

	internal.beatmapObject = beatmapObject
	internal.beatmapData = beatmapObject:getBeatmap(index)
	internal.beatmapIndex = index
end

function ls2ovrLoader.getFormatName()
	return "Live Simulator: 2 v4.0 Beatmap", "ls2ovr"
end

function ls2ovrLoader:getHash()
	local internal = Luaoop.class.data(self)
	return internal.beatmapObject:getBeatmapHash(internal.beatmapIndex)
end

function ls2ovrLoader:getNotesList()
	return Luaoop.class.data(self).beatmapData.mapData
end

function ls2ovrLoader:getName()
	return Luaoop.class.data(self).beatmapObject:getMetadata().title
end

function ls2ovrLoader:getCustomUnitInformation()
	local internal = Luaoop.class.data(self)
	local beatmapData = internal.beatmapData
	local customUnits = {}

	if beatmapData.customUnitList then
		local cache = {}

		for _, v in ipairs(beatmapData.customUnitList) do
			if v.position > 0 and v.position < 10 then
				local file = internal.beatmapObject:getFile(v.filename)
				if file then
					local x = cache[v.filename]

					if not(x) then
						local s
						s, x = pcall(love.image.newImageData, file)
						if s then
							cache[v.filename] = x
						else
							x = nil
						end
					end

					if x then
						customUnits[v.position] = x
					end
				end
			end
		end
	end

	return customUnits
end

function ls2ovrLoader:getDifficultyString()
	local diff = Luaoop.class.data(self).beatmapData.difficultyName

	if diff and #diff > 0 then
		return diff
	else
		return baseLoader.getDifficultyString(self)
	end
end

function ls2ovrLoader:getAudio()
	local beatmapObject = Luaoop.class.data(self).beatmapObject
	local metadata = beatmapObject:getMetadata()

	if metadata.audio then
		return beatmapObject:getFile(metadata.audio)
	end

	return nil
end

function ls2ovrLoader:getCoverArt()
	local beatmapObject = Luaoop.class.data(self).beatmapObject
	local metadata = beatmapObject:getMetadata()

	if metadata.artwork then
		local file = beatmapObject:getFile(metadata.artwork)

		if file then
			local s, imagedata = pcall(love.image.newImageData, file)

			if s then
				local descriptionString = nil

				if metadata.composers and #metadata.composers > 0 then
					local strb = {}

					for i, v in ipairs(metadata.composers) do
						strb[i] = string.format("%s: %s", v.role, v.name)
					end

					descriptionString = table.concat(strb, "  ")
				end

				return {
					title = metadata.title,
					info = descriptionString,
					image = imagedata
				}
			end
		end
	end

	return nil
end

function ls2ovrLoader:_getScoreOrComboInformation(type)
	local beatmapData = Luaoop.class.data(self).beatmapData

	if beatmapData[type] and #beatmapData[type] >= 4 then
		local info = beatmapData[type]
		local list = {}

		for i = 1, 4 do
			local v = info[i]

			if v >= 0 then
				if i >= 2 then
					if v <= list[i - 1] then
						-- Last value is bigger. Discard everything
						return nil
					end
				end
			else
				return nil
			end

			list[i] = v
		end

		return list
	end

	return nil
end

function ls2ovrLoader:getScoreInformation()
	return self:_getScoreOrComboInformation("scoreInfo")
end

function ls2ovrLoader:getComboInformation()
	return self:_getScoreOrComboInformation("comboInfo")
end

local ymlCombinations = {".yml", ".yaml"}

function ls2ovrLoader:getStoryboardData()
	local beatmapObject = Luaoop.class.data(self).beatmapObject
	local storyData, storyType

	for _, yaml in ipairs(ymlCombinations) do
		local f = beatmapObject:getFile("storyboard"..yaml..".gz")

		if f then
			-- gzip compressed storyboard data
			storyData = util.decompressToString(f, "gzip")
			storyType = "yaml"
		else
			f = beatmapObject:getFile("storyboard"..yaml)

			if f then
				-- uncompressed storyboard data
				storyData = f:getString()
				storyType = "yaml"
			end
		end
	end
	-- TODO: support more storyboard formats by Lovewing?

	if not(storyData) then
		return nil
	elseif storyType == "yaml" then
		storyData = storyData:gsub("\r\n", "\n")
	end

	local storyboardFiles = {}
	for _, v in pairs(beatmapObject:getFileTable()) do
		storyboardFiles[#storyboardFiles + 1] = v
	end

	return {
		type = storyType,
		storyboard = storyData,
		data = storyboardFiles
	}
end

function ls2ovrLoader:getBackground()
	local internal = Luaoop.class.data(self)
	local beatmapObject = internal.beatmapObject
	local beatmapData = internal.beatmapData
	local bgtype = type(internal.beatmapData.background)

	if bgtype == "table" then
		local bglist = beatmapData.background
		-- {mode, ...}
		-- where mode are bitwise:
		-- 1. main background only (index 2)
		-- 2. has left right background (index 3 and 4)
		-- 4. has top bottom background (index 5 and 6)
		-- If main background (bit 0) is false, then index 2 is assumed
		-- to be number.
		local mode = {1, nil, nil, nil, nil, nil}

		if bglist.main and beatmapObject:getFile(bglist.main) then
			local s, tempIData = pcall(love.image.newImageData, beatmapObject:getFile(bglist.main))

			if s then
				local isCombinationOK = false
				mode[2] = tempIData

				-- Left and right background
				if
					bglist.left and bglist.right and
					beatmapObject:getFile(bglist.left) and
					beatmapObject:getFile(bglist.right)
				then
					s, tempIData = pcall(love.image.newImageData, beatmapObject:getFile(bglist.left))

					if s then
						mode[3] = tempIData
						s, tempIData = pcall(love.image.newImageData, beatmapObject:getFile(bglist.right))

						if s then
							mode[1] = mode[1] + 2
							isCombinationOK = true
							mode[4] = tempIData
						end
					end
				end

				if not(isCombinationOK) then
					mode[3], mode[4] = nil, nil
				else
					isCombinationOK = false
				end

				-- Top and bottom background
				if
					bglist.top and bglist.bottom and
					beatmapObject:getFile(bglist.top) and
					beatmapObject:getFile(bglist.bottom)
				then
					s, tempIData = pcall(love.image.newImageData, beatmapObject:getFile(bglist.top))

					if s then
						mode[5] = tempIData
						s, tempIData = pcall(love.image.newImageData, beatmapObject:getFile(bglist.bottom))

						if s then
							mode[1] = mode[1] + 4
							isCombinationOK = true
							mode[6] = tempIData
						end
					end
				end

				if not(isCombinationOK) then
					mode[5], mode[6] = nil, nil
				end

				return mode
			end
		end
	elseif bgtype == "string" then
		local bg = internal.beatmapData.background
		if bg:sub(1, 1) == ":" then
			return tonumber(bg:sub(2)) or 0
		else
			local f = beatmapObject:getFile(bg)

			if f then
				local s, id = pcall(love.image.newImageData, f)

				if s then
					return {1, id}
				end
			end
		end
	end

	return 0
end

function ls2ovrLoader:getScorePerTap()
	return Luaoop.class.data(self).beatmapData.baseScorePerTap or 0
end

function ls2ovrLoader:getStamina()
	return Luaoop.class.data(self).beatmapData.stamina or 0
end

function ls2ovrLoader:getStarDifficultyInfo()
	local internal = Luaoop.class.data(self)
	return internal.beatmapData.star, internal.beatmapData.starRandom
end

function ls2ovrLoader:getLyrics()
	local beatmapObject = Luaoop.class.data(self).beatmapObject
	local f = beatmapObject:getFile("lyrics.srt.gz")

	if f then
		return util.decompressToData(f, "gzip")
	else
		f = beatmapObject:getFile("lyrics.srt")

		if f then
			return f
		end
	end

	return nil
end

return function(file)
	local beatmapObject = ls2ovrBeatmap.load(file)
	local beatmapCount = beatmapObject:getBeatmapCount()

	if beatmapCount == 1 then
		return ls2ovrLoader(beatmapObject, 1)
	else
		local ret = {}

		for i = 1, beatmapCount do
			ret[i] = ls2ovrLoader(beatmapObject, beatmapCount)
		end

		return ret
	end
end, "file"
