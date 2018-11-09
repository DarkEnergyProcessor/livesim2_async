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
local backNavigation = require("game.ui.back_navigation")
local longButtonUI = require("game.ui.long_button")

local gameSetting = gamestate.create {
	fonts = {}, images = {},
}

gamestate.register("settings::general", require("game.settings.states.general"))
gamestate.register("settings::live", require("game.settings.states.live"))
gamestate.register("settings::nstyle", require("game.settings.states.nstyle"))
gamestate.register("settings::score", require("game.settings.states.score"))
gamestate.register("settings::background", require("game.settings.states.bg"))
gamestate.register("settings::liveui", require("game.settings.states.liveui"))
gamestate.register("settings::volume", require("game.settings.states.volume"))

local function makeEnterGamestateFunction(name)
	return function()
		return gamestate.enter(loadingInstance.getInstance(), name)
	end
end

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

function gameSetting:load()
	glow.clear()

	if self.data.settingButtons == nil then
		self.data.settingButtons = {
			longButtonUI(L"setting:general"),
			longButtonUI(L"setting:volume"),
			longButtonUI(L"setting:background"),
			longButtonUI(L"setting:noteStyle"),
			longButtonUI(L"setting:live"),
			longButtonUI(L"setting:stamina"),
			longButtonUI(L"setting:liveUI")
		}
		self.data.settingButtons[1]:addEventListener("mousereleased", makeEnterGamestateFunction("settings::general"))
		self.data.settingButtons[2]:addEventListener("mousereleased", makeEnterGamestateFunction("settings::volume"))
		self.data.settingButtons[3]:addEventListener("mousereleased", makeEnterGamestateFunction("settings::background"))
		self.data.settingButtons[4]:addEventListener("mousereleased", makeEnterGamestateFunction("settings::nstyle"))
		self.data.settingButtons[5]:addEventListener("mousereleased", makeEnterGamestateFunction("settings::live"))
		self.data.settingButtons[6]:addEventListener("mousereleased", makeEnterGamestateFunction("settings::score"))
		self.data.settingButtons[7]:addEventListener("mousereleased", makeEnterGamestateFunction("settings::liveui"))
	end
	for i = 1, #self.data.settingButtons do
		glow.addElement(self.data.settingButtons[i], 101, (i - 1) * 78 + 50)
	end

	if self.data.back == nil then
		self.data.back = backNavigation(L"menu:settings")
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addFixedElement(self.data.back, 0, 0)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end
end

function gameSetting:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	glow.draw()
end

gameSetting:registerEvent("keyreleased", function(_, key)
	if key == "escape" then leave() end
end)

return gameSetting
