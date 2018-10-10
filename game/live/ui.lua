-- Live User Interface loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local util = require("util")
local Luaoop = require("libs.Luaoop")
local log = require("logging")
local ui = {list = {}}

function ui.newLiveUI(name)
	-- MUST RUN IN ASYNC!
	if not(ui.list[name]) then
		error("live ui '"..name.."' not found", 2)
	end

	return ui.list[name]()
end

for _, dirs in ipairs(love.filesystem.getDirectoryItems("game/live/ui")) do
	local name = "game/live/ui/"..dirs
	if util.fileExists(name) and dirs:sub(-4) == ".lua" then
		log.debug("live.ui", "loading ui "..dirs)
		local s, msg = love.filesystem.load(name)
		if s then
			local v = s()
			if Luaoop.class.is(v, "livesim2.LiveUI") then
				ui.list[dirs:sub(1, -5)] = v
			else
				log.error("live.ui", "cannot load file "..dirs.." (not uibase class)")
			end
		else
			log.error("live.ui", "cannot load file "..dirs.." ("..msg..")")
		end
	end
end

return ui