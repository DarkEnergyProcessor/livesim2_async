-- Base Storyboard class
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local baseStoryboard = Luaoop.class("Livesim2.Storyboard.Base")

function baseStoryboard.__construct()
	error("attempt to construct abstract class 'Livesim2.Storyboard.Base'", 2)
end

function baseStoryboard.update(dt)
	error("pure virtual method 'update'", 2)
end

function baseStoryboard.draw()
	error("pure virtual method 'draw'", 2)
end

function baseStoryboard.callback(name, ...)
	error("pure virtual method 'callback'", 2)
end

return baseStoryboard
