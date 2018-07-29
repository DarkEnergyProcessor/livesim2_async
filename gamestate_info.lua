-- Simple gamestate to show DEPLS variable
-- luacheck: read_globals DEPLS_VERSION
-- luacheck: read_globals DEPLS_VERSION_NUMBER
local love = require("love")
local gamestate = require("gamestate")
local backgroundLoader = require("game.background_loader")

local info = gamestate.create {
	fonts = {
		main = {"fonts/MTLmr3m.ttf", 16}
	},
	images = {},
	audios = {},
}

function info:load()
	self.data.background = backgroundLoader.load(14)
end

function info:draw()
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(self.data.background)
	love.graphics.setFont(self.assets.fonts.main)
	local str = string.format("Version = %s (%08d)", DEPLS_VERSION, DEPLS_VERSION_NUMBER)
	love.graphics.setColor(0, 0, 0)
	love.graphics.print(str, 5+1.25, 5+1)
	love.graphics.setColor(255, 255, 255)
	love.graphics.print(str, 5, 5)
end

info:registerEvent("keyreleased", function(self, key)
	if key == "escape" then
		local nilvalue = rawget(_G, "anilvalue")
		nilvalue()
		gamestate.leave()
	end
end)

return info
