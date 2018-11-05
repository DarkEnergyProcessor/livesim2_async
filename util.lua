-- Utilities helper function
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local color = require("color")
local version11 = love._version >= "11.0"
local util = {}

function util.basename(file)
	return ((file:match("^(.+)%..*$") or file):gsub("(.*/)(.*)", "%2"))
end

function util.fileExists(path)
	if version11 then
		return not(not(love.filesystem.getInfo(path, "file")))
	else
		return love.filesystem.isFile(path)
	end
end

function util.directoryExist(path)
	if version11 then
		return not(not(love.filesystem.getInfo(path, "directory")))
	else
		return love.filesystem.isDirectory(path)
	end
end

function util.removeExtension(file)
	return file:sub(1, -(file:reverse():find(".", 1, true) or 0) - 1)
end

function util.getExtension(file)
	local pos = file:reverse():find(".", 1, true)
	if not(pos) then return ""
	else return file:sub(-pos + 1) end
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

	for _, v in ipairs(ext) do
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
	if version11 then
		return love.mouse.isCursorSupported()
	else
		return love.mouse.hasCursor()
	end
end

function util.releaseObject(obj)
	if version11 then return obj:release() end
end

function util.getChannelCount(sounddata)
	if version11 then return sounddata:getChannelCount()
	else return sounddata:getChannels() end
end

-- Class for wrapping Lua io file to LOVE file compatible
local fileWrapClass = Luaoop.class("util.FileWrapper")

function fileWrapClass:__construct(path, file)
	self.file = file
	self.path = path
end

function fileWrapClass:__destruct()
	if self.file then self.file:close() end
end

function fileWrapClass:read(n)
	return self.file:read(tonumber(n) or "*a")
end

function fileWrapClass:write(str, size)
	if type(str) == "userdata" and str:typeOf("Data") then
		str = str:getString()
	end

	return self.file:write(tostring(str):sub(1, size))
end

function fileWrapClass:seek(offset)
	return self.file:seek("set", offset)
end

function fileWrapClass:tell()
	return self.file:seek("cur")
end

function fileWrapClass:close()
	self.file:close()
	self.file = nil
end

function fileWrapClass:getFilename()
	return self.path
end

function util.newFileWrapper(path, mode)
	local file, msg = io.open(path, mode)
	if not(file) then return nil, msg end
	return fileWrapClass(path, file)
end

function util.addTextWithShadow(text, str, x, y, intensity)
	x = x or 0 y = y or 0
	intensity = intensity or 1
	text:add({color.black, str}, x-intensity, y-intensity)
	text:add({color.black, str}, x+intensity, y+intensity)
	text:add({color.white, str}, x, y)
end

function util.lerp(a, b, t)
	return a * (1 - t) + b * t
end

return util
