-- Utilities helper function
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
require("libs.ls2x")
require("io_open_wide")
local color = require("color")
local hasLVEP = not(not(package.preload.lvep))
local lvep
if hasLVEP then
	lvep = require("lvep")
end

local Util = {}

---@param maj number
---@param min number
---@param rev number
---@return "-1" | "0" | "1"
function Util.compareLOVEVersion(maj, min, rev)
	if love._version_major > maj then
		return 1
	elseif love._version_major < maj then
		return -1
	elseif min then
		if love._version_minor > min then
			return 1
		elseif love._version_minor < min then
			return -1
		elseif rev then
			if love._version_revision > rev then
				return 1
			elseif love._version_revision < rev then
				return -1
			end
		end
	end
	-- equal
	return 0
end

local version11 = Util.compareLOVEVersion(11, 0) >= 0

---@param file string
function Util.basename(file)
	if not(file) then return end
	local x = file:reverse()
	return x:sub(1, (x:find("/") or x:find("\\") or #x + 1) - 1):reverse()
end

function Util.fileExists(path)
	if version11 then
		return not(not(love.filesystem.getInfo(path, "file")))
	else
		return love.filesystem.isFile(path)
	end
end

function Util.directoryExist(path)
	if version11 then
		return not(not(love.filesystem.getInfo(path, "directory")))
	else
		return love.filesystem.isDirectory(path)
	end
end

---@param file string
function Util.removeExtension(file)
	return file:sub(1, -(file:reverse():find(".", 1, true) or 0) - 1)
end

function Util.getExtension(file)
	local pos = file:reverse():find(".", 1, true)
	if not(pos) then return ""
	else return file:sub(-pos + 1):lower() end
end

-- ext nust contain dot
function Util.substituteExtension(file, ext, hasext)
	if hasext then
		if Util.fileExists(file) then
			return file
		else
			file = Util.removeExtension(file)
		end
	end

	for _, v in ipairs(ext) do
		local a = file..v
		if Util.fileExists(a) then
			return a
		end
	end

	return nil
end

local SUPPORTED_AUDIO_EXT = {".wav", ".ogg", ".mp3"} -- in order
function Util.getNativeAudioExtensions()
	return SUPPORTED_AUDIO_EXT
end

---@param value number
---@param min number
---@param max number
function Util.clamp(value, min, max)
	return math.max(math.min(value, max), min)
end

function Util.isCursorSupported()
	if version11 then
		return love.mouse.isCursorSupported()
	else
		return love.mouse.hasCursor()
	end
end

---@param obj love.Object
function Util.releaseObject(obj)
	if version11 then return obj:release() end
	return false
end

---@param sounddata love.SoundData
function Util.getChannelCount(sounddata)
	if version11 then return sounddata:getChannelCount()
	else return sounddata:getChannels() end
end

-- Class for wrapping Lua io file to LOVE file compatible
---@class util.FileWrapper: love.File
local FileWrapClass = Luaoop.class("util.FileWrapper")

---@param path string
---@param file file*
function FileWrapClass:__construct(path, file)
	self.file = file
	self.path = path
end

function FileWrapClass:__destruct()
	if self.file then self.file:close() end
end

function FileWrapClass:read(n)
	return self.file:read(tonumber(n) or "*a")
end

---@param str string|love.Data
---@param size number
function FileWrapClass:write(str, size)
	if type(str) == "userdata" and str:typeOf("Data") then
		str = str:getString()
	end

	return self.file:write(tostring(str):sub(1, size))
end

---@param offset number
function FileWrapClass:seek(offset)
	return self.file:seek("set", offset)
end

function FileWrapClass:tell()
	return self.file:seek("cur")
end

function FileWrapClass:close()
	self.file:close()
	self.file = nil
end

function FileWrapClass:getFilename()
	return self.path
end

---@param path string
---@param mode openmode
---@return util.FileWrapper?
---@return string?
function Util.newFileWrapper(path, mode)
	local file, msg = io.open(path, mode)
	if not(file) then return nil, msg end
	return FileWrapClass(path, file)
end

function Util.isFileWrapped(f)
	return Luaoop.class.is(f, FileWrapClass)
end

---@param text love.Text
---@param str string
---@param x number
---@param y number
---@param intensity number
function Util.addTextWithShadow(text, str, x, y, intensity)
	x = x or 0 y = y or 0
	intensity = intensity or 1
	text:add({color.black, str}, x-intensity, y-intensity)
	text:add({color.black, str}, x+intensity, y+intensity)
	text:add({color.white, str}, x, y)
end

---@param a number
---@param b number
---@param t number
---@return number
---@overload fun(a: NVec, b: NVec, t: number): NVec
function Util.lerp(a, b, t)
	return a * (1 - t) + b * t
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param squared boolean
---@return number
function Util.distance(x1, y1, x2, y2, squared)
	local value = (x2 - x1)^2 + (y2 - y1)^2
	if squared then
		return value
	else
		return math.sqrt(value)
	end
end

---@param n number
---@return "-1" | "0" | "1"
function Util.sign(n)
	return n > 0 and 1 or (n < 0 and -1 or 0)
end

---@param num number
---@param numDecimalPlaces number
---@return number
function Util.round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	local x = num * mult
	if Util.sign(x) >= 0 then
		return math.floor(x + 0.5) / mult
	else
		return math.ceil(x - 0.5) / mult
	end
end

---@generic T: table
---@param orig T
---@return T
function Util.deepCopy(orig)
	if type(orig) == 'table' then
		local copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[orig_key] = Util.deepCopy(orig_value)
		end
		return copy
	else -- number, string, boolean, etc
		return orig
	end
end

function Util.isValueInArray(array, value)
	for i = 1, #array do
		if array[i] == value then
			return i
		end
	end

	return nil
end

function Util.isMobile()
	return love._os == "iOS" or love._os == "Android"
end

function Util.newDecoder(path)
	if hasLVEP then
		local s, v = pcall(love.sound.newDecoder, path)
		if not(s) then
			return lvep.newDecoder(path)
		else
			return v
		end
	else
		return love.sound.newDecoder(path)
	end
end

function Util.newVideoStream(path)
	if hasLVEP then
		local s, v = pcall(love.video.newStream, path)
		if not(s) then
			return lvep.newVideoStream(path)
		else
			return v
		end
	else
		return love.video.newVideoStream(path)
	end
end

function Util.hasExtendedVideoSupport()
	return hasLVEP
end

---@param data string|love.Data
---@param algo love.CompressedDataFormat
---@return love.Data
function Util.decompressToData(data, algo)
	if version11 then
		return love.data.decompress("data", algo, data)
	else
		return love.filesystem.newFileData(love.math.decompress(data, algo), "")
	end
end

if Util.compareLOVEVersion(12, 0) >= 0 then
	function Util.stencil11(fn, action, value, keepvalue)
		love.graphics.setColorMask(false)
		love.graphics.setStencilMode(action, "always", value)
		if not keepvalue then
			love.graphics.clear(false, true, false)
		end
		fn()
		love.graphics.setStencilMode();
		love.graphics.setColorMask(true)
	end

	function Util.setStencilTest11(cmp, val)
		if cmp then
			love.graphics.setStencilMode("keep", cmp, val)
		else
			love.graphics.setStencilMode()
		end
	end

	Util.newFileCompat = love.filesystem.openFile
else
	Util.stencil11 = love.graphics.stencil
	Util.setStencilTest11 = love.graphics.setStencilTest
	Util.newFileCompat = love.filesystem.newFile
end

---@param data string|love.Data
---@param algo love.CompressedDataFormat
---@return string
function Util.decompressToString(data, algo)
	if version11 then
		return love.data.decompress("string", algo, data)
	else
		return love.math.decompress(data, algo)
	end
end

do
	local COLOR_MUL = Util.compareLOVEVersion(11, 0) >= 0 and 1 or 255

	---@param dir '"horizontal"' | '"vertical"'
	---@vararg number[]
	---@return love.Mesh
	function Util.gradient(dir, ...)
		-- Check for direction
		local isHorizontal = true
		if dir == "vertical" then
			isHorizontal = false
		elseif dir ~= "horizontal" then
			error("bad argument #1 to 'gradient' (invalid value)", 2)
		end

		-- Check for colors
		local colorLen = select("#", ...)
		if colorLen < 2 then
			error("color list is less than two", 2)
		end

		-- Generate mesh
		local meshData = {}
		if isHorizontal then
			for i = 1, colorLen do
				local c = select(i, ...)
				local x = (i - 1) / (colorLen - 1)

				meshData[#meshData + 1] = {x, 1, x, 1, c[1], c[2], c[3], c[4] or (1 * COLOR_MUL)}
				meshData[#meshData + 1] = {x, 0, x, 0, c[1], c[2], c[3], c[4] or (1 * COLOR_MUL)}
			end
		else
			for i = 1, colorLen do
				local c = select(i, ...)
				local y = (i - 1) / (colorLen - 1)

				meshData[#meshData + 1] = {1, y, 1, y, c[1], c[2], c[3], c[4] or (1 * COLOR_MUL)}
				meshData[#meshData + 1] = {0, y, 0, y, c[1], c[2], c[3], c[4] or (1 * COLOR_MUL)}
			end
		end

		-- Resulting Mesh has 1x1 image size
		return love.graphics.newMesh(meshData, "strip", "static")
	end
end

if Util.compareLOVEVersion(11, 0) >= 0 then
	---@param w number
	---@param h number
	---@param f love.PixelFormat
	---@param m boolean
	---@return love.Canvas
	function Util.newCanvas(w, h, f, m)
		return love.graphics.newCanvas(w, h, {dpiscale = 1, format = f or "normal", mipmaps = m and "auto" or "none"})
	end
else
	---@param w number
	---@param h number
	---@param f love.PixelFormat
	---@return love.Canvas
	function Util.newCanvas(w, h, f)
		-- No mipmap support
		return love.graphics.newCanvas(w, h, f or "normal")
	end
end

-- Draw text without black fringes
if Util.compareLOVEVersion(11, 3) >= 0 then
	-- https://github.com/love2d/love/commit/02fa8b0
	-- As of that commit, workaround shader to prevent black
	-- fringes is no longer necessary. For compatibility with
	-- previous LOVE versions, this function does nothing.
	---@type fun(text: love.Text, ...)
	Util.drawText = setmetatable({}, {__call = function(self, ...)
		return love.graphics.draw(...)
	end})
else
	---@type fun(text: love.Text, ...)
	Util.drawText = setmetatable({workaroundShader = nil}, {
		__call = function(self, text, ...)
			local shader = love.graphics.getShader()
			love.graphics.setShader(self.workaroundShader)
			love.graphics.draw(text, ...)
			love.graphics.setShader(shader)
		end,
		__index = function(self, var)
			if var == "workaroundShader" then
				local x = love.graphics.newShader("assets/shader/text_workaround.fs")
				rawset(self, "workaroundShader", x)
				return x
			end

			return rawget(self, var)
		end
	})
end

-- Blur drawing
---@type fun(w: number, h: number, s: number, func: fun(...), ...)
Util.drawBlur = setmetatable({shader = nil}, {
	__call = function(self, w, h, s, func, ...)
		local canvas1 = love.graphics.newCanvas(w, h)
		local canvas2 = love.graphics.newCanvas(w, h)

		love.graphics.push("all")
		love.graphics.reset()
		love.graphics.setCanvas(canvas1)
		love.graphics.clear(color.black0PT)
		func(...)
		love.graphics.setBlendMode("alpha", "premultiplied")
		love.graphics.setShader(self.shader)
		self.shader:send("resolution", {w, h})

		while s > 0 do
			local ms = math.min(s, 1)
			love.graphics.setCanvas(canvas2)
			love.graphics.clear(color.black0PT)
			self.shader:send("dir", {ms, 0})
			love.graphics.draw(canvas1)
			love.graphics.setCanvas(canvas1)
			love.graphics.clear(color.black0PT)
			self.shader:send("dir", {0, ms})
			love.graphics.draw(canvas2)
			s = s - 1
		end

		love.graphics.pop()
		Util.releaseObject(canvas2)
		return canvas1
	end,
	__index = function(self, var)
		if var == "shader" then
			local x = love.graphics.newShader("assets/shader/blur9.fs")
			rawset(self, "shader", x)
			return x
		end

		return rawget(self, var)
	end
})

function Util.stringToHex(str)
	local a = {}
	for i = 1, #str do
		a[#a + 1] = string.format("%02x", str:sub(i, i):byte())
	end
	return table.concat(a)
end

---@param text string
---@param delim string
---@param removeempty boolean
---@return string[]
function Util.split(text, delim, removeempty)
	local t = {}

	local b = 0
	while b ~= nil do
		local c, d = text:find(delim, b + 1, true)
		c = c or (#text + 1)

		t[#t + 1] = text:sub(b + 1, c - 1)
		b = d
	end

	if removeempty then
		local a = #t
		while a > 0 and #t[a] == 0 do
			t[a] = nil
			a = a - 1
		end
	end

	return t
end


if version11 then
	local fontDPIScale = 1

	---@return number
	function Util.getFontDPIScale()
		local dpi = love.window and love.window.getDPIScale() or 1
		return dpi > 1 and dpi or (fontDPIScale + 1)
	end

	function Util.setDefaultFontDPIScale(scale)
		fontDPIScale = math.max(math.ceil(scale), 1)
	end
else
	function Util.getFontDPIScale()
		return 1
	end

	function Util.setDefaultFontDPIScale(scale)
	end
end
---@generic T: table, V
---@param t T
---@return fun(table: V[], i?: integer):integer, V
---@return T
---@return integer i
function Util.ipairsi(t, i)
	return ipairs(t), t, i - 1
end

return Util
