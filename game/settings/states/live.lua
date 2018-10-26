-- Live Setting
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local gamestate = require("gamestate")
local color = require("color")
local loadingInstance = require("loading_instance")
local L = require("language")

local gui = require("libs.fusion-ui")

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
	if self.data.settingData == nil then
		self.data.settingData = {
			switchSetting(L"setting:live:customUnits", "CBF_UNIT_LOAD")
				:setPosition(61, 60),
			switchSetting(L"setting:live:minimalEffect", "MINIMAL_EFFECT")
				:setPosition(61, 146),
			numberSetting(L"setting:live:noteSpeed", "NOTE_SPEED", {min = 400, max = 3000, snap = 50})
				:setPosition(61, 232),
			numberSetting(L"setting:live:textScaling", "TEXT_SCALING", {min = 0.5, max = 1, default = 0, snap = 0.1})
				:setPosition(61, 318),
		}
	end

	if self.data.back == nil then
		self.data.back = backNavigation.new(L"setting:live", leave)
	end

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
	backNavigation.draw(self.data.back)

	for i = 1, #self.data.settingData do
		self.data.settingData[i]:draw()
	end
	gui.draw()
end

liveSetting:registerEvent("keyreleased", function(_, key)
	if key == "escape" then leave() end
end)

return liveSetting
