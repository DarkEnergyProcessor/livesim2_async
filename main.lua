-- Live Simulator: 2
-- High-performance LL!SIF Live Simulator

--[[---------------------------------------------------------------------------
-- Copyright (c) 2038 Dark Energy Processor Corporation
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.
--]]---------------------------------------------------------------------------

-- Version
DEPLS_VERSION = "2.0-beta3"
DEPLS_VERSION_NUMBER = 01010503	-- xxyyzzww. x = major, y = minor, z = patch, w = pre-release counter

local AquaShine = love._getAquaShineHandle()
AquaShine.SetDefaultFont("MTLmr3m.ttf")

if love.filesystem.isFused() then
	love._getAquaShineHandle = nil
end

--------------------------------
-- Yohane Initialization Code --
--------------------------------
local Yohane = require("Yohane")

Yohane.Platform.ResolveImage = AquaShine.LoadImage
function Yohane.Platform.ResolveAudio(path)
	local s = love.audio.newSource(AquaShine.LoadAudio(path .. ".wav"))
	s:setVolume(AquaShine.LoadConfig("SE_VOLUME", 80) * 0.008)
	
	return s
end

function Yohane.Platform.CloneImage(image_handle)
	return image_handle
end

function Yohane.Platform.CloneAudio(audio)
	if audio then
		return audio:clone()
	end
	
	return nil
end

function Yohane.Platform.PlayAudio(audio)
	if audio then
		audio:stop()
		audio:play()
	end
end

function Yohane.Platform.Draw(drawdatalist)
	local r, g, b, a = love.graphics.getColor()
	
	for _, drawdata in ipairs(drawdatalist) do
		if drawdata.image then
			love.graphics.setColor(drawdata.r / 255, drawdata.g / 255, drawdata.b / 255, drawdata.a / 255)
			love.graphics.draw(drawdata.image, drawdata.x, drawdata.y, drawdata.rotation, drawdata.scaleX, drawdata.scaleY)
		end
	end
	
	love.graphics.setColor(r, g, b, a)
end

function Yohane.Platform.OpenReadFile(fn)
	return assert(love.filesystem.newFile(fn, "r"))
end

Yohane.Init(love.filesystem.load)

-------------------------------------------
-- Live Simulator: 2 binary beatmap init --
-------------------------------------------
local ls2 = require("ls2")

-- LOVE File object to be FILE*-like object
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
			assert(false, "Invalid whence")
		end
		
		stream:seek(set + (offset or 0))
		return stream:tell()
	end
}

--------------------------
-- Lua Storyboard setup --
--------------------------
local LuaStoryboard = require("luastoryboard2")
LuaStoryboard._SetAquaShine(AquaShine)

----------------------------
-- Force Create Directory --
----------------------------
assert(love.filesystem.createDirectory("audio"), "Failed to create directory \"audio\"")
assert(love.filesystem.createDirectory("beatmap"), "Failed to create directory \"beatmap\"")
assert(love.filesystem.createDirectory("live_icon"), "Failed to create directory \"live_icon\"")
assert(love.filesystem.createDirectory("screenshots"), "Failed to create directory \"screenshots\"")
assert(love.filesystem.createDirectory("temp"), "Failed to create directory \"temp\"")
assert(love.filesystem.createDirectory("unit_icon"), "Failed to create directory \"unit_icon\"")
