-- System Information (for bug reporting)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: read_globals DEPLS_VERSION
-- luacheck: read_globals DEPLS_VERSION_NUMBER

local love = require("love")
local color = require("color")
local mainFont = require("font")
local gamestate = require("gamestate")

local backgroundLoader = require("game.background_loader")

local glow = require("game.afterglow")
local backNavigation = require("game.ui.back_navigation")

local sysInfo = gamestate.create {
	images = {},
	fonts = {}
}

-- Build version information
local textString
do
	local sb = {
		"Before reporting bug, please screenshot this window",
		"",
		string.format("Live Simulator: 2 v%s -- %08d", DEPLS_VERSION, DEPLS_VERSION_NUMBER),
	}

	do
		local feature = {}
		if os.getenv("LLA_IS_SET") then
			-- From modified Openal-Soft
			feature[#feature + 1] = "LLA: "..os.getenv("LLA_BUFSIZE").."smp/"..os.getenv("LLA_FREQUENCY").."Hz"
		end

		if jit then
			feature[#feature + 1] = jit.version
			if jit.status() then
				feature[#feature + 1] = "JIT ON"
			end
		end

		sb[#sb + 1] = "Opts: "..table.concat(feature, " ")
		sb[#sb + 1] = ""
	end

	-- System Information
	local sos = love._os
	if sos == "Windows" then
		-- Get Windows Version
		local ffi = require("ffi")
		local ntdll = ffi.load("ntdll")

		ffi.cdef[[
		typedef struct livesim2Win_osVersionInfoExW
		{
			uint32_t  dwOSVersionInfoSize;
			uint32_t  dwMajorVersion;
			uint32_t  dwMinorVersion;
			uint32_t  dwBuildNumber;
			uint32_t  dwPlatformId;
			int16_t  szCSDVersion[128];
			uint16_t wServicePackMajor;
			uint16_t wServicePackMinor;
			uint16_t wSuiteMask;
			uint8_t  wProductType;
			uint8_t  wReserved;
		} livesim2Win_osVersionInfoExW;
		int32_t __stdcall RtlGetVersion(livesim2Win_osVersionInfoExW *);
		]]

		local ver = ffi.new("livesim2Win_osVersionInfoExW")
		if ntdll.RtlGetVersion(ver) == 0 then
			local build = string.format("%d.%d.%d", ver.dwMajorVersion, ver.dwMinorVersion, ver.dwBuildNumber)

			-- List of hardcoded Windows version strings :P
			if ver.dwMajorVersion == 10 then
				local relidf = io.popen("reg query \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\" /v ReleaseId")
				local release = tonumber(relidf:read("*a"):match("ReleaseId%s+REG_SZ%s+(%d+)"))
				relidf:close()

				if release then
					sb[#sb + 1] = string.format("OS: Windows 10 %d (%s)", release, build)
				else
					sb[#sb + 1] = string.format("OS: Windows 10 (%s)", build)
				end
			elseif ver.dwMajorVersion == 6 then
				if ver.dwMinorVersion == 3 then
					sb[#sb + 1] = string.format("OS: Windows 8.1 (%s)", build)
				elseif ver.dwMinorVersion == 2 then
					sb[#sb + 1] = string.format("OS: Windows 8 (%s)", build)
				elseif ver.dwMinorVersion == 1 then
					sb[#sb + 1] = string.format("OS: Windows 7 (%s)", build)
				elseif ver.dwMinorVersion == 0 then
					sb[#sb + 1] = string.format("OS: Windows Vista (%s)", build)
				else
					sb[#sb + 1] = string.format("OS: Windows (%s)", build)
				end
			elseif ver.dwMajorVersion == 5 then
				if ver.dwMinorVersion == 2 then
					sb[#sb + 1] = string.format("OS: Windows XP Professional 64-bit (%s)", build)
				elseif ver.dwMinorVersion == 1 then
					sb[#sb + 1] = string.format("OS: Windows XP (%s)", build)
				else
					sb[#sb + 1] = string.format("OS: Windows (%s)", build)
				end
			else
				sb[#sb + 1] = string.format("OS: Windows (%s)", build)
			end
		else
			sb[#sb + 1] = "OS: Windows"
		end
	elseif sos == "Android" then
		-- Get Android API level
		local out = io.popen("getprop ro.build.version.sdk", "r")
		local sdk = tonumber(out:read("*l"))

		out:close()
		sb[#sb + 1] = "OS: Android (API Level "..sdk..")"
	else
		sb[#sb + 1] = "OS: "..sos
	end
	sb[#sb + 1] = ""
	sb[#sb + 1] = "Renderer: "..table.concat({love.graphics.getRendererInfo()}, " ")
	sb[#sb + 1] = ""
	sb[#sb + 1] = "R/W Directory: "..love.filesystem.getSaveDirectory()
	sb[#sb + 1] = ""

	-- LOVE Information
	do
		local fmts = {}
		local fbos = {}
		local syslim = {}
		local gftr = {}
		local func = love.graphics.getImageFormats or love.graphics.getCompressedImageFormats

		for k, v in pairs(func()) do
			if v then
				fmts[#fmts + 1] = k
			end
		end

		for k, v in pairs(love.graphics.getCanvasFormats()) do
			if v then
				fbos[#fbos + 1] = k
			end
		end

		for k, v in pairs(love.graphics.getSystemLimits()) do
			syslim[#syslim + 1] = string.format("%s=%s", k, tostring(v))
		end

		for k, v in pairs(love.graphics.getSupported()) do
			if v then
				gftr[#gftr + 1] = k
			end
		end

		sb[#sb + 1] = "Image Formats: "..table.concat(fmts, " ")
		sb[#sb + 1] = ""
		sb[#sb + 1] = "Canvas Formats: "..table.concat(fbos, " ")
		sb[#sb + 1] = ""
		sb[#sb + 1] = "System Limits: "..table.concat(syslim, " ")
		sb[#sb + 1] = ""
		sb[#sb + 1] = "Graphics Features: "..table.concat(gftr, " ")
	end

	textString = table.concat(sb, "\n")
end

local function leave()
	return gamestate.leave(nil)
end

function sysInfo:load()
	glow.clear()

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(14)
	end

	if self.data.back == nil then
		self.data.back = backNavigation("System Information")
		self.data.back:addEventListener("mousereleased", leave)
	end

	if self.data.text == nil then
		local font = mainFont.get(20)
		self.data.text = love.graphics.newText(font)
		-- border
		for i = 0, 360, 45 do
			local mag = i % 90 == 0 and 1 or math.sqrt(2)
			local x, y = mag * math.cos(math.rad(i)), mag * math.sin(math.rad(i))
			self.data.text:addf({color.black, textString}, 950, "left", 2 + x, 60 + y)
		end
		self.data.text:addf({color.white, textString}, 950, "left", 2, 60)
	end
	glow.addFixedElement(self.data.back, 0, 0)
end

function sysInfo:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.push()
	love.graphics.origin()
	love.graphics.setColor(color.white80PT)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
	love.graphics.pop()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.text)
	glow.draw()
end

sysInfo:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return sysInfo
