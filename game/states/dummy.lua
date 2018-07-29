-- Dummy gamestate (debug)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local gamestate = require("gamestate")

local dummy = gamestate.create {fonts = {}, images = {}, audios = {}}

dummy:registerEvent("keyreleased", function(key)
	if key == "return" then
		gamestate.replace(nil, "splash")
	end
end)

return dummy
