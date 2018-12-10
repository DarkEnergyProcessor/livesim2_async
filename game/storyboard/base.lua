-- Base Storyboard class
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local baseStoryboard = Luaoop.class("Livesim2.Storyboard.Base")

function baseStoryboard.__construct()
	error("attempt to construct abstract class 'Livesim2.Storyboard.Base'", 2)
end

function baseStoryboard.update()
	error("pure virtual method 'update'", 2)
end

function baseStoryboard.draw()
	error("pure virtual method 'draw'")
end

function baseStoryboard.setSkillCallback()
	error("pure virtual method 'setSkillCallback'")
end

function baseStoryboard.emitCallback()
	error("pure virtual method 'emitCallback'")
end

return baseStoryboard
