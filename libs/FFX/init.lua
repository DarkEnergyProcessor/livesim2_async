-- FFX choosing wrapper
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local FFX = {}
local lvepLoaded = pcall(require, "lvep")

if lvepLoaded then
	return require("libs.FFX.FFXNative")
else
	return require("libs.FFX.FFX2")
end
