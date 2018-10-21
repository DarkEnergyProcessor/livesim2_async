-- General settings
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local gamestate = require("gamestate")
local color = require("color")
local loadingInstance = require("loading_instance")
local L = require("language")

local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")
local switchSetting = require("game.settings.switch")

local generalSetting = gamestate.create {
	images = {}, fonts = {}
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

function generalSetting:load()
	if self.data.settingData == nil then
		-- TODO: more settings
		self.data.settingData = {
			switchSetting(L"setting:general:nsAccumulation", "NS_ACCUMULATION")
				:setPosition(29, 172),
		}
	end

	if self.data.back == nil then
		self.data.back = backNavigation.new(L"setting:general", leave)
	end

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end
end

function generalSetting:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	backNavigation.draw(self.data.back)

	for i = 1, #self.data.settingData do
		self.data.settingData[i]:draw()
	end
end

generalSetting:registerEvent("keyreleased", function(_, key)
	if key == "escape" then leave() end
end)

return generalSetting
