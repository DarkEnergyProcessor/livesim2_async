-- Invisible UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local Glow = require("game.afterglow")

local invisibleButton = Luaoop.class("Livesim2.InvisibleButtonUI", Glow.Element)

function invisibleButton:new(w, h)
	self.width, self.height = w, h
end

function invisibleButton.render() end

return invisibleButton
