-- Utilities helper function
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local util = {}

function util.basename(file)
	return ((file:match("^(.+)%..*$") or file):gsub("(.*/)(.*)", "%2"))
end

function util.fileExists(path)
	if love._version >= "11.0" then
		return not(not(love.filesystem.getInfo(path, "file")))
	else
		return love.filesystem.isFile(path)
	end
end

function util.directoryExist(path)
	if love._version >= "11.0" then
		return not(not(love.filesystem.getInfo(path, "directory")))
	else
		return love.filesystem.isDirectory(path)
	end
end

function util.removeExtension(file)
	return file:sub(1, -(file:reverse():find(".", 1, true) or 0) - 1)
end

-- ext nust contain dot
function util.substituteExtension(file, ext, hasext)
	if hasext then
		if util.fileExists(file) then
			return file
		else
			file = util.removeExtension(file)
		end
	end

	for i, v in ipairs(ext) do
		local a = file..v
		if util.fileExists(a) then
			return a
		end
	end

	return nil
end

local supportedAudioExtensions = {".wav", ".ogg", ".mp3"} -- in order
function util.getNativeAudioExtensions()
	return supportedAudioExtensions
end

function util.clamp(value, min, max)
	return math.max(math.min(value, max), min)
end

function util.isCursorSupported()
	if love._version >= "11.0" then
		return love.mouse.isCursorSupported()
	else
		return love.mouse.hasCursor()
	end
end

return util
