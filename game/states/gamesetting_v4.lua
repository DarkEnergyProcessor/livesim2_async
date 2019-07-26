-- Game settings
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local L = require("language")

local backgroundLoader = require("game.background_loader")

local glow = require("game.afterglow")
local ciButton = require("game.ui.circle_icon_button")

local mipmap = {mipmaps = true}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

-- Setting section frame size is 868x426+50+184
-- Tab selection is 868x62+50+162
local gameSetting = gamestate.create {
	images = {
		navigateBack = {"assets/image/ui/over_the_rainbow/navigate_back.png", mipmap},
	},
	fonts = {}
}

function gameSetting:load()
	glow.clear()
	self.data = self.data or {} -- for sake of luacheck

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(2)
	end


end

function gameSetting:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
end

gameSetting:registerEvent("keyreleased", function(_, k)
	if k == "escape" then
		return leave()
	end
end)

return gameSetting
