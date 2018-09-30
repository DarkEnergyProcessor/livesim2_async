-- Game settings
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local backgroundLoader = require("game.background_loader")

local gui = require("libs.fusion-ui")
local backNavigation = require("game.ui.back_navigation")
local longButtonUI = require("game.ui.long_button")

local gameSetting = gamestate.create {
	fonts = {},
	images = {},
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

function gameSetting:load()
	if self.data.settingButtons == nil then
		self.data.settingButtons = {
			longButtonUI.new("General Setting"),
			longButtonUI.new("Volume Setting"),
			longButtonUI.new("Background Setting"),
			longButtonUI.new("Note Style Setting"),
			longButtonUI.new("Live Setting"),
			longButtonUI.new("Score & Stamina Setting"),
			longButtonUI.new("Live User Interface Setting")
		}
	end

	if self.data.back == nil then
		self.data.back = backNavigation.new("Settings", leave)
	end

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end
end

function gameSetting:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)

	backNavigation.draw(self.data.back)
	for i = 1, #self.data.settingButtons do
		longButtonUI.draw(self.data.settingButtons[i], 101, (i - 1) * 78 + 50)
	end

	gui.draw()
end

return gameSetting
