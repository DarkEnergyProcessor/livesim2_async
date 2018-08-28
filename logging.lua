-- Logging
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local log = {dbg = false}

local function getCallingScript()
	return debug.traceback("", 3):match("\nstack traceback:\n\t([^:]+)")
end

-- Default implementation
local function infoImpl(text)
	io.stderr:write("I[", getCallingScript(), "] ", text, "\n")
end
local function warnImpl(text)
	io.stderr:write("W[", getCallingScript(), "] ", text, "\n")
end
local function errorImpl(text)
	io.stderr:write("E[", getCallingScript(), "] ", text, "\n")
end
local function debugImpl(text)
	io.stderr:write("D[", getCallingScript(), "] ", text, "\n")
end

-- Codepath used if ANSI color code is supported
local function setupANSICode()
	local function m(n)
		return string.format("\27[%dm", n)
	end

	function warnImpl(text)
		io.stderr:write(m(1), m(33), "W[", getCallingScript(), "] ", text, m(0), "\n")
	end

	function errorImpl(text)
		io.stderr:write(m(31), "E[", getCallingScript(), "] ", text, m(0), "\n")
	end

	function debugImpl(text)
		io.stderr:write(m(1), m(37), "D[", getCallingScript(), "] ", text, m(0), "\n")
	end
end

if love._os == "Windows" then
	-- Windows can have many options depending on Windows version
	-- * if "ANSICON" environment variable is present (Windows 10 FCU+), then ANSI color code is used
	-- * if it's possible to set VT100 mode to console (Windows 10 Anniv.), then ANSI color code is used
	-- * otherwise, use to Console API for setting color (Windows 10 RTM or older)
	if os.getenv("ANSICON") then
		setupANSICode()
	else
		local hasFFI, ffi = pcall(require, "ffi")
		if hasFFI then
			local bit = require("bit")
			local Kernel32 = ffi.C -- cache namespace
			ffi.cdef [[
				// coord structure
				typedef struct logging_Coord {
					int16_t x, y;
				} logging_Coord;
				// small rect structure
				typedef struct logging_SmallRect {
					int16_t l, t, r, b;
				} logging_SmallRect;
				// CSBI structure
				typedef struct logging_CSBI {
					logging_Coord csbiSize;
					logging_Coord cursorPos;
					int16_t attributes;
					logging_SmallRect windowRect;
					logging_Coord maxWindowSize;
				} logging_CSBI;
				void * __stdcall GetStdHandle(uint32_t );
				int SetConsoleMode(void *, uint32_t );
				int GetConsoleMode(void *, uint32_t *);
				int __stdcall GetConsoleScreenBufferInfo(void *, logging_CSBI *);
				int __stdcall SetConsoleTextAttribute(void *, int16_t );
			]]
			local stderr = Kernel32.GetStdHandle(-12)

			-- Try to use VT100 processing if it's available
			-- Reference: https://bugs.php.net/bug.php?id=72768
			local cmode = ffi.new("uint32_t[1]")
			Kernel32.GetConsoleMode(stderr, cmode);
			-- Try to enable ENABLE_VIRTUAL_TERMINAL_PROCESSING (0x4)
			if Kernel32.SetConsoleMode(stderr, bit.bor(cmode[0], 4)) > 0 then
				-- ENABLE_VIRTUAL_TERMINAL_PROCESSING is supported. Use ANSI color codes
				setupANSICode()
			else
				-- ENABLE_VIRTUAL_TERMINAL_PROCESSING is not supported. Fallback to Console APIs
				local csbi = ffi.new("logging_CSBI[1]")
				local function pushMode(mode)
					Kernel32.GetConsoleScreenBufferInfo(stderr, csbi)
					local m = csbi.attributes
					Kernel32.SetConsoleTextAttribute(stderr, mode)
					return m
				end
				local function popMode(mode)
					Kernel32.SetConsoleTextAttribute(stderr, mode)
					ffi.fill(csbi, ffi.sizeof("logging_CSBI"), 0)
				end

				function warnImpl(text)
					local m = pushMode(0x0004+0x0002+0x0008) -- bright yellow
					io.stderr:write("W[", getCallingScript(), "] ", text, "\n")
					io.stderr:flush()
					popMode(m)
				end

				function errorImpl(text)
					local m = pushMode(0x0004) -- red
					io.stderr:write("E[", getCallingScript(), "] ", text, "\n")
					io.stderr:flush()
					popMode(m)
				end

				function debugImpl(text)
					local m = pushMode(0x0004+0x0002+0x0001+0x0008) -- bright white
					io.stderr:write("D[", getCallingScript(), "] ", text, "\n")
					io.stderr:flush()
					popMode(m)
				end
			end
		end
	end
elseif love._os == "Linux" or love._os == "OS X" then
	-- Well does macOS support this?
	setupANSICode()
elseif love._os == "Android" then
	-- Use android log function if there's FFI access
	-- It's slow but it's better than nothing
	local hasFFI, ffi = pcall(require, "ffi")
	if hasFFI then
		-- I hope this works in Android 7 due to dlopen behaviour changes in Android 7
		local hasLog, llog = pcall(ffi.load, "log")
		if hasLog then
			ffi.cdef [[
				int __android_log_write(int prio, const char *tag, const char *text);
			]]

			function infoImpl(text)
				llog.__android_log_write(4, getCallingScript(), text)
			end

			function warnImpl(text)
				llog.__android_log_write(5, getCallingScript(), text)
			end

			function errorImpl(text)
				llog.__android_log_write(6, getCallingScript(), text)
			end

			function debugImpl(text)
				llog.__android_log_write(3, getCallingScript(), text)
			end
		end
	end
end

function log.info(text)
	return infoImpl(text)
end

function log.warning(text)
	return warnImpl(text)
end

function log.error(text)
	return errorImpl(text)
end

function log.debug(text)
	if log.dbg then
		return debugImpl(text)
	end
end

return log
