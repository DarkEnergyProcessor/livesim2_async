-- Language Setting
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local setting = require("setting")
local mainFont = require("font")
local util = require("util")
local L = require("language")

local backgroundLoader = require("game.background_loader")
local liveUI = require("game.live.ui")

local glow = require("game.afterglow")
local backNavigation = require("game.ui.back_navigation")
local longButtonUI = require("game.ui.long_button")

local liveUISetting = gamestate.create {
	fonts = {},
	images = {},
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

-- just a copypasta from gamelang.lua
local function updateString(text, value)
	text:clear()
	util.addTextWithShadow(text, L("setting:liveUI:current", {name = value}), 0, 0)
end

local function setPlayUI(_, value)
	setting.set("PLAY_UI", value.real)
	updateString(value.instance.persist.text, value.real)
end

function liveUISetting:load()
	glow.clear()

	if self.persist.text == nil then
		self.persist.text = love.graphics.newText(mainFont.get(26))
	end

	if self.data.buttonFrame == nil then
		local elements = {}
		for i, v in ipairs(liveUI.enum()) do
			local elem = longButtonUI(v)
			elem:addEventListener("mousereleased", setPlayUI)
			elem:setData({real = v, instance = self})
			elements[i] = elem
		end

		self.data.buttonFrame = elements
	end
	for i = 1, #self.data.buttonFrame do
		glow.addElement(self.data.buttonFrame[i], 101, i * 78 - 28)
	end

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end

	if self.data.back == nil then
		self.data.back = backNavigation(L"setting:liveUI:short")
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addFixedElement(self.data.back, 0, 0)
end

function liveUISetting:start()
	updateString(self.persist.text, setting.get("PLAY_UI"))
end

function liveUISetting:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.persist.text, 480, 8)

	glow.draw()
end

liveUISetting:registerEvent("keyreleased", function(_, key)
	if key == "escape" then leave() end
end)

return liveUISetting
