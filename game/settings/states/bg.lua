-- Background Settings
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local async = require("async")
local gamestate = require("gamestate")
local color = require("color")
local loadingInstance = require("loading_instance")
local L = require("language")

local glow = require("game.afterglow")
local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")
local switchSetting = require("game.settings.switch")
local numberSetting = require("game.settings.number")

local bgSetting = gamestate.create {
	images = {}, fonts = {}
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

local function changeBackgroundAsync(obj, v)
	obj.persist.background = backgroundLoader.load(v)
end

local function startChangeBackground(obj, v)
	return async.runFunction(changeBackgroundAsync):run(obj, v)
end

function bgSetting:load()
	glow.clear()

	-- always must be recreated anyway
	self.data.settingData = {
		switchSetting(L"setting:background:loadCustom", "AUTO_BACKGROUND")
			:setPosition(61, 60),
		numberSetting(L"setting:background:image", "BACKGROUND_IMAGE", {min = 1, max = 15})
			:setChangedCallback(self, startChangeBackground)
			:setPosition(61, 554),
	}

	if self.data.back == nil then
		self.data.back = backNavigation(L"setting:stamina")
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addElement(self.data.back, 0, 0)
end

function bgSetting:start()
	if self.persist.background == nil then
		async.runFunction(changeBackgroundAsync):run(self, self.data.settingData[2]:getValue())
	end
end

function bgSetting:update(dt)
	for i = 1, #self.data.settingData do
		self.data.settingData[i]:update(dt)
	end
end

function bgSetting:draw()
	love.graphics.setColor(color.white)
	if self.persist.background then
		love.graphics.draw(self.persist.background)
	end

	for i = 1, #self.data.settingData do
		self.data.settingData[i]:draw()
	end

	return glow.draw()
end

bgSetting:registerEvent("keyreleased", function(_, key)
	if key == "escape" then leave() end
end)

return bgSetting
