-- Live User Interface loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Util = require("util")
local Luaoop = require("libs.Luaoop")
local log = require("logging")
local uibase = require("game.live.uibase")
local ui = {list = {}}

function ui.newLiveUI(name, autoplay, mineff)
	-- MUST RUN IN ASYNC!
	if not(ui.list[name]) then
		error("live ui '"..name.."' not found", 2)
	end

	return ui.list[name](autoplay, mineff)
end

function ui.enum()
	local name = {}
	for k, _ in pairs(ui.list) do
		if k == "sif" then
			table.insert(name, 1, k) -- sif must be at highest
		else
			name[#name + 1] = k
		end
	end

	return name
end

for _, dirs in ipairs(love.filesystem.getDirectoryItems("game/live/ui")) do
	local name = "game/live/ui/"..dirs
	if Util.fileExists(name) and dirs:sub(-4) == ".lua" then
		log.debug("live.ui", "loading ui "..dirs)
		local s, msg = love.filesystem.load(name)
		if s then
			local v = s()
			if Luaoop.class.is(v, uibase) then
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
