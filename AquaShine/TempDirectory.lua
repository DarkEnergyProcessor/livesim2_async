-- Temp directory detection on multiple platforms
-- Part of AquaShine loader
-- See copyright notice in AquaShine.lua

-- An important note when using temp directory:
-- You can't use any love.filesystem.* functions
-- in temp directory. You have to fallback to
-- standard Lua io.* and (FILE*):* methods

local AquaShine = ...
local love = require("love")
local ffi = require("ffi")
local temp_dir

if AquaShine.OperatingSystem == "iOS" then
	-- Use os.getenv("TMPDIR")
	temp_dir = os.getenv("TMPDIR")
	
	if temp_dir then
		if temp_dir:sub(-1) == "/" then
			temp_dir = temp_dir:sub(1, -2)
		end
	else
		-- Fallback
		temp_dir = love.filesystem.getSaveDirectory().."/temp"
		assert(love.filesystem.createDirectory("temp"), "Failed to create directory \"temp\"")
	end
	print("Temp dir i", temp_dir)
elseif AquaShine.OperatingSystem == "Windows" then
	-- Two techniques (the former is more reliable)
	ffi.cdef "uint32_t __stdcall GetTempPathA(uint32_t, char*);"
	
	local buf = ffi.new("char[260]")
	local size = ffi.C.GetTempPathA(259, buf)
	assert(size > 0, "GetTempPathA fail")
	
	for i = 0, size - 1 do
		if buf[i] == 92 then
			buf[i] = 47
		end
	end
	
	if buf[size - 1] == 47 then
		buf[size - 1] = 0
		size = size - 1
	end
	
	temp_dir = ffi.string(buf, size)
	print("Temp dir w", temp_dir)
elseif AquaShine.OperatingSystem == "Android" then
	-- Get internal storage
	if AquaShine.Config.LOVE.AndroidExternalStorage then
		love.filesystem._setAndroidSaveExternal(false)
		love.filesystem.setIdentity(love.filesystem.getIdentity(), true)
	end
	
	temp_dir = love.filesystem.getSaveDirectory().."/../../../cache"
	
	-- Reset back to external storage mode
	if AquaShine.Config.LOVE.AndroidExternalStorage then
		love.filesystem._setAndroidSaveExternal(true)
		love.filesystem.setIdentity(love.filesystem.getIdentity(), true)
	end
	print("Temp dir a", temp_dir)
else	-- Linux & Mac OS X
	temp_dir = (os.getenv("TMPDIR") or
	            os.getenv("TMP") or
	            os.getenv("TEMP") or
	            os.getenv("TEMPDIR") or
	            "/var/tmp"):gsub("^(.+)/$", "%1")
	
	if os.execute("[ -d \""..temp_dir.."\" ]") ~= 0 then
		temp_dir = "/tmp"
		print("Temp dir lx", temp_dir)
	end
end

function AquaShine.GetTempDir()
	return temp_dir
end
