-- Configuration
-- Part of AquaShine loader
-- See copyright notice in AquaShine.lua

----------------------
-- AquaShine loader --
----------------------
local AquaShine = assert(love.filesystem.load("AquaShine/AquaShine.lua"))()
AquaShine.ParseCommandLineConfig(assert(arg))

------------------
-- /gles switch --
------------------
local gles = AquaShine.GetCommandLineConfig("gles")
local integrated = AquaShine.GetCommandLineConfig("integrated") or AquaShine.GetCommandLineConfig("igpu")
do
	local s, ffi = pcall(require, "ffi")

	if s then
		local setenv_load = function(x) return x.setenv end
		local putenv_load = function(x) return x.SetEnvironmentVariableA end
		local dpiaware = function(x) return x.SetProcessDPIAware end
		ffi.cdef [[
			int setenv(const char *envname, const char *envval, int overwrite);
			int __stdcall SetEnvironmentVariableA(const char* envname, const char* envval);
			int __stdcall SetProcessDPIAware();
		]]
		
		local ss, setenv = pcall(setenv_load, ffi.C)
		local ps, putenv = pcall(putenv_load, ffi.C)
		local dp, setdpiaware = pcall(dpiaware, ffi.C)
        
        if ss then
            if gles then setenv("LOVE_GRAPHICS_USE_OPENGLES", "1", 1) end
            if integrated then setenv("SHIM_MCCOMPAT", "0x800000000", 1) setenv("DRI_PRIME", "0", 1) end
			-- Always request compatibility profile
			setenv("LOVE_GRAPHICS_USE_GL2", "1", 1)
        elseif ps then
            if gles then putenv("LOVE_GRAPHICS_USE_OPENGLES", "1") end
            if integrated then putenv("SHIM_MCCOMPAT", "0x800000000") end
			-- Always request compatibility profile
			putenv("LOVE_GRAPHICS_USE_GL2", "1")
        end
        
        if dp then setdpiaware() end
	end
end

local function gcfgn(n, m)
	return tonumber(AquaShine.GetCommandLineConfig(n)) or m
end

local function gcfgb(n)
	return not(not(AquaShine.GetCommandLineConfig(n)))
end

local function vsync(v)
	if AquaShine.NewLove then
		return v == true and 1 or 0
	end
	
	return v
end

------------------------
-- Configuration file --
------------------------
function love.conf(t)
	local conf = AquaShine.Config
	
	t.identity              = assert(conf.LOVE.Identity)
	t.version               = assert(conf.LOVE.Version) > love._version and conf.LOVE.Version or love._version
	t.console               = false
	t.accelerometerjoystick = false
	t.externalstorage       = conf.LOVE.AndroidExternalStorage
	t.gammacorrect          = false
	
	t.window.title          = assert(conf.LOVE.WindowTitle)
	t.window.icon           = conf.LOVE.WindowIcon
	t.window.width          = gcfgn("width", assert(conf.LOVE.Width))
	t.window.height         = gcfgn("height", assert(conf.LOVE.Height))
	t.window.borderless     = false
	t.window.resizable      = conf.LOVE.Resizable
	t.window.minwidth       = conf.LOVE.MinWidth
	t.window.minheight      = conf.LOVE.MinHeight
	t.window.fullscreen     = gcfgb("fullscreen")
	t.window.fullscreentype = "desktop"
	t.window.vsync          = vsync(not(gcfgb("novsync")))
	t.window.msaa           = gcfgn("msaa", 0)
	t.window.display        = 1
	t.window.highdpi        = true
	t.window.x              = nil
	t.window.y              = nil
	
	t.modules.audio         = not(conf.Extensions.DisableAudio)
	t.modules.joystick      = false
	t.modules.physics       = false
	t.modules.sound         = not(conf.Extensions.DisableAudio)
	t.modules.video         = not(conf.Extensions.DisableVideo)
	t.modules.touch         = not(conf.Extensions.NoMultiTouch)
	t.modules.thread        = not(conf.Extensions.DisableThreads)
end
