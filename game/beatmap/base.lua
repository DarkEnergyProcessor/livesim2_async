-- Beatmap loader base object
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local util = require("util")
local base = Luaoop.class("beatmap.Base")

-- For getStoryboardData function
-- The function returns table (or nil) with these information:
-- - type = storyboard type (string)
-- - data = storyboard data (string)
-- If "type" is "lua" then it's Lua scripted storyboard.
-- As of writing, only "lua" storyboard is supported, but the
-- API should be able to be extended to have additional storyboard
-- parser

function base.__construct()
	error("attempt to construct abstract class 'Base'", 2)
end

function base.getFormatName()
	error("pure virtual method 'getFormatName'")
	return "readable name", "internal name"
end

function base.getNotesList()
	error("pure virtual method 'getNotesList'", 2)
end

function base.getCustomUnitInformation()
	return {}
end

function base:getDifficultyString()
	local din, dir = self:getStarDifficultyInfo()
	if din > 0 then
		if dir and dir ~= din then
			return string.format("%d\226\152\134 (Random %d\226\152\134)", din, dir)
		else
			return string.format("%d\226\152\134", din)
		end
	end

	return nil
end

function base.getAudioPathList()
	return {} -- audio path, without extension!
end

function base:getAudio()
	local paths = self:getAudioPathList()
	local ext = util.getNativeAudioExtensions()

	for i = 1, #paths do
		local value = util.substituteExtension(paths[i], ext)
		if value then
			return love.filesystem.newFileData(value)
		end
	end

	return nil
end

local function nilret() return nil end
local function zeroret() return 0 end

base.getName = nilret
base.getCoverArt = nilret            -- {title = song title, image = imagedata, info = arr info}
base.getScoreInformation = nilret    -- CBAS order, array
base.getComboInformation = nilret    -- CBAS order, array
base.getStoryboardData = nilret      -- {type = storyboard type, data = storyboard data}
base.getBackground = nilret
base.getScorePerTap = zeroret
base.getStamina = zeroret
base.getNoteStyle = zeroret          -- TODO
base.getLiveClearVoice = nilret      -- same as above
base.getStarDifficultyInfo = zeroret -- star, random_star (2 values, or 1 if random not avail.)

return base
