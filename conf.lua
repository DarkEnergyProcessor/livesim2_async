-- Configuration file
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: globals DEPLS_VERSION
-- luacheck: globals DEPLS_VERSION_NUMBER
-- luacheck: globals DEPLS_VERSION_CODENAME

local love = require("love")
local util = require("util")

love._version = love._version or love.getVersion()

-- Set identity and give game directory a priority
love.filesystem.setIdentity("DEPLS", true)

-- Override love.run
love.filesystem.load("run.lua")()
-- Override love.errhand
love.filesystem.load("errorhandler.lua")()

-- Set in main.lua later
DEPLS_VERSION = false
DEPLS_VERSION_NUMBER = false
DEPLS_VERSION_CODENAME = false

if love._exe then
	setmetatable(_G, {
		__index = function(_, var) error("unknown variable "..var, 2) end,
		__newindex = function(_, var) error("new variable not allowed "..var, 2) end,
		__metatable = function(_) error("global variable protection", 2) end,
	})
end

if love.filesystem.isFused() and util.fileExists("OUTSIDE_ASSET") then
	assert(love.filesystem.mount(love.filesystem.getSourceBaseDirectory(), ""), "failed to load game directory")
end

function love.conf(t)
	t.version = util.compareLOVEVersion(0, 10, 0) >= 0 and love._version or "0.10.0"
	t.identity = "DEPLS"
	t.appendidentity = true             -- Search files in source directory before save directory (boolean)
	t.console = false                   -- Attach a console (boolean, Windows only)
	t.accelerometerjoystick = false     -- Enable accelerometer on iOS and Android as a Joystick (boolean)
	t.externalstorage = true            -- True to use external storage on Android (boolean)
	t.gammacorrect = false              -- Enable gamma-correct rendering, when supported by the system (boolean)
	t.window = false                    -- Defer window creation
	t.modules.audio = false             -- Delay audio module
	t.modules.joystick = false          -- Enable the joystick module (boolean)
	t.modules.physics = false           -- Enable the physics module (boolean)
end
