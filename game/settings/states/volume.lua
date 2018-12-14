-- Volume Settings
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local gamestate = require("gamestate")
local color = require("color")
local loadingInstance = require("loading_instance")
local volume = require("volume")
local L = require("language")

local glow = require("game.afterglow")
local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")
local numberSetting = require("game.settings.number")

local volumeSetting = gamestate.create {
	images = {}, fonts = {}
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

local function setVolumeSetting(name, value)
	return volume.set(name, value * 0.01)
end

function volumeSetting:load()
	glow.clear()

	self.data.settingData = {
		numberSetting(L"setting:volume:master", "MASTER_VOLUME", {min = 0, max = 100, default = 80})
			:setPosition(61, 60)
			:setChangedCallback("master", setVolumeSetting),
		numberSetting(L"setting:volume:song", "SONG_VOLUME", {min = 0, max = 100, default = 80})
			:setPosition(61, 146)
			:setChangedCallback("music", setVolumeSetting),
		numberSetting(L"setting:volume:effect", "SE_VOLUME", {min = 0, max = 100, default = 80})
			:setPosition(61, 232)
			:setChangedCallback("se", setVolumeSetting),
		numberSetting(L"setting:volume:voice", "VOICE_VOLUME", {min = 0, max = 100, default = 80})
			:setPosition(61, 318)
			:setChangedCallback("voice", setVolumeSetting),
	}

	if self.data.back == nil then
		self.data.back = backNavigation(L"setting:volume")
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addElement(self.data.back, 0, 0)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end
end

function volumeSetting:update(dt)
	for i = 1, #self.data.settingData do
		self.data.settingData[i]:update(dt)
	end
end

function volumeSetting:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)

	for i = 1, #self.data.settingData do
		self.data.settingData[i]:draw()
	end

	return glow.draw()
end

volumeSetting:registerEvent("keyreleased", function(_, key)
	if key == "escape" then leave() end
end)

return volumeSetting
