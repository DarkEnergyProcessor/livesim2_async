-- Configuration
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

----------------------
-- AquaShine loader --
----------------------
local AquaShine = assert(love.filesystem.load("AquaShine.lua"))({
	Entries = {
		-- name = {minarg, "scriptfile.lua"}
		livesim = {1, "livesim2_cliwrap.lua"},
		livesim_main = {-1, "livesim.lua"},		-- -1 argument means can't be invoked from command-line
		settings = {0, "setting_view.lua"},
		main_menu = {0, "main_menu.lua"},
		beatmap_select = {0, "beatmap_select_wrapper.lua"},
		unit_editor = {0, "unit_editor.lua"},
		unit_selection = {-1, "unit_selection.lua"},
		about = {0, "about_screen.lua"},
		render = {3, "render_livesim.lua"},
		noteloader = {1, "invoke_noteloader.lua"},
		unit_create = {0, "unit_create.lua"},
	},
	DefaultEntry = "main_menu",
	Width = 960,	-- Letterboxing
	Height = 640	-- Letterboxing
})
AquaShine.ParseCommandLineConfig(assert(arg))

------------------
-- /gles switch --
------------------
local enabledpiaware
local gles = AquaShine.GetCommandLineConfig("gles")
local integrated = AquaShine.GetCommandLineConfig("integrated") or AquaShine.GetCommandLineConfig("igpu")
do
	local s, ffi = pcall(require, "ffi")

	if s then
		local setenv_load = function(x) return x.setenv end
		local putenv_load = function(x) return x.SetEnvironmentVariableA end
		local dpiaware = function(x) return x.SetProcessDPIAware end
		ffi.cdef [[
			int NvOptimusEnablement;
			int AmdPowerXpressRequestHighPerformance;
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
        elseif ps then
            if gles then putenv("LOVE_GRAPHICS_USE_OPENGLES", "1") end
            if integrated then putenv("SHIM_MCCOMPAT", "0x800000000") end
        end
        
        if dp then enabledpiaware = setdpiaware end
		
		if dp then enabledpiaware = setdpiaware end
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
	t.identity = "DEPLS"                          -- The name of the save directory (string)
	t.version = "0.10.1"                          -- The LÖVE version this game was made for (string)
	t.console = false                             -- Attach a console (boolean, Windows only)
	t.accelerometerjoystick = false               -- Enable the accelerometer on iOS and Android by exposing it as a Joystick (boolean)
	t.externalstorage = true                      -- True to save files (and read from the save directory) in external storage on Android (boolean) 
	t.gammacorrect = false                        -- Enable gamma-correct rendering, when supported by the system (boolean)
	
	t.window.title = "Live Simulator: 2"          -- The window title (string)
	t.window.icon = "assets/image/icon/icon.png"  -- Filepath to an image to use as the window's icon (string)
	t.window.width = gcfgn("width", 960)          -- The window width (number)
	t.window.height = gcfgn("height", 640)        -- The window height (number)
	t.window.borderless = false                   -- Remove all border visuals from the window (boolean)
	t.window.resizable = true                     -- Let the window be user-resizable (boolean)
	t.window.minwidth = 320                       -- Minimum window width if the window is resizable (number)
	t.window.minheight = 240                      -- Minimum window height if the window is resizable (number)
	t.window.fullscreen = gcfgb("fullscreen")     -- Enable fullscreen (boolean)
	t.window.fullscreentype = "desktop"           -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
	t.window.vsync = vsync(not(gcfgb("novsync"))) -- Enable vertical sync (boolean)
	t.window.msaa = gcfgn("msaa", 0)              -- The number of samples to use with multi-sampled antialiasing (number)
	t.window.display = 1                          -- Index of the monitor to show the window in (number)
	t.window.highdpi = true                       -- Enable high-dpi mode for the window on a Retina display (boolean)
	t.window.x = nil                              -- The x-coordinate of the window's position in the specified display (number)
	t.window.y = nil                              -- The y-coordinate of the window's position in the specified display (number)
	
	-- AquaShine requires event, graphics, image, system, window, timer, and thread
	t.modules.audio = true                        -- Enable the audio module (boolean)
	t.modules.event = true                        -- Enable the event module (boolean)
	t.modules.graphics = true                     -- Enable the graphics module (boolean)
	t.modules.image = true                        -- Enable the image module (boolean)
	t.modules.joystick = false                    -- Enable the joystick module (boolean)
	t.modules.keyboard = true                     -- Enable the keyboard module (boolean)
	t.modules.math = true                         -- Enable the math module (boolean)
	t.modules.mouse = true                        -- Enable the mouse module (boolean)
	t.modules.physics = false                     -- Enable the physics module (boolean)
	t.modules.sound = true                        -- Enable the sound module (boolean)
	t.modules.system = true                       -- Enable the system module (boolean)
	t.modules.timer = true                        -- Enable the timer module (boolean), Disabling it will result 0 delta time in love.update
	t.modules.touch = true                        -- Enable the touch module (boolean)
	t.modules.video = true                        -- Enable the video module (boolean)
	t.modules.window = true                       -- Enable the window module (boolean)
	t.modules.thread = true                       -- Enable the thread module (boolean)
	
	if AquaShine.NewLove and t.window.highdpi and enabledpiaware then enabledpiaware() end
end
