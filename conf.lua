-- Live simulator config
LIVESIM_DELAY = 2000
BACKGROUND_IMAGE = "image/liveback_12.png"
IDOL_IMAGE = {	-- Order: leftmost > rightmost
	"a.png",
	"a.png",
	"a.png",
	"a.png",
	"a.png",
	"a.png",
	"a.png",
	"a.png",
	"a.png"
}
NOTE_SPEED = 0.8
TOKEN_IMAGE = "image/tap_circle/e_icon_08.png"
RANDOM_NOTE_IMAGE = false
STAMINA_DISPLAY = 32
SCORE_ADD_NOTE = 1221	-- Raw score value added when taping a note

-- Love2d config function
function love.conf(t)
	t.identity = "DEPLS"                -- The name of the save directory (string)
	t.version = "0.10.0"                -- The LÖVE version this game was made for (string)
	t.console = true                    -- Attach a console (boolean, Windows only)
	t.accelerometerjoystick = true      -- Enable the accelerometer on iOS and Android by exposing it as a Joystick (boolean)
	t.externalstorage = false           -- True to save files (and read from the save directory) in external storage on Android (boolean) 
	t.gammacorrect = false              -- Enable gamma-correct rendering, when supported by the system (boolean)
	
	t.window.title = "Assembler Output" -- The window title (string)
	t.window.icon = nil                 -- Filepath to an image to use as the window's icon (string)
	t.window.width = 960                -- The window width (number)
	t.window.height = 640               -- The window height (number)
	t.window.borderless = false         -- Remove all border visuals from the window (boolean)
	t.window.resizable = false          -- Let the window be user-resizable (boolean)
	t.window.minwidth = 960             -- Minimum window width if the window is resizable (number)
	t.window.minheight = 640            -- Minimum window height if the window is resizable (number)
	t.window.fullscreen = false         -- Enable fullscreen (boolean)
	t.window.fullscreentype = "desktop" -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
	t.window.vsync = true               -- Enable vertical sync (boolean)
	t.window.msaa = 0                   -- The number of samples to use with multi-sampled antialiasing (number)
	t.window.display = 1                -- Index of the monitor to show the window in (number)
	t.window.highdpi = false            -- Enable high-dpi mode for the window on a Retina display (boolean)
	t.window.x = nil                    -- The x-coordinate of the window's position in the specified display (number)
	t.window.y = nil                    -- The y-coordinate of the window's position in the specified display (number)
	
	t.modules.audio = true              -- Enable the audio module (boolean)
	t.modules.event = true              -- Enable the event module (boolean)
	t.modules.graphics = true           -- Enable the graphics module (boolean)
	t.modules.image = true              -- Enable the image module (boolean)
	t.modules.joystick = false          -- Enable the joystick module (boolean)
	t.modules.keyboard = true           -- Enable the keyboard module (boolean)
	t.modules.math = true               -- Enable the math module (boolean)
	t.modules.mouse = true              -- Enable the mouse module (boolean)
	t.modules.physics = false           -- Enable the physics module (boolean)
	t.modules.sound = true              -- Enable the sound module (boolean)
	t.modules.system = true             -- Enable the system module (boolean)
	t.modules.timer = true              -- Enable the timer module (boolean), Disabling it will result 0 delta time in love.update
	t.modules.touch = false             -- Enable the touch module (boolean)
	t.modules.video = true              -- Enable the video module (boolean)
	t.modules.window = true             -- Enable the window module (boolean)
	t.modules.thread = true             -- Enable the thread module (boolean)
end