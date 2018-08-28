-- Live User Interface loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local util = require("util")
local Luaoop = require("libs.Luaoop")
local ui = {list = {}}

function ui.newLiveUI(name)
	-- MUST RUN IN ASYNC!
	if not(ui.list[name]) then
		error("live ui '"..name.."' not found", 2)
	end

	return ui.list[name]()
end

for dirs in ipairs(love.filesystem.getDirectoryItems("game/live/ui")) do
	local name = "game/live/ui"..dirs
	if util.fileExists(name) and dirs:sub(-4) == ".lua" then
		local s = love.filesystem.load(name)
		if s then
			local v = s()
			if Luaoop.class.is(v, "livesim2.LiveUI") then
				ui.list[dirs:sub(1, -5)] = v
			end
		end
	end
end

return ui
