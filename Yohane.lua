-- Yohane FLSH abstraction layer
-- Base tables. You only need to "require" this then
-- call Yohane.Init()

local isInitialized = false
local memreadstream = {}
local Yohane = {
	Platform = {}
}

---------------------------------------------
-- Memory stream code, copied from Shelsha --
---------------------------------------------
function memreadstream.new(buf)
	local len = #buf + 1
	local buffer = ffi.new("uint8_t["..len.."]", buf)
	local out = {
		pos = 0,
		buflen = len,
		initbuf = buffer,
		curbuf = buffer
	}
	
	return setmetatable(out, {__index = memreadstream})
end

function memreadstream.read(this, bytes)
	local afterpos
	local newbuf
	
	if pos == buflen then return end
	
	afterpos = pos + bytes
	
	if afterpos > buflen then
		bytes = bytes - (afterpos - buflen)
	end
	
	newbuf = ffi.string(curbuf, bytes)
	this.curbuf = this.curbuf + bytes
	this.pos = this.pos + bytes
	
	return newbuf
end

function memreadstream.seek(this, whence, offset)
	offset = offset or 0
	whence = whence or cur
	
	if whence == "set" then
		assert(offset > 0 and offset <= buflen, "Invalid seek offset")
		
		this.curbuf = this.initbuf + offset
		this.pos = offset
	elseif whence == "cur" then
		local after = this.pos + offset
		
		assert(after > 0 and after <= buflen, "Invalid seek offset")
		
		this.curbuf = this.curbuf + offset
		this.pos = this.pos + offset
	elseif whence == "end" then
		local after = this.buflen + offset
		
		assert(after > 0 and after <= buflen, "Invalid seek offset")
		
		this.curbuf = this.curbuf + this.buflen + offset
		this.pos = this.buflen + offset
	else
		assert(false, "Invalid seek mode")
	end
	
	return this.pos
end

---------------------------
-- Yohane base functions --
---------------------------

--! @brief Initialize Yohane Flash Abstraction
--! @param loaderfunc Function which behaves like `loadfile` (defaults to `loadfile`)
--! @param sysroot Where does the library file is located? (forward slash,
--!        without trailing slash)
--! @note Calling this if it's already initialized is no-op
function Yohane.Init(loaderfunc, sysroot)
	if isInitialized then return end
	
	loaderfunc = loaderfunc or loadfile
	
	if sysroot then
		Yohane.Flash = assert(loaderfunc(sysroot.."/YohaneFlash.lua"))(Yohane)
		Yohane.Movie = assert(loaderfunc(sysroot.."/YohaneMovie.lua"))(Yohane)
	else
		Yohane.Flash = assert(loaderfunc("YohaneFlash.lua"))(Yohane)
		Yohane.Movie = assert(loaderfunc("YohaneMovie.lua"))(Yohane)
	end
	isInitialized = true
end

--! @brief Converts string to read-only memory stream. Used internally
--! @param str String to convert to memory stream
--! @returns new memorystream object
function Yohane.MakeMemoryStream(str)
	return memreadstream.new(str)
end

function Yohane.newFlashFromStream(stream, movie_name)
	local yf = Yohane.Flash._internal.parseStream(stream)
	
	if movie_name then
		yf:setMovie(movie_name)
	end
	
	return yf
end

function Yohane.newFlashFromString(str, movie_name)
	local yf = Yohane.Flash._internal.parseStream(memreadstream.new(str))
	
	if movie_name then
		yf:setMovie(movie_name)
	end
	
	return yf
end

function Yohane.newFlashFromFilename(fn, movie_name)
	-- By default use io.open
	local f = assert((Yohane.Platform.OpenReadFile or io.open)(fn, "rb"))
	local yf = Yohane.Flash._internal.parseStream(f)
	
	if movie_name then
		yf:setMovie(movie_name)
	end
	
	f:close()
	return yf
end

-- Used internally
function Yohane.CopyTable(table, except)
	local new_table = {}
	
	for a, b in pairs(table) do
		if a ~= except then
			new_table[a] = b
		end
	end
	
	return new_table
end

return Yohane
