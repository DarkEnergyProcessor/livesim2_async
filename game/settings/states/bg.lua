-- Background Settings
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local async = require("async")
local gamestate = require("gamestate")
local color = require("color")
local setting = require("setting")
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

local function setBackgroundDim(obj, v)
	obj.persist.backgroundDim = v / 100
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
		numberSetting(L"setting:background:dim", "LIVESIM_DIM", {min = 0, max = 100})
			:setChangedCallback(self, setBackgroundDim)
			:setPosition(61, 468)
	}

	if self.data.back == nil then
		self.data.back = backNavigation(L"setting:stamina")
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addElement(self.data.back, 0, 0)
end

function bgSetting:start()
	self.persist.backgroundDim = setting.get("LIVESIM_DIM") / 100
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
	if self.persist.background then
		love.graphics.draw(self.persist.background)
	end

	love.graphics.push()
	love.graphics.origin()
	love.graphics.setColor(color.compat(0, 0, 0, self.persist.backgroundDim))
	love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
	love.graphics.pop()

	love.graphics.setColor(color.white)
	for i = 1, #self.data.settingData do
		self.data.settingData[i]:draw()
	end

	love.graphics.setColor(color.white)
	return glow.draw()
end

bgSetting:registerEvent("keyreleased", function(_, key)
	if key == "escape" then leave() end
end)

return bgSetting
