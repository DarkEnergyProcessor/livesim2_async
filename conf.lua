-- Configuration file
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: ignore DEPLS_VERSION
-- luacheck: ignore DEPLS_VERSION_NUMBER

local love = require("love")
love._version = love._version or love.getVersion()

-- Override love.run
love.filesystem.load("run.lua")()
-- Override love.errhand
love.filesystem.load("errorhandler.lua")()

-- Set in main.lua later
DEPLS_VERSION = false
DEPLS_VERSION_NUMBER = false

if love._exe then
	setmetatable(_G, {
		__index = function(_, var) error("Unknown variable "..var, 2) end,
		__newindex = function(_, var) error("New variable not allowed "..var, 2) end,
		__metatable = function(_) error("Global variable protection", 2) end,
	})
end

function love.conf(t)
	t.version = "0.10.0"                -- At the moment. TODO: Remove.
	t.identity = "DEPLS"                -- The name of the save directory (string)
	t.appendidentity = true             -- Search files in source directory before save directory (boolean)
	t.console = false                   -- Attach a console (boolean, Windows only)
	t.accelerometerjoystick = false     -- Enable accelerometer on iOS and Android as a Joystick (boolean)
	t.externalstorage = true            -- True to use external storage on Android (boolean)
	t.gammacorrect = false              -- Enable gamma-correct rendering, when supported by the system (boolean)
	t.window = false                    -- Defer window creation
	t.modules.joystick = false          -- Enable the joystick module (boolean)
	t.modules.physics = false           -- Enable the physics module (boolean)
end
