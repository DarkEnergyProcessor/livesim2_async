-- Score & Stamina Settings
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local gamestate = require("gamestate")
local color = require("color")
local loadingInstance = require("loading_instance")
local L = require("language")

local glow = require("game.afterglow")
local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")
local switchSetting = require("game.settings.switch")
local numberSetting = require("game.settings.number")

local scoreSetting = gamestate.create {
	images = {}, fonts = {}
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

function scoreSetting:load()
	glow.clear()

	self.data.settingData = {
		numberSetting(L"setting:stamina:score", "SCORE_ADD_NOTE", {min = 100, max = 8192})
			:setPosition(61, 60),
		numberSetting(L"setting:stamina:display", "STAMINA_DISPLAY", {min = 1, max = 99})
			:setPosition(61, 146),
		switchSetting(L"setting:stamina:noFail", "STAMINA_FUNCTIONAL")
			:setPosition(61, 232),
	}

	if self.data.back == nil then
		self.data.back = backNavigation(L"setting:stamina")
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addElement(self.data.back, 0, 0)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end
end

function scoreSetting:update(dt)
	for i = 1, #self.data.settingData do
		self.data.settingData[i]:update(dt)
	end
end

function scoreSetting:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)

	for i = 1, #self.data.settingData do
		self.data.settingData[i]:draw()
	end

	return glow.draw()
end

scoreSetting:registerEvent("keyreleased", function(_, key)
	if key == "escape" then leave() end
end)

return scoreSetting
