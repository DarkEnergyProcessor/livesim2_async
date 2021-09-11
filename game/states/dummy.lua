-- Dummy gamestate (debug)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Gamestate = require("gamestate")

local dummy = Gamestate.create {fonts = {}, images = {}, audios = {}}

dummy:registerEvent("keyreleased", function(self, key)
	if key == "return" then
		Gamestate.replace(nil, "splash")
	end
end)

return dummy
