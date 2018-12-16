-- Live Setting
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

local liveSetting = gamestate.create {
	images = {}, fonts = {}
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

function liveSetting:load()
	glow.clear()

	self.data.settingData = {
		switchSetting(L"setting:live:customUnits", "CBF_UNIT_LOAD")
			:setPosition(61, 60),
		switchSetting(L"setting:live:minimalEffect", "MINIMAL_EFFECT")
			:setPosition(61, 146),
		numberSetting(L"setting:live:noteSpeed", "NOTE_SPEED", {min = 400, max = 3000, snap = 50})
			:setPosition(61, 232),
		numberSetting(L"setting:live:textScaling", "TEXT_SCALING", {min = 0.5, max = 1, default = 1, snap = 0.1})
			:setPosition(61, 318),
		switchSetting(L"setting:live:skillPopup", "SKILL_POPUP")
			:setPosition(61, 404),
	}

	if self.data.back == nil then
		self.data.back = backNavigation(L"setting:live")
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addElement(self.data.back, 0, 0)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end
end

function liveSetting:update(dt)
	for i = 1, #self.data.settingData do
		self.data.settingData[i]:update(dt)
	end
end

function liveSetting:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)

	for i = 1, #self.data.settingData do
		self.data.settingData[i]:draw()
	end

	return glow.draw()
end

liveSetting:registerEvent("keyreleased", function(_, key)
	if key == "escape" then leave() end
end)

return liveSetting
