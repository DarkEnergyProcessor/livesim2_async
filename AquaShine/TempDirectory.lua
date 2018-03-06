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
elseif AquaShine.OperatingSystem == "Android" then
	-- Just read /proc/self/cmdline then construct /data/data/package/cache
	-- FIXME: Probably not work in Android 6.0 or later!
	local f = io.open("/proc/self/cmdline", "r")
	local package = f:read("*a")

	temp_dir = "/data/data/"..package.."/cache"
	f:close()
else	-- Linux & Mac OS X
	temp_dir = (os.getenv("TMPDIR") or
	            os.getenv("TMP") or
	            os.getenv("TEMP") or
	            os.getenv("TEMPDIR") or
	            "/var/tmp"):gsub("^(.+)/$", "%1")
	
	if os.execute("[ -d \""..temp_dir.."\" ]") ~= 0 then
		temp_dir = "/tmp"
	end
end

function AquaShine.GetTempDir()
	return temp_dir
end
